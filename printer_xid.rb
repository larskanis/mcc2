# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'rubygems'
  require 'printer'
end

require 'Win32API'

begin
  require 'fox16'
  require 'fox16/colors'
rescue LoadError
  require 'fox12'
  require 'fox12/colors'
  $enable_fox12_workaround = true
end
include Fox

class TestMain < FXMainWindow
  def initialize(app)
    # Initialize base class
    super(app, "MCC2", nil, nil, DECOR_ALL, 0, 0, 700, 550)
  end
end

class PrinterXID < Printer
  @@loadCard = Win32API.new('prnsc', '_LoadCardSC@24', ['N','N','N','N','P','N'],  'N')
  @@unloadCard = Win32API.new('prnsc', '_UnloadCardSC@28', ['N','N','N','N','N','N','N'],  'N')
  
  def load_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
    check(ic_type, Integer)
    check(hwndSender, Integer)
    check(nSCSI_ID, Integer)
    check(nHost_ID, Integer)
    check(szPrnName, String)
    check(reserved1, Integer)
    api_call(@@loadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  end
  
  def unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
    check(ic_type, Integer)
    check(hwndSender, Integer)
    check(nSCSI_ID, Integer)
    check(nHost_ID, Integer)
    check(fEject, Integer)
    check(fCardFlip, Integer)
    check(reserved1, Integer)
    api_call(@@unloadCard, ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
  end

  def api_call(apiFunction, *args)
    begin
      return apiFunction.Call(*args)
    rescue RuntimeError => e
      raise show_error
    end
  end
  private :api_call
  
  def check(variable, klass)
    raise "#{variable}, #{variable.class} != #{klass.to_s}" unless variable.kind_of?(klass)
  end
  private :check


end


if __FILE__ == $0
GetDesktopWindow = Win32API.new("user32", "GetDesktopWindow", [], 'L')
GetActiveWindow = Win32API.new("user32", "GetActiveWindow", [], 'L')
h = GetDesktopWindow.Call

  app = FXApp.new("MCC2", "ComCard")
  tm = TestMain.new(app)
#  p self.methods.sort!.each{|e| p e}
  pr = PrinterXID.new
  ic_type = 1     # contact – 0, contactless – 1
  nSCSI_ID = -1   # -1 erster verfügbarer Drucker
  nHost_ID = -1   # -1 erster verfügbarer Drucker
  fEject = 0      # 0 – don’t eject 1 – eject after card moved from smart chip position
  fCardFlip = 0   # 0 – no flip, 1 – flip card when card is moved from smart chip position
  reserved1 = 0
  szPrnName = "DIGID XID440\0"
  #~ p tm.methods.sort!.each{|e| p e}
  hwndSender = h
  pr.load_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, szPrnName, reserved1)
  pr.unload_card(ic_type, hwndSender, nSCSI_ID, nHost_ID, fEject, fCardFlip, reserved1)
end
