# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class DataManCSV < DataMan
  def initialize(datasource)
#   puts "\nFile: #{ fname }  #{csv.length} Datensätze"  
#   puts "Erster : #{ csv[0][:vorname] } #{ csv[0][:name] }"  
    @csv = nil
    if datasource && FileTest.exists?(datasource.strip)
      @csv = FasterCSV.read(datasource, :col_sep=>';', :headers=>true, :header_converters=>:symbol)
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

end


if __FILE__ == $0
end
