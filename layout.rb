# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Layout
  attr_accessor :changed
  attr_accessor :xml_doc
  attr_accessor :filename
  attr_accessor :zoom
  attr_accessor :scale
  
  attr_accessor :attributes
  
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
    
    @attributes = {}
    add_attr(S_DUPLEX, Integer, 0)
    add_attr(S_WIDTH, Integer, $pr.default_width)
    add_attr(S_HEIGHT, Integer, $pr.default_height)
    add_attr(S_DATASOURCE, String, "")
    
    @changed = false

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
      
      
      @lf.textfield_name.connect(SEL_COMMAND){ textfield_name_exit }
      text_field_trigger = SEL_COMMAND
#      text_field_trigger = SEL_CHANGED # geht sehr langsam und macht bei Barcode und Bild Probleme
      @lf.textfield_data_non_text.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_data.connect(SEL_CHANGED){|sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_sample_data.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_SAMPLE_DATA) }
      
      # .............................................................................................
      # Korrektur, da der LIBGUI-Builder irgendwie einen Fehler macht
      @lf.matrix1.numColumns = 2 
      @lf.matrix2.numColumns = 2 
      @lf.matrix3.numColumns = 2 
    end
  end
  # ---------------------------------------------------------------------------------------------------------
#    node['object_name'] = "Test" # Attribute lesen und schreiben
#    p node.debug
  # ---------------------------------------------------------------------------------------------------------
  def textfield_exit(sender, attr_name)
    node = get_objectnode_by_id(@selected_object_id).find(attr_name)
    if sender.text != node.first.content
      node.first.content = sender.text
      changed_attributes
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def textfield_name_exit
    orig_name = get_objectnode_by_id(@selected_object_id).find(GOA_NAME)
    if @lf.textfield_name.text != orig_name.first.content
      orig_name.first.content = @lf.textfield_name.text
      changed_attributes
      fill_objectlist
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  # kann jedesmal dann aufgerufen werden, wenn ein Attribut des Layouts geändert wurde
  # es wird das changed-Flag gesetzt und der Titel aktualisiert und die Vorschau neu gezeichnet
  def changed_attributes
    @changed = true
    draw_card
    set_title
  end
  # ---------------------------------------------------------------------------------------------------------
  def add_attr(name, typ, default)
    attr = GO_Attribut.new(name, typ, default) 
    @attributes[attr.attr_name] = attr
  end
  # ---------------------------------------------------------------------------------------------------------
  def object_selection_changed
    item_ID = @lf.iconlist_objects.currentItem
    @selected_object_id = @lf.iconlist_objects.getItemData(item_ID).to_i
    #~ p "id #{@selected_object_id} selektiert"
    node = get_objectnode_by_id(@selected_object_id)
    
    # allgemeine Attribute auslesen
    @lf.textfield_name.text = node.find(GOA_NAME).first.content
    @lf.textfield_data_non_text.text = node.find(GOA_DATA).first.content
    @lf.textfield_data.text = node.find(GOA_DATA).first.content
    @lf.textfield_sample_data.text = node.find(GOA_SAMPLE_DATA).first.content
    
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
    width =  @xml_doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_WIDTH}").first.content.to_f
    height = @xml_doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_HEIGHT}").first.content.to_f
    
    Magick::RVG.dpi = dpi
    
    preview = true
    
    card_offset = 10
    
    image_width = (Page.width_with_margins(width) * @zoom).mm
    image_height = ((2 * Page.height_with_margins(height) + card_offset) * @zoom ).mm
    
    scale_width = Page.width_with_margins(width) * @scale 
    scale_height = (2 * Page.height_with_margins(height) + card_offset) * @scale
    
    rvg = Magick::RVG.new(image_width, image_height).viewbox(0, 0, scale_width, scale_height) do |canvas|
      # Verhältnis zwischen Viewbox und Größe im RVG entspricht einem Zoom (je größer die viewbox-Werte desto weiter weg erscheint das Bild)
    
      drwa_pos_x = 0
      drwa_pos_y = 0
      Page.draw(canvas, drwa_pos_x, drwa_pos_y, 0, @xml_doc, preview, @selected_object_id) # Seite 1 drucken
      
      drwa_pos_y = (Page.height_with_margins(height) + card_offset).mm
      Page.draw(canvas, drwa_pos_x, drwa_pos_y, 1, @xml_doc, preview, @selected_object_id) # Seite 2 drucken
      
      canvas.background_fill = 'white'
      #~ canvas.background_fill = 'gray'
      
    end
    #~ image.draw.write('test.gif')
    
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
  # erzeugt eine neue XML-Datei und initialisiert die entsprechenden Variablen und Objekte
	def create_xml
    @xml_doc = LibXML::XML::Document.new
    @xml_doc.encoding = XML::Encoding::UTF_8
    @xml_doc.root = XML::Node.new(S_ROOT)
    
    # Layout definieren
    @xml_doc.root << node = XML::Node.new(S_LAYOUT)
      attributes.each_pair{|attr_name, attr|
        node << XML::Node.new(attr.attr_name, attr.attr_value.to_s)
      }
    
    # Chip definieren
    @xml_doc.root << node = XML::Node.new(S_CHIP)
    chip = Chip.new
    (1..chip.anz_params).each{|i|
      node << param = XML::Node.new("#{S_PARAM}_#{i}", "")
    }
    
    # Magstripe definieren
    @xml_doc.root << node = XML::Node.new(S_MAGSTRIPE)
    
    # Container für die GraphikObjekte definieren definieren
    @xml_doc.root << node = XML::Node.new(GRAPHICOBJECTS)
    
    draw_card
  end
 	# ---------------------------------------------------------------------------------------------------------
  # lädt das XML-File und initialisiert die entsprechenden Variablen und Objekte
	def load_from_xml
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fn = FXFileDialog.getOpenFilename(@parent, 'Laden', '.', patterns = '*.XML', initial = 0)
      @filename = fn
    end
    XML.indent_tree_output = true
    return nil if @filename == ""
    
#    @xml_doc = LibXML::XML::Document.file(filename, :options => XML::Parser::Options::NOBLANKS | XML::Parser::Options::PEDANTIC | XML::Parser::Options::COMPACT)
    @xml_doc = LibXML::XML::Document.file(@filename, :options => XML::Parser::Options::NOBLANKS )
    # kontrollieren, ob alle Nodes des Layouts existieren, ansonsten anlegen und als 'changed' markieren
    lay_attrs = @xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
    @attributes.each_pair{|attr_bez, attr|
      element = lay_attrs.find_first(attr.attr_name)
      unless element
        lay_attrs << XML::Node.new(attr.attr_name, attr.attr_value.to_s)
        @changed = true
      end
    }
    
    # kontrollieren, ob alle Nodes des Chips existieren, ansonsten anlegen und als 'changed' markieren
    chip = Chip.new
    chip_attrs = @xml_doc.find_first("//#{S_ROOT}/#{S_CHIP}")
    (1..chip.anz_params).each{|i|
      attr_name = "#{S_PARAM}_#{i}"
      element = chip_attrs.find_first(attr_name)
      unless element
        chip_attrs << param = XML::Node.new(attr_name , "")
        @changed = true
      end
    }
    
    # kontrollieren, ob alle Nodes des Magstripes existieren, ansonsten anlegen und als 'changed' markieren
    # todo
    
    # kontrollieren, ob alle Nodes der GraphicObjects existieren, ansonsten anlegen und als 'changed' markieren
    @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
      typ = go_struct.find(GOA_TYP).first.content
      go = GraphicObject.get_object_by_typ(typ)
      go.go_attributes.each_pair{|go_attrname, go_attr|
        element = go_struct.find_first(go_attr.attr_name)
        unless element
          go_struct << XML::Node.new(go_attr.attr_name, go_attr.attr_value.to_s)
          @changed = true
        end
      }
    }
    
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fill_objectlist 
      draw_card
      set_title
    end
    @filename
    #~ print @xml_doc.to_s
  end
	# ---------------------------------------------------------------------------------------------------------
  def get_objectnode_by_id(id)
    @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
      if go_struct.find(GOA_ID).first.content.to_i == id
        return go_struct
      end
    }
    nil
  end
 	# ---------------------------------------------------------------------------------------------------------
  def set_title
    #~ p "set_title changed: #{@changed.inspect}"
    @parent.title = "#{@filename}#{@changed ? ' *' : '' }"
  end
 	# ---------------------------------------------------------------------------------------------------------
  # speichert alle GraphicObjekte und Layout-Einstellungen im XML-File
	def store_to_xml
    unless @filename
      fn = FXFileDialog.getSaveFilename(@parent, 'Speichern', '.', patterns = '*.XML', initial = 0)
      unless fn.split(".")[-1].downcase == 'xml'
        fn = [fn, 'XML'].join(".")
      end
      @filename = fn
    end
    file = File.new(@filename,'w')
    @xml_doc.save(@filename)
    file.close
    @changed = false
    set_title
  end
 	# ---------------------------------------------------------------------------------------------------------
  # fügt ein GraphicObjekt zur Objektliste hinzu
  def add_object(typ)
    o = GraphicObject.get_object_by_typ(typ)
    id = get_new_id
 		node = @xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}")
    node << go = XML::Node.new(GRAPHICOBJECT)
    go << XML::Node.new(GOA_TYP, typ)
    go << XML::Node.new(GOA_ID, id.to_s)
    o.go_attributes.each_pair{|goa_name, go_attribute|
      if go_attribute.attr_name != GOA_ID && go_attribute.attr_name != GOA_TYP
        go << XML::Node.new(go_attribute.attr_name, go_attribute.attr_value.to_s)
      end
    }
    
    #~ print @xml_doc.to_s
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fill_objectlist
      draw_card
    end
  end
 	# ---------------------------------------------------------------------------------------------------------
  # 
  def fill_objectlist
    @lf.iconlist_objects.clearItems
		@xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
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
		@xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
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
  
  # ...........................................................
  # Test für das Erstellen einer neune XML-Datei
  lay.filename = 't:\Project\MCC2a\trunk\layouts\Test1.XML'
  lay.load_from_xml
  # ...........................................................
  # Test für das Erstellen einer neune XML-Datei
  #~ lay.create_xml
  
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(PICTUREOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  
  
  print lay.xml_doc.to_s
end
