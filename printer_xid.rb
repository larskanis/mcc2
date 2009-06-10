# -*- coding: UTF-8 -*-

begin

$: << File.dirname(__FILE__)

if __FILE__ == $0
  require 'mcc2'
end

# diese Klasse definiert einen XID-Drucker
class PrinterXID < CardPrinter
  # falls doch noch auf Aufruf über DLL umgebaut wird, werden folgende Zeilen benötigt
  #~ prnsc_wrapper = 't:\Project\XID\prnsc_wrapper\prnsc_wrapper.dll'
  #~ @@loadCard = Win32API.new(prnsc_wrapper, 'LoadCard', ['N','N','N','N','P','N'],  'N')
  #~ @@unloadCard = Win32API.new(prnsc_wrapper, 'UnloadCard', ['N','N','N','N','N','N','N'],  'N')
  #~ @@test_LoadCard = Win32API.new(prnsc_wrapper, 'test_LoadCard', [],  'N')
  #~ @@test_UnloadCard = Win32API.new(prnsc_wrapper, 'test_UnloadCard', [],  'N')
  
  # kein Fehler
  ERR_NO = 0
  
  # falscher Modus angegeben
  ERR_bad_modus = 1
  
  # falscher IC-Modus angegeben ('contactless' oder 'contact')
  ERR_bad_ic = 2
  
  # falscher Flip-Modus ('flip' oder 'no_flip')
  ERR_bad_flip = 3
  
  # falsche Anzahl übergener Parameter
  ERR_bad_param_count = 4

  # 
  def initialize(app)
    @app = app
    super()
    @sc_printer = 't:\Project\XID\XID_Card_Loader\XID_Card_Loader.exe'
  end

  # wenn es denn mal funktionieren würde, wäre dies Methode effizienter
  #~ def load_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
    #~ ruby_printer = TextPrinterControl.new
    #~ check(ic_type, Integer)
    #~ check(hwndSender, Integer)
    #~ check(nSCSI_ID, Integer)
    #~ check(nHost_ID, Integer)
    #~ check(szPrnName, String)
    #~ check(reserved1, Integer)
    #~ ruby_printer.api_call(@@loadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  #~ end
  
  #~ def unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
    #~ ruby_printer = TextPrinterControl.new
    #~ check(ic_type, Integer)
    #~ check(hwndSender, Integer)
    #~ check(nSCSI_ID, Integer)
    #~ check(nHost_ID, Integer)
    #~ check(fEject, Integer)
    #~ check(fCardFlip, Integer)
    #~ check(reserved1, Integer)
    #~ ruby_printer.api_call(@@unloadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
  #~ end
  
  # lädt eine Karte in das SmartCard-Modul des Druckers
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def load_card
    reserved1 = '1'
    ic_type = 'contactless'
    flip = 'no_flip'
    system([@sc_printer, 'load', ic_type, flip].join(" "))
    $?.exitstatus
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # entlädt die Karte aus dem SmartCard-Modul des Druckers und transportiert sie zum Druckmodul
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def unload_card
    ic_type = 'contactless'
    flip = 'no_flip'
    system([@sc_printer, 'unload', ic_type, flip].join(" "))
    $?.exitstatus
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # entlädt die Karte aus dem SmartCard-Modul des Druckers und wirft sie in das Ausschussfach aus
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def reject_card
    ic_type = 'contactless'
    flip = 'no_flip'
    system([@sc_printer, 'reject', ic_type, flip].join(" "))
    $?.exitstatus
  end
  #--------------------------------------------------------------------------------------------------------------

  # nur zum Testen
  def test_LC #:nodoc:
    p "*"*50
    p "test_LC"
    #~ ruby_printer = TextPrinterControl.new
    #~ erg = ruby_printer.api_call(@@test_LoadCard)
    p system("#{@sc_printer} load contactless no_flip")
    status = $?.exitstatus
    p "erg: #{human_status(status)}"
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # nur zum Testen
  def test_ULC #:nodoc:
    p "*"*50
    p "test_ULC"
    #~ ruby_printer = TextPrinterControl.new
    #~ erg = ruby_printer.api_call(@@test_UnloadCard)
    p system("#{@sc_printer} unload contactless no_flip")
    status = $?.exitstatus
    p "erg: #{human_status(status)}"
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # nur zum Testen
  def test_RLC #:nodoc:
    p "*"*50
    p "test_ULC"
    #~ ruby_printer = TextPrinterControl.new
    #~ erg = ruby_printer.api_call(@@test_UnloadCard)
    p system("#{@sc_printer} reject contactless no_flip")
    status = $?.exitstatus
    p "erg: #{human_status(status)}"
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # ermittelt aus dem Rückkehrcode einen Klartext für die Fehleranzeige
  # === Return
  # den Klartext [String]
  # === Parameter
  # +status+:: der von load_card, unload_card oder reject_card zurückgelieferte Status [Integer]
  def human_status(status)
    if status == ERR_NO then "ok"
    elsif status == ERR_bad_modus then "unbekannte Modus '#{status}' (load, unload, reject)"
    elsif status == ERR_bad_ic then "unbekannter chip-Modus '#{status}' (contact, contactless)"
    elsif status == ERR_bad_flip then "unbekannter flip-Modus '#{status}' (flip, no_flip)" 
    elsif status == ERR_bad_param_count then "falsche Anzahl Parameter!\nAufruf mit #{@sc_printer} MODUS CHIP FLIP"
    else "unbekannte Fehlernummer #{status}"
    end
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # startet das Drucken 
  # === Return
  # -
  # === Parameter
  # +child+:: das selektierte Layout
  # +row+:: momentan ein CSV-Row-Objekt
  def print(child, row, chip)
    
    preview = false
    selected_object_id = nil
    
    # 
    # der Chip-Teil
    #~ devicename = "Jaws PDF Creator" # nur für Tests
    devicename = "DIGID XID440\0" # todo aus Druckerauswahl übernehmen und in Einstellungen speichern
    if chip
      begin
        # Karte in Leser einziehen
        #~ load_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1) # siehe DLL_Benutzung
        load_card
        
        #~ sleep 2 mal probieren, ob es auch so geht
        
        # Kartenpersonalisierung
        chip.pers_card(child, row)
        
        # Karte vom Leser zum Drucken weiter schicken
        #~ unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1) # siehe DLL_Benutzung
        unload_card
      rescue => e
        reject_card # im Fehlerfall die Karte auswerfen, sonst muss man jedes Mal ein Druckerreset machen
				s = "Fehler bei Kartenpersonalisierung!" + (["Exception in #{__FILE__}: #{e.to_s}"]+e.backtrace).join("\n")
        error_WahlMessage = FXFehlerAuswahlDialog.new(@app, s, 'ok')
        error_WahlMessage.execute
        return false
      end
    end
    
    page_width = default_width + card_margin_left + card_margin_right # vorläufig todo ??? warum eigentlich vorläufig?
    page_height = default_height + card_margin_top + card_margin_bottom # vorläufig todo  ??? warum eigentlich vorläufig?

    datasourcename = child.get_attr_value(S_DATASOURCE)
    duplex = child.get_attr_value(S_DUPLEX) == 'true'
    
    # einen DeviceContext für den Drucker erzeugen
    hPrinter = @w32gdi.create_dc( nil, devicename, nil, nil);
    
    # setzt den Durcker in den Duplex- oder Simplexmodus
    set_duplex(hPrinter, duplex)
    
    with_doc("mcc2 - #{datasourcename} - Satz #{}", hPrinter) do  # todo aussagekräftigen Dokumentnamen übergeben
      page_nr = 0
      print_page(hPrinter, child, row, page_nr, page_width , page_height )
      
      if duplex
        page_nr = 1
        print_page(hPrinter, child, row, page_nr, page_width , page_height )
      end
      
    end
    @w32gdi.delete_dc(hPrinter)
    return true
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # definiert, dass der Drucker duplex drucken kann
  def can_duplex?
    true
  end
  
end

if __FILE__ == $0

  #~ system("ruby mcc2.rb #{ARGV}")
  #~ exit
  

#~ GetDesktopWindow = Win32API.new("user32", "GetDesktopWindow", [], 'L')
#~ GetActiveWindow = Win32API.new("user32", "GetActiveWindow", [], 'L')
#~ h = GetDesktopWindow.Call

  pr = PrinterXID.new
  pr.test_LC
  sleep 5
  pr.test_ULC
  #~ pr.test_RLC
  exit
  
  # die folgenden Zeilen sind durch das Einziehen der Karten über den XID_Card_Loader obsolet geworden
  #~ ic_type = 1     # contact – 0, contactless – 1
  #~ nSCSI_ID = -1   # -1 erster verfügbarer Drucker
  #~ nHost_ID = -1   # -1 erster verfügbarer Drucker
  #~ fEject = 0      # 0 – don’t eject 1 – eject after card moved from smart chip position
  #~ fCardFlip = 0   # 0 – no flip, 1 – flip card when card is moved from smart chip position
  #~ reserved1 = 0
  #~ szPrnName = "DIGID XID440\0"
  #~ hwndSender = h
  #~ pr.load_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  #~ pr.unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
end

rescue Exception => e
  puts "#{e} #{e.backtrace}"
  sleep 3
end