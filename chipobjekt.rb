# -*- coding: UTF-8 -*-

$: << 'win32'

require 'win32api_base'

# diese Klasse ist für die Personalisierung der Chips verantwortlich
class Chip < Win32ApiBase
  def chipdll
    return @@chipdll if @@chipdll
    olddir = Dir.pwd
    Dir.chdir 'chip'
    @@chipdll = DL.dlopen('chip32n.dll')
    Dir.chdir olddir
    return @@chipdll
  end
  
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
    @@chipdll = nil
  end
	#---------------------------------------------------------------------------------------------------------

  # diese Methode ruft die Funktion GetReaderError in der chip32n.dll auf
  # ==== Return
  # liefert den Status zurück, ob die Funktion erfolgreich ausgeführt werden konnte [Integer]
  # ==== Parameter
  # +errcode+::     _in_  der Errorcode, der von einer CHIPDLL-Funktion zurückgegeben wurde [Integer]
  # +errmessage+::  _out_ eine Zeifer auf einen nullterminierten String, in dem die Fehlermeldung zurückliefert wird
  def get_reader_error(errcode, errmessage)
    #~ int DllExport GetReaderError (int ErrorCode, char * ErrorMessage);
    @@GetReaderError ||= chipdll['GetReaderError', ['L','Lp'].join]
    api_call(@@GetReaderError, errcode, errmessage)
  end
	#---------------------------------------------------------------------------------------------------------
  
  # diese Methode ruft die Funktion ReaderEjectCard in der chip32n.dll auf
  # ==== Return
  # liefert den Status zurück, ob die Funktion erfolgreich ausgeführt werden konnte [Integer]
  def reader_eject_card
    #~ int DllExport ReaderEjectCard (void);
    @@ReaderEjectCard ||= chipdll['ReaderEjectCard', 'L']
    api_call(@@ReaderEjectCard)
  end
	#---------------------------------------------------------------------------------------------------------
  
  # diese Methode ruft die Funktion IdentifyCard in der chip32n.dll auf
  # ==== Return
  # liefert den Status zurück, ob die Funktion erfolgreich ausgeführt werden konnte [Integer]
  # ==== Parameter
  # ++:: 
  def identify_card(card_code)
    #~ int DllExport IdentifyCard (char * CardCode);
    @@IdentifyCard ||= chipdll['IdentifyCard', ['L','p'].join]
    api_call(@@IdentifyCard, card_code)
  end
	#---------------------------------------------------------------------------------------------------------
  
  # diese Methode ruft die Funktion CloseChipSystem in der chip32n.dll auf
  # ==== Return
  # liefert den Status zurück, ob die Funktion erfolgreich ausgeführt werden konnte [Integer]
  def close_chip_system
    #~ int DllExport CloseChipSystem (void);
    @@CloseChipSystem ||= chipdll['CloseChipSystem', 'L']
    api_call(@@CloseChipSystem)
  end
	#---------------------------------------------------------------------------------------------------------
  
  # diese Methode ruft die Funktion InitSystem in der chip32n.dll auf
  # ==== Return
  # liefert den Status zurück, ob die Funktion erfolgreich ausgeführt werden konnte [Integer]
  # ==== Parameter
  # +comm_id+:: 
  # +comm_settings+:: 
  def init_system(comm_id, comm_settings)
    #~ int DllExport InitChipSystem (int CommID, char * CommSettings);
    @@InitChipSystem ||= chipdll['InitChipSystem', ['L','LP'].join]
    olddir = Dir.pwd
    Dir.chdir 'chip'
      erg = api_call(@@InitChipSystem, comm_id, comm_settings)
    Dir.chdir olddir
    erg
  end
	#---------------------------------------------------------------------------------------------------------
  
  # diese Methode ruft die Funktion PersonalizeCard in der chip32n.dll auf
  # ==== Return
  # liefert den Status zurück, ob die Funktion erfolgreich ausgeführt werden konnte [Integer]
  # ==== Parameter
  # +chipparams+:: die Paramter, welche an PersonalizeCard übergeben werden sollen [Array]
  def personalize_card(chipparams)
    #~ int DllExport PersonalizeCard (long CardNumber, int nargs, char * params[]);
    @@PersonalizeCard ||= chipdll['PersonalizeCard', ['L','L','P'].join]
    p chipparams
    ptrs = DL.malloc((chipparams.length+1)*DL.sizeof('P'))
    ptrs[0,ptrs.size] = chipparams.map{|par|
      ptr = DL.malloc(par.length+1)
      ptr[0,par.length] = par
      ptr[par.length] = "\0"
      [ptr.ptr].pack('V')
    }.join
    p ptrs[0,ptrs.size].unpack("H*")
    #~ ptrs = chipparams.pack('p'*chipparams.length)+"\0\0\0\0"
    #~ p ptrs.unpack("H*")
    api_call(@@PersonalizeCard, chipparams.length, ptrs)
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
  
  
  p chip.init_system(0, "")  
  
  s = DL.malloc(9999)
  chip.get_reader_error(0, s)
  p s.to_s
  
  params = []
  (1..chip.anz_params).each{|i| 
    params <<  ""
  }
  params[0] = 'ohne'
  chip.personalize_card(params)
  p chip.params
  
  chip.close_chip_system
end
