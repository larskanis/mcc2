# -*- coding: UTF-8 -*-

require 'win32api4ruby'
require 'mcc2/printer/card_printer'
require 'mcc2/printer/rmagick_drawer'


module Mcc2
module Printer
class GdiPrinter < CardPrinter
  include RmagickDrawer
  
  
  #
  def with_doc(documentName, handleToPrinter)
    begin
      documentName << "\0"
      #~ p "documentName #{documentName}"
      docinfo = [documentName].pack('px12')
      #~ p "docinfo #{docinfo}"
      Win32api4ruby::Gdi.start_doc(handleToPrinter, docinfo)
      yield
    ensure
      Win32api4ruby::Gdi.end_doc(handleToPrinter)
    end
  end
  #--------------------------------------------------------------------------------------------------------------
  
  #
  def with_page(hPrinter)
    begin
      Win32api4ruby::Gdi.start_page(hPrinter)
      yield
    ensure
      Win32api4ruby::Gdi.end_page(hPrinter)
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
        hBmp = Win32api4ruby::Gdi.create_bitmap(pic.columns, 1, 1, 24, linedata)
        
        tmpDC = Win32api4ruby::Gdi.create_compatible_dc(hPrinter)
        oldBmp = Win32api4ruby::Gdi.select_object( tmpDC, hBmp )
        
        nXDest = 0
        nYDest = 0 + row_idx
        hdcSrc = tmpDC
        nXSrc = 0
        nYSrc = 0
        dwRop = SRCCOPY
        Win32api4ruby::Gdi.bit_blt(hPrinter, nXDest, nYDest, pic.columns, 1, hdcSrc, nXSrc, nYSrc, dwRop)
        
        Win32api4ruby::Gdi.select_object( tmpDC, oldBmp )
        Win32api4ruby::Gdi.delete_dc(tmpDC)
        Win32api4ruby::Gdi.delete_object(hBmp)
        Win32api4ruby::Gdi.delete_object(oldBmp)
      }
    end
  end

end
end
end
