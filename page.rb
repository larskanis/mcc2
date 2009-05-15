# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Page
 	# ---------------------------------------------------------------------------------------------------------
  def self.width_with_margins(width)
    width + $pr.card_margin_left + $pr.card_margin_right
  end
 	# ---------------------------------------------------------------------------------------------------------
  def self.height_with_margins(height)
    height + $pr.card_margin_bottom + $pr.card_margin_top
  end
 	# ---------------------------------------------------------------------------------------------------------
  def self.draw(canvas, draw_pos_x, draw_pos_y, page_nr, xml_doc, preview, selected_object_id)
    width =  xml_doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_WIDTH}").first.content.to_f
    height = xml_doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_HEIGHT}").first.content.to_f
    
    if preview
      canvas.g.translate(draw_pos_x, draw_pos_y) do |canvas1|
        rx = 10
        canvas1.rect(Page.width_with_margins(width).mm, Page.height_with_margins(height).mm ).styles(:fill=>'none', :stroke=>'black')
      end
    end

    canvas.g.translate(draw_pos_x + $pr.card_margin_left.mm, draw_pos_y + $pr.card_margin_top.mm) do |canvas1|
      # ..........................................................................................
      # Rand zeichnen (für Vorschau)
      if preview
        rx = 10
        canvas1.rect(width.mm, height.mm ).round(rx).styles(:fill=>'yellow', :stroke=>'blue')
      end
      
      # ..........................................................................................
      # die graphischen Elemnte zeichnen
    
      # Text-Objekte
      xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
        # nur die Objekte zeichnen, die auf diese Seite sollen
        if go.find(GOA_PAGE_NR).first.content.to_i == page_nr
          if go.find(GOA_TYP).first.content == TEXTOBJECT 
          
            id = go.find(GOA_ID).first.content.to_i
            text = go.find(GOA_DATA).first.content
            x = go.find(GOA_X).first.content.to_f.mm
            y = go.find(GOA_Y).first.content.to_f.mm
            go_width = go.find(GOA_WIDTH).first.content.to_f.mm
            go_height = go.find(GOA_HEIGHT).first.content.to_f.mm
            font = go.find(GOA_FONT_TYP).first.content
            fontsize = go.find(GOA_FONT_HEIGHT).first.content.to_f
            rotation = go.find(GOA_ROTATION).first.content.to_f
            font_color = ["#", go.find(GOA_FONT_COLOR).first.content].join
            font_color = Page.check_color_definition(font_color)
            
            
            canvas1.text(x, y, text).styles(
              :font_family => font, 
              :font_size => fontsize, 
              :fill => font_color, 
              :font_weight=>'normal', 
              :font_style=>'normal').rotate(rotation)
            
            # in Vorschau einen Rahmen um das selektierte Objekt zeichnen
            if preview && selected_object_id == id 
              canvas1.g.translate(x, y - go_height) do |body|
                body.rect(go_width, go_height ).styles(:fill=>'none', :stroke=>'red')
              end
            end
              
          end
        end
      }
        
      # Bild-Objekte
      
      # Barcode-Objekte
      
    end
  end
 	# ---------------------------------------------------------------------------------------------------------
  def self.check_color_definition(color)
    # erstellt einen Dummy-Text, um zu testen, ob die Farbdefinition gültig ist
    # liefert die Farbe zurück, wenn sie gültig ist, ansonsten liefert sie vorläufig schwarz als Standard zurück
    
    begin
      rvg = Magick::RVG.new(1, 1) do |canvas|
        canvas.text(1, 1, "1").styles(
          :font_family => "Arial", 
          :font_size => 10, 
          :fill => color, 
          :font_weight=>'normal', 
          :font_style=>'normal')
      end
      rvg.draw.to_blob{
        self.format = 'PNG'
      }
    rescue => e
      return "#000000FF"
    end
    color
  end
end

#*****************************************************************************
# Main

if __FILE__ == $0
  system('ruby mcc2.rb')
end
