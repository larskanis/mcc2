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
    
    close_dataman
    
    @attributes = {}
    add_attr(S_DUPLEX, Integer, 0)
    add_attr(S_WIDTH, Integer, $pr.default_width)
    add_attr(S_HEIGHT, Integer, $pr.default_height)
    add_attr(S_DATASOURCE, String, "")
    add_attr(S_DATASOURCETYP, String, NONE)
    
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
      
      # die Buttons für das Ändern der Objektreihenfolge
      @lf.button_up.connect(SEL_COMMAND){ object_move_up_down(UP) }
      @lf.button_down.connect(SEL_COMMAND){ object_move_up_down(DOWN) }
      
      text_field_trigger = SEL_COMMAND
#      text_field_trigger = SEL_CHANGED # geht sehr langsam und macht bei Barcode und Bild Probleme
      
      # Zoom
      @lf.dial_zoom.connect(SEL_CHANGED){ set_zoom }
      @lf.dial_zoom.connect(SEL_LEFTBUTTONRELEASE){ draw_card }
      @lf.dial_zoom.value = 100
      set_zoom

      # Objektliste
      @lf.iconlist_objects.connect(SEL_SELECTED){ object_selection_changed }
      @lf.iconlist_objects.connect(SEL_DESELECTED){ object_deselected }
#      @lf.iconlist_objects.connect(SEL_CHANGED){ object_selection_changed }  # wenn der Cursor in der Liste bewegt wird
      
      # die allgemeinen Objektattribute
      @lf.textfield_name.connect(SEL_COMMAND){ textfield_name_exit }
      
      # die Daten-Attribute
      @lf.textfield_data_non_text.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_data.connect(SEL_CHANGED){|sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_sample_data.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_SAMPLE_DATA) }

      # die Font-Attribute
      @lf.textfield_text_color.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_FONT_COLOR) }
      @lf.button_text_color.connect(text_field_trigger){ text_color_dialog }
      @lf.radiomutex_justify.on_event_selected{|r| radiomutex_justify_changed(r) }

      # die Positions-Attribute
      @lf.textfield_x.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_X) }
      @lf.textfield_y.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_Y) }
      @lf.textfield_width.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_WIDTH) }
      @lf.textfield_height.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_HEIGHT) }
      @lf.textfield_rotation.connect(text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_ROTATION) }
      
      # die Checkbox, ob der Inhalt des Feldes in der Liste des Druckdialogs mit angezeigt werden soll
      @lf.checkbutton_printlist.connect(SEL_COMMAND ){ change_chkbtn_printlist }
      # .............................................................................................
      # Korrektur, da der LIBGUI-Builder irgendwie einen Fehler macht
      @lf.matrix1.numColumns = 2 
      @lf.matrix2.numColumns = 2 
      @lf.matrix3.numColumns = 3 
      deactivate_object_tabs
      
      deactivat_up_down
      @lf.dial_zoom.range = (49..359)
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def close_dataman
    @dataman = nil
  end
  # ---------------------------------------------------------------------------------------------------------
  def open_dataman
    datamantyp =  @xml_doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_DATASOURCETYP}").first.content
    datasource =  xml_doc.find("//#{S_ROOT}/#{S_LAYOUT}/#{S_DATASOURCE}").first.content
    
    if datamantyp == DATABASE
      @dataman = DataManDatabase.new(datasource)
    elsif datamantyp == CSV
      @dataman = DataManCSV.new(datasource)
    else
      @dataman = nil
    end
  end
  # ---------------------------------------------------------------------------------------------------------
#    node['object_name'] = "Test" # Attribute lesen und schreiben
#    p node.debug
  # ---------------------------------------------------------------------------------------------------------
  def change_chkbtn_printlist
    node = get_objectnode_by_id(@selected_object_id).find(GOA_PRINTLIST)
    if @lf.checkbutton_printlist.state != node.first.content
      node.first.content = @lf.checkbutton_printlist.state.to_s
      changed_attributes
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def object_move_up_down(dest)
    if @selected_object_id
      get_objectnode_by_id(@selected_object_id)
      
      # erst einmal eine sortierte Liste aller ID's der Grafikobjekte holen
      obj_arr = sorted_id_list
      
      # dann das entsprechende Objekt verschieben
      pos = obj_arr.index(@selected_object_id)
      if dest == UP
        obj_arr[pos], obj_arr[pos - 1] = obj_arr[pos - 1], obj_arr[pos] 
      elsif dest == DOWN
        obj_arr[pos], obj_arr[pos + 1] = obj_arr[pos + 1], obj_arr[pos] 
      end
      
      # dann die ID's im XML entsprechend des ARRAY-Indexes über die alte ID setzen (ist automatisch eine Re-Indizierung zum Entfernen von Löschern
      # dabei alle Objekte durchlaufen und im Array die Position der alten ID suchen und in die ID schreiben
      # dies muss so getan werden
      # wenn es anders herum versucht wird, d.h. das Array durchlaufen und dann das Objekt im XML gesucht, dann werden die ID's schon verändert und die Suche schlägt dann fehl
      @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
        id = go_struct.find(GOA_ID).first.content.to_i
        new_id = obj_arr.index(id)
        go_struct.find(GOA_ID).first.content = new_id.to_s
      }
      
      # changed-Flag setzen
      changed_attributes
      
      # Objekt-Liste aktualisieren
      fill_objectlist
      
      notify = true
      if dest == UP
        @lf.iconlist_objects.setCurrentItem(@selected_object_id - 1, notify)
        @lf.iconlist_objects.selectItem(@selected_object_id - 1, notify)
      elsif dest == DOWN
        @lf.iconlist_objects.setCurrentItem(@selected_object_id + 1, notify)
        @lf.iconlist_objects.selectItem(@selected_object_id + 1, notify)
      end
    
    
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def text_color_dialog
    cdlg = FXColorDialog.new(@parent, "Textfarbe")
    cdlg.execute
    if @lf.textfield_text_color.text != cdlg.rgba
      node = get_objectnode_by_id(@selected_object_id).find(GOA_FONT_COLOR)
      s = cdlg.rgba.to_i.to_s(16)
      @lf.textfield_text_color.text = [s[6,2], s[4,2], s[2,2], s[0,2]].join
      node.first.content = @lf.textfield_text_color.text
      changed_attributes
      draw_card
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def radiomutex_justify_changed(r)
    node = get_objectnode_by_id(@selected_object_id).find(GOA_JUSTIFICATION)
    if r.to_s != node.first.content
      node.first.content = r.to_s
      changed_attributes
    end
  end
  # ---------------------------------------------------------------------------------------------------------
  def textfield_exit(sender, attr_name)
    node = get_objectnode_by_id(@selected_object_id).find(attr_name)
    if sender.text != node.first.content
      node.first.content = sender.text
      changed_attributes
      #~ print @xml_doc.to_s
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
  def deactivat_up_down
    @lf.button_up.enabled = false
    @lf.button_down.enabled = false
  end
  # ---------------------------------------------------------------------------------------------------------
  def object_deselected
    deactivate_object_tabs
    @selected_object_id = nil
    deactivat_up_down
  end
  # ---------------------------------------------------------------------------------------------------------
  def object_selection_changed
    # erst einmal alle Objekt-Tabs deaktivieren, damit sicher gestellt ist, dass nur die Objekt-typischen angezeigt werden
    deactivate_object_tabs

    item_ID = @lf.iconlist_objects.currentItem
    @selected_object_id = @lf.iconlist_objects.getItemData(item_ID).to_i
    
    # die Buttons für das Ändern der Reihenfolge aktivieren
    @lf.button_up.enabled = (@selected_object_id > 0)
    @lf.button_down.enabled = (@selected_object_id < (sorted_id_list.length - 1)) 
    
    #~ p "id #{@selected_object_id} selektiert"
    node = get_objectnode_by_id(@selected_object_id)
    
    # allgemeine Attribute auslesen
      # 
      @lf.tabitem_object.shown = true
      @lf.tabitem_posit.shown = true
      
      # Daten-Attribute
      @lf.textfield_name.text = node.find(GOA_NAME).first.content
      @lf.textfield_sample_data.text = node.find(GOA_SAMPLE_DATA).first.content
      @lf.textfield_data.text = node.find(GOA_DATA).first.content
      @lf.textfield_data_non_text.text = node.find(GOA_DATA).first.content
    
      # Positionsattribute
      @lf.textfield_x.text = node.find(GOA_X).first.content
      @lf.textfield_y.text = node.find(GOA_Y).first.content
      @lf.textfield_width.text = node.find(GOA_WIDTH).first.content
      @lf.textfield_height.text = node.find(GOA_HEIGHT).first.content
      @lf.textfield_rotation.text = node.find(GOA_ROTATION).first.content
#      @lf.iconlist_justify.connect(SEL_CHANGED){iconlist_justify_exit } # todo

      if node.find(GOA_PRINTLIST).first.content == 'false' || node.find(GOA_PRINTLIST).first.content == '0'
        @lf.checkbutton_printlist.state = false 
      else
        @lf.checkbutton_printlist.state = true
      end
    
    # Typ-spezifische Attribute auslesen
      # Attribute, die Barcode und Texte haben
      if node.find(GOA_TYP).first.content == TEXTOBJECT || node.find(GOA_TYP).first.content == BARCODEOBJECT
        @lf.tabitem_font.shown = true
        @lf.textfield_text_color.text = node.find(GOA_FONT_COLOR).first.content
      end
      
      # Attribute, die nur Texte haben
      if node.find(GOA_TYP).first.content == TEXTOBJECT
        data_block_shown
      end
      
      # Attribute, die nur Barcodes haben
      if node.find(GOA_TYP).first.content == BARCODEOBJECT
        data_shown
      end
      
      # Attribute, die nur Bilder haben
      if node.find(GOA_TYP).first.content == PICTUREOBJECT
        data_shown
      end
    
    draw_card
  end
  # ---------------------------------------------------------------------------------------------------------
  def data_shown
    @lf.textfield_data.shown = false
    @lf.label_textblock.shown = false
    @lf.textfield_data_non_text.shown = true
    @lf.label_textfield.shown = true
  end
  # ---------------------------------------------------------------------------------------------------------
  def data_block_shown
    @lf.textfield_data.shown = true
    @lf.label_textblock.shown = true
    @lf.textfield_data_non_text.shown = false
    @lf.label_textfield.shown = false
  end
  # ---------------------------------------------------------------------------------------------------------
  def set_zoom
    @zoom = (@lf.dial_zoom.value + 1).to_f / 100
    @scale = 3.6
    @lf.label_zoom.text = "Zoom: #{@zoom}"
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
    
    image_width = (Page.width_with_margins(width) * @zoom)
    image_height = ((2 * Page.height_with_margins(height) + card_offset) * @zoom )
    
    scale_width = Page.width_with_margins(width) * @scale 
    scale_height = (2 * Page.height_with_margins(height) + card_offset) * @scale
    
    @dataman ? row = @dataman.row(0) : row = nil
    
    rvg = Magick::RVG.new(image_width.mm, image_height.mm).viewbox(0, 0, scale_width, scale_height) do |canvas|
      # Verhältnis zwischen Viewbox und Größe im RVG entspricht einem Zoom (je größer die viewbox-Werte desto weiter weg erscheint das Bild)
    
      draw_pos_x = 0
      draw_pos_y = 0
      page = Page.new(0)
      page.draw(canvas, draw_pos_x, draw_pos_y, @xml_doc, sorted_id_list, preview, @selected_object_id, row) # Seite 1 drucken
      
      page = Page.new(1)
      draw_pos_y = (Page.height_with_margins(height) + card_offset)
      page.draw(canvas, draw_pos_x, draw_pos_y, @xml_doc, sorted_id_list, preview, @selected_object_id, row) # Seite 2 drucken
      
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
	def load_from_xml(filename)
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      if filename && FileTest.exists?(filename)
        @filename = filename
      else
        fn = FXFileDialog.getOpenFilename(@parent, 'Laden', '.', patterns = '*.XML', initial = 0)
        @filename = fn
      end
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
    
    open_dataman
    
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
    # Objekt-Liste leeren
    @lf.iconlist_objects.clearItems
    
    # Array mit sortierten Objekt-ID's holen
    sorted_id_list.each{|id|
      go = @xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[contains(., #{id.to_s})]").parent
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
 	# ---------------------------------------------------------------------------------------------------------
  # deaktivieren der Anzeige der Objektattribute, wenn kein Objekt selektiert ist
  def deactivate_object_tabs
    @lf.tabitem_object.shown = false
    @lf.tabitem_posit.shown = false
    @lf.tabitem_font.shown = false
  end
 	# ---------------------------------------------------------------------------------------------------------
  def sorted_id_list
    @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").collect{|go_struct|
      go_struct.find(GOA_ID).first.content.to_i
    }.sort!
  end
end

#*****************************************************************************
# Main

if __FILE__ == $0
  system("ruby mcc2.rb #{ARGV}")
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
