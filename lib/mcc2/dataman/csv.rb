# -*- coding: UTF-8 -*-

require 'fastercsv'
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
    @table = FasterCSV.read(fn, :col_sep=>';', :headers=>true)
    @filename = fn
  end

  def headers
    return unless @table
    @table.headers
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  def row(index)
    if @table
      @table[index]
    else
      nil
    end
  end
 	# ---------------------------------------------------------------------------------------------------------
  def rows
    @table
  end

end
end
end
