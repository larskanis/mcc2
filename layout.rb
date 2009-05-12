# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Layout
  attr_accessor :xml
  attr_accessor :filename
  attr_accessor :zoom
  attr_accessor :scale
  
#  attr_accessor :graphic_objects
#  attr_accessor :duplex
#  attr_accessor :chip
#  attr_accessor :magstripe
#  attr_accessor :height
#  attr_accessor :width
  
 	# ---------------------------------------------------------------------------------------------------------
  def initialize(parent, app)
    @filename = nil
    @parent = parent
    @app = app
    

    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      
      @lf = LayoutFrame.new parent
      @lf.iconlist_objects.appendHeader('ID', nil, 50)
      @lf.iconlist_objects.appendHeader('Name', nil, 100)
      @lf.iconlist_objects.appendHeader('Typ', nil, 100)
      
      @lf.splitter10.setSplit(0, 400)   
      @lf.splitter11.setSplit(0, 250)   
      @lf.splitter12.setSplit(0, 100)
      
      @image_view = FXImageView.new(@lf.verticalframe_right, :opts => LAYOUT_FILL_X | LAYOUT_FILL_Y)

      # .............................................................................................
      # die Aktionen definieren, die ausgeführt werden, wenn am Layout irgend etwas gearbeitet wird
      @lf.dial_zoom.connect(SEL_CHANGED){ set_zoom }
      @lf.dial_zoom.connect(SEL_LEFTBUTTONRELEASE){ draw_card }
      
      @lf.dial_zoom.value = 100
      set_zoom

      @lf.iconlist_objects.connect(SEL_SELECTED){ object_selection_changed }
      
      
      
      
      #~ @graphic_objects = {}
      #~ @duplex = false
      #~ @height = $pr.default_height
      #~ @width = $pr.default_width
      #~ @chip = Chip.new
      #~ @magstripe = Magstripe.new
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def object_selection_changed
    item_ID = @lf.iconlist_objects.currentItem
    @selected_object_id = @lf.iconlist_objects.getItemData(item_ID).to_i
    #~ p "id #{@selected_object_id} selektiert"
    node = @xml.get_objectnode_by_id(@selected_object_id)
    
    # allgemeine Attribute auslesen
    @lf.textfield_name.text = node.find(GOA_NAME).first.content
    
    # Typ-spezifische Attribute auslesen
    
    
    draw_card
  end
  # ---------------------------------------------------------------------------------------------------------
  def set_zoom
    @zoom = (@lf.dial_zoom.value + 1).to_f / 100
    @scale = 3.6
    #~ p "@zoom: #{@zoom}"
    #~ p "@scale: #{@scale}"
  end
  # ---------------------------------------------------------------------------------------------------------
  def draw_card
    # allgemeine Einstellungen des Image vornehmen
    dpi = 90
    width =  @xml.doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_WIDTH}").first.content.to_f
    height = @xml.doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_HEIGHT}").first.content.to_f
    
    Magick::RVG.dpi = dpi
    rvg = Magick::RVG.new(width.mm * @zoom, 2 * height.mm * @zoom).viewbox(0, 0, width * @scale, 2 * height * @scale) do |canvas|
#    rvg = Magick::RVG.new(width.mm * @zoom, 2 * height.mm * @zoom) do |canvas|
      # Verhältnis zwischen Viewbox und Größe im RVG entspricht einem Zoom (je größer die viewbox-Werte desto weiter weg erscheint das Bild)
      canvas.background_fill = 'yellow'
#      canvas.desc = "Example text01 - 'Hello, out there' in blue"

      #with_margins:: true - Rand wird mit ausgegeben
      
      with_margins = true
      #~ with_margins = false

      # ..........................................................................................
      # Rand zeichnen (für Vorschau)
      if with_margins
        rx = 10
        canvas.g.translate(0, 0) do |body|
          body.rect(width.mm, height.mm ).round(rx).styles(:fill=>'none', :stroke=>'blue')
        end
        canvas.g.translate(0, height.mm) do |body|
          body.rect(width.mm, height.mm ).round(rx).styles(:fill=>'none', :stroke=>'blue')
        end
      end
      
      # ..........................................................................................
      # die graphischen Elemnte zeichnen
    

      @xml.doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
        if go.find(GOA_TYP).first.content == TEXTOBJECT
          id = go.find(GOA_ID).first.content.to_i
          text = go.find(GOA_DATA).first.content
          x = go.find(GOA_X).first.content
          y = go.find(GOA_Y).first.content
          width = go.find(GOA_WIDTH).first.content
          height = go.find(GOA_HEIGHT).first.content
          canvas.text(x, y, text).styles(
            :font_family=>'Verdana', 
            :font_size=>15, 
            :fill=>'blue', 
            :font_weight=>'normal', 
            :font_style=>'normal')
            
          if @selected_object_id == id
            canvas.g.translate(x, y).rotate(-90) do |body|
              body.rect(width, height ).styles(:fill=>'none', :stroke=>'red')
            end
          end
            
        end
      }
    end
    #~ image.draw.write('test.gif')
    
    # ..........................................................................................
    # weitere Bearbeitungen (drehen, stretchen, etc.)
    
#    image = image.rotate(@rotation)
#    image = image.quantize(2, Magick::RGBColorspace, false)
    
    #print_image_info(image)
    
    # ..........................................................................................
    # Image in einen Blob schreiben, damit es dann aus diesem heraus angezeigt werden kann
    data = rvg.draw.to_blob{
      self.format = 'PNG'
    }
    
    # ..........................................................................................
    # das erzeugte Bild als Icon anzeigen
    fx_image = FXPNGImage.new(@app, data)
    fx_image.create
    @image_view.image = fx_image
    @image_view.show
    @image_view.recalc
  end
 	# ---------------------------------------------------------------------------------------------------------
  # lädt das INI-File und initialisiert die entsprechenden Variablen und Objekte
	def create_xml
    @xml = MyXML.new # erzeugt ein neue Layout-Objekt
    @xml.create      # füllt das Layoutobjekt mit der Grundstruktur
  end
 	# ---------------------------------------------------------------------------------------------------------
# lädt das INI-File und initialisiert die entsprechenden Variablen und Objekte
	def load_from_xml
    fn = FXFileDialog.getOpenFilename(@parent, 'Laden', '.', patterns = '*.XML', initial = 0)
    @filename = fn
#    XML.default_keep_blanks = false
    XML.indent_tree_output = true
    @xml = MyXML.new # erzeugt ein neue Layout-Objekt
    return nil if @filename == ""
    @xml.load(@filename)
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fill_objectlist 
      draw_card
      set_title
    end
    @filename
    #~ print @xml.doc.to_s
  end
 	# ---------------------------------------------------------------------------------------------------------
  def set_title
    p "set_title changed: #{@xml.changed.inspect}"
    @parent.title = "#{@filename}#{@xml.changed ? ' *' : '' }"
  end
 	# ---------------------------------------------------------------------------------------------------------
  # speichert alle GraphicObjekte und Layout-Einstellungen im INI-File
	def store_to_xml
    unless @filename
      fn = FXFileDialog.getSaveFilename(@parent, 'Speichern', '.', patterns = '*.XML', initial = 0)
      unless fn.split(".")[-1].downcase == 'xml'
        fn = [fn, 'XML'].join(".")
      end
      @filename = fn
    end
#    @xml.indent_tree_output = true
    @xml.doc.save(@filename, :indent => true)
    @xml.changed = false
    set_title
  end
 	# ---------------------------------------------------------------------------------------------------------
	# lädt das INI-File und initialisiert die entsprechenden Variablen und Objekte
	def load_from_ini
		oIni = MyIniFile::new(@inifile_name)
    
    # die Layout-Optionen laden
    @duplex = oIni.get_or_create(S_LAYOUT, S_DUPLEX, false)
    @height = oIni.get_or_create(S_LAYOUT, S_HEIGHT, $pr.default_height)
    @width = oIni.get_or_create(S_LAYOUT, S_WIDTH, $pr.default_width)
    
    # die CHIP-Optionen laden
    @chip = Chip.new
    @chip.params.each_with_index{|param, index|
      @chip.params[index] = oIni.get_or_create(S_CHIP, "#{S_PARAM}_#{index}", "")
    }
    
    # die Magnetstreifen-Optionen laden
    
    # alle Graphicobjekte laden
    oIni.sections.each{|s|
      #~ print "*"*50
      #~ print "\n"
      #~ print "[#{s}]\n"
      a = s.split('_')
      typ = a[0]
      id = a[1].to_i
      next if typ != TEXTOBJECT && typ != BARCODEOBJECT && typ != PICTUREOBJECT # hier nur GraphikObjekte laden

      o = GraphicObject.get_object_by_typ(typ)
      o.go_attributes[GOA_ID].attr_value = id
      # je nach Graphicobjekt-Typ die Attribute eines Graphicobjectes durchlaufen diese in das Object laden und falls nicht vorhanden, dann neu anlegen
      o.go_attributes.each_pair{|go_attribute_name, go_attribute|
        unless go_attribute.attr_name == GOA_TYP || go_attribute.attr_name == GOA_ID
          v = oIni.get_or_create(s, go_attribute_name, go_attribute.attr_value)
          o.go_attributes[go_attribute_name].attr_value = v
        end
      }
      #~ oIni[s].each { |k, v|
        #~ print "  #{k} = #{v}\n"
      #~ }
#      o.go_attributes.each{|e| p e }

      o.go_attributes.each_pair{|k, v| print "#{v.attr_name}: #{v.attr_value} \n" }
    }

    oIni.save
	end
 	# ---------------------------------------------------------------------------------------------------------
  # speichert alle GraphicObjekte und Layout-Einstellungen im INI-File
	def store_to_ini
		oIni = MyIniFile::new(@inifile_name)
    
    # die Layout-Optionen speichern
    oIni.store(S_LAYOUT, S_DUPLEX, @duplex)
    oIni.store(S_LAYOUT, S_HEIGHT, @height)
    oIni.store(S_LAYOUT, S_WIDTH, @width)
    
    # die CHIP-Optionen speichern
    @chip.params.each_with_index{|param, index|
      oIni.store(S_CHIP, "#{S_PARAM}_#{index}", param)
    }
    
    # die Magnetstreifen-Optionen speichern
    
    # alle Graphicobjekte durchlaufen und speichern
    @graphic_objects.each_pair{|graphic_object_name, graphic_object_attributes|
      graphic_object_attributes.go_attributes.each_pair{|go_attribute_name, go_attribute|
        # alle Attribute, außer Typ und ID (diese stehen schon im Sektor) im INI-File speichern
        unless go_attribute.attr_name == GOA_TYP || go_attribute.attr_name == GOA_ID
          section = graphic_object_name
          key = go_attribute.attr_name
          value = go_attribute.attr_value
          oIni.store(section, key, value)
        end
      }
    }
    
    oIni.save
  end
 	# ---------------------------------------------------------------------------------------------------------
  # fügt ein GraphicObjekt zur Objektliste hinzu
  def add_object(typ)
    o = GraphicObject.get_object_by_typ(typ)
    id = get_new_id
 		node = @xml.doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}")
    node << go = XML::Node.new(GRAPHICOBJECT)
    go << XML::Node.new(GOA_TYP, typ)
    go << XML::Node.new(GOA_ID, id.to_s)
    o.go_attributes.each_pair{|goa_name, go_attribute|
      if go_attribute.attr_name != GOA_ID && go_attribute.attr_name != GOA_TYP
        go << XML::Node.new(go_attribute.attr_name, go_attribute.attr_value.to_s)
      end
    }
    
    #~ print @xml.doc.to_s
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fill_objectlist
      draw_card
    end
  end
 	# ---------------------------------------------------------------------------------------------------------
  # 
  def fill_objectlist
    @lf.iconlist_objects.clearItems
		@xml.doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
      id = go.find(GOA_ID).first.content
      name = go.find(GOA_NAME).first.content
      typ = go.find(GOA_TYP).first.content
      @lf.iconlist_objects.appendItem([id, name, typ].join("\t"), nil, nil, id)
    }
  end
 	# ---------------------------------------------------------------------------------------------------------
  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
		@xml.doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
      id = go.find(GOA_ID).first.content.to_i+1 if go.find(GOA_ID).first.content.to_i >= id
    }
    id
  end
  
end

#*****************************************************************************
# Main

if __FILE__ == $0
  system('ruby mcc2.rb')
  exit
  lay = Layout.new(nil, nil)
  lay.create_xml
  
  #~ lay.add_object(TEXTOBJECT)  
  lay.add_object(BARCODEOBJECT)  
  lay.add_object(PICTUREOBJECT)  
  lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  #~ print lay.xml.doc.to_s
#  lay.store_to_ini
  #~ lay.load_from_ini
end
