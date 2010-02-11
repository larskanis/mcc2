# -*- coding: UTF-8 -*-

if RUBY_VERSION < '1.9'
  require 'fastercsv'
else
  require 'csv'
end
require 'mcc2/dataman/base'

module Mcc2
module DataMan
class CSV < Base
  class CanNotOpenFile  < RuntimeError
  end
  
  def initialize(datasource)
    @table = nil
    
    fn = datasource.strip
    return if fn.empty?
    
    raise CanNotOpenFile, "file not found: #{fn.inspect}" unless File.exists?(fn)
    @table = if RUBY_VERSION < '1.9'
      FasterCSV.read(fn, :col_sep=>';', :headers=>true)
    else
      ::CSV.read(fn, :col_sep=>';', :headers=>true)
    end
    @filename = fn
  end

  def headers
    return unless @table
    @table.headers
  end
  
  def row(index)
    if @table
      @table[index]
    else
      nil
    end
  end

  def rows
    @table
  end

end
end
end
