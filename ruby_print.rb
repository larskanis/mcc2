if __FILE__ == $0
  require 'Win32API'
end

require "my_winspool"

module Win32
  class TextPrinterControl
    #API FUNCTIONS
    @@PrintDlg = Win32API.new("comdlg32", "PrintDlg", ['P'], 'N')
    @@GlobalLock = Win32API.new('kernel32', 'GlobalLock', ['N'], 'N')
    @@GlobalFree = Win32API.new('kernel32', 'GlobalFree', ['N'], 'N')
    @@GetLastError = Win32API.new('kernel32', 'GetLastError', [],  'N')
    @@FormatMessage = Win32API.new('kernel32', 'FormatMessage', ['N','P','N','N','P','N','P'], 'N')
    
    @@OpenPrinter = Win32API.new('winspool.drv', 'OpenPrinter', ['P','P','P'],  'N')
    @@ClosePrinter = Win32API.new('winspool.drv', 'ClosePrinter', ['N'], 'N')
    @@AbortPrinter = Win32API.new('winspool.drv', 'AbortPrinter', ['N'], 'N')
    @@StartDocPrinter = Win32API.new('winspool.drv', 'StartDocPrinter', ['N','N','P'],  'N')
    @@EndDocPrinter = Win32API.new('winspool.drv', 'EndDocPrinter', ['N'], 'N')
    @@StartPagePrinter = Win32API.new('winspool.drv', 'StartPagePrinter', ['N'],  'N')
    @@EndPagePrinter = Win32API.new('winspool.drv', 'EndPagePrinter', ['N'], 'N')
    @@WritePrinter = Win32API.new('winspool.drv', 'WritePrinter', ['N','P','N','P'],  'N')
    #~ @@StretchBlt = Win32API.new('kernel32', 'FormatMessage', ['N','P','N','N','P','N','P'], 'N')
#    PrintRectBox:=StretchBlt(phdc, LClientNew.Left, LClientNew.Top, LClientNew.Right-LClientNew.Left, LClientNew.Bottom-LClientNew.Top, rc.RectBitmap.Canvas.Handle, 0, 0, rc.RectBitmap.Width, rc.RectBitmap.Height, SRCAND);  //MERGECOPY
    
    #the functions that wrap the Win32API calls enforce type checking on arguments
    # (through #check). This is to be consistent with the Win32API which will assume
    # different arguments are calling different functions, throwing wacky errors
    #API WRAPPERS
    def print_dlg(pPrintDlg)
      check(pPrintDlg, String)
      api_call(@@PrintDlg, pPrintDlg)
    end
    
    def global_lock(hMovableMemory)
      check(hMovableMemory,Integer)
      api_call(@@GlobalLock, hMovableMemory)
    end
    
    def global_free(hMovableMemory)
      check(hMovableMemory,Integer)
      api_call(@@GlobalFree, hMovableMemory)
    end
    
    @@EnumPrinters = Win32API.new('winspool.drv', 'EnumPrinters', ['N', 'P', 'N', 'P', 'N', 'P', 'P'], 'N')
    #~ @@EnumPrinters = Win32API.new('winspool.drv', 'EnumPrinters', ['N', 'P', 'N', 'P', 'N', 'N', 'N'], 'N')
    
    def enum_printers()
        #~ __in   DWORD Flags,
        #~ __in   LPTSTR Name,
        #~ __in   DWORD Level,
        #~ __out  LPBYTE pPrinterEnum,
        #~ __in   DWORD cbBuf,
        #~ __out  LPDWORD pcbNeeded,
        #~ __out  LPDWORD pcReturned
#      EnumPrinters( PRINTER_ENUM_LOCAL, Nil, 2, Nil, 0, cbBuf, cReturned );
      pcbNeeded = "\0" * 4
      pcReturned = "\0" * 4
      pr = 
      PRINTER_ENUM_DEFAULT |
      PRINTER_ENUM_LOCAL |
      #~ PRINTER_ENUM_CONNECTIONS |
      #~ PRINTER_ENUM_FAVORITE |
      #~ PRINTER_ENUM_NAME |
      #~ PRINTER_ENUM_REMOTE |
      #~ PRINTER_ENUM_SHARED |
      #~ PRINTER_ENUM_NETWORK |
      #~ PRINTER_ENUM_EXPAND |
      #~ PRINTER_ENUM_CONTAINER |
      #~ PRINTER_ENUM_ICONMASK |
      0 # Dummy
      # erst einmal ermittel, wieveil Speichjer gebaraucht wird
      cbBuf = 0
      pPrinterEnum = "\0" * cbBuf # Buffer
      p api_call(@@EnumPrinters, pr, nil, 5, pPrinterEnum, 0, pcbNeeded, pcReturned)
      cbBuf = xxx2i(pcbNeeded) + 1
      pPrinterEnum = "\0" * cbBuf # Buffer
      p api_call(@@EnumPrinters, pr, nil, 5, pPrinterEnum, cbBuf, pcbNeeded, pcReturned)
      p "definierte Rueckgabelaenge: #{cbBuf}"
      p "benoetigte Bytes: #{xxx2i(pcbNeeded)}"
      p "zurueckgegebene Bytes: #{xxx2i(pcReturned)}"
      if xxx2i(pcReturned) > 0
        p pPrinterEnum
      end
    end
    
    def xxx2i(x)
      # dreht alle Zeichen herum macht dann einen Hexstring daraus und anschließend eine Zahl
      x.unpack("h8")[0].reverse.hex
    end
    
    def open_printer(pPrinterName, phPrinter, pDefault)
      check(pPrinterName,String)
      check(phPrinter,String) #handle to string.. return value
      #phPrinter is the PRINTER_DEFAULTS structure.. 0 for default
      # since we want to send through a zero for default, can't enforce string check...
      api_call(@@OpenPrinter, pPrinterName, phPrinter, pDefault)
    end

    def close_printer(hPrinter)
      check(hPrinter,Integer)
      api_call(@@ClosePrinter, hPrinter)
    end
    
    def abort_printer(hPrinter)
      check(hPrinter,Integer)
      api_call(@@AbortPrinter, hPrinter)
    end
    
    def start_doc_printer(hPrinter, level, pDocInfo)
      check(hPrinter, Integer); check(level, Integer); check(pDocInfo, String)
      api_call(@@StartDocPrinter, hPrinter, level, pDocInfo)
    end
    
    def end_doc_printer(hPrinter)
      check(hPrinter, Integer)
      api_call(@@EndDocPrinter, hPrinter)
    end

    def start_page_printer(hPrinter)
      check(hPrinter, Integer)
      api_call(@@StartPagePrinter, hPrinter)
    end
    
    def end_page_printer(hPrinter)
      check(hPrinter, Integer)
      api_call(@@EndPagePrinter, hPrinter)
    end
    
    def write_printer(hPrinter, pBuf, cdBuf, pcWritten)
      check(hPrinter,Integer); check(pBuf,String);
      check(cdBuf,Integer);check(pcWritten,String)
      api_call(@@WritePrinter, hPrinter, pBuf, cdBuf, pcWritten)
    end
    
    def get_last_error()
      api_call(@@GetLastError)
    end
    
    def format_message(dwFlags, lpSource, dwMessageID, dwLanguageID, lpBuffer, nSize, arguments)
      check(dwFlags,Integer);
      check(lpSource,String);
      check(dwMessageID,Integer)
      check(dwLanguageID,Integer); check(lpBuffer,String);
      check(nSize,Integer);
      check(arguments,String)
      api_call(@@FormatMessage, dwFlags, lpSource, dwMessageID, dwLanguageID, lpBuffer, nSize, arguments)
    end
    
    #HELPER FUNCTIONS
    def show_error
      message = " " * 1024 #store 1kb space
      format_message(0x1000, '', get_last_error(), 0, message, 1024, '')
      puts message[0 ... message.index("\0")]
    end
    
    def api_call(apiFunction, *args)
      begin
        return apiFunction.Call(*args)
      rescue RuntimeError => e
        raise show_error
      end
    end
#    private :api_call
    
    def check(variable, klass)
      raise "#{variable}, #{variable.class} != #{klass.to_s}" unless variable.kind_of?(klass)
    end
    private :check
    
    def with_global_lock(handle)
      begin
        globalMemory = global_lock(handle)
        yield globalMemory
      ensure
        show_error unless global_free(handle) == 0
      end
    end
    
    def with_printer(devicename, datatype, devmode)
      begin
        devicename << "\0"
        printer = "\0" * 4
        if devmode == 0
          pdefaults = 0
        else
          datatype << "\0"
          pdefaults = [datatype, devmode.to_s, 0x8].pack('ppL')
        end
        if (open_printer(devicename, printer, pdefaults) == 0) 
          show_error
        end
        hprinter = printer.unpack('L')[0]
        yield hprinter
      ensure
        close_printer(hprinter) if hprinter 
      end
    end
    
    def with_doc_printer(documentName, handleToPrinter)
      begin
        documentName << "\0"
        docinfo = [documentName].pack('px12')
        start_doc_printer(handleToPrinter, 1, docinfo)
        yield
      ensure
        end_doc_printer(handleToPrinter)
      end
    end

    def show_print_dialog
      pd = [66, 0x140].pack("Lx16Lx42")
      print_dlg(pd)
      p pd
      devmode, dc = pd.unpack("x8Lx4L")
    end

    def parse_devmode(devmode)
      devicename, orient, duplex, formname = devmode.to_s.unpack('A32x12Sx16Sx6A32')
    end

    def print_doc_from_dialog(docString, docName, pageLength=50)
      #need a more reasonable default for pageLength
      devmode, dc = show_print_dialog
      devicename, orient, duplex, formname = parse_devmode(devmode)
      _print_doc(docString, devicename, devmode, docName, pageLength) 
    end
    
    def _print_doc(docString, printerName, devMode, docName, pageLength)
      raise "bad docString" unless docString.respond_to?(:each_line)
      raise "bad pageLength" unless pageLength > 1
      datatype = (devMode == 0) ? nil : "TEXT"
      with_printer(printerName, datatype, devMode) do |hPrinter|
        with_doc_printer(docName, hPrinter) do
          lines = 0
          written =  "\0" * 4
          docString.each_line do |line|
            line.chomp!
            if (lines == 0)
              start_page_printer(hPrinter)
              lines += 1
            end
            line << "\r\n"
            write_printer(hPrinter, line, line.length, written)
            lines += 1
            if lines == pageLength
              lines = 0
              write_printer(hPrinter, "\f", 1, written)
              end_page_printer(hPrinter)
            end
          end
          #flush last page
          write_printer(hPrinter, "\f", 1, written)
          #~ end_page_printer(hPrinter)
        end
      end      
    end
    
    def print_doc(docString, printerName, docName="printjob", pageLength=50)
      _print_doc(docString, printerName, 0, docName, pageLength)  
    end                   
    
  end
end

if __FILE__ == $0
  p = Win32::TextPrinterControl.new
  devicename = '\\\COMFILE1\P0049'
  docString =<<EOF
This is a test.
Should be on a different line.
Should be 3 lines in total, with a y at the end.
EOF
  #~ p.print_doc(docString, devicename)
  p.enum_printers
end
