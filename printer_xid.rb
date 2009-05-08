# -*- coding: UTF-8 -*-

begin

$: << File.dirname(__FILE__)

if __FILE__ == $0
  require 'mcc2'
end

require 'Win32API'

class PrinterXID < CardPrinter

  prnsc_wrapper = 't:\Project\XID\prnsc_wrapper\prnsc_wrapper.dll'
#  @@loadCard = Win32API.new(prnsc_wrapper, 'LoadCard', ['N','N','N','N','P','N'],  'N')
#  @@unloadCard = Win32API.new(prnsc_wrapper, 'UnloadCard', ['N','N','N','N','N','N','N'],  'N')
  @@test_LoadCard = Win32API.new(prnsc_wrapper, 'test_LoadCard', [],  'N')
  @@test_UnloadCard = Win32API.new(prnsc_wrapper, 'test_UnloadCard', [],  'N')
  
  ERR_NO = 0
  ERR_bad_modus = 1
  ERR_bad_ic = 2
  ERR_bad_flip = 3
  ERR_bad_param_count = 4

  def initialize
    super
#    @sc_printer = 't:\Project\XID\Delphi\Prj_xid_test.exe' # wurde durch die nächste Zeile ersetzt
    @sc_printer = 't:\Project\XID\XID_Card_Loader\XID_Card_Loader.exe'
  end
  
  def load_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
    ruby_printer = TextPrinterControl.new
    check(ic_type, Integer)
    check(hwndSender, Integer)
    check(nSCSI_ID, Integer)
    check(nHost_ID, Integer)
    check(szPrnName, String)
    check(reserved1, Integer)
    ruby_printer.api_call(@@loadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  end
  
  def unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
    ruby_printer = TextPrinterControl.new
    check(ic_type, Integer)
    check(hwndSender, Integer)
    check(nSCSI_ID, Integer)
    check(nHost_ID, Integer)
    check(fEject, Integer)
    check(fCardFlip, Integer)
    check(reserved1, Integer)
    ruby_printer.api_call(@@unloadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
  end

  def unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
    ruby_printer = TextPrinterControl.new
    check(ic_type, Integer)
    check(hwndSender, Integer)
    check(nSCSI_ID, Integer)
    check(nHost_ID, Integer)
    check(fEject, Integer)
    check(fCardFlip, Integer)
    check(reserved1, Integer)
    ruby_printer.api_call(@@unloadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
  end
  
  def test_LC
    p "*"*50
    p "test_LC"
    #~ ruby_printer = TextPrinterControl.new
    #~ erg = ruby_printer.api_call(@@test_LoadCard)
    p system("#{@sc_printer} load contactless no_flip 1")
    status = $?.exitstatus
    p "erg: #{human_status(status)}"
  end
  
  def test_ULC
    p "*"*50
    p "test_ULC"
    #~ ruby_printer = TextPrinterControl.new
    #~ erg = ruby_printer.api_call(@@test_UnloadCard)
    p system("#{@sc_printer} unload contactless no_flip")
    status = $?.exitstatus
    p "erg: #{human_status(status)}"
  end
  
  def test_RLC
    p "*"*50
    p "test_ULC"
    #~ ruby_printer = TextPrinterControl.new
    #~ erg = ruby_printer.api_call(@@test_UnloadCard)
    p system("#{@sc_printer} reject contactless no_flip")
    status = $?.exitstatus
    p "erg: #{human_status(status)}"
  end
  
  def human_status(status)
    if status == ERR_NO then "ok"
    elsif status == ERR_bad_modus then "unbekannte Modus '#{status}' (load, unload, reject)"
    elsif status == ERR_bad_ic then "unbekannter chip-Modus '#{status}' (contact, contactless)"
    elsif status == ERR_bad_flip then "unbekannter flip-Modus '#{status}' (flip, no_flip)" 
    elsif status == ERR_bad_param_count then "falsche Anzahl Parameter!\nAufruf mit #{@sc_printer} MODUS CHIP FLIP"
    else "unbekannte Fehlernummer #{status}"
    end
  end
  
end

if __FILE__ == $0


#~ GetDesktopWindow = Win32API.new("user32", "GetDesktopWindow", [], 'L')
#~ GetActiveWindow = Win32API.new("user32", "GetActiveWindow", [], 'L')
#~ h = GetDesktopWindow.Call

  pr = PrinterXID.new
  pr.test_LC
  #~ pr.test_ULC
  sleep 5
  pr.test_RLC
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