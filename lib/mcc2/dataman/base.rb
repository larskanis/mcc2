module Mcc2
  module DataMan
    class Base
      class BadEncodingError < RuntimeError
      end
      attr_reader :filename

      def headers
        data_headers + meta_headers
      end

      def meta_headers
        DataMan.meta_headers
      end
    end
  end
end
