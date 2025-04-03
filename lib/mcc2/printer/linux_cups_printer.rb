require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"
require 'ffi-cups'

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

      def print_card(layout_file, row, chip)
        @layout_file = layout_file

        printer = Cups::Printer.get_destination(printer_name)

        file_pdf = Tempfile.new(['mcc2', '.pdf'])

        img_pdf = Magick::ImageList.new
        img_pdf << print_page(row, 0)
        duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE
        if duplex
          img_pdf << print_page(row, 1)
        end
        img_pdf.write(file_pdf.path)

        json_str = @layout_file.get_attr_value(S_LINUX_CUPS_OPTIONS)
        options = JSON.parse(json_str)
        job = printer.print_file(file_pdf.path, "MCC2 - #{layout_file.filename}", options)

        chip&.pers_card(layout_file, row)

        true
      end

      #--------------------------------------------------------------------------------------------------------------

      def print_page(row, page_nr)
        self.dpi = @layout_file.get_attr_value(S_LINUX_CUPS_DPI).to_f

        page_width = @layout_file.get_attr_value(S_WIDTH).to_f
        page_height = @layout_file.get_attr_value(S_HEIGHT).to_f
        draw_pos_x = @layout_file.get_attr_value(S_X_OFFSET).to_f
        draw_pos_y = @layout_file.get_attr_value(S_Y_OFFSET).to_f

        # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
        selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
        preview = false          # wird nur für Darstellung auf Bildschirm gebraucht
        img = Magick::RVG.new(mm(page_width), mm(page_height)) do |canvas|
          canvas.background_fill = "white"
          canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
            draw(canvas1, layout_file, preview, selected_object_id, row, page_nr)
          end
        end

        # das RVG in ein Bitmap konvertieren
        pic = img.draw
        pic = postprocess_image(pic, layout_file, page_nr)
        pic
      end
    end
  end
end
