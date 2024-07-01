$: << "../win32"

if __FILE__ == $0
  # ~ begin
  # ~ require 'fox16'
  # ~ require 'fox16/colors'
  # ~ require 'fox16/responder'
  # ~ p "loading fox16"
  # ~ rescue LoadError
  # ~ p "Error loading fox16 try fox12"
  # ~ require 'fox12'
  # ~ require 'fox12/colors'
  # ~ $enable_fox12_workaround = true
  # ~ end
  # ~ include Fox
  #   require 'RMagick'
  #   include Magick
  #   require 'rvg/rvg'        # f�r RMagick

  require "tempfile"

end

$stderr.sync = true
$stdout.sync = true

require "dl"

require "win32api4ruby"

class RubyPrinting
  # --------------------------------------------------------------------------------------------------------------
  def with_printer(devicename, datatype, devmode)
    devicename << "\0"
    printer = "\0" * 4
    if devmode == 0
      pdefaults = 0
    else
      datatype << "\0"
      # ~ pdefaults = [datatype, devmode.to_s, 0x8].pack('ppL')
      pdefaults = [datatype, devmode.to_s, PRINTER_ACCESS_USE].pack("ppL")
    end
    open_printer(devicename, printer, pdefaults)
    hprinter = printer.unpack1("L")
    yield hprinter
  ensure
    close_printer(hprinter) if hprinter
  end

  # --------------------------------------------------------------------------------------------------------------
  # ~ typedef struct _DOC_INFO_1 {
  # ~ LPTSTR pDocName;
  # ~ LPTSTR pOutputFile;
  # ~ LPTSTR pDatatype;
  # ~ } DOC_INFO_1;
  # --------------------------------------------------------------------------------------------------------------
  def with_doc_printer(documentName, handleToPrinter)
    documentName << "\0"
    # ~ docinfo = [documentName].pack('px12')
    docinfo = [documentName, nil, "TEXT"].pack("ppp") # das hat zumindest ein Blatt bef�rdert
    # ~ docinfo = [documentName, nil, "RAW"].pack('ppp') # das tut so, als wenn es drucken will, tut es aber nicht
    # ~ docinfo = [documentName, nil, nil].pack('ppp') # das tut nicht drucken wollen
    start_doc_printer(handleToPrinter, 1, docinfo)
    yield
  ensure
    end_doc_printer(handleToPrinter)
  end

  # --------------------------------------------------------------------------------------------------------------
  def with_page_printer(hPrinter)
    start_page_printer(hPrinter)
    yield
  ensure
    end_page_printer(hPrinter)
  end

  # --------------------------------------------------------------------------------------------------------------
  def with_doc(documentName, handleToPrinter)
    documentName << "\0"
    docinfo = [documentName].pack("px12")
    Win32api4ruby::Gdi.start_doc(handleToPrinter, docinfo)
    yield
  ensure
    Win32api4ruby::Gdi.end_doc(handleToPrinter)
  end

  # --------------------------------------------------------------------------------------------------------------
  def with_page(hPrinter)
    Win32api4ruby::Gdi.start_page(hPrinter)
    yield
  ensure
    Win32api4ruby::Gdi.end_page(hPrinter)
  end

  def print_dlg(str)
    Win32api4ruby::Comdlg.print_dlg(str)
  end

  # --------------------------------------------------------------------------------------------------------------
  def show_print_dialog
    # wird zwar gestartet, liefert aber keine gef�llte struktur zur�ck
    pdlg = Win32api4ruby::Comdlg.create_PRINTDLG
    pdlg[:hwndOwner] = 0
    pdlg[:hDevMode] = 0
    pdlg[:hDC] = 0
    # ~ pdlg[:Flags] = 0x140
    pdlg[:Flags] = PD_RETURNDC | PD_NOSELECTION
    # ~ pdlg[:Flags] = PD_RETURNDC | PD_PRINTSETUP | PD_NONETWORKBUTTON
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
    # ~ pdlg.each{|e| p e }

    # ~ bin_struct = pdlg.serialize
    # ~ ok = print_dlg(StringIO.new(bin_struct))
    # ~ pdlg = PRINTDLG.read(bin_struct)

    # ~ pd = [66, 0x140].pack("Lx16Lx46")
    # ~ ok = print_dlg(pd)
    ok = print_dlg(pdlg)

    p "res: #{ok.to_s(16)} pdlg: #{pdlg.inspect}"
    # ~ p PRINTDLG.read(pdlg)
    p pdlg[:lStructSize]
    p pdlg[0, 64].unpack("LLLLLLLLLLLLLLLL")
    # ~ p pd
    # ~ p pd.unpack("H*")
    # ~ p pd.unpack("LLLLLLLLLLLLLLLL")
    # ~ p pd.unpack("x8Lx4L")
    p "hdc: #{pdlg[:hDC]}"
    p "devMode: #{pdlg[:hDevMode]}"
    dm_prt = DL::PtrData.new(pdlg[:hDevMode], 100)
    p dm_prt.to_s

    p "devnames: #{pdlg[:hDevNames]}"
    hDevNames = pdlg[:hDevNames]
    pDevNames = Win32api4ruby::Kernel.global_lock(hDevNames)
    dn_prt = DL::PtrData.new(pDevNames, DL.sizeof("H" * 4))
    dn_prt.struct!("H" * 4,
      :wDriverOffset,
      :wDeviceOffset,
      :wOutputOffset,
      :wDefault)

    puts "wDriverOffset: #{dn_prt[:wDriverOffset]} wDeviceOffset: #{dn_prt[:wDeviceOffset]} wOutputOffset: #{dn_prt[:wOutputOffset]} wDefault: #{dn_prt[:wDefault]}"

    p DL::PtrData.new(pDevNames + dn_prt[:wDriverOffset]).to_s
    p DL::PtrData.new(pDevNames + dn_prt[:wDeviceOffset]).to_s
    p DL::PtrData.new(pDevNames + dn_prt[:wOutputOffset]).to_s
    p DL::PtrData.new(pDevNames + dn_prt[:wDefault]).to_s

    Win32api4ruby::Kernel.global_unlock(hDevNames)
    # ~ devmode, dc = pd.unpack("x8Lx4L")
  end

  def show_print_setup_dialog
    pdlg = Win32api4ruby::Comdlg.create_PAGESETUPDLG
    p "pdlg: #{pdlg.inspect}"
    p Win32api4ruby::Comdlg.print_setup_dlg(pdlg)

    p "pdlg: #{pdlg.inspect}"
  end

  WS_VISIBLE = 0x10000000
  def create_dummy_window(name = "dummy-window")
    Win32api4ruby::User.create_window_ex(0, "Button", name, WS_VISIBLE, 0, 0, 100, 100, 0, 0, 0, 0)
  end

  def show_print_dialog_ex
    pdlg = Win32api4ruby::Comdlg.create_PRINTDLGEX

    hWnd = create_dummy_window
    pdlg[:hwndOwner] = hWnd
    pdlg[:hDevMode] = 0
    pdlg[:hDevNames] = 0
    pdlg[:hDC] = 0
    pdlg[:Flags] = PD_RETURNDC | PD_COLLATE | PD_NOPAGENUMS
    pdlg[:Flags2] = 0
    pdlg[:ExclusionFlags] = 0
    pdlg[:nPageRanges] = 0
    pdlg[:nMaxPageRanges] = 10
    pdlg[:lpPageRanges] = "1234" * 2 * 10
    pdlg[:nMinPage] = 1
    pdlg[:nMaxPage] = 1000
    pdlg[:nCopies] = 1
    pdlg[:hInstance] = 0
    pdlg[:lpPrintTemplateName] = nil
    pdlg[:lpCallback] = nil
    pdlg[:nPropertyPages] = 0
    pdlg[:lphPropertyPages] = 0
    pdlg[:nStartPage] = 0 # START_PAGE_GENERAL
    pdlg[:dwResultAction] = 0

    p "pdlg: #{pdlg.inspect}"
    p Win32api4ruby::Comdlg.print_dlg_ex(pdlg)

    p "pdlg: #{pdlg.inspect}"
  end

  # --------------------------------------------------------------------------------------------------------------
  def parse_devmode(devmode)
    p devmode
    #      p devmode.unpack("p").to_s
    devicename, orient, duplex, formname = devmode.to_s.unpack("A32x12Sx16Sx6A32")
  end

  # --------------------------------------------------------------------------------------------------------------
  def print_doc_from_dialog(docString, docName, pageLength = 50)
    # need a more reasonable default for pageLength
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
        written = "\0" * 4
        docString.each_line do |line|
          line.chomp!
          if lines == 0
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
        # flush last page
        write_printer(hPrinter, "\f", 1, written)
        end_page_printer(hPrinter)
      end
    end
  end

  # --------------------------------------------------------------------------------------------------------------
  def print_doc(docString, printerName, docName = "printjob", pageLength = 50)
    _print_doc(docString, printerName, 0, docName, pageLength)
  end

  # --------------------------------------------------------------------------------------------------------------
  def print_graphic(devicename, datatype)
    # den Pfad ermitteln, wo das tempor�re File abgelegt werden soll
    tf = Tempfile.new("afile")
    temp_path = File.join(tf.path.split("/")[0..-2])
    tf.close(true)            # #<File:0x4016e3c0>\n0x40187c30

    Magick::RVG.dpi = 600
    crd_width = 85
    crd_height = 55

    img = Magick::RVG.new((crd_width + 10).mm, (crd_height + 10).mm) do |canvas|
      canvas.background_fill = "white"

      canvas.rect(crd_width.mm, crd_height.mm, 5.mm, 5.mm).styles(fill: "none", stroke: "black")
      canvas.text(200, 200, "das ist ein ganz neuer Test Test").styles(
        font_family: "Arial",
        font_size: 20.pt,
        fill: "black",
        font_weight: "bold",
        font_style: "normal"
      )

      canvas.text(100, 100, "Blue 15").styles(
        font_family: "Arial",
        font_size: 15.pt,
        fill: "blue",
        font_weight: "bold",
        font_style: "normal"
      )
      canvas.text(500, 100, "Green 15").styles(
        font_family: "Arial",
        font_size: 15.pt,
        fill: "green",
        font_weight: "bold",
        font_style: "normal"
      )
      canvas.text(900, 100, "Red 15").styles(
        font_family: "Arial",
        font_size: 15.pt,
        fill: "red",
        font_weight: "bold",
        font_style: "normal"
      )
    end
    pic = img.draw
    p pic

    # create_dc(lpszDriver, lpszDevice, lpszOutput, lpInitData)
    hDC = Win32api4ruby::Gdi.create_dc(nil, devicename, nil, nil)

    hPrinter = hDC

    # ~ devMode, dc = show_print_dialog
    # ~ devicename, orient, duplex, formname = parse_devmode(devMode)
    written = ""
    devMode = 0
    datatype = (devMode == 0) ? nil : "TEXT"

    with_doc("Test", hPrinter) do
      with_page(hPrinter) do
        bmdata = pic.to_blob {
          self.format = "rgb"
          self.depth = 8
        }
        puts "size: #{bmdata.length}"

        (0...pic.rows).each { |row_idx|
          linedata = bmdata[3 * row_idx * pic.columns, 3 * pic.columns]
          linedata = linedata.unpack("a3" * pic.columns).map { |a| a.reverse! }.pack("a3" * pic.columns)
          hBmp = Win32api4ruby::Gdi.create_bitmap(pic.columns, 1, 1, 24, linedata)
          # ~ p "hBmp: #{hBmp}"

          tmpDC = Win32api4ruby::Gdi.create_compatible_dc(hPrinter)

          oldBmp = Win32api4ruby::Gdi.select_object(tmpDC, hBmp)

          nXDest = 500
          nYDest = 500 + row_idx
          hdcSrc = tmpDC
          nXSrc = 0
          nYSrc = 0
          dwRop = SRCCOPY
          Win32api4ruby::Gdi.bit_blt(hPrinter, nXDest, nYDest, pic.columns, 1, hdcSrc, nXSrc, nYSrc, dwRop)

          Win32api4ruby::Gdi.select_object(tmpDC, oldBmp)
        }

        s = "Teststring"
        Win32api4ruby::Gdi.text_out(hPrinter, 10, 10, s, s.length)
      end
    end
  end
end
# ======================================================================================================
# ======================================================================================================
if __FILE__ == $0
  # ~ require 'libguib16.rb'
  rp = RubyPrinting.new

  #   rp.show_print_dialog
  # ~ rp.show_print_setup_dialog
  #   rp.show_print_dialog_ex
  #   rp.enum_printers
  rp.document_properties
  exit

  devicename = "Jaws PDF Creator"
  # ~ devicename = '\\\COMFILE1\P0049'
  # ~ devicename = "XeroxPhaser7750DN PS"
  # ~ rp.enum_printers
  rp.print_graphic(devicename, "RAW")

  exit

  docString = <<~EOF
    This is a test.
    Should be on a different line.
    Should be 3 lines in total, with a y at the end.
  EOF
  rp.print_doc(docString, devicename)
  # ~ rp.print_doc_from_dialog(docString, nil) # funktioniert nicht
end
