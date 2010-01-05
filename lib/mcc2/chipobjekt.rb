# -*- coding: UTF-8 -*-


require 'mcc2/dataman'

module Mcc2
# diese Klasse ist für die Personalisierung der Chips verantwortlich
class Chip
  # muss vor dem require 'chibbase' kommen
  ENV['CHIPBASE_ENV'] = 'chip32'
  
  # die Chip-Parameter
  attr_accessor :params
  
  # der Kartenleser
  attr_accessor :reader
  
  def initialize
    p "Chip::Initialize"
    @params = []
    (1..anz_params).each{|i|
      @params << ""
    }
  end
	#---------------------------------------------------------------------------------------------------------
  
  # Schließen des Chip-Objekts
  def  close_reader
    @chip_obj.close if @chip_obj
    @chip_obj = nil
  end
	#---------------------------------------------------------------------------------------------------------
  
  # liefert die Anzahl der Parameter zurück, die für Chip-Objekte gespeichert werden sollen
  def anz_params
    23
  end
	#---------------------------------------------------------------------------------------------------------
  
  # personalisiert eine Karte
  # === Parameter
  # +xml_doc+::   die XML-Struktur mit den Definitionen des Kartenlayouts
  # +row+::       ein Datensatz im FasteCSV-Format
  def pers_card(layout_file, row)
    require 'libs/chipcoding/chipbase'
    
    p "pers_card #{row.inspect}"
    # die Chip-Parameter auslesen
    # erst ein leeres Array anlegen
    params = []
    encoding = layout_file.get_attr_value(S_DATASOURCEENCODING)
    
    # un dann die Parameter aus dem XML auslesen und entsprechend ihrer  ID in das Array schreiben
    chip_attrs = layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_CHIP}")
    (1..anz_params).each{|i|
      attr_name = "#{S_PARAM}_#{i}"
      params << DataMan.replace_variables(chip_attrs.find_first(attr_name).content, row, encoding)
    }
    
    # die Personalisierung durchführen
    if params[7] =~ /^RUBY;(.*)/
      @chip_obj ||= Chip32n::ClassLoader.load($1)
    end
     
    @chip_obj.personalize(params)
    
  end
  
end
end

if __FILE__ == $0
  #~ system("ruby mcc2.rb #{ARGV}")
  #~ exit
  
  chip = Chip.new
  
  params = [nil]*chip.anz_params  
  params[0] = 'ohne'
  params[3] = '31382' # Batch
  params[4] = '413' # Card
  params[7] = 'RUBY;i:/THERMO/golf/GOLF_MIF_PLATZREIFE.RB'
  params[10] = 'ffffffffffff'
  params[22] = 'feigusb'
  
  if params[7] =~ /^RUBY;(.*)/
    basename = File.basename($1)
    chip_obj = Chip32n::ClassLoader.load(basename)
  end
   
  chip_obj.personalize(params)
  chip_obj.close
  

end
