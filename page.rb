# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Page
  
 	# ---------------------------------------------------------------------------------------------------------
  def self.draw(canvas, drwa_paos_x, drwa_paos_y, page_nr, xml, preview)
    canvas.g.translate(drwa_paos_x, drwa_paos_y) do |canvas1|
      width =  xml.doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_WIDTH}").first.content.to_f
      height = xml.doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_HEIGHT}").first.content.to_f
      # ..........................................................................................
      # Rand zeichnen (für Vorschau)
      if preview
        rx = 10
        canvas1.rect(width.mm, height.mm ).round(rx).styles(:fill=>'yellow', :stroke=>'blue')
      end
      
      # ..........................................................................................
      # die graphischen Elemnte zeichnen
    
      # Text-Objekte
      xml.doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
        # nur die Objekte zeichnen, die auf diese Seite sollen
        if go.find(GOA_PAGE_NR).first.content.to_i == page_nr
          if go.find(GOA_TYP).first.content == TEXTOBJECT 
            id = go.find(GOA_ID).first.content.to_i
            text = go.find(GOA_DATA).first.content
            x = go.find(GOA_X).first.content.to_f.mm
            y = go.find(GOA_Y).first.content.to_f.mm
            width = go.find(GOA_WIDTH).first.content.to_f.mm
            height = go.find(GOA_HEIGHT).first.content.to_f.mm
            canvas1.text(x, y, text).styles(
              :font_family=>'Verdana', 
              :font_size=>15, 
              :fill=>'blue', 
              :font_weight=>'normal', 
              :font_style=>'normal')
              
            if @selected_object_id == id
              canvas1.g.translate(x, y).rotate(-90) do |body|
                body.rect(width, height ).styles(:fill=>'none', :stroke=>'red')
              end
            end
              
          end
        end
      }
        
      # Bild-Objekte
      
      # Barcode-Objekte
    end
    
  end
end

#*****************************************************************************
# Main

if __FILE__ == $0
  system('ruby mcc2.rb')
end
