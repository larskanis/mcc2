# momentaner Stand:
# es wird nur bei den API-Funktionen des spoolers tatsächlich was mit dem Drucker gemacht, alle anderen tun nur so
# das heißt, die graphische Ausgabe funktioniert nicht

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

  require 'cstruct'
  
end

$stderr.sync = true
$stdout.sync = true

require "dl"

require "my_winspool"
require "my_winuser.rb"
require "my_wingdi.rb"
require "my_commdlg.rb"


module Win32
  class TextPrinterControl
    #~ LPVOID = Pointer = 'N'
    #~ HGDIOBJ = Handle = 'N'

    GDI32 = DL.dlopen('gdi32')
    #~ WINSPOOL = DL.dlopen('winspool.drv') # scheint nicht zu funktionieren
    USER32 = DL.dlopen('user32')
    COMMDLG32 = DL.dlopen('comdlg32')

    
    #~ @@StretchBlt = Win32API.new('kernel32', 'FormatMessage', ['N','P','N','N','P','N','P'], 'N')
#    PrintRectBox:=StretchBlt(phdc, LClientNew.Left, LClientNew.Top, LClientNew.Right-LClientNew.Left, LClientNew.Bottom-LClientNew.Top, rc.RectBitmap.Canvas.Handle, 0, 0, rc.RectBitmap.Width, rc.RectBitmap.Height, SRCAND);  //MERGECOPY
    
    #the functions that wrap the Win32API calls enforce type checking on arguments
    # (through #check). This is to be consistent with the Win32API which will assume
    # different arguments are calling different functions, throwing wacky errors
    #API WRAPPERS
    # --------------------------------------------------------------------------------------------------------------
    @@PrintDlg = Win32API.new("comdlg32", "PrintDlg", ['P'], 'N')
    #~ @@PrintDlg = COMMDLG32['PrintDlg', 'Lp']
    def print_dlg(pPrintDlg)
      #~ check(pPrintDlg, String)
      api_call(@@PrintDlg, pPrintDlg)
    end
    # --------------------------------------------------------------------------------------------------------------
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
    # --------------------------------------------------------------------------------------------------------------
    #~ @@TextOut = Win32API.new('gdi32', 'TextOut', ['N', 'N', 'N', 'P', 'N'],  'N')
    @@TextOut = GDI32['TextOut', 'LLLLPL']
    def text_out(hdc, nXStart, nYStart, lpString, cbString)
        #~ BOOL TextOut(
          #~ __in  HDC hdc,
          #~ __in  int nXStart,
          #~ __in  int nYStart,
          #~ __in  LPCTSTR lpString,
          #~ __in  int cbString
        #~ );
      api_call(@@TextOut, hdc, nXStart, nYStart, lpString, cbString)
    end
    # --------------------------------------------------------------------------------------------------------------
    #~ @@LoadImage = Win32API.new('user32', 'LoadImage', ['N', 'P', 'N', 'N', 'N', 'N'],  'N')
    @@LoadImage = USER32['LoadImage', 'LLPLLLL']
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
    # --------------------------------------------------------------------------------------------------------------
    #~ @@SelectObject = Win32API.new('gdi32', 'SelectObject', ['N', 'N'],  'N')
    @@SelectObject = GDI32['SelectObject', 'LLL']
    def select_object(hdc, hgdiobj)
        #~ HGDIOBJ SelectObject(
          #~ HDC hdc, 
          #~ HGDIOBJ hgdiobj
        #~ ); 
      #~ check(hMovableMemory,Integer)
      api_call(@@SelectObject, hdc, hgdiobj)
    end
    # --------------------------------------------------------------------------------------------------------------
    #~ @@GetObject = Win32API.new('gdi32', 'GetObject', ['N', 'N', 'P'],  'N')
    @@GetObject = GDI32['GetObject', 'LLLp']
    def get_object(hgdiobj, cbBuffer, lpvObject)
        #~ int GetObject(
          #~ __in   HGDIOBJ hgdiobj,
          #~ __in   int cbBuffer,
          #~ __out  LPVOID lpvObject
        #~ );
      #~ check(hMovableMemory,Integer)
      api_call(@@GetObject, hgdiobj, cbBuffer, lpvObject)
    end
    # --------------------------------------------------------------------------------------------------------------
    #~ @@CreateCompatibleDC = Win32API.new('gdi32', 'CreateCompatibleDC', ['N'],  'N')
    @@CreateCompatibleDC = GDI32['CreateCompatibleDC', 'LL']
    def create_compatible_dc(x)
        #~ HDC CreateCompatibleDC(
          #~ __in  HDC hdc
        #~ );
      #~ check(hMovableMemory,Integer)
      api_call(@@CreateCompatibleDC, x)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@GlobalLock = Win32API.new('kernel32', 'GlobalLock', ['N'], 'N')
    def global_lock(hMovableMemory)
      check(hMovableMemory,Integer)
      api_call(@@GlobalLock, hMovableMemory)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@GlobalFree = Win32API.new('kernel32', 'GlobalFree', ['N'], 'N')
    def global_free(hMovableMemory)
      check(hMovableMemory,Integer)
      api_call(@@GlobalFree, hMovableMemory)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@EnumPrinters = Win32API.new('winspool.drv', 'EnumPrinters', ['N', 'P', 'N', 'P', 'N', 'P', 'P'], 'N')
    #~ @@EnumPrinters = WINSPOOL['EnumPrinters', 'LLPLpLpp']
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
            p pointer_to_devmode(pDevMode)
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
    # --------------------------------------------------------------------------------------------------------------
    #~ @@CreateDC = Win32API.new('gdi32', 'CreateDC', ['N','P','N','N'],  'N')
    @@CreateDC = GDI32['CreateDC', 'LPPPP']
    def create_dc(lpszDriver, lpszDevice, lpszOutput, lpInitData)
         #~ HDC CreateDC(
              #~ LPCTSTR lpszDriver,
        #~ __in  LPCTSTR lpszDevice,
              #~ LPCTSTR lpszOutput,
        #~ __in  const DEVMODE *lpInitData
      #~ );

      #~ hDC = CreateDC( 0, sPrnName, 0, dm );
      api_call(@@CreateDC, lpszDriver, lpszDevice, lpszOutput, lpInitData)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@OpenPrinter = Win32API.new('winspool.drv', 'OpenPrinter', ['P','P','P'],  'N')
    #~ @@OpenPrinter = WINSPOOL['OpenPrinter', 'LPpP']
    def open_printer(pPrinterName, phPrinter, pDefault)
        #~ BOOL OpenPrinter(
          #~ __in   LPTSTR pPrinterName,
          #~ __out  LPHANDLE phPrinter,
          #~ __in   LPPRINTER_DEFAULTS pDefault
        #~ );      
      check(pPrinterName,String)
      check(phPrinter,String) #handle to string.. return value
      #phPrinter is the PRINTER_DEFAULTS structure.. 0 for default
      # since we want to send through a zero for default, can't enforce string check...
      api_call(@@OpenPrinter, pPrinterName, phPrinter, pDefault)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@ClosePrinter = Win32API.new('winspool.drv', 'ClosePrinter', ['N'], 'N')
    #~ @@ClosePrinter = WINSPOOL['ClosePrinter', 'LL']
    def close_printer(hPrinter)
      check(hPrinter,Integer)
      api_call(@@ClosePrinter, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@AbortPrinter = Win32API.new('winspool.drv', 'AbortPrinter', ['N'], 'N')
    def abort_printer(hPrinter)
      check(hPrinter,Integer)
      api_call(@@AbortPrinter, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@StartDocPrinter = Win32API.new('winspool.drv', 'StartDocPrinter', ['N','N','P'],  'N')
    #~ @@StartDocPrinter = WINSPOOL['StartDocPrinter', 'LLLP']
    def start_doc_printer(hPrinter, level, pDocInfo)
      check(hPrinter, Integer); check(level, Integer); check(pDocInfo, String)
      api_call(@@StartDocPrinter, hPrinter, level, pDocInfo)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@EndDocPrinter = Win32API.new('winspool.drv', 'EndDocPrinter', ['N'], 'N')
    #~ @@EndDocPrinter = WINSPOOL['EndDocPrinter', 'LL']
    def end_doc_printer(hPrinter)
      check(hPrinter, Integer)
      api_call(@@EndDocPrinter, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@StartPagePrinter = Win32API.new('winspool.drv', 'StartPagePrinter', ['N'],  'N')
    #~ @@StartPagePrinter = WINSPOOL['StartPagePrinter', 'LL']
    def start_page_printer(hPrinter)
      check(hPrinter, Integer)
      api_call(@@StartPagePrinter, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@EndPagePrinter = Win32API.new('winspool.drv', 'EndPagePrinter', ['N'], 'N')
    #~ @@EndPagePrinter = WINSPOOL['EndPagePrinter', 'LL']
    def end_page_printer(hPrinter)
      check(hPrinter, Integer)
      api_call(@@EndPagePrinter, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@StartDoc = Win32API.new('gdi32', 'StartDoc', ['N','P'], 'N')
    #~ @@StartDoc = GDI32['StartDoc', 'LLP']
    def start_doc(hPrinter, pDocInfo)
      check(hPrinter, Integer); check(pDocInfo, String)
      api_call(@@StartDoc, hPrinter, pDocInfo)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@EndDoc = Win32API.new('gdi32', 'EndDoc', ['N'], 'N')
    #~ @@EndDoc = GDI32['EndDoc', 'LL']
    def end_doc(hPrinter)
      check(hPrinter, Integer)
      api_call(@@EndDoc, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@StartPage = Win32API.new('gdi32', 'StartPage', ['N'],  'N')
    #~ @@StartPage = GDI32['StartPage', 'LL']
    def start_page(hPrinter)
      check(hPrinter, Integer)
      api_call(@@StartPage, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@EndPage = Win32API.new('gdi32', 'EndPage', ['N'], 'N')
    #~ @@EndPage = GDI32['EndPage', 'LL']
    def end_page(hPrinter)
        #~ int EndPage(
          #~ __in  HDC hdc
        #~ );
      check(hPrinter, Integer)
      api_call(@@EndPage, hPrinter)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@WritePrinter = Win32API.new('winspool.drv', 'WritePrinter', ['N','P','N','P'],  'N')
    #~ @@WritePrinter = WINSPOOL['WritePrinter', 'LLPLp']
    def write_printer(hPrinter, pBuf, cdBuf, pcWritten)
        #~ BOOL WritePrinter(
          #~ __in   HANDLE hPrinter,
          #~ __in   LPVOID pBuf,
          #~ __in   DWORD cbBuf,
          #~ __out  LPDWORD pcWritten
        #~ );
      check(hPrinter,Integer); check(pBuf,String);
      check(cdBuf,Integer);check(pcWritten,String)
      api_call(@@WritePrinter, hPrinter, pBuf, cdBuf, pcWritten)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@GetLastError = Win32API.new('kernel32', 'GetLastError', [],  'N')
    def get_last_error()
      api_call(@@GetLastError)
    end
    # --------------------------------------------------------------------------------------------------------------
    @@FormatMessage = Win32API.new('kernel32', 'FormatMessage', ['N','P','N','N','P','N','P'], 'N')
    def format_message(dwFlags, lpSource, dwMessageID, dwLanguageID, lpBuffer, nSize, arguments)
      check(dwFlags,Integer);
      check(lpSource,String);
      check(dwMessageID,Integer)
      check(dwLanguageID,Integer); check(lpBuffer,String);
      check(nSize,Integer);
      check(arguments,String)
      api_call(@@FormatMessage, dwFlags, lpSource, dwMessageID, dwLanguageID, lpBuffer, nSize, arguments)
    end
    # --------------------------------------------------------------------------------------------------------------
    # --------------------------------------------------------------------------------------------------------------
    #HELPER FUNCTIONS
    # --------------------------------------------------------------------------------------------------------------
    def pointer_to_s(ptr)
      if ptr != 0
        ptr1 = DL::PtrData.new(ptr)
        ptr1.to_s
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    def pointer_to_devmode(ptr)
      if ptr != 0
        ptr1 = DL::PtrData.new(ptr)
        ptr1
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    def show_error
      message = " " * 1024 #store 1kb space
      format_message(0x1000, '', get_last_error(), 0, message, 1024, '')
      puts message[0 ... message.index("\0")]
    end
    # --------------------------------------------------------------------------------------------------------------
    def api_call(apiFunction, *args)
      begin
        res = apiFunction.call(*args)
        return res.kind_of?(Array) ? res[0] : res
      rescue RuntimeError => e
        raise "#{e.class} #{e}: #{show_error}"
      end
    end
#    private :api_call
    # --------------------------------------------------------------------------------------------------------------
    def check(variable, klass)
      raise "#{variable}, #{variable.class} != #{klass.to_s}" unless variable.kind_of?(klass)
    end
    private :check
    # --------------------------------------------------------------------------------------------------------------
    def with_global_lock(handle)
      begin
        globalMemory = global_lock(handle)
        yield globalMemory
      ensure
        show_error unless global_free(handle) == 0
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    
    def with_printer(devicename, datatype, devmode)
      begin
        devicename << "\0"
        printer = "\0" * 4
        if devmode == 0
          pdefaults = 0
        else
          datatype << "\0"
          #~ pdefaults = [datatype, devmode.to_s, 0x8].pack('ppL')
          pdefaults = [datatype, devmode.to_s, PRINTER_ACCESS_USE].pack('ppL')
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
    # --------------------------------------------------------------------------------------------------------------
      #~ typedef struct _DOC_INFO_1 {
        #~ LPTSTR pDocName;
        #~ LPTSTR pOutputFile;
        #~ LPTSTR pDatatype;
      #~ } DOC_INFO_1;
    # --------------------------------------------------------------------------------------------------------------
    def with_doc_printer(documentName, handleToPrinter)
      begin
        documentName << "\0"
        #~ docinfo = [documentName].pack('px12')
        docinfo = [documentName, nil, "TEXT"].pack('ppp') # das hat zumindest ein Blatt befördert
        #~ docinfo = [documentName, nil, "RAW"].pack('ppp') # das tut so, als wenn es drucken will, tut es aber nicht
        #~ docinfo = [documentName, nil, nil].pack('ppp') # das tut nicht drucken wollen
        start_doc_printer(handleToPrinter, 1, docinfo)
        yield
      ensure
        end_doc_printer(handleToPrinter)
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    def with_page_printer(hPrinter)
      begin
        start_page_printer(hPrinter)
        yield
      ensure
        end_page_printer(hPrinter)
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    def with_doc(documentName, handleToPrinter)
      begin
        documentName << "\0"
        docinfo = [documentName].pack('px12')
        start_doc(handleToPrinter, docinfo)
        yield
      ensure
        end_doc(handleToPrinter)
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    def with_page(hPrinter)
      begin
        start_page(hPrinter)
        yield
      ensure
        end_page(hPrinter)
      end
    end
    # --------------------------------------------------------------------------------------------------------------
    def show_print_dialog
      #~ typedef struct tagPD {
          #~ DWORD lStructSize;
          #~ HWND hwndOwner;
          #~ HGLOBAL hDevMode;
          #~ HGLOBAL hDevNames;
          #~ HDC hDC;
          #~ DWORD Flags;
          #~ WORD nFromPage;
          #~ WORD nToPage;
          #~ WORD nMinPage;
          #~ WORD nMaxPage;
          #~ WORD nCopies;
          #~ HINSTANCE hInstance;
          #~ LPARAM lCustData;
          #~ LPPRINTHOOKPROC lpfnPrintHook;
          #~ LPSETUPHOOKPROC lpfnSetupHook;
          #~ LPCTSTR lpPrintTemplateName;
          #~ LPCTSTR lpSetupTemplateName;
          #~ HGLOBAL hPrintTemplate;
          #~ HGLOBAL hSetupTemplate;
      #~ } PRINTDLG, *LPPRINTDLG;
      
      #~ pdlg = PRINTDLG.new
      pdlg = DL.malloc(DL.sizeof("L"*6 + "H"*5 + "L"*8))
      p pdlg
      pdlg.struct!("L"*6 + "H"*5 + "L"*8, 
                          :lStructSize,
                          :hwndOwner,
                          :hDevMode,
                          :hDevNames,
                          :hDC,
                          :Flags,
                          :nFromPage,
                          :nToPage,
                          :nMinPage,
                          :nMaxPage,
                          :nCopies,
                          :hInstance,
                          :lCustData,
                          :lpfnPrintHook,
                          :lpfnSetupHook,
                          :lpPrintTemplateName,
                          :lpSetupTemplateName,
                          :hPrintTemplate,
                          :hSetupTemplate)
      
      pdlg[:lStructSize] = 66
      #~ pdlg[:lStructSize] = pdlg.size
      pdlg[:hwndOwner] = 0
      pdlg[:hDevMode] = 0
      pdlg[:hDC] = 0
      #~ pdlg[:Flags] = 0x140
      pdlg[:Flags] = PD_RETURNDC | PD_PRINTSETUP | PD_NONETWORKBUTTON
      pdlg[:nFromPage] = 0
      pdlg[:nToPage] = 0
      pdlg[:nMinPage] = 0
      pdlg[:nMaxPage] = 0
      pdlg[:nCopies] = 0
      pdlg[:hInstance] = 0
      pdlg[:lCustData] = 0
      pdlg[:lpfnPrintHook] = 0
      pdlg[:lpfnSetupHook] = 0
      pdlg[:lpPrintTemplateName] = 0
      pdlg[:lpSetupTemplateName] = 0
      pdlg[:hPrintTemplate] = 0
      pdlg[:hSetupTemplate] = 0
      devnames = 0
      pdlg[:hDevNames] = devnames
      p "pdlg: #{pdlg.inspect}"
      #~ pdlg.each{|e| p e }
      
      #~ bin_struct = pdlg.serialize
      #~ ok = print_dlg(StringIO.new(bin_struct))
      #~ pdlg = PRINTDLG.read(bin_struct)
      
      #~ pd = [66, 0x140].pack("Lx16Lx46")
      #~ ok = print_dlg(pd)
      ok = print_dlg(pdlg)
      
      p "pdlg: #{pdlg.inspect}"
      #~ p PRINTDLG.read(pdlg)
      p pdlg[:lStructSize]
      p pdlg[0,64].unpack("LLLLLLLLLLLLLLLL")
      #~ p pd
      #~ p pd.unpack("H*")
      #~ p pd.unpack("LLLLLLLLLLLLLLLL")
      #~ p pd.unpack("x8Lx4L")
      p "hdc: #{pdlg[:hDC]}"
      p "devMode: #{pdlg[:hDevMode]}"
      #~ devmode, dc = pd.unpack("x8Lx4L")
      
    end
    # --------------------------------------------------------------------------------------------------------------
    def parse_devmode(devmode)
      p devmode
#      p devmode.unpack("p").to_s
      devicename, orient, duplex, formname = devmode.to_s.unpack('A32x12Sx16Sx6A32')
    end
    # --------------------------------------------------------------------------------------------------------------
    def print_doc_from_dialog(docString, docName, pageLength=50)
      #need a more reasonable default for pageLength
      devmode, dc = show_print_dialog
      devicename, orient, duplex, formname = parse_devmode(devmode)
      _print_doc(docString, devicename, devmode, docName, pageLength) 
    end
    # --------------------------------------------------------------------------------------------------------------
    def _print_doc(docString, printerName, devMode, docName, pageLength)
      raise "bad docString" unless docString.respond_to?(:each_line)
      raise "bad pageLength" unless pageLength > 1
      datatype = (devMode == 0) ? nil : "TEXT"
      #~ datatype = "RAW"
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
    # --------------------------------------------------------------------------------------------------------------
    def print_doc(docString, printerName, docName="printjob", pageLength=50)
      _print_doc(docString, printerName, 0, docName, pageLength)  
    end                   
    # --------------------------------------------------------------------------------------------------------------
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
        self.format = 'BMP'
      }
      #~ p data
      p hDC = create_dc( nil, devicename, nil, nil);
      hPrinter = hDC
      #~ devMode, dc = show_print_dialog
      #~ devicename, orient, duplex, formname = parse_devmode(devMode)
      written = ""
#      devMode = nil
      devMode = 0
      datatype = (devMode == 0) ? nil : "TEXT"
      #~ datatype = "RAW"
      #~ with_printer(devicename, datatype, devMode) do |hPrinter|
      
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
        
        with_doc("Test", hPrinter) do
          with_page(hPrinter) do
        #~ with_doc_printer("Test", hPrinter) do
          #~ with_page_printer(hPrinter) do
        
            hBmp = load_image( 0, 't:\Project\MCC2a\trunk\Image-FastArrowRight.bmp ', IMAGE_BITMAP, 
              0, 0, LR_LOADFROMFILE | LR_CREATEDIBSECTION );          
            
            tmpDC = create_compatible_dc(hPrinter)
            
            oldBmp = select_object( tmpDC, hBmp )
            
            get_object(hBmp, info.size, info)
            
            p info
            p info[:bmWidth]
            p info[:bmHeight]
            p info[:bmType]
            p info[:bmWidthBytes]
            p info[:bmPlanes]
            p info[:bmBitsPixel]
            p info[:bmBits]
            
            nXDest = 100
            nYDest = 100
            nWidth = info[:bmWidth]
            nHeight = info[:bmHeight]
            hdcSrc = tmpDC
            nXSrc = 0
            nYSrc = 0
            dwRop = SRCCOPY
            bit_blt(hPrinter, nXDest, nYDest, nWidth, nHeight, hdcSrc, nXSrc, nYSrc, dwRop)
            
            select_object( tmpDC, oldBmp );
            
            s = "Teststring"
            text_out(hPrinter, 10, 10, s, s.length)
            
            #~ write_printer(hPrinter, "neuer Test", 4, written)
            #~ write_printer(hPrinter, "neuer Test", 10, written)
          end
        #~ end
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
  p.print_doc_from_dialog(docString, nil)
end
