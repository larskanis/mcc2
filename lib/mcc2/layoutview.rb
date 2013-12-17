# -*- coding: UTF-8 -*-

module Mcc2
require 'mcc2/layoutview_dlg'

class Layoutview
  include Fox

  JobSetupObjID = -1


  # initialisiert zusätzliche Elemente im Layout-Dialog, die nicht oder schlecht im Fox-GUI-Builder erzeugt werden können
  # setzt Parameter bei Dialog-Elementen
  # definiert die Aktionen, welche bei bestimmten Ereignissen auf bestimmten Elementen des Dialogs ausgeführt werden sollen
  # ==== Parameter
  # +parent+:: ??
  def initialize(parent, layout)
    @layout = layout
    @parent = parent
    @layout_file = nil

    @lf = Dialogbox_layoutview.new parent
    @lf.splitter_layoutview.reparent parent, nil
    @lf.dialogbox_layoutview.close
    @lf.iconlist_objects.appendHeader('ID', nil, 50)
    @lf.iconlist_objects.appendHeader('Name', nil, 100)
    @lf.iconlist_objects.appendHeader('Typ', nil, 100)

    @lf.splitter_layoutview.setSplit(0, 170)
    @lf.splitter12.setSplit(0, 100)

    # .............................................................................................
    # die Aktionen definieren, die ausgeführt werden, wenn am Layout irgend etwas gearbeitet wird

    # die Buttons für das Ändern der Objektreihenfolge
    @lf.button_up.connect(SEL_COMMAND){ object_move_up_down(UP) }
    @lf.button_down.connect(SEL_COMMAND){ object_move_up_down(DOWN) }

    @text_field_trigger = SEL_COMMAND
#      text_field_trigger = SEL_CHANGED # geht sehr langsam und macht bei Barcode und Bild Probleme

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
    @lf.button_text_color.connect(@text_field_trigger){ text_color_dialog(@lf.textfield_text_color) }
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
    @lf.textfield_page_width.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_WIDTH) }
    @lf.textfield_page_height.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_HEIGHT) }
    l = @lf.combobox_datasource_typ
    l.clearItems
    l.appendItem('keine Daten - statisches Layout', NONE)
    l.appendItem('CSV-Datei', CSV)
    l.appendItem('DBF-Datei', DBF)
    l.appendItem('Datenbank', DATABASE)
    l.connect(SEL_COMMAND){ combobox_datasource_typ_changed }

    l = @lf.combobox_datasource_encoding
    l.clearItems
    VALID_ENCODINGS.each{|enc| l.appendItem(enc, enc) }
    l.connect(SEL_COMMAND){ combobox_datasource_encoding_changed }


    # die Auswahl auf welche Seite das Objekt soll
    @lf.spinner_seiten_nr.connect(SEL_COMMAND){ seiten_nr_changed }
    @lf.spinner_seiten_nr.range = (1..999)

    # der Checkbutton für die Einstellung Simplex/Duplex
    @lf.checkbutton_duplex.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_DUPLEX) }

    # der Button auf den Objektattributen, mit dem die Daten erweitert bearbeitet werden können (Variablen aus der Datenquelle verwenden usw.)
    @lf.button_enhanced_data_edit.connect(SEL_COMMAND){ enhanced_data_edit(@lf.textfield_data_non_text) }
    @lf.button_enhanced_data_text_edit.connect(SEL_COMMAND){ enhanced_data_edit(@lf.textfield_data) }
    @lf.button_sample_data.connect(SEL_COMMAND){ button_sample_data }


    # die Listbox zum Auswählen der Schriftart
    @lf.listbox_fonts.connect(SEL_COMMAND){ |sender, sel, event| sel_list_box_changed(sender) }
    @lf.textfield_font_file.connect(SEL_COMMAND){ |sender, sel, event| textfield_exit(sender, GOA_FONT_FILE) }
    Layout.connect_filebutton_to_textfield( @lf.button_fontfile_select, @lf.textfield_font_file,
          ["Truetype/Opentype font (*.ttf,*.otf)",  "PS-type1 font (*.pfb)", "All Files (*)"]
    )
    @lf.textfield_fontsize.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, GOA_FONT_HEIGHT) }

    # der Checkbuttons für die Einstellung, ob Magnestreifen, Kontaktchip und Kontaktlos personalisiert werden sollen
    @lf.checkbutton_contactless.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_CONTACTLESS) }
    @lf.checkbutton_contact.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_CONTACT) }
    @lf.checkbutton_magstripe.connect(SEL_COMMAND){|sender, sel, event| change_chkbtn(sender, S_MAGSTRIPE) }

    @lf.textfield_box_fill_color.connect(SEL_COMMAND){ |sender, sel, event| textfield_exit(sender, GOA_FILL_COLOR)}
    @lf.button_box_fill_color.connect(SEL_COMMAND){ text_color_dialog(@lf.textfield_box_fill_color) }
    @lf.textfield_box_border_color.connect(SEL_COMMAND){ |sender, sel, event| textfield_exit(sender, GOA_BORDER_COLOR) }
    @lf.button_box_border_color.connect(SEL_COMMAND){ text_color_dialog(@lf.textfield_box_border_color) }
    @lf.textfield_box_border_width.connect(SEL_COMMAND){ |sender, sel, event| textfield_exit(sender, GOA_BORDER_WIDTH) }
    @lf.textfield_box_corner_radius.connect(SEL_COMMAND){ |sender, sel, event| textfield_exit(sender, GOA_CORNER_RADIUS) }

    # die Checkbuttons für das Löschen und Kopieren von Graphik-Objekten
    @lf.button_copy.enabled = false
    @lf.button_copy.connect(SEL_COMMAND){ manage_objects(COPY) }
    @lf.button_delete.enabled = false
    @lf.button_delete.connect(SEL_COMMAND){ manage_objects(DELETE) }

    # die Textfelder für die Magnetstreifenattribute
    @lf.textfield_spur1.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_MSSPUR1) }
    @lf.textfield_spur2.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_MSSPUR2) }
    @lf.textfield_spur3.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_MSSPUR3) }

    @barcodes = if Object.const_defined?(:Barby)
      Barby.constants.map{|c| c.to_s }.sort.select{|c| Barby.const_get(c).ancestors.include?(Barby::Barcode)} - %w[Barcode Barcode1D Barcode2D Code128]
    else
      []
    end
    @lf.listbox_barcode_typ.connect(SEL_COMMAND){ |sender, sel, event| sel_list_box_changed(sender) }
    @lf.spinner_barcode_ratio.connect(SEL_COMMAND){ bc_modul_with_changed }
    @lf.spinner_barcode_ratio.range = (1..100)
    # .............................................................................................

    create_chipparam_fields

    # Korrektur, da der LIBGUI-Builder irgendwie einen Fehler macht
    @lf.matrix1.numColumns = 3
    @lf.matrix2.numColumns = 4
    @lf.matrix_boxtab.numColumns = 3
    fill_objectlist
    object_selection_changed
  end
  #---------------------------------------------------------------------------------------------------------

  # erzeugt Textfelder für die Eingabe der Chip-Parameter
  # erzeugt so viele Felder, wie in der Methode anz_params der Klasse Chip definiert sind
  # erzeugt ein Array, in welchem alle Felder gespeichert sind
  def create_chipparam_fields
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

    (0 ... CHIPPARAM_FIELD_COUNT).each{|i|
      FX::Label.new(matrix_chipparams){|w|
        w.wdg_name = "label_chipparam_#{i}"
        w.text = ['Parameter', i+1].join(' ')
        w.font=FX::Font.new.from_s('Helvetica|80|40|5|0|0|0').to_FXFont
      }
      tf = FX::TextField.new(matrix_chipparams, LAYOUT_FILL_X){|w|
        w.textFieldTextStyle = LAYOUT_FILL_X
        w.wdg_name = "textfield_chipparam_#{i}"
        w.font = FX::Font.new.from_s('Helvetica|80|40|5|0|0|0').to_FXFont
        w.numColumns = 40
      }
      tf.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, S_CHIPPARAMS) }
      @chipparam_textfields << tf
    }
  end
  #---------------------------------------------------------------------------------------------------------

  def layoutview_tab_activated(active=true)
    draw_preview if active
  end

  def layout_file= file
    @layout_file = file

    # füllt die Liste mit der Übersicht über die graphischen Objekte
    fill_objectlist

    # die allgemeinen Layout-Attribute
    fill_layout_attr_tab

    # die Chip-Attribute
    chip = @layout_file.chip_object
    chip.params.each_with_index{|param, idx|
      @chipparam_textfields[idx].text = param
    }

    # die Magnetstreifenattribute
    mag_attrs = @layout_file.magstripe_object
    @lf.textfield_spur1.text = mag_attrs[S_MSSPUR1]
    @lf.textfield_spur2.text = mag_attrs[S_MSSPUR2]
    @lf.textfield_spur3.text = mag_attrs[S_MSSPUR3]

    draw_preview(true)
  end
  #

  def enhanced_data_edit(textfield)
    if (dm=@layout.dataman) && dm.headers
      filemenu = FXMenuPane.new(textfield)
      dm.headers.each{|col|
        FXMenuCommand.new(filemenu, col).connect(SEL_COMMAND) {
          text = textfield.text
          text[textfield.cursorPos,0] = "{#{col}[0,999]}"
          textfield.setText(text, true)
        }
      }
      x = textfield.x
      y = textfield.y
      filemenu.x, filemenu.y = *textfield.parent.translateCoordinatesTo(@parent, x, y)
      filemenu.create
      filemenu.show
    end
  end

  def button_sample_data
    objnode = @layout_file.get_objectnode_by_id(@selected_object_id)
    return unless objnode
    typ = objnode.at_xpath(GOA_TYP).content
    if typ == PICTUREOBJECT
      Layout.execute_filedialog_for_textfield(@lf.textfield_sample_data, filepatterns='*')
    end
  end

  #---------------------------------------------------------------------------------------------------------
  # die Reaktion, wenn der Status eines Checkbuttons geänderrt wurde
  # setzt das changed-Flag
  # ==== Parameter
  # +sender+::    das Objekt, welches das Ereignis gesendet hat
  # +attr_name+:: der Name des Attributs
  def change_chkbtn(sender, attr_name)
    if sender.state != @layout_file.get_attr_value(attr_name)
      @layout_file.set_attr_value attr_name, sender.state.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # ???
  def change_chkbtn_printlist
    objnode = @layout_file.get_objectnode_by_id(@selected_object_id)
    return unless objnode
    node = objnode.at_xpath(GOA_PRINTLIST)
    if @lf.checkbutton_printlist.state != node.content
      node.content = @lf.checkbutton_printlist.state.to_s
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
      @layout_file.xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
        id = go_struct.at_xpath(GOA_ID).content.to_i
        new_id = obj_arr.index(id)
        go_struct.at_xpath(GOA_ID).content = new_id.to_s
      }
      currentItem = @lf.iconlist_objects.currentItem

      # changed-Flag setzen
      changed_attributes

      # Objekt-Liste aktualisieren
      fill_objectlist

      notify = true
      if currentItem>1 && dest == UP
        @lf.iconlist_objects.setCurrentItem(currentItem - 1, notify)
        @lf.iconlist_objects.selectItem(currentItem - 1, notify)
      elsif currentItem>0 && currentItem<@lf.iconlist_objects.numItems && dest == DOWN
        @lf.iconlist_objects.setCurrentItem(currentItem + 1, notify)
        @lf.iconlist_objects.selectItem(currentItem + 1, notify)
      end
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # öffnet einen Dialog, mit dem die Textfarbe gewählt werden kann und
  # trägt diese in das Textfeld für die Farbangabe ein
  # zeichnet anschließend die Vorschau neu
  def text_color_dialog(textfield)
    cdlg = FXColorDialog.new(@parent, "Textfarbe")
    if cdlg.execute>0 && textfield.text != cdlg.rgba
      s = cdlg.rgba.to_i.to_s(16)
      textfield.setText([s[6,2], s[4,2], s[2,2], s[0,2]].join, true)
    end
  end
  #---------------------------------------------------------------------------------------------------------

  def combobox_datasource_typ_changed
    datatype = @lf.combobox_datasource_typ.getItemData(@lf.combobox_datasource_typ.currentItem)
    @layout_file.set_attr_value(S_DATASOURCETYP, datatype)
    changed_attributes
  end

  def combobox_datasource_encoding_changed
    datatype = @lf.combobox_datasource_encoding.getItemData(@lf.combobox_datasource_encoding.currentItem)
    @layout_file.set_attr_value(S_DATASOURCEENCODING, datatype)
    changed_attributes
  end

  # die Aktion, welche ausgeführt wird, wenn die Auswahl der Seitennummer geändert wurde, auf welcher das Objekt ausgegeben werden soll
  def seiten_nr_changed
    seite = @lf.spinner_seiten_nr.value - 1
    node = @layout_file.get_objectnode_by_id(@selected_object_id).at_xpath(GOA_PAGE_NR)
    if seite != node.content.to_i
      node.content = seite.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # die Aktion, welche ausgeführt wird, wenn die Auswahl der Textausrichtung geändert wurde
  # ==== Parameter
  # +r+:: das Radio-Mutex-Objekt
  def radiomutex_justify_changed(r)
    node = @layout_file.get_objectnode_by_id(@selected_object_id).at_xpath(GOA_JUSTIFICATION)
    if r.to_s != node.content
      node.content = r.to_s
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
      chip_attrs = @layout_file.xml_doc.at_xpath("//#{S_ROOT}/#{S_CHIP}")

      # den entsprechenden Parameter suchen
      attr_name = "#{S_PARAM}_#{id+1}"
      node = chip_attrs.at_xpath(attr_name)
    elsif [S_X_OFFSET, S_Y_OFFSET, S_WIDTH, S_HEIGHT].include?(attr_name)
      @layout_file.set_attr_value(attr_name, sender.text)
      changed_attributes
    elsif attr_name == S_X_OFFSET
      lay_attrs = @layout_file.xml_doc.at_xpath("//#{S_ROOT}/#{S_LAYOUT}")
      node = lay_attrs.at_xpath(S_X_OFFSET)
    elsif attr_name == S_MSSPUR1
      node = @layout_file.xml_doc.at_xpath("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}/#{S_MSSPUR1}")
    elsif attr_name == S_MSSPUR2
      node = @layout_file.xml_doc.at_xpath("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}/#{S_MSSPUR2}")
    elsif attr_name == S_MSSPUR3
      node = @layout_file.xml_doc.at_xpath("//#{S_ROOT}/#{S_MAGSTRIPEPARAMS}/#{S_MSSPUR3}")
    else
      # in diesem Zweig werden alle Graphik-Objekte bearbeitet
      # das Attribut suchen
      objnode = @layout_file.get_objectnode_by_id(@selected_object_id)
      return unless objnode
      node = objnode.at_xpath(attr_name)
    end

    # nur wenn im Textfeld etwas geändert wurde, den Text in das Attribut schreiben und das changed-Flag setzen
    if node && sender.text != node.content
      node.content = sender.text
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # schreibt den Text der im Textfeld eingegeben wurde in das Attribut 'name' des graphischen Objekts und aktualisiert die Objektliste
  def textfield_name_exit
    objnode = @layout_file.get_objectnode_by_id(@selected_object_id)
    return unless objnode
    orig_name = objnode.at_xpath(GOA_NAME)
    if @lf.textfield_name.text != orig_name.content
      orig_name.content = @lf.textfield_name.text
      changed_attributes
      fill_objectlist
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # deaktivieren der Anzeige der Objektattribute, wenn kein Objekt selektiert ist
  def activate_object_tabs(on=true)
    @lf.tabitem_object.shown = on
    @lf.tabitem_posit.shown = on
    @lf.tabitem_font.shown = on
    @lf.tabitem_barcode.shown = on
    @lf.tabitem_box.shown = on
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

  attr_reader :selected_object_id
  def selected_object_id= id
    @selected_object_id = id
    @layout.selected_object_id = id
  end

  #---------------------------------------------------------------------------------------------------------

  # deaktiviert die Tabs im Layout-Dialog, welche Objekt-spezifisch sind
  def object_deselected
    activate_object_tabs(false)
    self.selected_object_id = nil
    activate_up_down(false)
    activate_copy_delete(false)
  end
  #---------------------------------------------------------------------------------------------------------

  # wenn in der Objektliste ein anderes Objekt selektiert wird, dann werden mit dieser Methode die Anzeigen aktualisiert,
  # z.Bsp, nur die Tabs aktiviert, die zum Objekttyp passen, usw.
  def object_selection_changed
    item_ID = @lf.iconlist_objects.currentItem
    self.selected_object_id = @lf.iconlist_objects.getItemData(item_ID).to_i

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
      @lf.textfield_name.text = node.at_xpath(GOA_NAME).content

      # Positionsattribute
      @lf.textfield_x.text = node.at_xpath(GOA_X).content
      @lf.textfield_y.text = node.at_xpath(GOA_Y).content
      @lf.textfield_width.text = node.at_xpath(GOA_WIDTH).content
      @lf.textfield_height.text = node.at_xpath(GOA_HEIGHT).content
      @lf.textfield_rotation.text = node.at_xpath(GOA_ROTATION).content
      @lf.textfield_rotation.text = node.at_xpath(GOA_ROTATION).content
      @lf.spinner_seiten_nr.value = node.at_xpath(GOA_PAGE_NR).content.to_i + 1
  #      @lf.iconlist_justify.connect(SEL_CHANGED){iconlist_justify_exit } # todo

      if node.at_xpath(GOA_PRINTLIST).content == 'false' || node.at_xpath(GOA_PRINTLIST).content == '0'
        @lf.checkbutton_printlist.state = false
      else
        @lf.checkbutton_printlist.state = true
      end

      # Typ-spezifische Attribute auslesen
      if [BARCODEOBJECT, TEXTOBJECT, PICTUREOBJECT].include?( node.at_xpath(GOA_TYP).content )
        @lf.textfield_sample_data.text = node.at_xpath(GOA_SAMPLE_DATA).content
        @lf.textfield_data.text = node.at_xpath(GOA_DATA).content
        @lf.textfield_data_non_text.text = node.at_xpath(GOA_DATA).content
      end

      # Attribute, die Barcode und Texte haben
      if node.at_xpath(GOA_TYP).content == TEXTOBJECT || node.at_xpath(GOA_TYP).content == BARCODEOBJECT
        @lf.tabitem_font.shown = true
        @lf.textfield_text_color.text = node.at_xpath(GOA_FONT_COLOR).content

        # den Radiobutton der Ausrichtung setzen
        @lf.radiobutton_just_l.state = false
        @lf.radiobutton_just_l.state = false
        @lf.radiobutton_just_r.state = false
        just = @layout_file.get_objectnode_by_id(@selected_object_id).at_xpath(GOA_JUSTIFICATION).content
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
      if node.at_xpath(GOA_TYP).content == TEXTOBJECT
        data_block_shown
      end

      # Attribute, die nur Barcodes haben
      if node.at_xpath(GOA_TYP).content == BARCODEOBJECT
        @lf.tabitem_barcode.shown = true
        @lf.spinner_barcode_ratio.value = node.at_xpath(GOA_BAR_RATIO).content.to_i
        fill_barcode_typ_list
        fill_barcode_fields(node)
        data_shown
      end

      # Attribute, die nur Bilder haben
      if node.at_xpath(GOA_TYP).content == PICTUREOBJECT
        data_shown
      end

      if node.at_xpath(GOA_TYP).content == BOXOBJECT
        @lf.tabitem_box.shown = true
        @lf.tabitem_box.recalc
        @lf.textfield_box_fill_color.text = node.at_xpath(GOA_FILL_COLOR).content
        @lf.textfield_box_border_color.text = node.at_xpath(GOA_BORDER_COLOR).content
        @lf.textfield_box_border_width.text = node.at_xpath(GOA_BORDER_WIDTH).content
        @lf.textfield_box_corner_radius.text = node.at_xpath(GOA_CORNER_RADIUS).content
        no_data_shown
      end
    end

    draw_preview(true)
  end
  #---------------------------------------------------------------------------------------------------------

  def sel_list_box_changed(sender)
    #~ node.at_xpath(GOA_FONT_HEIGHT).content = (fontdesc.size.to_f/10).to_s

    if sender.wdg_name == 'listbox_fonts'
      font = @lf.listbox_fonts.getItemData(@lf.listbox_fonts.currentItem)
      @lf.textfield_font_file.enabled = font=='from_file'
      @layout_file.get_objectnode_by_id(@selected_object_id).at_xpath(GOA_FONT_TYP).content = font
    elsif sender.wdg_name == 'listbox_barcode_typ'
      bc = @lf.listbox_barcode_typ.getItemText(@lf.listbox_barcode_typ.currentItem)
      @layout_file.get_objectnode_by_id(@selected_object_id).at_xpath(GOA_BARCODE_TYP).content = bc
    else
      raise "unbekannter Sender. Eingriff des Programmierers nötig. :-("
    end
    changed_attributes
  end
  #---------------------------------------------------------------------------------------------------------

  # die Aktion, welche ausgeführt wird, wenn die Auswahl der Modulbreite des Barcodes geändert wird
  def bc_modul_with_changed
    mw = @lf.spinner_barcode_ratio.value
    node = @layout_file.get_objectnode_by_id(@selected_object_id).at_xpath(GOA_BAR_RATIO)
    if mw != node.content.to_i
      node.content = mw.to_s
      changed_attributes
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # füllt die Barcode-Typ-Auswahlliste mit den möglichen Barcodes
  def fill_barcode_typ_list
    @lf.listbox_barcode_typ.clearItems
    @barcodes.each{|bc|
      @lf.listbox_barcode_typ.appendItem(bc)
    }
  end
  #---------------------------------------------------------------------------------------------------------

  # füllt die Barcode-spezifischen Felder mit den gewählten Optionen aus dem Layout
  def fill_barcode_fields(node)
    # den gewählten Parameter in den entsprechenden Listen markieren
    bc_typ = node.at_xpath(GOA_BARCODE_TYP).content
    bc_id = @barcodes.index(bc_typ)
    error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Der Barcode-Typ #{bc_typ} existiert nicht in der Liste der verfügbaren Barcodes.\ Der Wert wird auf 'NONE' gesetzt.", ['&OK']) unless bc_id
    @lf.listbox_barcode_typ.currentItem = bc_id if bc_id
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
    @lf.textfield_fontsize.text = node.at_xpath(GOA_FONT_HEIGHT).content

    font_typ = node.at_xpath(GOA_FONT_TYP).content
    # den gewählten Parameter in den entsprechenden Listen markieren
    set_listbox_value('listbox_fonts', font_typ)
    @lf.textfield_font_file.enabled = font_typ=='from_file'
    @lf.textfield_font_file.text = node.at_xpath(GOA_FONT_FILE).content
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
  # deaktiviert die Textfelder für Dateneingabe
  def no_data_shown
    @lf.textfield_data.shown = false
    @lf.label_textblock.shown = false
    @lf.textfield_data_non_text.shown = false
    @lf.label_textfield.shown = false
    @lf.button_enhanced_data_edit.shown = false
    @lf.button_enhanced_data_text_edit.shown = false
  end

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
  # fügt ein GraphicObjekt zur Objektliste hinzu und zeichnet die Vorschau und die Objektliste neu
  # ==== Parameter
  # +typ+:: der Typ des Objekts (Bild, Text, Barcode)
  def manage_objects(action, typ = nil)
    node = @layout_file.get_objectnode_by_id(@selected_object_id) if @selected_object_id
    if action == ADD
      @layout_file.add_object(typ)
      changed_attributes
    elsif action == DELETE
      nn = node.at_xpath(GOA_NAME).content
      s = "Wollen Sie wirklich das Objekt '#{nn}' löschen?\nDieser Vorgang lässt sich nicht rückgängig machen!"
      error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, s, ['&Löschen','&Abbrechen'])
      error_WahlMessage.execute
      if error_WahlMessage.selection == 0
        @layout_file.delete_object(node)
        changed_attributes
      end
    elsif action == COPY
      @layout_file.copy_object(node)
      changed_attributes
    end

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
  #---------------------------------------------------------------------------------------------------------

  # füllt die Objektliste des Layout-Dialogs mit den Name der graphischen Objekte
  def fill_objectlist
    # Objekt-Liste leeren
    @lf.iconlist_objects.clearItems
    @lf.iconlist_objects.appendItem(['', '', 'Job-Einstellungen'].join("\t"), nil, nil, JobSetupObjID)

    if @layout_file
      # Array mit sortierten Objekt-ID's holen
      @layout_file.sorted_id_list.each{|id|
        go = @layout_file.find_graphic_object_by_id(id)
        @lf.iconlist_objects.appendItem([id, go[GOA_NAME], go[GOA_TYP]].join("\t"), nil, nil, id)
      }
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # diese Methode liest die allgemeinen Einstellungen des Layouts aus dem XML aus und befüllt damit die Bearbeitungsfelder im Tab 'Allgemein'
  def fill_layout_attr_tab
    @lf.textfield_x_offset.text = @layout_file.get_attr_value(S_X_OFFSET)
    @lf.textfield_y_offset.text = @layout_file.get_attr_value(S_Y_OFFSET)
    @lf.textfield_page_width.text = @layout_file.get_attr_value(S_WIDTH)
    @lf.textfield_page_height.text = @layout_file.get_attr_value(S_HEIGHT)
    Layout.set_combobox_by_data( @lf.combobox_datasource_typ, @layout_file.get_attr_value(S_DATASOURCETYP))
    Layout.set_combobox_by_data( @lf.combobox_datasource_encoding, @layout_file.get_attr_value(S_DATASOURCEENCODING))
    set_check_button('checkbutton_contactless', @layout_file.get_attr_value(S_CONTACTLESS), true)
    set_check_button('checkbutton_contact', @layout_file.get_attr_value(S_CONTACT), true)
    set_check_button('checkbutton_magstripe', @layout_file.get_attr_value(S_MAGSTRIPE), true)
    set_check_button('checkbutton_duplex', @layout_file.get_attr_value(S_DUPLEX), true)
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

  def draw_preview(immediately=false)
    @layout.draw_preview(immediately)
  end

  def changed_attributes
    @layout.changed_attributes
    draw_preview
  end

end
end
