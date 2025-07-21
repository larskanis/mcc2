require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"

module Mcc2
  module Printer
    class FilePrinter < CardPrinter
      include RmagickDrawer

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
        row_idx = row["row_number"] if row
        documentName = @layout_file.get_attr_value(S_FILEPRINTER_SAVE_AS).gsub("%i", @image_idx.to_s).gsub("%p", page_nr.to_s).gsub("%d", row_idx.to_s)
        documentName = @layout_file.expand_path(documentName)

        self.dpi = @layout_file.get_attr_value(S_FILEPRINTER_DPI).to_f

        page_width = @layout_file.get_attr_value(S_WIDTH).to_f
        page_height = @layout_file.get_attr_value(S_HEIGHT).to_f
        draw_pos_x = @layout_file.get_attr_value(S_X_OFFSET).to_f
        draw_pos_y = @layout_file.get_attr_value(S_Y_OFFSET).to_f

        # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
        selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
        preview = false          # wird nur für Darstellung auf Bildschirm gebraucht

        pic = Magick::ImageList.new
        pic.new_image(mm(page_width), mm(page_height)){ |options| options.background_color = "white" }
        drawing = Magick::Draw.new
        drawing.text_antialias(false)

        tra = Transformation.new
        draw(drawing, tra.translate(mm(draw_pos_x).round, mm(draw_pos_y).round), layout_file, preview, selected_object_id, row, page_nr)

        # Draw in ein Image zeichnen
        drawing.draw(pic)
        pic = postprocess_image(pic, layout_file, page_nr)

        self_dpi = dpi
        pic.write(documentName) do |img|
          img.density = "#{self_dpi}x#{self_dpi}"
        end
      end
    end
  end
end
