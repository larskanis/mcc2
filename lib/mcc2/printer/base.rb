module Mcc2
  module Printer
    class Base
      class PrintError < RuntimeError
      end

      class ResourceNotFoundError < PrintError
      end

      class InvalidBarcodeData < PrintError
      end
      class DpiDoesntMatch < PrintError
      end

      attr_reader :default_width
      attr_reader :default_height
      attr_reader :default_x_offset
      attr_reader :default_y_offset
      attr_reader :dpi
      attr_accessor :layout_file

      def initialize
        @dpi = 300
        @default_x_offset = 0.0
        @default_y_offset = 0.0
      end

      def dpi=(v)
        v = v.to_f
        if layout_file
          barcode_dpi = layout_file.get_attr_value(S_BARCODE_DPI).to_f
          unless ((barcode_dpi - 0.9) .. (barcode_dpi + 0.9)) === v
            raise DpiDoesntMatch, "Barcode-DPI in der Vorschau (#{format("%0.1f", barcode_dpi)}) und vom Druck (#{format("%0.1f", v)}) sind verschieden. Bitte DPI anpassen und Barcodes neu prüfen!"
          end
        end
        @dpi = v
      end

      # mm to px
      def mm(l)
        @dpi / 25.4 * l
      end

      # points to px
      def pt(l)
        @dpi / 72.0 * l
      end

      def print_page(hPrinter, layout_file, row, page_nr, page_width = default_width, page_height = default_height)
        raise "not implemented"
      end

      def max_pages
        1
      end

      def can_duplex?
        false
      end

      def has_magstripe_engine?
        false
      end
      #--------------------------------------------------------------------------------------------------------------

      def has_contactless_engine?
        false
      end
      #--------------------------------------------------------------------------------------------------------------

      def has_contact_engine?
        false
      end
      #--------------------------------------------------------------------------------------------------------------

      # dies ist nur ein Platzhalter, die eigentlichen Methoden müssen bei den jeweiligen Druckern definiert werden
      def personalize_ms(hPrinter)
      end
      #--------------------------------------------------------------------------------------------------------------

      def set_duplex(hPrinter, state)
        raise "not implemented"
      end
    end
  end
end
