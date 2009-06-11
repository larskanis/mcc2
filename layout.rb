# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end

require 'cc_dialogbox'
require 'layout_file'

# definiert ein Clientfenster mit allen Einstellungen und Attributen, die für ein bestimmtes Kartenlayout benötigt werden
class Layout
  # definiert, ob an den Einstellungen seit dem letzten speichern oder laden etwas geändert wurde
  attr_accessor :changed
  
  # enthält die kompletten Einstellungen des Kartenlayouts
  #~ attr_accessor :xml_doc
  
  # die aktuelle Zoom-Stufe der Anzeige
  attr_accessor :zoom
  
  # ???
  attr_accessor :scale
  
  # ???

  # der Datamanager
  attr_accessor :dataman
  
  # enthält die ID des aktuellen Datensatzes
  attr_accessor :row_nr
  
 	#---------------------------------------------------------------------------------------------------------
  
  # initialisiert zusätzliche Elemente im Layout-Dialog, die nicht oder schlecht im Fox-GUI-Builder erzeugt werden können
  # setzt Parameter bei Dialog-Elementen
  # definiert die Aktionen, welche bei bestimmten Ereignissen auf bestimmten Elementen des Dialogs ausgeführt werden sollen
  # ==== Parameter
  # +parent+:: ??
  # +app+::    die Applikation
  def initialize(parent, app)
    @parent = parent
    @app = app
    @row_nr = 0
    
    close_dataman
    
    
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
      
      @text_field_trigger = SEL_COMMAND
#      text_field_trigger = SEL_CHANGED # geht sehr langsam und macht bei Barcode und Bild Probleme
      
      # Zoom
      @lf.dial_zoom.connect(SEL_CHANGED){ set_zoom }
      @lf.dial_zoom.connect(SEL_LEFTBUTTONRELEASE){ draw_card }
      @lf.dial_zoom.value = 100
      set_zoom

      # Objektliste
      @lf.iconlist_objects.connect(SEL_SELECTED){ object_selection_changed }
      @lf.iconlist_objects.connect(SEL_DESELECTED){ object_deselected }
      
      # die allgemeinen Objektattribute
      @lf.textfield_name.connect(SEL_COMMAND){ textfield_name_exit }
      
      # die Daten-Attribute
      @lf.textfield_data_non_text.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_data.connect(SEL_CHANGED){|sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_sample_data.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_SAMPLE_DATA) }

      # die Font-Attribute
      @lf.textfield_text_color.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_FONT_COLOR) }
      @lf.button_text_color.connect(@text_field_trigger){ text_color_dialog }
      @lf.radiomutex_justify.on_event_selected{|r| radiomutex_justify_changed(r) }

      # die Positions-Attribute
      @lf.textfield_x.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_X) }
      @lf.textfield_y.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_Y) }
      @lf.textfield_width.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_WIDTH) }
      @lf.textfield_height.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_HEIGHT) }
      @lf.textfield_rotation.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_ROTATION) }
      
      # die Checkbox, ob der Inhalt des Feldes in der Liste des Druckdialogs mit angezeigt werden soll
      @lf.checkbutton_printlist.connect(SEL_COMMAND ){ change_chkbtn_printlist }
      
      
      @lf.textfield_x_offset.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_X_OFFSET) }
      @lf.textfield_y_offset.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_Y_OFFSET) }
      
      # die Auswahl auf welche Seite das Objekt soll
      @lf.spinner_seiten_nr.connect(SEL_COMMAND){ seiten_nr_changed }
      @lf.spinner_seiten_nr.range = (1..$pr.max_pages)
      
      # der Checkbutton für die Einstellung Simplex/Duplex
      @lf.checkbutton_duplex.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_DUPLEX) }
      
      # der Button auf den Objektattributen, mit dem die Daten erweitert bearbeitet werden können (Variablen aus der Datenquelle verwenden usw.)
      @lf.button_enhanced_data_edit.connect(SEL_COMMAND){ enhanced_data_edit }
      @lf.button_enhanced_data_text_edit.connect(SEL_COMMAND){ enhanced_data_edit }
      
      # der Button zum Auswählen der Schriftart
      @lf.button_font_select.connect(SEL_COMMAND){ sel_font_button_pressed }
      # .............................................................................................
      
      create_chipparam_fields
      
      # Korrektur, da der LIBGUI-Builder irgendwie einen Fehler macht
      @lf.matrix1.numColumns = 3
      @lf.matrix2.numColumns = 3
      @lf.matrix3.numColumns = 3 
      @lf.matrix_layout_attrs.numColumns = 3
      deactivate_object_tabs
      
      deactivat_up_down
      @lf.dial_zoom.range = (49..359)
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  #
  def sel_font_button_pressed
    fontdlg = FXFontDialog.new(@parent, "Change Font", DECOR_BORDER|DECOR_TITLE)
    node = @layout_file.get_objectnode_by_id(@selected_object_id)
    fontdesc = FXFontDesc.new
    fontdesc.size = node.find_first(GOA_FONT_HEIGHT).content.to_i*10
    fontdesc.face = node.find_first(GOA_FONT_TYP).content
    w = Font_weight.index(node.find_first(GOA_FONT_WEIGHT).content)
    w ? fontdesc.weight = w : fontdesc.weight = 0
    st = Font_style.index(node.find_first(GOA_FONT_STYLE).content)
    st ? fontdesc.slant = st : fontdesc.slant = 0
    str = Font_stretch.index(node.find_first(GOA_FONT_STRETCH).content)
    str ? fontdesc.setwidth = str : fontdesc.setwidth = 0
    fontdesc.encoding = 0 # keine Vorauswahl treffen
    fontdlg.fontSelection = fontdesc
    if fontdlg.execute() != 0
      fontdesc = fontdlg.fontSelection
      node.find_first(GOA_FONT_HEIGHT).content = (fontdesc.size.to_f/10).to_s
      node.find_first(GOA_FONT_TYP).content = fontdesc.face
      node.find_first(GOA_FONT_WEIGHT).content = Font_weight[fontdesc.weight]
      node.find_first(GOA_FONT_STYLE).content = Font_style[fontdesc.slant]
      node.find_first(GOA_FONT_STRETCH).content = Font_stretch[fontdesc.setwidth]
      fill_font_fields(node)
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # erzeugt Textfelder für die Eingabe der Chip-Parameter
  # erzeugt so viele Felder, wie in der Methode anz_params der Klasse Chip definiert sind
  # erzeugt ein Array, in welchem alle Felder gespeichert sind
  def create_chipparam_fields
    @chip = Chip.new 
    @chipparam_textfields = []
    
    scrl_w = FX::ScrollWindow.new(@lf.verticalframe_chip, LAYOUT_FILL_X | LAYOUT_FILL_Y)
    matrix_chipparams = FX::Matrix.new(scrl_w){|w|
      @matrix3 = w
      w.wdg_name = 'matrix_xyz'
      w.numRows = 4 
      w.width = 650
      w.y = 2
      w.height = 0
      w.matrixStyle = MATRIX_BY_COLUMNS | LAYOUT_FILL_X | LAYOUT_FILL_Y
      w.x = 2
    }
    matrix_chipparams.numColumns = 2
      
    (0..(@chip.anz_params-1)).each{|i|
			FX::Label.new(matrix_chipparams){|w|
				w.wdg_name = "label_chipparam_#{i}"
        w.text = ['Parameter', i+1].join(' ')
				w.font=FX::Font.new.from_s('Arial|80|40|5|0|0|0').to_FXFont
			}
			tf = FX::TextField.new(matrix_chipparams){|w|
        w.textFieldTextStyle = LAYOUT_FIX_WIDTH
				w.wdg_name = "textfield_chipparam_#{i}"
				w.font = FX::Font.new.from_s('Arial|80|40|5|0|0|0').to_FXFont
        w.width = 200
				w.numColumns=10
			}
      tf.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_CHIPPARAMS) }
      tf.width = 800
      @chipparam_textfields << tf
    }
  end
  #---------------------------------------------------------------------------------------------------------
  
  # schließt den Datenmanager
  def close_dataman
    @dataman = nil
  end
  #---------------------------------------------------------------------------------------------------------
  
  # 
  def enhanced_data_edit
    typ = @layout_file.get_objectnode_by_id(@selected_object_id).find_first(GOA_TYP).content
    if typ == PICTUREOBJECT
      s = FXFileDialog.getOpenFilename(@parent, "Bild auswählen", ".", patterns="*", initial=0)   
      @lf.textfield_data_non_text.text = @lf.textfield_data_non_text.text + s
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # erzeugt einen Datenmanager abhängig davon welcher Datensourcetyp im Layout definiert ist (momentan DATABASE oder CSV)
  def open_dataman
    
    datamantyp =  @layout_file.get_attr_value(S_DATASOURCETYP)
    datasource =  @layout_file.get_attr_value(S_DATASOURCE)
    
    datamantyp
    
    if datamantyp == DATABASE
      @dataman = DataManDatabase.new(datasource)
    elsif datamantyp == CSV
      @dataman = DataManCSV.new(datasource)
    elsif datamantyp == NONE
      @dataman = nil
    else
      raise "falscher datasourcetyp '#{datamantyp}' angegeben!"
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # die Reaktion, wenn der Status eines Checkbuttons geänderrt wurde
  # setzt das changed-Flag
  # ==== Parameter
  # +sender+::    das Objekt, welches das Ereignis gesendet hat
  # +attr_name+:: der Name des Attributs
  def change_chkbtn(sender, attr_name)
    lay_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
    node = lay_attrs.find_first(attr_name)
    if sender.state != node.first.content
      node.first.content = sender.state.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # ???
  def change_chkbtn_printlist
    node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_PRINTLIST)
    if @lf.checkbutton_printlist.state != node.first.content
      node.first.content = @lf.checkbutton_printlist.state.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # mit dieser Methode kann ein Objekt in der Liste der Objekte nach oben oder unten verschoben werden
  # die Position hat einen Einfluss auf das Druckbild, wird zum Beispiel ein Bild gedruckt werden Objekte, 
  # die weiter oben stehen, hinter diesem Bild gedruckt
  # ==== Parameter
  # +dest+:: die Richtung (UP, oder DOWN)
  def object_move_up_down(dest)
    if @selected_object_id
      @layout_file.get_objectnode_by_id(@selected_object_id)
      
      # erst einmal eine sortierte Liste aller ID's der Grafikobjekte holen
      obj_arr = @layout_file.sorted_id_list
      
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
      @layout_file.xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
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
  #---------------------------------------------------------------------------------------------------------
  
  # öffnet einen Dialog, mit dem die Textfarbe gewählt werden kann und
  # trägt diese in das Textfeld für die Farbangabe ein 
  # zeichnet anschließend die Vorschau neu
  def text_color_dialog
    cdlg = FXColorDialog.new(@parent, "Textfarbe")
    cdlg.execute
    if @lf.textfield_text_color.text != cdlg.rgba
      node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_FONT_COLOR)
      s = cdlg.rgba.to_i.to_s(16)
      @lf.textfield_text_color.text = [s[6,2], s[4,2], s[2,2], s[0,2]].join
      node.first.content = @lf.textfield_text_color.text
      changed_attributes
      draw_card
    end
  end
  #~ #---------------------------------------------------------------------------------------------------------
  
  #~ # die Aktion, welche ausgeführt wird, wenn die Auswahl der Seitennummer geändert wurde, auf welcher das Objekt ausgegeben werden soll
  #~ def duplex_changed
    #~ seite = @lf.checkbutton_duplex.state - 1
    #~ node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_PAGE_NR)
    #~ if seite != node.first.content.to_i
      #~ node.first.content = seite.to_s
      #~ changed_attributes
    #~ end
  #~ end
  #---------------------------------------------------------------------------------------------------------
  
  # die Aktion, welche ausgeführt wird, wenn die Auswahl der Seitennummer geändert wurde, auf welcher das Objekt ausgegeben werden soll
  def seiten_nr_changed
    seite = @lf.spinner_seiten_nr.value - 1
    node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_PAGE_NR)
    if seite != node.first.content.to_i
      node.first.content = seite.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # die Aktion, welche ausgeführt wird, wenn die Auswahl der Textausrichtung geändert wurde
  # ==== Parameter
  # +r+:: das Radio-Mutex-Objekt
  def radiomutex_justify_changed(r)
    node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_JUSTIFICATION)
    if r.to_s != node.first.content
      node.first.content = r.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # händelt für bestimmte Textfelder das Eintragen des Textes in das jeweilige Attribut in der XML-Struktur
  # setzt das changed-Flag
  # ==== Parameter
  # +sender+::    das Objekt, welches das Ereignis gesendet hat
  # +attr_name+:: der Name des Attributs
  def textfield_exit(sender, attr_name)
    if attr_name == S_CHIPPARAMS
      # aus dem Namen des Textfeldes die ID ermitteln (sind durchnummeriert)
      id = sender.wdg_name.split("_")[-1].to_i
      
      # die die Route zu den Chipparams suchen
      chip_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_CHIP}")
      
      # den entsprechenden Parameter suchen
      attr_name = "#{S_PARAM}_#{id+1}"
      node = chip_attrs.find_first(attr_name)
    elsif attr_name == S_Y_OFFSET
      lay_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
      node = lay_attrs.find_first(S_Y_OFFSET)
    elsif attr_name == S_X_OFFSET
      lay_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
      node = lay_attrs.find_first(S_X_OFFSET)
    else
      # das Attribut suchen
      node = @layout_file.get_objectnode_by_id(@selected_object_id).find(attr_name).first
    end
    
    # nur wenn im Textfeld etwas geändert wurde, den Text in das Attribut schreiben und das changed-Flag setzen
    if sender.text != node.content
      node.content = sender.text
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # schreibt den Text der im Textfeld eingegeben wurde in das Attribut 'name' des graphischen Objekts und aktualisiert die Objektliste
  def textfield_name_exit
    orig_name = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_NAME)
    if @lf.textfield_name.text != orig_name.first.content
      orig_name.first.content = @lf.textfield_name.text
      changed_attributes
      fill_objectlist
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # sollte jedesmal dann aufgerufen werden, wenn ein Attribut des Layouts geändert wurde
  # es wird das changed-Flag gesetzt und der Titel aktualisiert und die Vorschau neu gezeichnet
  def changed_attributes
    @changed = true
    draw_card
    set_title
  end
  #---------------------------------------------------------------------------------------------------------
  
  # deaktiviert die Buttons für das Verschieben der Objekte in der Objektliste (zum Beispiel, wenn kein Objekt selektiert ist)
  def deactivat_up_down
    @lf.button_up.enabled = false
    @lf.button_down.enabled = false
  end
  #---------------------------------------------------------------------------------------------------------
  
  # deaktiviert die Tabs im Layout-Dialog, welche Objekt-spezifisch sind
  def object_deselected
    deactivate_object_tabs
    @selected_object_id = nil
    deactivat_up_down
  end
  #---------------------------------------------------------------------------------------------------------
  
  # wenn in der Objektliste ein anderes Objekt selektiert wird, dann werden mit dieser Methode die Anzeigen aktualisiert, 
  # z.Bsp, nur die Tabs aktiviert, die zum Objekttyp passen, usw.
  def object_selection_changed
    # erst einmal alle Objekt-Tabs deaktivieren, damit sicher gestellt ist, dass nur die Objekt-typischen angezeigt werden
    deactivate_object_tabs

    item_ID = @lf.iconlist_objects.currentItem
    @selected_object_id = @lf.iconlist_objects.getItemData(item_ID).to_i
    
    # die Buttons für das Ändern der Reihenfolge aktivieren
    @lf.button_up.enabled = (@selected_object_id > 0)
    @lf.button_down.enabled = (@selected_object_id < (@layout_file.sorted_id_list.length - 1)) 
    
    node = @layout_file.get_objectnode_by_id(@selected_object_id)
    
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
      @lf.textfield_rotation.text = node.find(GOA_ROTATION).first.content
      @lf.spinner_seiten_nr.value = node.find(GOA_PAGE_NR).first.content.to_i + 1
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
        fill_font_fields(node)
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
  #---------------------------------------------------------------------------------------------------------
  
  def fill_font_fields(node)
    @lf.textfield_font_face.text = node.find_first(GOA_FONT_TYP).content
    @lf.textfield_font_size.text = node.find_first(GOA_FONT_HEIGHT).content
    @lf.textfield_font_weight.text = node.find_first(GOA_FONT_WEIGHT).content
    @lf.textfield_font_style.text = node.find_first(GOA_FONT_STYLE).content
    @lf.textfield_font_width.text = node.find_first(GOA_FONT_STRETCH).content
  end
  #---------------------------------------------------------------------------------------------------------
  
  # aktiviert ein einzeiliges Textfeld für die Eingabe der Daten (wird für Barcode und Bilder gebraucht)
  def data_shown
    @lf.textfield_data.shown = false
    @lf.label_textblock.shown = false
    @lf.textfield_data_non_text.shown = true
    @lf.label_textfield.shown = true
    @lf.button_enhanced_data_edit.shown = true
    @lf.button_enhanced_data_text_edit.shown = false
  end
  #---------------------------------------------------------------------------------------------------------
  
  # aktiviert ein mehrzeiliges Textfeld für die Eingabe der Daten (wird für Text gebraucht)
  def data_block_shown
    @lf.textfield_data.shown = true
    @lf.label_textblock.shown = true
    @lf.textfield_data_non_text.shown = false
    @lf.label_textfield.shown = false
    @lf.button_enhanced_data_edit.shown = false
    @lf.button_enhanced_data_text_edit.shown = true
  end
  #---------------------------------------------------------------------------------------------------------
  
  # verändert die Zoomstufe, wenn am Rädchen gedreht wird
  def set_zoom
    @zoom = (@lf.dial_zoom.value + 1).to_f / 100
    @scale = 3.6
    @lf.label_zoom.text = "Zoom: #{@zoom}"
    #~ p "@zoom: #{@zoom}"
    #~ p "@scale: #{@scale}"
  end
  #---------------------------------------------------------------------------------------------------------
  
  # zeichnet die Vorschau im Layout-Modus
  # hier ist noch einiges zu tun, im speziellen sind einige Werte "hart" kodiert, 
  # die z.Bsp abhängig von anderen Einstellungen sein sollten
  def draw_card
    #~ Thread.new{
  
      # allgemeine Einstellungen des Image vornehmen
      dpi = 90
      width =  @layout_file.get_attr_value(S_WIDTH).to_f
      height = @layout_file.get_attr_value(S_HEIGHT).to_f
      
      Magick::RVG.dpi = dpi
      
      preview = true
      
      card_offset = 10
      
      image_width = (Page.width_with_margins(width) * @zoom)
      image_height = ((2 * Page.height_with_margins(height) + card_offset) * @zoom )
      
      scale_width = Page.width_with_margins(width) * @scale 
      scale_height = (2 * Page.height_with_margins(height) + card_offset) * @scale
      
      @dataman ? row = @dataman.row(@row_nr) : row = nil
      
      rvg = Magick::RVG.new(image_width.mm, image_height.mm).viewbox(0, 0, scale_width, scale_height) do |canvas|
        # Verhältnis zwischen Viewbox und Größe im RVG entspricht einem Zoom (je größer die viewbox-Werte desto weiter weg erscheint das Bild)
      
        draw_pos_x = 0
        draw_pos_y = 0
        page = Page.new(0)
        page.draw(canvas, draw_pos_x, draw_pos_y, @layout_file, preview, @selected_object_id, row) # Seite 1 drucken
        
        page = Page.new(1)
        draw_pos_y = (Page.height_with_margins(height) + card_offset)
        page.draw(canvas, draw_pos_x, draw_pos_y, @layout_file, preview, @selected_object_id, row) # Seite 2 drucken
        
        canvas.background_fill = 'white'
      end
      
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
    #~ }
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # aktualisiert den Titel des Layout-Fensters
  # es werden eingetragen
  # * der Dateiname des Layouts
  # * die verbunden Datenquelle (coming soon)
  # * ein Zeichen *, ob das Layout seit dem letzten Laden oder Speichern geändert wurde
  def set_title
    @parent.title = "#{@layout_file.filename} #{@dataman.filename}  #{@changed ? ' *' : '' }"
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # speichert alle GraphicObjekte und Layout-Einstellungen im XML-File
	def store_to_xml
    unless @layout_file.filename
      fn = FXFileDialog.getSaveFilename(@parent, 'Speichern', '.', patterns = '*.XML', initial = 0)
      unless fn.split(".")[-1].downcase == 'xml'
        fn = [fn, 'XML'].join(".")
      end
      @filename = fn
    end
    @layout_file.save
    @changed = false
    set_title
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # fügt ein GraphicObjekt zur Objektliste hinzu und zeichnet die Vorschau und die Objektliste neu
  # ==== Parameter
  # +typ+:: der Typ des Objekts (Bild, Text, Barcode)
  def add_object(typ)
    @layout_file.add_object(typ)
    
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fill_objectlist
      draw_card
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # füllt die Objektliste des Layout-Dialogs mit den Name der graphischen Objekte
  def fill_objectlist
    # Objekt-Liste leeren
    @lf.iconlist_objects.clearItems
    
    # Array mit sortierten Objekt-ID's holen
    @layout_file.sorted_id_list.each{|id|
      go = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[contains(., #{id.to_s})]").parent
      name = go.find(GOA_NAME).first.content
      typ = go.find(GOA_TYP).first.content
      @lf.iconlist_objects.appendItem([id, name, typ].join("\t"), nil, nil, id)
    }
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # deaktivieren der Anzeige der Objektattribute, wenn kein Objekt selektiert ist
  def deactivate_object_tabs
    @lf.tabitem_object.shown = false
    @lf.tabitem_posit.shown = false
    @lf.tabitem_font.shown = false
  end
 	#---------------------------------------------------------------------------------------------------------

  # diese Methode liest die allgemeinen Einstellungen des Layouts aus dem XML aus und befüllt damit die Bearbeitungsfelder im Tab 'Allgemein'
  def fill_layout_attr_tab
    @lf.textfield_x_offset.text = @layout_file.get_attr_value(S_X_OFFSET)
    @lf.textfield_y_offset.text = @layout_file.get_attr_value(S_Y_OFFSET)
    unless $pr.can_duplex?
      p "simplex"
      @lf.checkbutton_duplex.state = false
      @lf.checkbutton_duplex.enabled = false
    else
      p "duplex"
      @lf.checkbutton_duplex.enabled = true
      duplex = @layout_file.get_attr_value(S_DUPLEX)
      if duplex == 'false' || duplex == '0'
        @lf.checkbutton_duplex.state = false 
      else
        @lf.checkbutton_duplex.state = true
      end
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def load_from_xml(filename)
    begin
      @layout_file = LayoutFile.load_from_xml(filename)
    rescue LayoutFile::WrongDataSourceEncoding, LayoutFile::WrongDataSourceType => e
      changed_attributes 
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, e.to_s, 'ok')
      error_WahlMessage.execute
      # error_WahlMessage.selection # enthält die Nummer der gewählten Taste
    end
    open_dataman
    
    if @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      fill_objectlist 
      draw_card
      set_title
      
      fill_layout_attr_tab
      
      chip = Chip.new
      chip_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_CHIP}")
      #~ (1..chip.anz_params).each{|i|
        #~ attr_name = "#{S_PARAM}_#{i}"
        #~ element = chip_attrs.find_first(attr_name)
        #~ chip_attrs << param = XML::Node.new(attr_name , "")
      #~ }
      # diesen Teil getrennt vom oberen machen, damit die Reihenfolge der Chip-Params richtig bleibt, auch wenn sie im XML anders sind
      chip_attrs.each{|chip_attr|
        idx = chip_attr.name.split("_")[-1].to_i-1
        @chipparam_textfields[idx].text = chip_attr.content 
      }
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def create_xml
    @layout_file = LayoutFile.create_xml
    draw_card
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
