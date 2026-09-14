require "mcc2/dataman/base"
require "csv"

module Mcc2
  module DataMan
    class CSV < Base
      class CanNotOpenFile < RuntimeError
      end

      class DataNotAvailable < RuntimeError
      end

      def initialize(fn, encoding)
        @table = nil

        return if fn.empty?

        fail CanNotOpenFile, "CSV file not found: #{fn.inspect}" unless File.exist?(fn)
        @table = ::CSV.read(fn, col_sep: ";", encoding: "#{encoding}:UTF-8")
        fail DataNotAvailable, "CSV file #{fn} contains no records" unless @table

        @header_row = @table.slice!(0) if @table && @table.size > 0

        # convert Array of Arrays to Array of Hashs
        @table = @table.map.with_index(1) do |row, row_number|
          h = {"row_number" => row_number.to_s}
          row.each_with_index do |text, idx|
            h[@header_row[idx]] = text
          end
          h
        end
        @filename = fn
      end

      def data_headers
        @header_row
      end

      def row(index)
        return unless @table
        @table[index]
      end

      def rows
        @table
      end
    end
  end
end
