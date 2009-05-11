# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Layout
  attr_accessor :xml
  attr_accessor :filename
  
#  attr_accessor :graphic_objects
#  attr_accessor :duplex
#  attr_accessor :chip
#  attr_accessor :magstripe
#  attr_accessor :height
#  attr_accessor :width
  
 	# ---------------------------------------------------------------------------------------------------------
  def initialize(parent, app)
    @parent = parent
    @app = app
    @xml = MyXML.new # erzeugt ein neue Layout-Objekt
    @xml.create      # füllt das Layoutobjekt mit der Grundstruktur
    
    @filename = nil
    
    @lf = LayoutFrame.new parent
    @lf.iconlist_objects.appendHeader("ID", nil, 50)
    @lf.iconlist_objects.appendHeader("Name", nil, 100)
    @lf.iconlist_objects.appendHeader("Typ", nil, 100)
    
    #~ setSplit(index, size)   
    @lf.splitter10.setSplit(0, 400)   
    @lf.splitter11.setSplit(0, 250)   
    @lf.splitter12.setSplit(0, 100)

    draw_card
    
    #~ @graphic_objects = {}
    #~ @duplex = false
    #~ @height = $pr.default_height
    #~ @width = $pr.default_width
    #~ @chip = Chip.new
    #~ @magstripe = Magstripe.new
  end
 	# ---------------------------------------------------------------------------------------------------------
  def draw_card

    @dpi = 72
#		@image = Image.new(@width * @scale, @height * @scale)
		@image = Image.new(200 * 1, 200 * 1)
# 		@image.format = "PCX"
		@image.background_color = 'white'
		@image.border_color = 'red'
		@image.units = PixelsPerInchResolution
		@image.x_resolution = @dpi
		@image.y_resolution = @dpi

#    @lf.canvas_card.drawRoundRectangle(10, 10, 100, 100, 5, 5)
#    @lf.scrollarea_preview

    	#Gibt die Pixeldaten des erzeugten PCX-Bildes zurück.
    #with_margins:: true - Rand wird mit ausgegeben
    
    with_margins = true
    image = @image.copy
    
    #Rand zeichnen 
    if with_margins
      draw = Magick::Draw.new	
      draw.fill_opacity(0)
      draw.stroke('black')
      draw.stroke_antialias(false)
      #~ draw.rectangle(@x, @y, @max_x, @max_y)
      draw.rectangle(100, 100, 25, 25)
      draw.draw(image)
    end
    
#    image = image.rotate(@rotation)
#    image = image.quantize(2, Magick::RGBColorspace, false)
    
    #print_image_info(image)
    data = image.to_blob{
      self.format = "PNG"
    }
    
		#~ if icon.width <= 1
			#~ raise PreviewError.new("PCXIcon konnte nicht korrekt erzeugt werden (kann unter Linux an veralteter ImageMagick-Verion liegen, wenn das Bild mit RMagick erzeugt wurde)")
		#~ end
    
		icon = FXPNGIcon.new(@app, data)
    FXLabel.new(@lf.scrollwindow_preview, "", icon)
    #~ FXLabel.new(@lf.verticalframe_right, "", icon)
    
		@xml.doc.find("//Root/GraphicObjects/#{GRAPHICOBJECT}").each{|go|
      if go.find(GOA_TYP).first.content = TEXTOBJECT
        text = go.find(GOA_DATA).first.content
        FXLabel.new(@lf.scrollwindow_preview, text, nil){|label|
#          label.
        }
      end
    }
    
  end
 	# ---------------------------------------------------------------------------------------------------------
# lädt das INI-File und initialisiert die entsprechenden Variablen und Objekte
	def load_from_xml
    fn = FXFileDialog.getOpenFilename(@parent, "Speichern", ".", patterns="*.XML", initial=0)
    @filename = fn
    @xml = MyXML.new # erzeugt ein neue Layout-Objekt
    @xml.load(@filename)
    fill_objectlist
  end
 	# ---------------------------------------------------------------------------------------------------------
  # speichert alle GraphicObjekte und Layout-Einstellungen im INI-File
	def store_to_xml
    unless @filename
      fn = FXFileDialog.getSaveFilename(@parent, "Speichern", ".", patterns="*.XML", initial=0)
      unless fn.split(".")[-1].downcase == "xml"
        fn = [fn, 'XML'].join(".")
      end
      @filename = fn
    end
    @xml.doc.save(@filename)
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
      a = s.split("_")
      typ = a[0]
      id = a[1].to_i
      next if typ != TEXTOBJECT && typ != BARCODEOBJECT && typ != PICTUREOBJECT # hier nur GraphikObjekte laden

      o = get_object_by_typ(typ)
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
  def get_object_by_typ(typ)
    if typ == TEXTOBJECT then TextObject.new
    elsif typ == BARCODEOBJECT then BarcodeObject.new
    elsif typ == PICTUREOBJECT then PictureObject.new
    end
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  # fügt ein GraphicObjekt zur Objektliste hinzu
  def add_object(typ)
    o = get_object_by_typ(typ)
    id = get_new_id
 		node = @xml.doc.find_first("//Root/GraphicObjects")
    node << go = XML::Node.new(GRAPHICOBJECT)
    go << XML::Node.new(GOA_TYP, typ)
    go << XML::Node.new(GOA_ID, id.to_s)
    o.go_attributes.each_pair{|goa_name, go_attribute|
      unless go_attribute.attr_name == GOA_ID
        go << XML::Node.new(go_attribute.attr_name, go_attribute.attr_value.to_s)
      end
    }
    fill_objectlist
    draw_card
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  # 
  def fill_objectlist
    @lf.iconlist_objects.clearItems
		@xml.doc.find("//Root/GraphicObjects/#{GRAPHICOBJECT}").each{|go|
      id = go.find(GOA_ID).first.content
      name = go.find(GOA_NAME).first.content
      typ = go.find(GOA_TYP).first.content
      @lf.iconlist_objects.appendItem([id, name, typ].join("\t"))
    }
  end
 	# ---------------------------------------------------------------------------------------------------------
  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
		@xml.doc.find("//Root/GraphicObjects/#{GRAPHICOBJECT}").each{|go|
      id = go.find(GOA_ID).first.content.to_i+1 if go.find(GOA_ID).first.content.to_i >= id
    }
    id
  end
  
end


if __FILE__ == $0
  system("ruby mcc2.rb")
  #~ lay = Layout.new("layout_test.xml", nil)
  
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(PICTUREOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  #~ print lay.xml.doc.to_s
#  lay.store_to_ini
  #~ lay.load_from_ini
end
