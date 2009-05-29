$: << '../win32'

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

  #~ require 'cstruct'
  require "tempfile" 
  
end

$stderr.sync = true
$stdout.sync = true

require "dl"

require 'win32api_base'
#~ require 'win32api_comdlg'
require 'win32api_gdi'
#~ require 'win32api_kernel'
require 'win32api_user'
#~ require 'win32api_winspool'


class RubyPrinting
  def initialize
    @w32gdi = Win32ApiGDI.new
    @w32user = Win32ApiUser.new
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
      open_printer(devicename, printer, pdefaults)
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
      @w32gdi.start_doc(handleToPrinter, docinfo)
      yield
    ensure
      @w32gdi.end_doc(handleToPrinter)
    end
  end
  # --------------------------------------------------------------------------------------------------------------
  def with_page(hPrinter)
    begin
      @w32gdi.start_page(hPrinter)
      yield
    ensure
      @w32gdi.end_page(hPrinter)
    end
  end
  # --------------------------------------------------------------------------------------------------------------
  def show_print_dialog
    # wird zwar gestartet, liefert aber keine gefüllte struktur zurück
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
        end_page_printer(hPrinter)
      end
    end      
  end
  # --------------------------------------------------------------------------------------------------------------
  def print_doc(docString, printerName, docName="printjob", pageLength=50)
    _print_doc(docString, printerName, 0, docName, pageLength)  
  end                   
  # --------------------------------------------------------------------------------------------------------------
  def print_graphic(devicename, datatype)
 
    # den Pfad ermitteln, wo das temporäre File abgelegt werden soll
    tf = Tempfile.new("afile") 
    temp_path = File.join(tf.path.split("/")[0..-2])
    tf.close(true)            # #<File:0x4016e3c0>\n0x40187c30 

    # 
    Magick::RVG.dpi = 600
    crd_width = 85
    crd_height = 55

    img = Magick::RVG.new((crd_width+10).mm, (crd_height+10).mm) do |canvas|
      canvas.background_fill = 'white'
      
      canvas.rect(crd_width.mm, crd_height.mm, 5.mm, 5.mm).styles(:fill=>'none', :stroke=>'black')
      canvas.text(200, 200, "das ist ein ganz neuer Test Test").styles(
        :font_family => "Arial", 
        :font_size => 20.pt, 
        :fill => 'black', 
        :font_weight => 'bold', 
        :font_style => 'normal')
        
      canvas.text(100, 100, "Blue 15").styles(
        :font_family => "Arial", 
        :font_size => 15.pt, 
        :fill => 'blue', 
        :font_weight => 'bold', 
        :font_style => 'normal')
      canvas.text(500, 100, "Green 15").styles(
        :font_family => "Arial", 
        :font_size => 15.pt, 
        :fill => 'green', 
        :font_weight => 'bold', 
        :font_style => 'normal')
      canvas.text(900, 100, "Red 15").styles(
        :font_family => "Arial", 
        :font_size => 15.pt, 
        :fill => 'red', 
        :font_weight => 'bold', 
        :font_style => 'normal')
    end
    pic = img.draw
    p pic
    
    
    # create_dc(lpszDriver, lpszDevice, lpszOutput, lpInitData)
    hDC = @w32gdi.create_dc( nil, devicename, nil, nil);
    
    hPrinter = hDC
    
    #~ devMode, dc = show_print_dialog
    #~ devicename, orient, duplex, formname = parse_devmode(devMode)
    written = ""
    devMode = 0
    datatype = (devMode == 0) ? nil : "TEXT"
      
    with_doc("Test", hPrinter) do
      with_page(hPrinter) do
      
        bmdata = pic.to_blob{
          self.format='rgb'
          self.depth = 8
        }
        puts "size: #{bmdata.length}"

        (0 ... pic.rows).each{|row_idx|
          linedata = bmdata[3*row_idx*pic.columns, 3*pic.columns]
          linedata = linedata.unpack('a3'*pic.columns).map{|a| a.reverse! }.pack('a3'*pic.columns)
          hBmp = @w32gdi.create_bitmap(pic.columns, 1, 1, 24, linedata)
          #~ p "hBmp: #{hBmp}"
          
          tmpDC = @w32gdi.create_compatible_dc(hPrinter)
          
          oldBmp = @w32gdi.select_object( tmpDC, hBmp )
          
          nXDest = 500
          nYDest = 500+row_idx
          hdcSrc = tmpDC
          nXSrc = 0
          nYSrc = 0
          dwRop = SRCCOPY
          @w32gdi.bit_blt(hPrinter, nXDest, nYDest, pic.columns, 1, hdcSrc, nXSrc, nYSrc, dwRop)
          
          @w32gdi.select_object( tmpDC, oldBmp )
        }
          
        s = "Teststring"
        @w32gdi.text_out(hPrinter, 10, 10, s, s.length)
      end
    end
  end
  
end
# ======================================================================================================
# ======================================================================================================
if __FILE__ == $0
	#~ require 'libguib16.rb'
  rp = RubyPrinting.new
  devicename = "Jaws PDF Creator"
  #~ devicename = '\\\COMFILE1\P0049'
  #~ devicename = "XeroxPhaser7750DN PS"
  #~ rp.enum_printers
  rp.print_graphic(devicename, "RAW")
  
  exit
  
  docString =<<EOF
This is a test.
Should be on a different line.
Should be 3 lines in total, with a y at the end.
EOF
  rp.print_doc(docString, devicename)
  #~ rp.print_doc_from_dialog(docString, nil) # funktioniert nicht
end
