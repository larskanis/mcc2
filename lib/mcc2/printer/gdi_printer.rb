gem "win32api4ruby", ">= 0.2.1"
require "win32api4ruby"
require "mcc2/printer/card_printer"
require "mcc2/printer/svg_drawer"
require "mcc2_c_helper"

Win32api4ruby::Base.unicode = true

module Mcc2
  module Printer
    class GdiPrinter < CardPrinter
      include SvgDrawer
      include SimpleLogging

      attr_accessor :chip

      def with_page(hPrinter, row, page_nr)
        start_page(hPrinter, row, page_nr)
        yield
      ensure
        end_page(hPrinter, row, page_nr)
      end

      def device_name
        layout_file.get_attr_value(S_GDIPRINTER_NAME)
      end

      def device_initdata
        layout_file.get_binary_attr(S_GDIPRINTER_INITDATA)
      end

      # startet das Drucken
      # === Return
      # -
      # === Parameter
      # +layout_file+::
      # +row+:: ein Hash-Objekt
      def print_card(layout_file, row)
        @layout_file = layout_file
        @chip = layout_file.build_chip_instance

        devicename = device_name

        duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE

        if initdata = device_initdata
          initdata = Win32api4ruby::Winspool.create_DEVMOD(initdata)
        else
          raise Printer::Base::ResourceNotFoundError, I18n.t(:error_printer_not_setup, default: "Bitte richten Sie erst den ausgewählten Drucker ein !")
        end

        # einen DeviceContext für den Drucker erzeugen
        hPrinter = Win32api4ruby::Gdi.create_dc(nil, devicename.to_s_win32, nil, initdata)

        begin
          start_doc(hPrinter, row)

          page_nr = 0
          print_page(hPrinter, initdata, row, page_nr)

          if duplex
            page_nr = 1
            print_page(hPrinter, initdata, row, page_nr)
          end

          end_doc(hPrinter, row)
        rescue
          # wenn ein Fehler aufgetreten ist, wird der Druckjob abgebrochen und somit aus der Warteschlange entfernt
          abort_doc(hPrinter, row)
          raise
        end
        Win32api4ruby::Gdi.delete_dc(hPrinter)

        true
      end

      def print_page(hPrinter, initdata, row, page_nr)
        page = prepare_gdi_page(hPrinter, initdata, row, page_nr)
        page.draw
      end

      def start_doc(hPrinter, row)
        datasourcename = layout_file.get_attr_value(S_DATASOURCE)
        # set document title
        row_text = row["row_number"] if row
        if !row_text && row
          row_text = row.sort.map { |k, v| v }.select { |v| v && !v.empty? }.join(",")[0, 50]  # take row-values
        end
        documentName = "MCC #{row_text} #{datasourcename}"
        docinfo = Win32api4ruby::Gdi.create_DOCINFO
        # Store the pointer instance in docinfo to avoid GC'ing
        class << docinfo
          attr_accessor :pDocumentName
        end
        docinfo[:lpszDocName] = docinfo.pDocumentName = documentName.to_s_win32

        Win32api4ruby::Gdi.start_doc(hPrinter, docinfo)
      end

      def end_doc(hPrinter, row)
        Win32api4ruby::Gdi.end_doc(hPrinter)
        GC.start
      end

      def abort_doc(hPrinter, row)
        Win32api4ruby::Gdi.abort_doc(hPrinter)
      end

      class ReadyToSendPage
        attr_reader :row
        attr_reader :page_nr

        # hPrinter, xDest, yDest, dwWidth, dwHeight, xSrc, ySrc, uStartScan, cScanLines, lpvBits, lpbmi, fuColorUse
        def initialize(printer, set_dibits_to_device_args, row, page_nr)
          @args = set_dibits_to_device_args
          @row = row
          @page_nr = page_nr
          @printer = printer
        end

        def draw
          @printer.with_page(@args[0], row, page_nr) do
            Win32api4ruby::Gdi.set_dibits_to_device(*@args)
          end
        end
      end

      private def bin_regexp(text)
        Regexp.new(text.b, Regexp::MULTILINE | Regexp::FIXEDENCODING)
      end

      def prepare_gdi_page(hPrinter, initdata, row, page_nr)
        raise "unterschiedliche X- und Y-Auflösung wird beim Druck nicht unterstützt (#{initdata[:dmPrintQuality].inspect}x#{initdata[:dmYResolution].inspect})" if initdata[:dmYResolution] != initdata[:dmPrintQuality] && initdata[:dmYResolution] != 0 && initdata[:dmPrintQuality] != 0
        self.dpi = [initdata[:dmYResolution], initdata[:dmPrintQuality]].max

        page_width = @layout_file.get_attr_value(S_WIDTH).to_f + card_margin_left + card_margin_right
        page_height = @layout_file.get_attr_value(S_HEIGHT).to_f + card_margin_top + card_margin_bottom
        draw_pos_x = @layout_file.get_attr_value(S_X_OFFSET).to_f - card_margin_left
        draw_pos_y = @layout_file.get_attr_value(S_Y_OFFSET).to_f - card_margin_top

        # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
        selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
        preview = false          # wird nur für Darstellung auf Bildschirm gebraucht

        image_width = mm(page_width).round
        image_height = mm(page_height).round

        svg_data = svg_builder(viewBox: "0 0 #{image_width} #{image_height}") do |svg|
          svg.g(transform: "scale(1 -1) translate(0 -#{image_height})") do
            tra = Transformation.new
            draw(svg, tra, layout_file, preview, selected_object_id, row, page_nr)
          end
        end
        log.info "built svg text"

        svg_handle = RSVG::Handle.new_from_data(svg_data)
        surface = Cairo::ImageSurface.new(Cairo::FORMAT_RGB24, image_width, image_height)
        context = Cairo::Context.new(surface)
        context.set_source_rgb(1.0, 1.0, 1.0)
        context.paint
        context.render_rsvg_handle(svg_handle)
        lpvBits = surface.data
        log.info "rendered to pixels"
        # Convert BGRA data of librsvg to BGR of Win32 print API
        # lpvBits = lpvBits.unpack("a3x"*(lpvBits.bytesize/4)).join
        # The faster converter of BGRA to BGR image data
        lpvBits = Mcc2CHelper.bgra_to_bgr(lpvBits)
        log.info "converted to BGR"

        block_size = 4 # each scanline has to be DWORD padded
        # split the image in single rows
        lpvBits = lpvBits.unpack("a#{image_width * 3}" * image_height).map do |imgrow|
          # align each row to DWORD
          imgrow << "\0" * (block_size - 1 - (imgrow.length - 1 & (block_size - 1)))
        end.join
        log.info "converted to scan lines"

        xDest, yDest, dwWidth, dwHeight, xSrc, ySrc = mm(draw_pos_x), mm(draw_pos_y), image_width, image_height, 0, 0
        uStartScan, cScanLines = 0, dwHeight
        fuColorUse = Win32api4ruby::Gdi::DIB_RGB_COLORS

        lpbmi = Win32api4ruby::Gdi.create_BITMAPINFOHEADER
        lpbmi[:biWidth] = dwWidth
        lpbmi[:biHeight] = dwHeight
        lpbmi[:biPlanes] = 1
        lpbmi[:biBitCount] = 24
        lpbmi[:biCompression] = Win32api4ruby::Gdi::BI_RGB
        lpbmi[:biSizeImage] = lpvBits.length
        lpbmi[:biXPelsPerMeter] = 0
        lpbmi[:biYPelsPerMeter] = 0
        lpbmi[:biClrUsed] = 0
        lpbmi[:biClrImportant] = 0

        ReadyToSendPage.new self, [hPrinter, xDest, yDest, dwWidth, dwHeight, xSrc, ySrc, uStartScan, cScanLines, lpvBits, lpbmi, fuColorUse], row, page_nr
      end

      def start_page(hPrinter, row, page_nr)
        Win32api4ruby::Gdi.start_page(hPrinter)
      end

      def end_page(hPrinter, row, page_nr)
        Win32api4ruby::Gdi.end_page(hPrinter)
      end
    end
  end
end
