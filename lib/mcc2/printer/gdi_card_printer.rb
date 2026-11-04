module Mcc2
  module Printer
    class GdiCardPrinter < GdiPrinter
      include CardPrinting

      def initialize
        super
      end
    end
  end
end
