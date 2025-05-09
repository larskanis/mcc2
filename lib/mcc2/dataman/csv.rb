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

        fail CanNotOpenFile, "Datei nicht gefunden: #{fn.inspect}" unless File.exist?(fn)
        @table = ::CSV.read(fn, col_sep: ";", encoding: "#{encoding}:UTF-8")
        fail DataNotAvailable, "Keine Daten in CSV-Datei #{fn} vorhanden" unless @table

        @header_row = @table.slice!(0) if @table && @table.size > 0

        # convert Array of Arrays to Array of Hashs
        @table = @table.map { |row|
          h = {}
          row.each_with_index { |text, idx|
            h[@header_row[idx]] = text
          }
          h
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
