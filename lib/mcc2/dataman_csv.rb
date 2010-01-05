# -*- coding: UTF-8 -*-

require 'fastercsv'
require 'mcc2/dataman'

module Mcc2
class DataManCSV < DataMan
  class CanNotOpenFile  < RuntimeError
  end
  
  def initialize(datasource)
    @csv = nil
    
    fn = datasource.strip
    return if fn.empty?
    
    raise CanNotOpenFile, "file not found: #{fn.inspect}" unless File.exists?(fn)
    @csv = FasterCSV.read(fn, :col_sep=>';', :headers=>true)
    @filename = fn
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  def row(index)
    if @csv
      @csv[index]
    else
      nil
    end
  end
 	# ---------------------------------------------------------------------------------------------------------
  def rows
    @csv
  end

end
end
