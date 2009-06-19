# -*- coding: UTF-8 -*-

$: << 'win32'

require 'dataman'


# diese Klasse ist für die Personalisierung der Chips verantwortlich
class Chip
  # muss vor dem require 'chibbase' kommen
  ENV['CHIPBASE_ENV'] = 'chip32'
  require 'libs/chipcoding/chipbase'
  
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
  def pers_card(child, row)
    # die Chip-Parameter auslesen
    # erst ein leeres Array anlegen
    params = []
    encoding = child.layout_file.get_attr_value(S_DATASOURCEENCODING)
    
    # un dann die Parameter aus dem XML auslesen und entsprechend ihrer  ID in das Array schreiben
    chip_attrs = child.layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_CHIP}")
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
    chip_obj = Chip32n::ClassLoader.load($1)
  end
   
  chip_obj.personalize(params)
  chip_obj.close
  

end
