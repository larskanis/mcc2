# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end

require 'dataman'

class ResourceNotFoundError < RuntimeError
end

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
  def draw(canvas, draw_pos_x, draw_pos_y, layout_file, preview, selected_object_id, row)
    width =  layout_file.get_attr_value(S_WIDTH).to_f
    height = layout_file.get_attr_value(S_HEIGHT).to_f
    encoding = layout_file.get_attr_value(S_DATASOURCEENCODING)
    
    if preview
      canvas.g.translate(draw_pos_x.mm, draw_pos_y.mm) do |canvas1|
        rx = 10
        canvas1.rect(Page.width_with_margins(width).mm, Page.height_with_margins(height).mm ).styles(:fill=>'none', :stroke=>'black')
      end
    end
    
    rmfl = []
    Magick.fonts.each{|mf| 
      rmfl << mf.name
    }
    
    canvas.g.translate((draw_pos_x + $pr.card_margin_left).mm, (draw_pos_y + $pr.card_margin_top).mm) do |canvas1|
      rx = 10
      # ..........................................................................................
      # Kartenhintergrund füllen (für Vorschau)
      if preview
        canvas1.rect(width.mm, height.mm ).round(rx).styles(:fill=>'lightgray', :stroke=>'none')
      end
      # ..........................................................................................
      # die graphischen Elemnte zeichnen
    
      # Text-Objekte
      sorted_id_list = layout_file.sorted_id_list
      sorted_id_list.each{|id|
        go = layout_file.xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[contains(., #{id.to_s})]").parent
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
                text_x = 0
                just = 'start'
              elsif just == "mitte"
                text_x = go_width.to_f / 2
                just = 'middle'
              elsif just == "rechts"
                text_x = go_width
                just = 'end'
              else 
                just = 'start' # falls eine fehlerhafte Ausrichtung eingegeben wurde, wird einfach links ausgerichtet
              end
              
              unless rmfl.index(font)
                raise ResourceNotFoundError, "Die Schriftart '#{font}' konnte nicht gefunden werden. Der Druck wird angehalten."
              end
              
              if data != ""
                body.text(text_x.mm, 0, data).styles(
                  :font => ["'", font, "'"].join,
                  :font_size => fontsize.pt, 
                  :fill => font_color, 
                  :text_anchor => just
                )
              end
            
            # Bildobjekt
            elsif typ == PICTUREOBJECT 
              if FileTest.file?(data)
                go_image = Magick::Image.read(data).first
                body.image(go_image, go_width.mm, go_height.mm)
              else
                raise ResourceNotFoundError, "Das Bild '#{data}' konnte nicht gefunden werden. Der Druck wird angehalten."
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
        if page_nr == 1 && layout_file.get_attr_value(S_MAGSTRIPE) == S_TRUE
          canvas1.g.translate(0, 4.mm){|ms_rect|
            ms_rect.rect(width.mm, 12.5.mm ).styles(:fill=>'black', :stroke=>'none', :opacity => 0.5)
            ms_node = layout_file.xml_doc.find_first(S_MAGSTRIPEPARAMS)
            (1..3).each{|spurnr|
              spur_data = ms_node.find_first('ms_spur' + spurnr.to_s).content
                ms_rect.text(3.mm, ((3.5 * spurnr) + 0.5).mm, "Spur #{spurnr}: #{spur_data}").styles(
                  :font => "Courier-New-Bold",
                  :font_size => 10.pt, 
                  :fill => 'white'
                )
            }
          }
        end
        if page_nr == 0 && layout_file.get_attr_value(S_CONTACTLESS) == S_TRUE
          rx = 0.5.mm
          canvas1.g.translate(3.mm, 3.mm).rect(5.mm, 5.mm ).round(rx).styles(:fill=>'gray', :stroke=>'none', :opacity => 0.5)
          rx = 3.mm
          canvas1.g.translate(4.mm, 4.mm).rect(75.mm, 45.mm ).round(rx).styles(:fill=>'none', :stroke=>'gray', :stroke_opacity => 0.5)
          canvas1.g.translate(5.mm, 5.mm).rect(73.mm, 43.mm ).round(rx).styles(:fill=>'none', :stroke=>'gray', :stroke_opacity => 0.5)
          canvas1.g.translate(6.mm, 6.mm).rect(71.mm, 41.mm ).round(rx).styles(:fill=>'none', :stroke=>'gray', :stroke_opacity => 0.5)
        end
        if page_nr == 0 && layout_file.get_attr_value(S_CONTACT) == S_TRUE
          rx = 2.mm
          canvas1.g.translate(8.mm, 18.mm).rect(13.mm, 12.mm ).round(rx).styles(:fill=>'yellow', :stroke=>'gray')
        end
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
