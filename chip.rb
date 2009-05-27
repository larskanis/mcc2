# -*- coding: UTF-8 -*-

require 'mcc2'


class Chip
  olddir = Dir.pwd
  Dir.chdir 'chip'
  CHIPDLL = DL.dlopen('chip32n.dll')
  Dir.chdir olddir
  
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

  # diese Methode ruft die Funktion PersonalizeCard in der chip32n.dll auf
  # ==== Parameter
  # +chipparams+:: die Paramter, welche an PersonalizeCard übergeben werden sollen [Array]
  def personalize_card(chipparams)
    @@PersonalizeCard = CHIPDLL['PersonalizeCard', ['L','P'*anz_params].join]
    exception_for_0{
      api_call(@@PersonalizeCard, chipparams)
    }
  end
	#---------------------------------------------------------------------------------------------------------
  
  # diese Methode öffnet die chip32n.dll
  def open_chip32n
  end
	#---------------------------------------------------------------------------------------------------------
  
  # liefert die Anzahl der Parameter zurück, die für Chip-Objekte gespeichert werden sollen
  def anz_params
    22
  end
	#---------------------------------------------------------------------------------------------------------
  
  # personalisiert eine Karte
  def personalize(xml_doc)
    # kontrollieren, ob die DLL schon geöffnet ist, wenn nicht, dann öffnen
    unless Object.const_defined?(:CHIPDLL)
      open_chip32n
    end
    
    
    # die Chip-Parameter auslesen
    
    
    # die auszuführende Aktion ermitteln
    
    # die Personali
    sleep 5
  end
end


if __FILE__ == $0
  chip = Chip.new
  chip.open_chip32n
  chip.personalize_card(['', '', ''])
  p chip.params
end
