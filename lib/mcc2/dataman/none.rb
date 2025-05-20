require "mcc2/dataman/base"

module Mcc2
  module DataMan
    class None < Base
      def initialize(datasource)
        @num_rows = datasource.to_i
        @num_rows = 100 if @num_rows == 0
        @rows = @num_rows.times.map do |row_number|
          { 'row_number' => (row_number + 1).to_s }
        end
      end

      def data_headers
        []
      end

      def row(index)
        @rows[index]
      end

      def rows
        @rows
      end
    end
  end
end
