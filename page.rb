# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end

require 'dataman'


class Page
  attr_accessor :page_nr
  
  #
  def initialize(page_nr)
    @page_nr = page_nr
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def self.width_with_margins(width)
    width + $pr.card_margin_left + $pr.card_margin_right
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def self.height_with_margins(height)
    height + $pr.card_margin_bottom + $pr.card_margin_top
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def draw(canvas, draw_pos_x, draw_pos_y, child, preview, selected_object_id, row)
    width =  child.get_attr_value(S_WIDTH).to_f
    height = child.get_attr_value(S_HEIGHT).to_f
    encoding = child.get_attr_value(S_DATASOURCEENCODING)
    
    if preview
      canvas.g.translate(draw_pos_x.mm, draw_pos_y.mm) do |canvas1|
        rx = 10
        canvas1.rect(Page.width_with_margins(width).mm, Page.height_with_margins(height).mm ).styles(:fill=>'none', :stroke=>'black')
      end
    end
    
    canvas.g.translate((draw_pos_x + $pr.card_margin_left).mm, (draw_pos_y + $pr.card_margin_top).mm) do |canvas1|
      rx = 10
      # ..........................................................................................
      # Kartenhintergrund füllen (für Vorschau)
      if preview
        canvas1.rect(width.mm, height.mm ).round(rx).styles(:fill=>'yellow', :stroke=>'none')
      end
      # ..........................................................................................
      # die graphischen Elemnte zeichnen
    
      # Text-Objekte
      sorted_id_list = child.sorted_id_list
      sorted_id_list.each{|id|
        go = child.xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[contains(., #{id.to_s})]").parent
        # nur die Objekte zeichnen, die auf diese Seite sollen
        if go.find(GOA_PAGE_NR).first.content.to_i == @page_nr
        
          # die allgemeinen Attribute ermitteln
          id = go.find_first(GOA_ID).content.to_i
          x = go.find_first(GOA_X).content.to_f
          y = go.find_first(GOA_Y).content.to_f
          go_width = go.find_first(GOA_WIDTH).content.to_f
          go_height = go.find_first(GOA_HEIGHT).content.to_f
          rotation = go.find_first(GOA_ROTATION).content.to_f
          typ = go.find_first(GOA_TYP).content
          data = DataMan.replace_variables(go.find_first(GOA_DATA).content, row, encoding)
          
          canvas1.g.translate(x.mm, y.mm).rotate(rotation) do |body|
            # ............................................................................................................
            # die Objekt-spezifischen Attribute ermitteln
            # Textobjekt
            if typ == TEXTOBJECT 
            
              font = go.find(GOA_FONT_TYP).first.content
              fontsize = go.find(GOA_FONT_HEIGHT).first.content.to_f
              font_color = ["#", go.find(GOA_FONT_COLOR).first.content].join
              font_color = Page.check_color_definition(font_color)
              just = go.find(GOA_JUSTIFICATION).first.content.downcase
              if just == "links"
                just == 'start'
              elsif just == "mitte"
                just == 'middle'
              elsif just == "rechts"
                just == 'end'
              else 
                just == 'start' # falls eine fehlerhafte Ausrichtung eingegeben wurde, wird einfach links ausgerichtet
              end
              
              if data != ""
                body.text(0, 0, data).styles(
                  :font_family => font, 
                  :font_size => fontsize.pt, 
                  :fill => font_color, 
                  :font_weight => 'normal', 
                  :font_style => 'normal'
  #                :text_anchor => just
                )
              end
            
            # Bildobjekt
            elsif typ == PICTUREOBJECT 
              if FileTest.exists?(data)
                go_image = ::Magick::Image.read(data).first
                body.image(go_image, go_width.mm, go_height.mm)
              end
            end
            
            # Barcode-Objekte
            
            # ............................................................................................................
            
            # in Vorschau einen Rahmen um das selektierte Objekt zeichnen
            if preview && selected_object_id == id 
              body.rect(go_width.mm, go_height.mm).styles(:fill=>'none', :stroke=>'red')
            end
              
          end
        end
      }
        
      
      
      # ..........................................................................................
      # Rand zeichnen (für Vorschau)
      if preview
        canvas1.rect(width.mm, height.mm ).round(rx).styles(:fill=>'none', :stroke=>'blue')
      end
      
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
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
