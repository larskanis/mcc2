require "mcc2/dataman/base"
require "dbf"

module Mcc2
  module DataMan
    class DBF < Base
      class CanNotOpenFile < RuntimeError
      end

      def initialize(datasource, encoding)
        @table = nil

        fn = datasource.strip
        return if fn.empty?

        raise CanNotOpenFile, "file not found: #{fn.inspect}" unless File.exist?(fn)
        table = ::DBF::Table.new(fn)
        @header_row = table.columns.map { |c| c.name }

        # convert DBF::Table to Array of Hashs
        @table = []
        table.each { |row|
          h = {}
          row.to_a.each_with_index { |text, idx|
            h[@header_row[idx]] = text.to_s.encode("utf-8", encoding)
          }
          @table << h
        }
        @filename = fn
      end

      def headers
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
