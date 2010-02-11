# -*- coding: UTF-8 -*-

require 'mcc2/dataman/base'

if RUBY_VERSION < '1.9'
  require 'fastercsv'
  require 'iconv'
else
  require 'csv'
end

module Mcc2
module DataMan
class CSV < Base
  Mcc2::RUBY_18 = Object.const_defined?(:FasterCSV)
  
  class CanNotOpenFile  < RuntimeError
  end
  
  def initialize(datasource, encoding)
    @table = nil

    fn = datasource.strip
    return if fn.empty?
    
    raise CanNotOpenFile, "file not found: #{fn.inspect}" unless File.exists?(fn)
    @table = if RUBY_18
      @iconv = Iconv.new('utf-8', encoding)
      FasterCSV.read(fn, :col_sep=>';')
    else
      ::CSV.read(fn, :col_sep=>';', :encoding=>"#{encoding}:UTF-8")
    end

    @header_row = @table.slice!(0)

    # convert Array of Arrays to Array of Hashs
    @table = @table.map{|row|
      h = {}
      if RUBY_18
        row.each_with_index{|text, idx|
          h[@header_row[idx]] = @iconv.iconv(text)
        }
      else
        row.each_with_index{|text, idx|
          h[@header_row[idx]] = text
        }
      end
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
