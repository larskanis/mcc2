# -*- coding: UTF-8 -*-

require 'mcc2/dataman/base'
require 'csv'

module Mcc2
module DataMan
class CSV < Base
  class CanNotOpenFile < RuntimeError
  end

  def initialize(datasource, encoding)
    @table = nil

    fn = datasource.strip
    return if fn.empty?

    raise CanNotOpenFile, "file not found: #{fn.inspect}" unless File.exists?(fn)
    ::CSV.read(fn, :col_sep=>';', :encoding=>"#{encoding}:UTF-8")

    @header_row = @table.slice!(0)

    # convert Array of Arrays to Array of Hashs
    @table = @table.map{|row|
      h = {}
      row.each_with_index{|text, idx|
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
