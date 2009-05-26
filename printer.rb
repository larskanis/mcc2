# -*- coding: UTF-8 -*-

# diese Klasse dient als Basis für die Printer, es macht keinen Sinn direkt ein Objekt von dieser Klasse zu erzeugen

if __FILE__ == $0
  require 'mcc2'
end


class Printer
  attr_reader :default_width
  attr_reader :default_height
  attr_reader :dpi
  
  def initialize
    @dpi = 300
    @w32gdi = Win32ApiGDI.new
    @w32user = Win32ApiUser.new
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
  def print_page(devicename, xml_doc, sorted_id_list, row, page_nr , page_width = default_width, page_height = default_height)
  
    #~ page_width ||= default_width
    #~ page_height ||= default_height
 
    # den Pfad ermitteln, wo das temporäre File abgelegt werden soll
    tf = Tempfile.new("afile") 
    temp_path = File.join(tf.path.split("/")[0..-2])
    tf.close(true)            # #<File:0x4016e3c0>\n0x40187c30 

    Magick::RVG.dpi = @dpi

    # todo zentralen Offset einbauen
    draw_pos_x = -5
    draw_pos_y = -5

    # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
      selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
      preview = false          # wird nur für Darstellung auf Bildschirm gebraucht
      img = Magick::RVG.new(page_width.mm, page_height.mm) do |canvas|
        canvas.background_fill = 'white'
        Page.new(page_nr).draw(canvas, draw_pos_x, draw_pos_y, xml_doc, sorted_id_list, preview, selected_object_id, row)
      end
    
    # das VRG in ein Bitmap konvertieren
    pic = img.draw
    
    # einen DeviceContext für den Drucker erzeugen
    hPrinter = @w32gdi.create_dc( nil, devicename, nil, nil);
    
    with_doc("Test", hPrinter) do  # todo aussagekräftigen Dokumentnamen übergeben
      with_page(hPrinter) do
      
        bmdata = pic.to_blob{
          self.format='rgb'
          self.depth = 8
        }
        #~ puts "size: #{bmdata.length}"
        
        # das Bild zeilenweise drucken, da es ein Problem mit dem Drucken von Bildern > 4MB gibt # todo Problem beseitigen und mit einem Mal drucken
        (0 ... pic.rows).each{|row_idx|
          
          # Windows-Bitmap erzeugen
          hBmp = @w32gdi.create_bitmap(pic.columns, 1, 1, 24, bmdata[3*row_idx*pic.columns, 3*pic.columns])
          #~ p "hBmp: #{hBmp}"
          
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
        }
      end
    end
    @w32gdi.delete_dc(hPrinter)
  end
  
end


if __FILE__ == $0
end
