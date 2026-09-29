require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"
require "ffi-cups"

module Mcc2
  module Printer
    class LinuxCupsPrinter < CardPrinter
      include RmagickDrawer

      # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
      def card_margin_left
        0
      end

      def card_margin_right
        0
      end

      def card_margin_top
        0
      end

      def card_margin_bottom
        0
      end

      def printer_name
        layout_file.get_attr_value(S_LINUX_CUPS_PRINTER)
      end

      def mm_to_pt(mm)
        mm / 25.4 * 72.0
      end

      def print_card(layout_file, row)
        chip = layout_file.build_chip_instance
        @layout_file = layout_file
        self.dpi = layout_file.get_attr_value(S_LINUX_CUPS_DPI).to_f

        page_width = @layout_file.get_attr_value(S_WIDTH).to_f
        page_height = @layout_file.get_attr_value(S_HEIGHT).to_f
        image_width = mm(page_width).round
        image_height = mm(page_height).round

        printer = Cups::Printer.get_destination(printer_name)
        file_pdf = Tempfile.new(["mcc2", ".pdf"])

        Cairo::PDFSurface.new(file_pdf.path, mm_to_pt(page_width), mm_to_pt(page_height)) do |surface|
          surface.set_fallback_resolution(dpi, dpi)
          Cairo::Context.new(surface) do |context|
            print_page(context, row, 0, image_width, image_height)
            duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE
            if duplex
              context.show_page
              print_page(context, row, 1, image_width, image_height)
            end
          end
        end

        json_str = @layout_file.get_attr_value(S_LINUX_CUPS_OPTIONS)
        options = JSON.parse(json_str)
        options.transform_values! do |value|
          (value =~ /=(.*)\z/) ? $1 : value # Wert bei "CONST=wert" herausselektieren
        end

        # system("xdg-open", file_pdf.path)
        printer.print_file(file_pdf.path, "MCC2 - #{layout_file.filename}", options)

        chip&.pers_chip(row)

        true
      end

      #--------------------------------------------------------------------------------------------------------------

      def print_page(context, row, page_nr, image_width, image_height)
        draw_pos_x = @layout_file.get_attr_value(S_X_OFFSET).to_f
        draw_pos_y = @layout_file.get_attr_value(S_Y_OFFSET).to_f
        page_width = @layout_file.get_attr_value(S_WIDTH).to_f
        page_height = @layout_file.get_attr_value(S_HEIGHT).to_f

        # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
        selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
        preview = false          # wird nur für Darstellung auf Bildschirm gebraucht

        builder = Nokogiri::XML::Builder.new do |svg|
          svg.svg(xmlns: 'http://www.w3.org/2000/svg', width: "#{page_width/2.54*2}mm", height: "#{page_height/2.54*2}mm", viewBox: "0.5 0.5 #{image_width} #{image_height}") do
            svg.g(transform: "scale(1 1) translate(0 0)") do
              tra = Transformation.new
              draw(svg, tra.translate(mm(draw_pos_x).round, mm(draw_pos_y).round), layout_file, preview, selected_object_id, row, page_nr)
            end
          end
        end
        svg_data = builder.to_xml
        svg_handle = RSVG::Handle.new_from_data(svg_data)
        context.render_rsvg_handle(svg_handle)
      end
    end
  end
end
