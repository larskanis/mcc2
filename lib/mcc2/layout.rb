# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

if __FILE__ == $0
  require 'mcc2'
end

require 'cc_dialogbox'
require 'layout_file'

# definiert ein Clientfenster mit allen Einstellungen und Attributen, die für ein bestimmtes Kartenlayout benötigt werden
class Layout
  class ResourceNotFoundError < RuntimeError
  end

  JobSetupObjID = -1
  
  # definiert, ob an den Einstellungen seit dem letzten speichern oder laden etwas geändert wurde
  attr_accessor :changed
  
  # enthält die kompletten Einstellungen des Kartenlayouts
  attr_accessor :layout_file
  
  # die aktuelle Zoom-Stufe der Anzeige
  attr_accessor :zoom
  
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
    begin
      # Achtung! Nicht das Verzeichnis 'printer' in den Pfad einbinden. Dort befindet sich eine printer.rb, die nichts mit der printer.rb dieses Projektes zu tun hat.
      require 'libs/printer/tbarcode_api'
    rescue LoadError => e
      puts "Loading barcode driver failed: #{e}"
    end

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
      @lf.dial_zoom.connect(SEL_LEFTBUTTONRELEASE){ draw_preview(true) }
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
      
      # die Textfelder für die allgemeine Layoutoptionen
      @lf.textfield_x_offset.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_X_OFFSET) }
      @lf.textfield_y_offset.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_Y_OFFSET) }
      @lf.textfield_datasource.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_DATASOURCE) }
      
      # die Auswahl auf welche Seite das Objekt soll
      @lf.spinner_seiten_nr.connect(SEL_COMMAND){ seiten_nr_changed }
      @lf.spinner_seiten_nr.range = (1..$pr.max_pages)
      
      # der Checkbutton für die Einstellung Simplex/Duplex
      @lf.checkbutton_duplex.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_DUPLEX) }
      
      # der Button auf den Objektattributen, mit dem die Daten erweitert bearbeitet werden können (Variablen aus der Datenquelle verwenden usw.)
      @lf.button_enhanced_data_edit.connect(SEL_COMMAND){ enhanced_data_edit }
      @lf.button_enhanced_data_text_edit.connect(SEL_COMMAND){ enhanced_data_edit }
      
      # der Button dür das Auswählen einer Datenquelle
      @lf.button_datasource.connect(SEL_COMMAND){ datasource_button_pressed }
      
      # die Listbox zum Auswählen der Schriftart
      @lf.listbox_fonts.connect(SEL_COMMAND){ |sender, sel, event| sel_list_box_changed(sender) }
      @lf.textfield_font_file.connect(SEL_COMMAND){ |sender, sel, event| textfield_exit(sender, GOA_FONT_FILE) }
      @lf.button_fontfile_select.connect(SEL_COMMAND){ fontfile_select_button_pressed }
      
      @lf.textfield_fontsize.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_FONT_HEIGHT) }
      
      # der Checkbuttons für die Einstellung, ob Magnestreifen, Kontaktchip und Kontaktlos personalisiert werden sollen
      @lf.checkbutton_contactless.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_CONTACTLESS) }
      @lf.checkbutton_contact.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_CONTACT) }
      @lf.checkbutton_magstripe.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_MAGSTRIPE) }
      
      # die Checkbuttons für das Löschen und Kopieren von Graphik-Objekten
      @lf.button_copy.enabled = false
      @lf.button_copy.connect(SEL_COMMAND){ manage_objects(COPY) }
      @lf.button_delete.enabled = false
      @lf.button_delete.connect(SEL_COMMAND){ manage_objects(DELETE) }
      
      # die Textfelder für die Magnetstreifenattribute
      @lf.textfield_spur1.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_MSSPUR1) }
      @lf.textfield_spur2.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_MSSPUR2) }
      @lf.textfield_spur3.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_MSSPUR3) }

      @barcodes = if self.class.const_defined?(:BarcodeAPI)
        BarcodeAPI::bc_get_bc_list
      else
        []
      end
      @lf.listbox_bc_typ.connect(SEL_COMMAND){ |sender, sel, event| sel_list_box_changed(sender) }
      @lf.spinner_modul_width.connect(SEL_COMMAND){ bc_modul_with_changed }
      @lf.spinner_modul_width.range = (1..100)
      # .............................................................................................
      
      create_chipparam_fields
      
      # Korrektur, da der LIBGUI-Builder irgendwie einen Fehler macht
      @lf.matrix1.numColumns = 3
      @lf.matrix2.numColumns = 3
      @lf.dial_zoom.range = (49..359)
      fill_objectlist
      object_selection_changed
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
    matrix_chipparams = FX::Matrix.new(scrl_w, LAYOUT_FILL_X | LAYOUT_FILL_Y){|w|
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
			tf = FX::TextField.new(matrix_chipparams, LAYOUT_FILL_X){|w|
        w.textFieldTextStyle = LAYOUT_FILL_X
				w.wdg_name = "textfield_chipparam_#{i}"
				w.font = FX::Font.new.from_s('Arial|80|40|5|0|0|0').to_FXFont
				w.numColumns = 40
			}
      tf.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_CHIPPARAMS) }
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
    if cdlg.execute>0 && @lf.textfield_text_color.text != cdlg.rgba
      node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_FONT_COLOR)
      s = cdlg.rgba.to_i.to_s(16)
      @lf.textfield_text_color.text = [s[6,2], s[4,2], s[2,2], s[0,2]].join
      node.first.content = @lf.textfield_text_color.text
      changed_attributes
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
    elsif attr_name == S_MSSPUR1
      node = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}/#{S_MSSPUR1}")
    elsif attr_name == S_MSSPUR2
      node = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}/#{S_MSSPUR2}")
    elsif attr_name == S_MSSPUR3
      node = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}/#{S_MSSPUR3}")
    elsif attr_name == S_DATASOURCE
      lay_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
      node = lay_attrs.find_first(S_DATASOURCE)
    else
      # in diesem Zweig werden alle Graphik-Objekte bearbeitet
      # das Attribut suchen
      node = @layout_file.get_objectnode_by_id(@selected_object_id).find(attr_name).first
    end
    
    # nur wenn im Textfeld etwas geändert wurde, den Text in das Attribut schreiben und das changed-Flag setzen
    if sender.text != node.content
      node.content = sender.text
      changed_attributes
    end
    if attr_name == S_DATASOURCE
      # nachdem die Daten in das Layout eingetrage wurden, die neue Datei laden
      close_dataman
      open_dataman
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
    draw_preview
    set_title
  end
  #---------------------------------------------------------------------------------------------------------

  # deaktivieren der Anzeige der Objektattribute, wenn kein Objekt selektiert ist
  def activate_object_tabs(on=true)
    @lf.tabitem_object.shown = on
    @lf.tabitem_posit.shown = on
    @lf.tabitem_font.shown = on
    @lf.tabitem_barcode.shown = on
  end
  
  def activate_job_tabs(on=true)
    @lf.tabitem_allgemein.shown = on
    @lf.tabitem_chip.shown = on
    @lf.tabitem_magstripe.shown = on
  end
  #---------------------------------------------------------------------------------------------------------
  
  # deaktiviert die Buttons für das Verschieben der Objekte in der Objektliste (zum Beispiel, wenn kein Objekt selektiert ist)
  def activate_up_down(on=true)
    @lf.button_up.enabled = on
    @lf.button_down.enabled = on
  end

  def activate_copy_delete(on=true)
    @lf.button_copy.enabled = on
    @lf.button_delete.enabled = on
  end
  #---------------------------------------------------------------------------------------------------------
  
  # deaktiviert die Tabs im Layout-Dialog, welche Objekt-spezifisch sind
  def object_deselected
    activate_object_tabs(false)
    @selected_object_id = nil
    activate_up_down(false)
    activate_copy_delete(false)
  end
  #---------------------------------------------------------------------------------------------------------
  
  # wenn in der Objektliste ein anderes Objekt selektiert wird, dann werden mit dieser Methode die Anzeigen aktualisiert, 
  # z.Bsp, nur die Tabs aktiviert, die zum Objekttyp passen, usw.
  def object_selection_changed
    item_ID = @lf.iconlist_objects.currentItem
    @selected_object_id = @lf.iconlist_objects.getItemData(item_ID).to_i

    if @selected_object_id == JobSetupObjID
      object_deselected
      activate_job_tabs
      @lf.tabbook_objectattributes.current = 0
      
    else
      # erst einmal alle Objekt-Tabs deaktivieren, damit sicher gestellt ist, dass nur die Objekt-typischen angezeigt werden
      activate_object_tabs(false)
      activate_job_tabs(false)
      activate_copy_delete
      
      # die Buttons für das Ändern der Reihenfolge aktivieren
      @lf.button_up.enabled = item_ID > 1
      @lf.button_down.enabled = item_ID < @layout_file.sorted_id_list.length

      node = @layout_file.get_objectnode_by_id(@selected_object_id)

      # allgemeine Attribute auslesen
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

        # den Radiobutton der Ausrichtung setzen
        @lf.radiobutton_just_l.state = false
        @lf.radiobutton_just_l.state = false
        @lf.radiobutton_just_r.state = false
        just = @layout_file.get_objectnode_by_id(@selected_object_id).find_first(GOA_JUSTIFICATION).content
        if just == S_JUST_LEFT
          @lf.radiobutton_just_l.state = true
        elsif just == S_JUST_MID
          @lf.radiobutton_just_m.state = true
        elsif just == S_JUST_RIGHT
          @lf.radiobutton_just_r.state = true
        end

        fill_font_list
        fill_font_fields(node)
      end

      # Attribute, die nur Texte haben
      if node.find(GOA_TYP).first.content == TEXTOBJECT
        data_block_shown
      end

      # Attribute, die nur Barcodes haben
      if node.find(GOA_TYP).first.content == BARCODEOBJECT
        @lf.tabitem_barcode.shown = true
        @lf.spinner_modul_width.value = node.find(GOA_BC_MODUL_WIDTH).first.content.to_i
        fill_barcode_typ_list
        fill_barcode_fields(node)
        data_shown
      end

      # Attribute, die nur Bilder haben
      if node.find(GOA_TYP).first.content == PICTUREOBJECT
        data_shown
      end
    end

    draw_preview
  end
  #---------------------------------------------------------------------------------------------------------
  
  def sel_list_box_changed(sender)
    #~ node.find_first(GOA_FONT_HEIGHT).content = (fontdesc.size.to_f/10).to_s
    
    if sender.wdg_name == 'listbox_fonts'
      font = @lf.listbox_fonts.getItemData(@lf.listbox_fonts.currentItem)
      @lf.textfield_font_file.enabled = font=='from_file'
      @layout_file.get_objectnode_by_id(@selected_object_id).find_first(GOA_FONT_TYP).content = font
    elsif sender.wdg_name == 'listbox_bc_typ'
      bc = @lf.listbox_bc_typ.getItemText(@lf.listbox_bc_typ.currentItem)
      @layout_file.get_objectnode_by_id(@selected_object_id).find_first(GOA_BC_TYP).content = bc
    else 
      raise "unbekannter Sender. Eingriff des Programmierers nötig. :-("
    end
    changed_attributes
  end
  #---------------------------------------------------------------------------------------------------------
  
  # die Aktion, welche ausgeführt wird, wenn die Auswahl der Modulbreite des Barcodes geändert wird
  def bc_modul_with_changed
    mw = @lf.spinner_modul_width.value
    node = @layout_file.get_objectnode_by_id(@selected_object_id).find(GOA_BC_MODUL_WIDTH)
    if mw != node.first.content.to_i
      node.first.content = mw.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------
  
  # füllt die Barcode-Typ-Auswahlliste mit den möglichen Barcodes
  def fill_barcode_typ_list
    @barcodes.each{|bc|
      @lf.listbox_bc_typ.appendItem(bc)
    }
  end
  #---------------------------------------------------------------------------------------------------------
  
  # füllt die Barcode-spezifischen Felder mit den gewählten Optionen aus dem Layout
  def fill_barcode_fields(node)
    # den gewählten Parameter in den entsprechenden Listen markieren
    bc_typ = node.find_first(GOA_BC_TYP).content
    bc_id = @barcodes.index(bc_typ)
    error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Der Barcode-Typ #{bc_typ} existiert nicht in der Liste der verfügbaren Barcodes.\ Der Wert wird auf 'NONE' gesetzt.", 'ok') unless bc_id
    @lf.listbox_bc_typ.currentItem = bc_id if bc_id
  end
  #---------------------------------------------------------------------------------------------------------
  
  # füllt die Font-Auswahlliste mit den möglichen Fonts
  def fill_font_list
    # Font-Name
    rmfl = Magick.fonts.map{|mf| mf.name }
    rmfl.sort!
    @lf.listbox_fonts.clearItems
    idx = @lf.listbox_fonts.appendItem("aus Font-Datei") # die humanreadable
    @lf.listbox_fonts.setItemData(idx, 'from_file')         # die Werte

    rmfl.each_with_index{|rmf, idx|
      idx = @lf.listbox_fonts.appendItem(rmf.gsub("-"," ")) # die humanreadable
      @lf.listbox_fonts.setItemData(idx, rmf)         # die Werte
    }
  end
  #---------------------------------------------------------------------------------------------------------
  
  # füllt die Font-spezifischen Felder mit den gewählten Optionen aus dem Layout
  def fill_font_fields(node)
    # die Schriftgröße zurücklesen
    @lf.textfield_fontsize.text = node.find_first(GOA_FONT_HEIGHT).content

    font_typ = node.find_first(GOA_FONT_TYP).content
    # den gewählten Parameter in den entsprechenden Listen markieren
    set_listbox_value('listbox_fonts', font_typ)
    @lf.textfield_font_file.enabled = font_typ=='from_file'
  end
  #---------------------------------------------------------------------------------------------------------
  
  # selectiert in der über listbox_name angegebenen Listbox den Eintrag, der Value entspricht
  # wird beim Laden benötigt, um aus den Layoutdaten die Einstellungen zu restaurieren
  def set_listbox_value(listbox_name, value)
    #~ p "#{self.class.name}::set_listbox_value => listbox_name: #{listbox_name}; value: #{value.inspect}"
    ft_idx = nil
    idx = 0
    @lf.send(listbox_name.intern).each{|t, i, d| 
      if d == value
        ft_idx = idx
        break
      end
      idx += 1
    }
    if ft_idx
      @lf.send(listbox_name.intern).currentItem = ft_idx
    end
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
    @zoom = (@lf.dial_zoom.value).to_f / 100
    @lf.label_zoom.text = "Zoom: #{@zoom}"
    #~ p "@zoom: #{@zoom}"
    #~ p "@scale: #{@scale}"
  end
  #---------------------------------------------------------------------------------------------------------
  
  # zeichnet die Vorschau im Layout-Modus
  # hier ist noch einiges zu tun, im speziellen sind einige Werte "hart" kodiert, 
  # die z.Bsp abhängig von anderen Einstellungen sein sollten
  def draw_preview(immediately = false)
    @last_change = Time.now
    @last_change -= 5 if immediately
    return if @thread && @thread.alive?
  
    @thread = Thread.new{
      begin
        while Time.now-@last_change < 1
          sleep 0.1
        end
        
        # allgemeine Einstellungen des Image vornehmen
        dpi = 90
        width =  @layout_file.get_attr_value(S_WIDTH).to_f
        height = @layout_file.get_attr_value(S_HEIGHT).to_f
        
        Magick::RVG.dpi = dpi
        
        preview = true
        
        card_offset = 10
        
        image_width = (Page.width_with_margins(width) * @zoom)
        image_height = ((2 * Page.height_with_margins(height) + card_offset) * @zoom )
        
        scale_width = Page.width_with_margins(width).mm
        scale_height = (2 * Page.height_with_margins(height) + card_offset).mm
        
        row = @dataman ? @dataman.row(@row_nr) : nil
        begin
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
        rescue ResourceNotFoundError => e
          error_WahlMessage = FXFehlerAuswahlDialog.new(@app, e.to_s, 'ok')
          error_WahlMessage.execute
          @printing = false
        end
      rescue => e
        DebugTools::write_log_file('draw_preview_thread', unkown_error_message(e))
        error_WahlMessage = FXFehlerAuswahlDialog.new(@app, unkown_error_message(e), 'ok')
        error_WahlMessage.execute
      end # rescue
    }
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # aktualisiert den Titel des Layout-Fensters
  # es werden eingetragen
  # * der Dateiname des Layouts
  # * die verbunden Datenquelle (coming soon)
  # * ein Zeichen *, ob das Layout seit dem letzten Laden oder Speichern geändert wurde
  def set_title
    @parent.title = "#{@layout_file.filename} #{@dataman.filename.to_s if @dataman}  #{@changed ? ' *' : '' }"
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # speichert alle GraphicObjekte und Layout-Einstellungen im XML-File
	def store_to_xml(filename_dialog=false)
    if filename_dialog || !@layout_file.filename
      fn = FXFileDialog.getSaveFilename(@parent, 'Speichern', '.', patterns = '*.xml', initial = 0)
      return if fn.empty?
      unless fn.split(".")[-1].downcase == 'xml'
        fn = [fn, 'xml'].join(".")
      end
      @layout_file.filename = fn
    end
    @layout_file.save
    @changed = false
    set_title
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # fügt ein GraphicObjekt zur Objektliste hinzu und zeichnet die Vorschau und die Objektliste neu
  # ==== Parameter
  # +typ+:: der Typ des Objekts (Bild, Text, Barcode)
  def manage_objects(action, typ = nil)
    node = @layout_file.get_objectnode_by_id(@selected_object_id) if @selected_object_id
    if action == ADD
      @layout_file.add_object(typ)
      changed_attributes 
    elsif action == DELETE
      nn = node.find_first(GOA_NAME).content
      s = "Wollen Sie wirklich das Objekt '#{nn}' löschen? Dieser Vorgang lässt sich nicht rückgängig machen!"
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, s, ['löschen','abbrechen'])
      error_WahlMessage.execute
      if error_WahlMessage.selection == 0
        @layout_file.delete_object(node)
        changed_attributes 
      end
    elsif action == COPY
      @layout_file.copy_object(node)
      changed_attributes 
    end
    
    if @parent && @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      object_deselected
      fill_objectlist

      if action == ADD || action == COPY
        # neu hinzugefügtes Objekt aktiv schalten
        notify = true
        @lf.iconlist_objects.setCurrentItem(@lf.iconlist_objects.numItems-1, notify)
        @lf.iconlist_objects.selectItem(@lf.iconlist_objects.numItems-1, notify)
      end
      
      draw_preview(true)
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # füllt die Objektliste des Layout-Dialogs mit den Name der graphischen Objekte
  def fill_objectlist
    # Objekt-Liste leeren
    @lf.iconlist_objects.clearItems
    @lf.iconlist_objects.appendItem(['', '', 'Job-Einstellungen'].join("\t"), nil, nil, JobSetupObjID)

    if @layout_file
      # Array mit sortierten Objekt-ID's holen
      @layout_file.sorted_id_list.each{|id|
        go = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[contains(., #{id.to_s})]").parent
        name = go.find(GOA_NAME).first.content
        typ = go.find(GOA_TYP).first.content
        @lf.iconlist_objects.appendItem([id, name, typ].join("\t"), nil, nil, id)
      }
    end
  end
 	#---------------------------------------------------------------------------------------------------------

  # diese Methode liest die allgemeinen Einstellungen des Layouts aus dem XML aus und befüllt damit die Bearbeitungsfelder im Tab 'Allgemein'
  def fill_layout_attr_tab
    @lf.textfield_x_offset.text = @layout_file.get_attr_value(S_X_OFFSET)
    @lf.textfield_y_offset.text = @layout_file.get_attr_value(S_Y_OFFSET)
    @lf.textfield_datasource.text = @layout_file.get_attr_value(S_DATASOURCE)
    @lf.textfield_datasource.tipText = @lf.textfield_datasource.text
    set_check_button('checkbutton_contactless', @layout_file.get_attr_value(S_CONTACTLESS), $pr.has_contactless_engine?)
    set_check_button('checkbutton_contact', @layout_file.get_attr_value(S_CONTACT), $pr.has_contact_engine?)
    set_check_button('checkbutton_magstripe', @layout_file.get_attr_value(S_MAGSTRIPE), $pr.has_magstripe_engine?)
    set_check_button('checkbutton_duplex', @layout_file.get_attr_value(S_DUPLEX), $pr.can_duplex?)
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def set_check_button(objectname, state, enabled)
    if state == S_TRUE
      @lf.send(objectname).state = true
    else
      @lf.send(objectname).state = false 
    end
    @lf.send(objectname).enabled = enabled
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
      # füllt die Liste mit der Übersicht über die graphischen Objekte
      fill_objectlist 
      
      # die allgemeinen Layout-Attribute
      fill_layout_attr_tab
      
      # die Chip-Attribute
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
      
      # die Magnetstreifenattribute
      mag_attrs = @layout_file.xml_doc.find_first("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}")
      @lf.textfield_spur1.text = mag_attrs.find_first(S_MSSPUR1).content
      @lf.textfield_spur2.text = mag_attrs.find_first(S_MSSPUR2).content
      @lf.textfield_spur3.text = mag_attrs.find_first(S_MSSPUR3).content
      
      draw_preview(true)
      set_title
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def create_xml
    @layout_file = LayoutFile.create_xml
    draw_preview(true)
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def check_if_font_exist(fontdesc)
    rmfl = []
    Magick.fonts.each{|mf| 
      rmfl << mf.name
    }
    return fontdesc if rmfl.index(fontdesc.face.gsub(" ","-").gsub("@",""))
    fdlg.execute
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def print_cards
    c = @layout_file.get_attr_value(S_CONTACTLESS) == S_TRUE || @layout_file.get_attr_value(S_CONTACT) == S_TRUE 
    c ? chip = Chip.new : chip = nil
    if @layout_file.get_attr_value(S_DATASOURCE) == ""
      # nur eine Karte ohne Daten drucken
      printer = $pr 
      printer.print_card(@layout_file, nil, chip) # self ???
      chip.close_reader if chip
    else
      # Printdialog um Drucken von Karten mit Daten öffnen
      pr_dlg = MyPrintDialogBox.new(@app, self, chip)
      pr_dlg.topwin.show(Fox::PLACEMENT_SCREEN)
      pr_dlg.topwin.execute
    end
  end
 	#---------------------------------------------------------------------------------------------------------
  
  #
  def datasource_button_pressed
    lds = @layout_file.get_attr_value(S_DATASOURCE)
    ldsd = File.join(File.dirname(lds),'/')
    dest = FileTest.exists?(ldsd) ? ldsd : '.'
    s = FXFileDialog.getOpenFilename(@parent, "Datenquelle wählen", dest, patterns="*", initial=0)
    unless s.empty?
      @lf.textfield_datasource.text = s
      @lf.textfield_datasource.tipText = @lf.textfield_datasource.text
      textfield_exit(@lf.textfield_datasource, S_DATASOURCE)
      changed_attributes
    end
  end

  def fontfile_select_button_pressed
    lds = @layout_file.get_objectnode_by_id(@selected_object_id).find_first(GOA_FONT_FILE).content
    ldsd = File.join(File.dirname(lds),'/')
    dest = FileTest.exists?(ldsd) ? ldsd : '.'
    s = FXFileDialog.getOpenFilename(@parent, "Font-Datei wählen", dest, patterns="*", initial=0)
    unless s.empty?
      @lf.textfield_font_file.text = s
      textfield_exit(@lf.textfield_font_file, GOA_FONT_FILE)
      changed_attributes
    end
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
  lay.filename = 't:\Project\MCC2a\trunk\layouts\test1.xml'
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
