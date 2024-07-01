require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"

module Mcc2
  module Printer
    class FilePrinter < CardPrinter
      include RmagickDrawer

      attr_accessor :layout_file

      def initialize
        super
        @image_idx = 0
      end

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

      #--------------------------------------------------------------------------------------------------------------

      def print_card(layout_file, row, chip)
        @layout_file = layout_file

        print_page(row, 0)
        duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE
        if duplex
          print_page(row, 1)
        end

        # ............................................................................................
        # der Chip-Teil, er muss nach dem start_doc und den pages kommen, falls dort Fehler auftreten, wird dieser dan nicht ausgeführt,
        # und keine Karte eingezogen, dann gibt es weniger Probleme mit dem Entfernen von Karten aus dem Drucker, wenn ein Fehler aufgetreten ist
        # Kartenpersonalisierung
        chip&.pers_card(layout_file, row)

        @image_idx += 1

        true
      end

      #--------------------------------------------------------------------------------------------------------------

      def print_page(row, page_nr)
        row_idx = row["mcc2_row_index"] if row
        documentName = @layout_file.get_attr_value(S_FILEPRINTER_SAVE_AS).gsub("%i", @image_idx.to_s).gsub("%p", page_nr.to_s).gsub("%d", row_idx.to_s)

        self.dpi = @layout_file.get_attr_value(S_FILEPRINTER_DPI).to_f
        #    Magick::RVG::dpi = self.dpi

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

        pic.write(documentName)
      end
    end
  end
end
