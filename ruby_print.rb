if __FILE__ == $0
  require 'Win32API'
  #~ begin
    #~ require 'fox16'
    #~ require 'fox16/colors'
    #~ require 'fox16/responder'
    #~ p "loading fox16"
  #~ rescue LoadError
    #~ p "Error loading fox16 try fox12"
    #~ require 'fox12'
    #~ require 'fox12/colors'
    #~ $enable_fox12_workaround = true
  #~ end
  #~ include Fox
  require 'RMagick'
  include Magick
  require 'rvg/rvg'        # für RMagick
  
  
end

$stderr.sync = true
$stdout.sync = true

require "dl"

require "my_winspool"
require "my_winuser.rb"
require "my_wingdi.rb"


module Win32
  class TextPrinterControl
    #~ LPVOID = Pointer = 'N'
    #~ HGDIOBJ = Handle = 'N'

    GDI32 = DL.dlopen('gdi32')

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
    
    #~ @@GetObject = GDI32['GetObject', 'LPLp']
    #~ @@BitBlt = Win32API.new('gdi32', 'BitBlt', ['N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N'],  'N')
    @@BitBlt = GDI32['BitBlt', 'L'*10]
    def bit_blt(hdcDest, nXDest, nYDest, nWidth, nHeight, hdcSrc, nXSrc, nYSrc, dwRop)
        #~ BOOL BitBlt(
          #~ __in  HDC hdcDest,
          #~ __in  int nXDest,
          #~ __in  int nYDest,
          #~ __in  int nWidth,
          #~ __in  int nHeight,
          #~ __in  HDC hdcSrc,
          #~ __in  int nXSrc,
          #~ __in  int nYSrc,
          #~ __in  DWORD dwRop
        #~ );
      api_call(@@BitBlt, hdcDest, nXDest, nYDest, nWidth, nHeight, hdcSrc, nXSrc, nYSrc, dwRop)
    end
    
    @@LoadImage = Win32API.new('user32', 'LoadImage', ['N', 'P', 'N', 'N', 'N', 'N'],  'N')
    def load_image(hinst, lpszName, uType, cxDesired, cyDesired, fuLoad)
        #~ HANDLE LoadImage(      
            #~ HINSTANCE hinst,
            #~ LPCTSTR lpszName,
            #~ UINT uType,
            #~ int cxDesired,
            #~ int cyDesired,
            #~ UINT fuLoad
        #~ );
      api_call(@@LoadImage, hinst, lpszName, uType, cxDesired, cyDesired, fuLoad)
    end
    
    @@SelectObject = Win32API.new('gdi32', 'SelectObject', ['N', 'N'],  'N')
    def select_object(hdc, hgdiobj)
        #~ HGDIOBJ SelectObject(
          #~ HDC hdc, 
          #~ HGDIOBJ hgdiobj
        #~ ); 
      #~ check(hMovableMemory,Integer)
      api_call(@@SelectObject, hdc, hgdiobj)
    end
    
    @@GetObject = Win32API.new('gdi32', 'GetObject', ['N', 'N', 'P'],  'N')
    #~ @@GetObject = GDI32['GetObject', 'LPLp']
    def get_object(hgdiobj, cbBuffer, lpvObject)
        #~ int GetObject(
          #~ __in   HGDIOBJ hgdiobj,
          #~ __in   int cbBuffer,
          #~ __out  LPVOID lpvObject
        #~ );
      #~ check(hMovableMemory,Integer)
      api_call(@@GetObject, hgdiobj, cbBuffer, lpvObject)
    end
    
    @@CreateCompatibleDC = Win32API.new('gdi32', 'CreateCompatibleDC', ['N'],  'N')
    def create_compatible_dc(x)
        #~ HDC CreateCompatibleDC(
          #~ __in  HDC hdc
        #~ );
      #~ check(hMovableMemory,Integer)
      api_call(@@CreateCompatibleDC, x)
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
        
      pcbNeeded = "\0" * 4
      pcReturned = "\0" * 4
      pr = 
      #~ PRINTER_ENUM_DEFAULT |
      PRINTER_ENUM_LOCAL |
      PRINTER_ENUM_CONNECTIONS |
      PRINTER_ENUM_FAVORITE |
      #~ PRINTER_ENUM_NAME |
      #~ PRINTER_ENUM_REMOTE |
      #~ PRINTER_ENUM_SHARED |
      #~ PRINTER_ENUM_NETWORK |
      #~ PRINTER_ENUM_EXPAND |
      #~ PRINTER_ENUM_CONTAINER |
      #~ PRINTER_ENUM_ICONMASK |
      0 # Dummy
      
      #~ pi = PRINTER_INFO_1
      pi = PRINTER_INFO_2
      #~ pi = PRINTER_INFO_4
      #~ pi = PRINTER_INFO_5
      
      # erst einmal ermitteln, wieviel Speicher gebraucht wird
      cbBuf = 0
      pPrinterEnum = "\0" * cbBuf # Buffer
      api_call(@@EnumPrinters, pr, nil, pi, pPrinterEnum, 0, pcbNeeded, pcReturned)
      
      # und dann die Infos holen
      cbBuf = pcbNeeded.unpack("V")[0] + 1
      
      pPrinterEnum = "\0" * cbBuf # Buffer für die Datenübergabe aufbereiten
      
      api_call(@@EnumPrinters, pr, nil, pi, pPrinterEnum, cbBuf, pcbNeeded, pcReturned)
      
      #~ p "Laenge des übergebenen Puffers: #{cbBuf}"
      needed = pcbNeeded.unpack("V")[0]
      returned = pcReturned.unpack("V")[0]
      #~ p "benoetigte Bytes: #{needed}"
      #~ p "zurueckgegebene Drucker: #{returned}"
      if returned > 0
        if pi == PRINTER_INFO_1
          #~ typedef struct _PRINTER_INFO_1 {
            #~ DWORD  Flags;
            #~ LPTSTR pDescription;
            #~ LPTSTR pName;
            #~ LPTSTR pComment;
          #~ } PRINTER_INFO_1, *PPRINTER_INFO_1;

          anz_attr = 4
          printerattrs = pPrinterEnum.unpack("V" * anz_attr * returned)
          while (printerattr=printerattrs.slice!(0, anz_attr)) && !printerattr.empty?
            p "*"*50
            flags, pDescription, pName, pComment = *printerattr
            p pointer_to_s(pDescription)
            p pointer_to_s(pName)
            p pointer_to_s(pComment)
          end
        elsif pi == PRINTER_INFO_2
          #~ typedef struct _PRINTER_INFO_2 {
            #~ LPTSTR               pServerName;
            #~ LPTSTR               pPrinterName;
            #~ LPTSTR               pShareName;
            #~ LPTSTR               pPortName;
            #~ LPTSTR               pDriverName;
            #~ LPTSTR               pComment;
            #~ LPTSTR               pLocation;
            #~ LPDEVMODE            pDevMode;
            #~ LPTSTR               pSepFile;
            #~ LPTSTR               pPrintProcessor;
            #~ LPTSTR               pDatatype;
            #~ LPTSTR               pParameters;
            #~ PSECURITY_DESCRIPTOR pSecurityDescriptor;
            #~ DWORD                Attributes;
            #~ DWORD                Priority;
            #~ DWORD                DefaultPriority;
            #~ DWORD                StartTime;
            #~ DWORD                UntilTime;
            #~ DWORD                Status;
            #~ DWORD                cJobs;
            #~ DWORD                AveragePPM;
          #~ } PRINTER_INFO_2, *PPRINTER_INFO_2;
          anz_attr = 21
          printerattrs = pPrinterEnum.unpack("V" * anz_attr * returned)
          while (printerattr=printerattrs.slice!(0, anz_attr)) && !printerattr.empty?
            p "*"*50
            pServerName,
            pPrinterName,
            pShareName,
            pPortName,
            pDriverName,
            pComment,
            pLocation,
            pDevMode,
            pSepFile,
            pPrintProcessor,
            pDatatype,
            pParameters,
            pSecurityDescriptor,
            attributes,
            priority,
            defaultPriority,
            startTime,
            untilTime,
            status,
            cJobs,
            averagePPM = *printerattr
            p pointer_to_s(pServerName)
            p pointer_to_s(pPrinterName)
            p pointer_to_s(pShareName)
            p pointer_to_s(pPortName)
            p pointer_to_s(pDriverName)
            p pointer_to_s(pComment)
            p pointer_to_s(pLocation)
            p pointer_to_s(pServerName)
            p pointer_to_s(pSepFile)
            p pointer_to_s(pPrintProcessor)
            p pointer_to_s(pDatatype)
            p pointer_to_s(pParameters)
          end
        elsif pi == PRINTER_INFO_4
          #~ typedef struct _PRINTER_INFO_4 {
            #~ LPTSTR pPrinterName;
            #~ LPTSTR pServerName;
            #~ DWORD  Attributes;
          #~ } PRINTER_INFO_4, *PPRINTER_INFO_4;
          anz_attr = 3
          printerattrs = pPrinterEnum.unpack("V" * anz_attr * returned)
          while (printerattr=printerattrs.slice!(0, anz_attr)) && !printerattr.empty?
            p "*"*50
            pPrinterName,
            pServerName,
            attributes = *printerattr
            p pointer_to_s(pPrinterName)
          end
        elsif pi == PRINTER_INFO_5
          #~ typedef struct _PRINTER_INFO_5 {
            #~ LPTSTR pPrinterName;
            #~ LPTSTR pPortName;
            #~ DWORD  Attributes;
            #~ DWORD  DeviceNotSelectedTimeout;
            #~ DWORD  TransmissionRetryTimeout;
          #~ } PRINTER_INFO_5, *PPRINTER_INFO_5;
          anz_attr = 5
          printerattrs = pPrinterEnum.unpack("V" * anz_attr * returned)
          while (printerattr=printerattrs.slice!(0, anz_attr)) && !printerattr.empty?
            p "*"*50
            pPrinterName,
            pPortName,
            attributes,
            deviceNotSelectedTimeout,
            transmissionRetryTimeout = *printerattr
            p pointer_to_s(pPortName)
          end
        end
      end
    end
    
    def pointer_to_s(ptr)
      if ptr != 0
        ptr = DL::PtrData.new(ptr)
        ptr.to_s
      end
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
    
    def write_printer_graph(hPrinter, pBuf, cdBuf, pcWritten)
      check(hPrinter,Integer); 
      #~ check(pBuf,String);
      check(cdBuf,Integer);
      check(pcWritten,String)
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
        return apiFunction.call(*args)
      rescue RuntimeError => e
        raise "#{e.class} #{e}: #{show_error}"
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
      # datatype = "RAW"
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
    
    def print_graphic(devicename, datatype)
      img = Magick::RVG.new(85, 65) do |canvas|
        canvas.text(0, 0, "Test").styles(
          :font_family => "Arial", 
          :font_size => 10, 
          :fill => "black", 
          :font_weight => 'normal', 
          :font_style => 'normal')
      end
      data = img.draw.to_blob{
        self.format = 'PNG'
        #~ self.format = 'RAW'
      }
      #~ p data
      written = ""
      devMode = nil
      with_printer(devicename, datatype, devMode) do |hPrinter|
        start_page_printer(hPrinter)
          #~ hBmp = (HBITMAP) LoadImage( 0, dlg.m_ofn.lpstrFile, IMAGE_BITMAP, 
            #~ 0, 0, LR_LOADFROMFILE | LR_CREATEDIBSECTION );          
          #~ tmpDC = CreateCompatibleDC( hDC );
          #~ oldBmp = (HBITMAP)SelectObject( tmpDC, hBmp );

          #~ GetObject( hBmp, sizeof( info ), &info );

          #~ BitBlt( hDC, 0, 0, info.bmWidth, info.bmHeight, tmpDC, 0, 0, SRCCOPY );

          #~ SelectObject( tmpDC, oldBmp );
          #~ DeleteDC( tmpDC );

        #~ load_image(hinst, lpszName, uType, cxDesired, cyDesired, fuLoad)
        
        info = DL.malloc(DL.sizeof("LLLLHHP"))
        info.struct!('LLLLHHP', :bmType, :bmWidth, :bmHeight, :bmWidthBytes, :bmPlanes, :bmBitsPixel, :bmBits)
        
        with_doc_printer("Test", hPrinter) do
        
          p "hier1"
          hBmp = load_image( 0, 't:\Project\MCC2a\trunk\Image-FastArrowRight.bmp ', IMAGE_BITMAP, 
            0, 0, LR_LOADFROMFILE | LR_CREATEDIBSECTION );          
            
          p "hier2"
          tmpDC = create_compatible_dc(hPrinter)
          
          p "hier3"
          oldBmp = select_object( tmpDC, hBmp )
          
          p "hier4"
          get_object(hBmp, info.size, info)
          
          p info
          p info[:bmWidth]
          p info[:bmHeight]
          p info[:bmType]
          
          p "hier5"
          nXDest = 0
          nYDest = 0
          nWidth = info[:bmWidth]
          nHeight = info[:bmHeight]
          hdcSrc = tmpDC
          nXSrc = 0
          nYSrc = 0
          dwRop = SRCCOPY
          bit_blt(hPrinter, nXDest, nYDest, nWidth, nHeight, hdcSrc, nXSrc, nYSrc, dwRop)
          p "hier6"
          
          select_object( tmpDC, oldBmp );

          #~ write_printer_graph(hPrinter, "Test", 4, written)
          write_printer(hPrinter, "\f", 1, written)
          end_page_printer(hPrinter)
        end
      end
    end
    
  end
end

if __FILE__ == $0
	#~ require 'libguib16.rb'
  p = Win32::TextPrinterControl.new
  #~ devicename = "Jaws PDF Creator"
  devicename = '\\\COMFILE1\P0049'
  #~ p.enum_printers
  p.print_graphic(devicename, "RAW")
  
  exit
  
  docString =<<EOF
This is a test.
Should be on a different line.
Should be 3 lines in total, with a y at the end.
EOF
  #~ p.print_doc(docString, devicename)
end
