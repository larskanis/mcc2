# -*- coding: UTF-8 -*-

require 'fastercsv'
require 'mcc2/dataman'

module Mcc2
class DataManCSV < DataMan
  def initialize(datasource)
#   puts "\nFile: #{ fname }  #{csv.length} Datensätze"  
#   puts "Erster : #{ csv[0][:vorname] } #{ csv[0][:name] }"  
    @csv = nil
    
    fn = datasource.strip
    if datasource && FileTest.exists?(fn)
      @csv = FasterCSV.read(fn, :col_sep=>';', :headers=>true)
      @filename = fn
    end
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
