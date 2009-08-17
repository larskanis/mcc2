# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

p "printer_xid"
begin

$: << File.dirname(__FILE__)

#~ if __FILE__ == $0
  #~ require 'mcc2'
#~ end
require 'card_printer'      # die Basisklasse für alle CardPrinter
require 'win32/api'

class ApiPr <Win32ApiBase
end

# diese Klasse definiert einen XID-Drucker
class PrinterXID < CardPrinter
  # falls doch noch auf Aufruf über DLL umgebaut wird, werden folgende Zeilen benötigt
  
  #~ PRNSC = DL.dlopen('prnsc.dll')
  #~ @@LoadCard = PRNSC['_LoadCardSC@24', 'LLLLLPL']
  #~ @@UnloadCard = PRNSC['_UnloadCardSC@28', 'LLLLLLLL']
  
=begin
  prnsc_wrapper = 't:\Project\XID\prnsc_wrapper\prnsc_wrapper.dll'
  PRNSC = DL.dlopen(prnsc_wrapper)
  @@LoadCard = PRNSC['LoadCard', 'LLLLLPL']
  @@UnloadCard = PRNSC['UnloadCard', 'LLLLLLLL']
=end
  #~ @@LoadCard = PRNSC['test_LoadCard', 'LLLLLPL']
  #~ @@UnloadCard = PRNSC['test_UnloadCard', 'LLLLLLLL']

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
  
  # falsche Anzahl übergebener Parameter
  ERR_bad_param_count = 4

  # 
  def initialize
    super
    @sc_printer = 'XID_Card_Loader.exe'
  end

  def w32printer
    @w32printer
  end
  
  # wenn es denn mal funktionieren würde, wäre dies Methode effizienter
  def load_card1(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
    ruby_printer = ApiPr.new
    #~ ruby_printer.check(ic_type, Integer)
    #~ ruby_printer.check(hwndSender, Integer)
    #~ ruby_printer.check(nSCSI_ID, Integer)
    #~ ruby_printer.check(nHost_ID, Integer)
    #~ ruby_printer.check(szPrnName, String)
    #~ ruby_printer.check(reserved1, Integer)
    p ruby_printer.api_call(@@LoadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  end
  
  def unload_card1(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
    ruby_printer = ApiPr.new
    #~ ruby_printer.check(ic_type, Integer)
    #~ ruby_printer.check(hwndSender, Integer)
    #~ ruby_printer.check(nSCSI_ID, Integer)
    #~ ruby_printer.check(nHost_ID, Integer)
    #~ ruby_printer.check(fEject, Integer)
    #~ ruby_printer.check(fCardFlip, Integer)
    #~ ruby_printer.check(reserved1, Integer)
    p ruby_printer.api_call(@@UnloadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
  end
  
  # lädt eine Karte in das SmartCard-Modul des Druckers
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def load_card(nr, timeout)
    reserved1 = '1'
    ic_type = 'contactless'
    flip = 'no_flip'
    system([@sc_printer, 'load', ic_type, flip, nr, timeout].join(" "))
    $?.exitstatus
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # entlädt die Karte aus dem SmartCard-Modul des Druckers und transportiert sie zum Druckmodul
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def unload_card(nr, timeout)
    ic_type = 'contactless'
    flip = 'no_flip'
    system([@sc_printer, 'unload', ic_type, flip, nr, timeout].join(" "))
    $?.exitstatus
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # entlädt die Karte aus dem SmartCard-Modul des Druckers und transportiert sie zum Druckmodul
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def wait_on_print_ready(nr, timeout)
    ic_type = 'contactless' # dummy
    flip = 'no_flip'        # dummy
    system([@sc_printer, 'wait', ic_type, flip, nr, timeout].join(" "))
    $?.exitstatus
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # entlädt die Karte aus dem SmartCard-Modul des Druckers und wirft sie in das Ausschussfach aus
  # wird momentan über ein externes Programm ausgeführt
  # momentan fest definiert: contactless, no_flip
  # === Return
  # Ausführungsstatus (kann mit human_status in Klartext überetzt werden) [Integer]
  def reject_card(nr, timeout)
    ic_type = 'contactless'
    flip = 'no_flip'
    system([@sc_printer, 'reject', ic_type, flip, nr, timeout].join(" "))
    $?.exitstatus
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
  # +layout_file+:: 
  # +row+:: momentan ein CSV-Row-Objekt
  def print_card(layout_file, row, chip)
    #~ set_message_handler
    preview = false
    selected_object_id = nil
    
    #~ devicename = "DIGID XID440 an 192.168.253.157\0" # nur für Tests
    #~ devicename = "DIGIDXID_on_DELL\0" # nur für Tests
    #~ devicename = "Jaws PDF Creator" # nur für Tests
    devicename = "DIGID XID440\0" # todo aus Druckerauswahl übernehmen und in Einstellungen speichern
    
    page_width = default_width + card_margin_left + card_margin_right # vorläufig todo ??? warum eigentlich vorläufig?
    page_height = default_height + card_margin_top + card_margin_bottom # vorläufig todo  ??? warum eigentlich vorläufig?
    
    datasourcename = layout_file.get_attr_value(S_DATASOURCE)
    duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE
    
    # einen DeviceContext für den Drucker erzeugen
    hPrinter = @w32gdi.create_dc( nil, devicename, nil, nil)
    
    # setzt den Durcker in den Duplex- oder Simplexmodus
    set_duplex(hPrinter, duplex)
    
    documentName = "mcc2 - #{datasourcename} - Satz #{}\0"
    #~ p "documentName #{documentName}"
    docinfo = [documentName].pack('px120')
    #~ p "docinfo #{docinfo}"
    begin
      @w32gdi.start_doc(hPrinter, docinfo)
        page_nr = 0
        print_page(hPrinter, layout_file, row, page_nr, page_width , page_height )
        
        if duplex
          page_nr = 1
          print_page(hPrinter, layout_file, row, page_nr, page_width , page_height )
        end
        
        # ............................................................................................
        # der Chip-Teil, er muss nach dem start_doc und den pages kommen, falls dort Fehler auftreten, wird dieser dan nicht ausgeführt, 
        # und keine Karte eingezogen, dann gibt es weniger Probleme mit dem Entfernen von Karten aus dem Drucker, wenn ein Fehler aufgetreten ist
        if chip
          begin
            nr = Time.now.hour * Time.now.min * Time.now.sec
            timeout = 120
            # Karte in Leser einziehen
            load_card(nr, timeout)
            
            # Kartenpersonalisierung
            chip.pers_card(layout_file, row) 
            
            # Karte vom Leser zum Drucken weiter schicken
            unload_card(nr, timeout)
          rescue => e
            reject_card(nr, timeout) # im Fehlerfall die Karte auswerfen, sonst muss man jedes Mal ein Druckerreset machen
            raise
          end
        end
        # ............................................................................................
        
      #~ p "end_doc"
      @w32gdi.end_doc(hPrinter)
      wait_on_print_ready(nr, timeout)
    rescue => e
      # wenn ein Fehler aufgetreten ist, wird der Druckjob abgebrochen und somit aus der Warteschlange entfernt
      @w32gdi.abort_doc(hPrinter)
      raise
    end
    @w32gdi.delete_dc(hPrinter)
    #~ unset_message_handler
    return true
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # 
  def personalize_ms(hPrinter)
    super
    tmpDC = @w32gdi.create_compatible_dc(hPrinter)
    font = @w32gdi.create_font(0, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 0, 0, "Arial\0")
    oldFont = @w32gdi.select_object( tmpDC, font )
    @w32gdi.delete_dc(tmpDC)
    @w32gdi.delete_object(font)
    
    ms_node = layout_file.xml_doc.find_first(S_MAGSTRIPEPARAMS)
    (1..3).each{|spurnr|
      if spurnr == 1
        start_sentinel = '%'
      elsif spurnr == 2
        start_sentinel = ';'
      elsif spurnr == 3
        start_sentinel = '+'
      end
      ms_data = ['~', spurnr.to_s, start_sentinel, ms_node.find_first('ms_spur' + spurnr.to_s).content, "?\0\0\0\0\0"].join
#          lpchText = DL.malloc(ms_data.length + 10) # sicherheitshalber 10 Byte mehr, obwohl laut MSDN max. 4 Byte mehr gebraucht werden
      lpchText = ms_data
      lpRect = DL.malloc(100)
#        draw_text(hdc, lpchText, nCount, lpRect, uFormat)
      p "draw_text"
      p lpchText
      #~ @w32user.draw_text(hPrinter, lpchText, -1, lpRect, 0)
      @w32gdi.text_out(hPrinter, 0, 0, lpchText, lpchText.length)
    }
  end
  #--------------------------------------------------------------------------------------------------------------
  
  # definiert, dass der Drucker duplex drucken kann
  def can_duplex?
    true
  end
  #--------------------------------------------------------------------------------------------------------------
  
  def has_magstripe_engine?
    true
  end
  #--------------------------------------------------------------------------------------------------------------
  
  def has_contactless_engine?
    true
  end
  #--------------------------------------------------------------------------------------------------------------
  
  def has_contact_engine?
    false
  end
  #--------------------------------------------------------------------------------------------------------------
  
  def test_abort(devicename)
    hPrinter = @w32gdi.create_dc( nil, devicename, nil, nil)
    with_doc("abort", hPrinter) do  # todo aussagekräftigen Dokumentnamen übergeben
      #~ with_page(hPrinter) do
      #~ end
    end
  end
  #--------------------------------------------------------------------------------------------------------------
  
  def test_abort1(devicename)
    printer = "\0" * 4
    pdefaults = 0
    pr.w32printer
    pr.w32printer.open_printer(devicename, printer, pdefaults)
    hprinter = printer.unpack('L')[0]

    level = 1
    documentName ="reject_card\0"
    docinfo = [documentName].pack('px120')
    pr.w32printer.start_doc_printer(hprinter, level, docinfo)
      pr.w32printer.start_page_printer(hprinter)
        written =  "\0" * 4
        pr.w32printer.write_printer(hprinter, "Test", 4, written)
        pr.w32printer.write_printer(hprinter, "\f", 1, written)
      pr.w32printer.end_page_printer(hprinter)
    #~ pr.w32printer.abort_printer(hprinter)
    pr.w32printer.end_doc_printer(hprinter)
  end
  #--------------------------------------------------------------------------------------------------------------
  
  #~ '2.  Add window message loop handler: 
  def myWndProc(hwnd, wMsg, wResult, lDocID)
    #~ 132 32 513 243 514 243 533 132 32
    if wMsg == 243
      @quit = true
    end

   
    p wMsg
    if wMsg == WM_PRINT_RESULT
      if wResult == DRV_PRINT_FAILED 
          p "Card print failed."
      elsif wResult == CARD_DONE
          p "Card was printed successfylly."
      end
    end
     
    return @w32user.call_window_proc(@oldWndProc, hwnd, wMsg, wResult, lDocID)
   
  end 
  #--------------------------------------------------------------------------------------------------------------
  
  GWL_WNDPROC = - 4  
  
  #~ 'Printer driver sends this message with print results 
  WM_PRINT_RESULT = 1024 + 6 
   
  #~ 'wParam values for wMsg = WM_PRINT_RESULT will be following: 
  #~ 'printing failed 
  DRV_PRINT_FAILED = 255 
  
  #~ 'Card was printed successfully 
  CARD_DONE = 0 
  #--------------------------------------------------------------------------------------------------------------
  
  WS_VISIBLE = 0x10000000
  
  def create_dummy_window(name='dummy-window')
    @w32user.create_window_ex(0, 'Button', name, WS_VISIBLE, 0,0,100,100, 0, 0, 0, 0)
  end
  
  def set_message_handler(hwnd, &myWndProc)
    cb = DL.callback('LLLLL', myWndProc)
    @oldWndProc = @w32user.set_window_long(hwnd, GWL_WNDPROC, cb) 
    
    #~ loop do
      #~ Win32ApiUser.new.update_window(hwnd)
    #~ end
    
    #~ typedef struct {
        #~ HWND hwnd;
        #~ UINT message;
        #~ WPARAM wParam;
        #~ LPARAM lParam;
        #~ DWORD time;
        #~ POINT pt;
    #~ } MSG, *PMSG;
    msg = DL.malloc(DL.sizeof('LIILLLL'))

    while @w32user.get_message(msg,0,0,0) > 0 && !@quit
      #~ {GetMessage will return True until it gets a WM_OUIT message. 
      #~ So this program will keep running untill you Post a Quit Message}
       
      #~ {Translate any WM_KEYDOWN keyboard Msg to a WM_CHAR message} 
      @w32user.translate_message(msg)
                               
      #~ {this Sends Msg to the address of the 
       #~ "Window Procedure" set in the Resistered
       #~ Window's Class for that window}
      @w32user.dispatch_message(msg)
    end
  end
  #--------------------------------------------------------------------------------------------------------------
  
  def unset_message_handler(hwnd)
    @w32user.set_window_long(hwnd, GWL_WNDPROC, @oldWndProc)
  end
end

if __FILE__ == $0

  #~ system("ruby mcc2.rb #{ARGV}")
  #~ exit
  
  pr = PrinterXID.new
  hwnd = pr.create_dummy_window
  pr.set_message_handler(hwnd, &pr.method(:myWndProc))
  pr.unset_message_handler(hwnd)
  exit


  #~ devicename = '\\\COMFILE1\P0049'
  #~ devicename = "Jaws PDF Creator" # nur für Tests
  devicename = "DIGID XID440\0" # todo aus Druckerauswahl übernehmen und in Einstellungen speichern
  pr = PrinterXID.new
  
  #~ pr.test_abort1(devicename)
  #~ pr.test_abort(devicename)
  
  #~ exit
  
  #~ pr.test_LC
  #~ sleep 5
  #~ pr.test_ULC
  #~ pr.test_RLC
  #~ exit
  
  # die folgenden Zeilen sind durch das Einziehen der Karten über den XID_Card_Loader obsolet geworden
  ic_type = 1     # contact – 0, contactless – 1
  nSCSI_ID = -1   # -1 erster verfügbarer Drucker
  nHost_ID = -1   # -1 erster verfügbarer Drucker
  fEject = 0      # 0 – don’t eject 1 – eject after card moved from smart chip position
  fCardFlip = 0   # 0 – no flip, 1 – flip card when card is moved from smart chip position
  reserved1 = 111
  szPrnName = "DIGID XID440a\0"
  GetDesktopWindow = Win32API.new("user32", "GetDesktopWindow", [], 'L')
  GetActiveWindow = Win32API.new("user32", "GetActiveWindow", [], 'L')
  h = GetDesktopWindow.Call
  p h
  hwndSender = h
  pr.load_card1(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  #~ pr.unload_card1(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
end

rescue Exception => e
  puts "#{e} #{e.backtrace}"
  sleep 3
end