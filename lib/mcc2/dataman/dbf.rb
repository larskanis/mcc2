require "mcc2/dataman/base"
require "dbf"

module Mcc2
  module DataMan
    class DBF < Base
      class CanNotOpenFile < RuntimeError
      end

      def initialize(fn, encoding)
        @table = nil

        return if fn.empty?

        raise CanNotOpenFile, "DBF file not found: #{fn.inspect}" unless File.exist?(fn)
        table = ::DBF::Table.new(fn)
        @header_row = table.columns.map { |c| c.name }

        # convert DBF::Table to Array of Hashs
        @table = []
        table.each.with_index(1) do |row, row_number|
          h = {"row_number" => row_number.to_s}
          row.to_a.each_with_index do |text, idx|
            h[@header_row[idx]] = text.to_s.encode("utf-8", encoding)
          end
          @table << h
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
