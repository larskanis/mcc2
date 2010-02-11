# -*- coding: UTF-8 -*-


require 'mcc2/constants'
require 'mcc2/dataman/base'

module Mcc2
module LayoutObject
# diese Klasse ist für die Personalisierung der Chips verantwortlich
class Chip
  class InvalidScriptType < RuntimeError
  end
  
  # der Kartenleser
  attr_accessor :reader
  
  def initialize(xml_elem)
    @xml_elem = xml_elem
  end

  # Array der Chip-Parameter
  def params(row=nil)
    (1 .. CHIPPARAM_FIELD_COUNT).inject([]){|params, i|
      attr_name = "#{S_PARAM}_#{i}"
      param = self[attr_name]
      param = DataMan.replace_variables(param, row) if row
      params << param
    }
  end
  
  # Schließen des Chip-Objekts
  def  close_reader
    @chip_obj.close if @chip_obj
    @chip_obj = nil
  end
  
  def [](attr)
    @xml_elem.find_first(attr).content
  end
  
  # personalisiert eine Karte
  # === Parameter
  # +xml_doc+::   die XML-Struktur mit den Definitionen des Kartenlayouts
  # +row+::       ein Datensatz im FasteCSV-Format
  def pers_card(layout_file, row)
    # muss vor dem require 'chipbase' kommen
    ENV['CHIPBASE_ENV'] = 'chip32'
    
    require 'libs/chipcoding/chipbase'
    
    p "pers_card #{row.inspect}"
    # die Chip-Parameter auslesen
    # erst ein leeres Array anlegen
    params = []
    # un dann die Parameter aus dem XML auslesen und entsprechend ihrer  ID in das Array schreiben
    (1 .. CHIPPARAM_FIELD_COUNT).each{|i|
      attr_name = "#{S_PARAM}_#{i}"
      params << DataMan.replace_variables(self[attr_name], row)
    }
    
    # die Personalisierung durchführen
    if params[7] =~ /^RUBY;(.*)/
      @chip_obj ||= Chip32n::ClassLoader.load($1)
    else
      raise InvalidScriptType, "Ungültiges Perso-Script eingestellt"
    end
     
    @chip_obj.personalize(params)
    
  end
  
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
