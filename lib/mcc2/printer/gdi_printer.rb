# -*- coding: UTF-8 -*-
# diese Klasse dient als Basis für die Printer, es macht keinen Sinn direkt ein Objekt von dieser Klasse zu erzeugen

require 'win32api_base'
require 'win32api_gdi'
require 'win32api_user'
require 'win32api_winspool'
#~ require 'win32api_comdlg'
#~ require 'win32api_kernel'

require 'mcc2/printer/card_printer'
require 'mcc2/printer/rmagick_drawer'


module Mcc2
module Printer
class GdiPrinter < CardPrinter
  include RmagickDrawer
  
  #
  def initialize
    super
    @w32gdi = Win32ApiGDI.new
    @w32user = Win32ApiUser.new
    @w32printer = Winspool.new
  end
  #--------------------------------------------------------------------------------------------------------------
  
  #
  def with_doc(documentName, handleToPrinter)
    begin
      documentName << "\0"
      #~ p "documentName #{documentName}"
      docinfo = [documentName].pack('px12')
      #~ p "docinfo #{docinfo}"
      @w32gdi.start_doc(handleToPrinter, docinfo)
      yield
    ensure
      @w32gdi.end_doc(handleToPrinter)
    end
  end
  #--------------------------------------------------------------------------------------------------------------
  
  #
  def with_page(hPrinter)
    begin
      @w32gdi.start_page(hPrinter)
      yield
    ensure
      @w32gdi.end_page(hPrinter)
    end
  end
  #--------------------------------------------------------------------------------------------------------------
  
  
  def print_gdi_page(hPrinter, row, page_nr)
    self.dpi = @layout_file.get_attr_value(S_FILEPRINTER_DPI).to_f

    page_width =  @layout_file.get_attr_value(S_WIDTH).to_f
    page_height = @layout_file.get_attr_value(S_HEIGHT).to_f
    draw_pos_x  = @layout_file.get_attr_value(S_X_OFFSET).to_f
    draw_pos_y  = @layout_file.get_attr_value(S_Y_OFFSET).to_f

    # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
    selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
    preview = false          # wird nur für Darstellung auf Bildschirm gebraucht
    img = Magick::RVG.new(mm(page_width), mm(page_height)) do |canvas|
      canvas.background_fill = 'white'
      canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
        draw(canvas1, layout_file, preview, selected_object_id, row, page_nr)
      end
    end
    
    # das RVG in ein Bitmap konvertieren
    pic = img.draw
    
    with_page(hPrinter) do
      
      # die Magnetstreifendaten für die Personalisierung aufbereiten
      if (page_nr == 0) && (layout_file.get_attr_value(S_MAGSTRIPE) == S_TRUE)
        personalize_ms(hPrinter)
      end
      
      # die Bilddaten für die Seite aufbereiten
      bmdata = pic.to_blob{
        self.format='rgb'
        self.depth = 8
      }
      #~ now = Time.now
      #~ pic.write("test_#{now.strftime("%H%M%S")}.png")
      #~ break
      pack_rgb2bgr = 'a3'*pic.columns
      
      # das Bild zeilenweise drucken, da es ein Problem mit dem Drucken von Bildern > 4MB gibt # todo Problem beseitigen und mit einem Mal drucken
      (0 ... pic.rows).each{|row_idx|
        
        linedata = bmdata[3*row_idx*pic.columns, 3*pic.columns]
        # RGB -> BGR wandeln
        linedata = linedata.unpack(pack_rgb2bgr).map{|a| a.reverse! }.pack(pack_rgb2bgr)
        # Windows-Bitmap erzeugen
        hBmp = @w32gdi.create_bitmap(pic.columns, 1, 1, 24, linedata)
        
        tmpDC = @w32gdi.create_compatible_dc(hPrinter)
        oldBmp = @w32gdi.select_object( tmpDC, hBmp )
        
        nXDest = 0
        nYDest = 0 + row_idx
        hdcSrc = tmpDC
        nXSrc = 0
        nYSrc = 0
        dwRop = SRCCOPY
        @w32gdi.bit_blt(hPrinter, nXDest, nYDest, pic.columns, 1, hdcSrc, nXSrc, nYSrc, dwRop)
        
        @w32gdi.select_object( tmpDC, oldBmp )
        @w32gdi.delete_dc(tmpDC)
        @w32gdi.delete_object(hBmp)
        @w32gdi.delete_object(oldBmp)
      }
    end
  end

  #--------------------------------------------------------------------------------------------------------------
  
  def set_duplex(hPrinter, state)
    return
      #~ __in   HANDLE hPrinter,
      #~ __in   DWORD Level,
      #~ __out  LPBYTE pPrinter,
      #~ __in   DWORD cbBuf,
      #~ __out  LPDWORD pcbNeeded
    level = PRINTER_INFO_2
      
    # erst einmal ermitteln, wieviel Speicher gebraucht wird
    cbBuf = 0
    pPrinter = "\0" * cbBuf # Buffer
    @w32printer.get_printer(hPrinter, Level, pPrinter, cbBuf, pcbNeeded)
    
    # und dann die Infos holen
    cbBuf = pcbNeeded.unpack("V")[0] + 1
    pPrinterEnum = "\0" * cbBuf # Buffer für die Datenübergabe aufbereiten
    @w32printer.get_printer(hPrinter, Level, pPrinter, cbBuf, pcbNeeded)
    
  end
end
end
end
