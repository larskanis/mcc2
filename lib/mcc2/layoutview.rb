module Mcc2
  require "mcc2/layoutview_dlg"

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
      @selected_object_ids = []

      @lf = Dialogbox_layoutview.new parent
      @lf.splitter_layoutview.reparent parent, nil
      @lf.dialogbox_layoutview.close
      @lf.iconlist_objects.appendHeader("ID", nil, 50 * $gui_scale)
      @lf.iconlist_objects.appendHeader("Name", nil, 100 * $gui_scale)
      @lf.iconlist_objects.appendHeader("Typ", nil, 100 * $gui_scale)

      @lf.splitter_layoutview.setSplit(0, 250 * $gui_scale)
      @lf.splitter12.setSplit(0, 70 * $gui_scale)

      # .............................................................................................
      # die Aktionen definieren, die ausgeführt werden, wenn am Layout irgend etwas gearbeitet wird

      # die Buttons für das Ändern der Objektreihenfolge
      @lf.button_up.connect(SEL_COMMAND) { object_move_up_down(UP) }
      @lf.button_down.connect(SEL_COMMAND) { object_move_up_down(DOWN) }

      @text_field_trigger = SEL_CHANGED
      #      text_field_trigger = SEL_CHANGED # geht sehr langsam und macht bei Barcode und Bild Probleme

      # Objektliste
      @lf.iconlist_objects.connect(SEL_SELECTED) { object_selected }
      @lf.iconlist_objects.connect(SEL_DESELECTED) { object_selected }

      # die allgemeinen Objektattribute
      @lf.textfield_name.connect(SEL_COMMAND) { obj_attr_changed(GOA_NAME, @lf.textfield_name.text) }

      # die Daten-Attribute
      @lf.textfield_data_non_text.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_data.connect(SEL_CHANGED) { |sender, sel, event| textfield_exit(sender, GOA_DATA) }
      @lf.textfield_sample_data.connect(SEL_CHANGED) { |sender, sel, event| textfield_exit(sender, GOA_SAMPLE_DATA) }

      # die Font-Attribute
      @lf.textfield_text_color.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_FONT_COLOR) }
      @lf.button_text_color.connect(@text_field_trigger) { text_color_dialog(@lf.textfield_text_color) }
      @lf.radiomutex_justify.on_event_selected { |r| obj_attr_changed(GOA_JUSTIFICATION, r) }

      # die Positions-Attribute
      @lf.textfield_x.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_X) }
      @lf.textfield_y.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_Y) }
      @lf.textfield_width.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_WIDTH) }
      @lf.textfield_height.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_HEIGHT) }
      @lf.textfield_rotation.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_ROTATION) }

      # die Checkbox, ob der Inhalt des Feldes in der Liste des Druckdialogs mit angezeigt werden soll
      @lf.checkbutton_printlist.connect(SEL_COMMAND) { obj_attr_changed(GOA_PRINTLIST, @lf.checkbutton_printlist.state) }

      # die Textfelder für die allgemeine Layoutoptionen
      @lf.textfield_x_offset.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_X_OFFSET) }
      @lf.textfield_y_offset.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_Y_OFFSET) }
      @lf.textfield_page_width.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_WIDTH) }
      @lf.textfield_page_height.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_HEIGHT) }
      l = @lf.combobox_datasource_typ
      l.clearItems
      l.appendItem("keine Daten - statisches Layout", NONE)
      l.appendItem("CSV-Datei", CSV)
      l.appendItem("DBF-Datei", DBF)
      l.appendItem("Datenbank", DATABASE)
      l.connect(SEL_COMMAND) do
        value = @lf.combobox_datasource_typ.getItemData(@lf.combobox_datasource_typ.currentItem)
        attr_changed(S_DATASOURCETYP, value)
      end

      l = @lf.combobox_datasource_encoding
      l.clearItems
      VALID_ENCODINGS.each { |enc| l.appendItem(enc, enc) }
      l.connect(SEL_COMMAND) do
        value = @lf.combobox_datasource_encoding.getItemData(@lf.combobox_datasource_encoding.currentItem)
        attr_changed(S_DATASOURCEENCODING, value)
      end

      # die Auswahl auf welche Seite das Objekt soll
      @lf.spinner_seiten_nr.connect(SEL_COMMAND) { obj_attr_changed(GOA_PAGE_NR, @lf.spinner_seiten_nr.value - 1) }
      @lf.spinner_seiten_nr.range = (1..999)
      @lf.spinner_layer.connect(SEL_COMMAND) { obj_attr_changed(GOA_LAYER, @lf.spinner_layer.value) }
      @lf.spinner_image_page.connect(SEL_COMMAND) { obj_attr_changed(GOA_IMAGE_PAGE, @lf.spinner_image_page.value) }
      @lf.spinner_image_page.range = (1..999)

      # der Checkbutton für die Einstellung Simplex/Duplex
      @lf.checkbutton_duplex.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_DUPLEX) }
      @lf.checkbutton_flip_front.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_FRONT_FLIP) }
      @lf.checkbutton_flop_front.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_FRONT_FLOP) }
      @lf.checkbutton_flip_back.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_BACK_FLIP) }
      @lf.checkbutton_flop_back.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_BACK_FLOP) }

      # der Button auf den Objektattributen, mit dem die Daten erweitert bearbeitet werden können (Variablen aus der Datenquelle verwenden usw.)
      @lf.menubutton_enhanced_data_edit.connect(SEL_LEFTBUTTONPRESS) { enhanced_data_edit(@lf.menubutton_enhanced_data_edit, @lf.textfield_data_non_text) }
      @lf.menubutton_enhanced_data_text_edit.connect(SEL_LEFTBUTTONPRESS) { enhanced_data_edit(@lf.menubutton_enhanced_data_text_edit, @lf.textfield_data) }

      @lf.menubutton_sample_data.connect(SEL_LEFTBUTTONPRESS) { button_sample_data }
      @layout.add_tipText_to_filedialog_for_textfield(@lf.textfield_sample_data)

      # die Listbox zum Auswählen der Schriftart
      @lf.listbox_fonts.connect(SEL_COMMAND) { |sender, sel, event| sel_list_box_changed(sender) }
      @lf.textfield_font_file.connect(SEL_COMMAND) { |sender, sel, event| textfield_exit(sender, GOA_FONT_FILE) }
      @layout.connect_filebutton_to_textfield(@lf.button_fontfile_select, @lf.textfield_font_file,
        filepatterns: ["Truetype/Opentype font (*.ttf,*.otf)", "PS-type1 font (*.pfb)", "All Files (*)"])
      @lf.textfield_fontsize.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, GOA_FONT_HEIGHT) }

      # der Checkbuttons für die Einstellung, ob Magnestreifen, Kontaktchip und Kontaktlos personalisiert werden sollen
      @lf.checkbutton_contactless.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_CONTACTLESS) }
      @lf.checkbutton_contact.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_CONTACT) }
      @lf.checkbutton_magstripe.connect(SEL_COMMAND) { |sender, sel, event| change_chkbtn(sender, S_MAGSTRIPE) }

      @lf.textfield_box_fill_color.connect(SEL_COMMAND) { |sender, sel, event| textfield_exit(sender, GOA_FILL_COLOR) }
      @lf.button_box_fill_color.connect(SEL_COMMAND) { text_color_dialog(@lf.textfield_box_fill_color) }
      @lf.textfield_box_border_color.connect(SEL_COMMAND) { |sender, sel, event| textfield_exit(sender, GOA_BORDER_COLOR) }
      @lf.button_box_border_color.connect(SEL_COMMAND) { text_color_dialog(@lf.textfield_box_border_color) }
      @lf.textfield_box_border_width.connect(SEL_COMMAND) { |sender, sel, event| textfield_exit(sender, GOA_BORDER_WIDTH) }
      @lf.textfield_box_corner_radius.connect(SEL_COMMAND) { |sender, sel, event| textfield_exit(sender, GOA_CORNER_RADIUS) }

      # die Checkbuttons für das Löschen und Kopieren von Graphik-Objekten
      @lf.button_copy.enabled = false
      @lf.button_copy.connect(SEL_COMMAND) { manage_objects(COPY) }
      @lf.button_delete.enabled = false
      @lf.button_delete.connect(SEL_COMMAND) { manage_objects(DELETE) }
      @lf.button_move_up.connect(SEL_COMMAND) { move_selected(0, -1) }
      @lf.button_move_down.connect(SEL_COMMAND) { move_selected(0, 1) }
      @lf.button_move_left.connect(SEL_COMMAND) { move_selected(-1, 0) }
      @lf.button_move_right.connect(SEL_COMMAND) { move_selected(1, 0) }

      # die Textfelder für die Magnetstreifenattribute
      @lf.textfield_spur1.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_MSSPUR1) }
      @lf.textfield_spur2.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_MSSPUR2) }
      @lf.textfield_spur3.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_MSSPUR3) }

      @barcodes = if Object.const_defined?(:Zint)
        [
          :Aztec,
          :C25inter,
          :C25standard,
          :Codabar,
          :CodablockF,
          :Code11,
          :Code128,
          :Code128AB,
          :Code128B,
          :Code16k,
          :Code32,
          :Code39,
          :Code49,
          :Code93,
          :CodeOne,
          :DataMatrix,
          :DotCode,
          :Ean128,
          :Ean14,
          :Eanx,
          :EanxChk,
          :Excode39,
          :Gs1_128,
          :C25inter,
          :MaxiCode,
          :MicroPdf417,
          :MicroQr,
          :Pdf417,
          :Pdf417comp,
          :Pdf417trunc,
          :Qr,
          :UpcA,
          :UpcAChk,
          :UpcE,
          :UpcEChk
        ]
      else
        []
      end
      @lf.listbox_barcode_typ.connect(SEL_COMMAND) { |sender, sel, event| sel_list_box_changed(sender) }
      @lf.spinner_barcode_ratio.connect(SEL_COMMAND) do
        changed_attributes if @layout_file.set_object_by_ids(@selected_object_ids, GOA_BAR_RATIO, @lf.spinner_barcode_ratio.value)
      end
      @lf.spinner_barcode_height.connect(SEL_COMMAND) do
        changed_attributes if @layout_file.set_object_by_ids(@selected_object_ids, GOA_BARCODE_HEIGHT, @lf.spinner_barcode_height.value)
      end
      @lf.checkbutton_barcode_optimized.connect(SEL_COMMAND) do
        changed_attributes if @layout_file.set_object_by_ids(@selected_object_ids, GOA_BARCODE_OPTIMIZED, @lf.checkbutton_barcode_optimized.checked?)
      end
      @lf.spinner_barcode_ratio.range = (1..100)

      create_chipparam_fields

      fill_objectlist
      object_selection_changed
    end

    # erzeugt Textfelder für die Eingabe der Chip-Parameter
    # erzeugt so viele Felder, wie in der Methode anz_params der Klasse Chip definiert sind
    # erzeugt ein Array, in welchem alle Felder gespeichert sind
    def create_chipparam_fields
      @chipparam_textfields = []

      scrl_w = FX::ScrollWindow.new(@lf.verticalframe_chip, LAYOUT_FILL_X | LAYOUT_FILL_Y)
      matrix_chipparams = FX::Matrix.new(scrl_w, LAYOUT_FILL_X | LAYOUT_FILL_Y) do |w|
        @matrix3 = w
        w.wdg_name = "matrix_xyz"
        w.numRows = 4
        w.numColumns = 2
        w.width = 650 * $gui_scale
        w.y = 2
        w.height = 0
        w.matrixStyle = MATRIX_BY_COLUMNS | LAYOUT_FILL_X | LAYOUT_FILL_Y
        w.x = 2
      end

      (0...CHIPPARAM_FIELD_COUNT).each do |i|
        FX::Label.new(matrix_chipparams) do |w|
          w.wdg_name = "label_chipparam_#{i}"
          w.text = ["Parameter", i + 1].join(" ")
          w.font = FX::Font.new.from_s("Helvetica|80|40|5|0|0|0").to_FXFont
        end
        tf = FX::TextField.new(matrix_chipparams, LAYOUT_FILL_X) do |w|
          w.textFieldTextStyle = LAYOUT_FILL_X
          w.wdg_name = "textfield_chipparam_#{i}"
          w.font = FX::Font.new.from_s("Helvetica|80|40|5|0|0|0").to_FXFont
          w.numColumns = 40
        end
        tf.connect(@text_field_trigger) { |sender, sel, event| textfield_exit(sender, S_CHIPPARAMS) }
        @chipparam_textfields << tf
      end
    end

    def layoutview_tab_activated(active = true)
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
      chip.params.each_with_index do |param, idx|
        @chipparam_textfields[idx].text = param
      end

      # die Magnetstreifenattribute
      mag_attrs = @layout_file.magstripe_object
      @lf.textfield_spur1.text = mag_attrs[S_MSSPUR1]
      @lf.textfield_spur2.text = mag_attrs[S_MSSPUR2]
      @lf.textfield_spur3.text = mag_attrs[S_MSSPUR3]

      draw_preview(true)
    end

    def enhanced_data_edit(menubutton, textfield)
      if (dm = @layout.dataman)
        menupane = menubutton.menu
        menupane.each_child { |ch| menupane.removeChild(ch) }
        [dm.data_headers, dm.meta_headers].each_with_index do |headers, idx|
          FXMenuSeparator.new(menupane) if idx > 0
          headers.each do |col|
            FXMenuCommand.new(menupane, col).connect(SEL_COMMAND) do
              text = textfield.text
              text.bytesplice(textfield.cursorPos, 0, "{#{col}[0,999]}")
              textfield.setText(text, true)
            end
          end
        end
        menupane.create
        menupane.resize(menupane.getDefaultWidth, menupane.getDefaultHeight)
        menubutton.handle(menubutton, Fox.FXSEL(Fox::SEL_COMMAND, Fox::FXMenuButton::ID_POST), nil)
      end
    end

    def button_sample_data
      typ = @layout_file.get_object_by_id(@selected_object_ids.last, GOA_TYP)
      if [PICTUREOBJECT, EMBEDOBJECT].include?(typ)
        @layout.execute_filedialog_for_textfield(@lf.textfield_sample_data, filepatterns: "*")
      end
    end

    # die Reaktion, wenn der Status eines Checkbuttons geänderrt wurde
    # setzt das changed-Flag
    # ==== Parameter
    # +sender+::    das Objekt, welches das Ereignis gesendet hat
    # +attr_name+:: der Name des Attributs
    def change_chkbtn(sender, attr_name)
      if @layout_file.set_attr_value attr_name, sender.state.to_s
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
      # erst einmal eine sortierte Liste aller ID's der Grafikobjekte holen
      obj_arr = @layout_file.sorted_id_list

      # die Positionen in dieser Liste ermitteln und von oben nach unten abarbeiten
      positions = @selected_object_ids.map do |object_id|
        obj_arr.index(object_id)
      end.sort
      # bzw. von unten nach oben, wenn Objekte nach unten geschoben werden
      positions.reverse! if dest == DOWN

      positions.each do |pos|
        # dann das entsprechende Objekt mit dem nächstgelegenen tauschen
        if dest == UP
          obj_arr[pos], obj_arr[pos - 1] = obj_arr[pos - 1], obj_arr[pos]
        elsif dest == DOWN
          obj_arr[pos], obj_arr[pos + 1] = obj_arr[pos + 1], obj_arr[pos]
        end
      end

      # Nun im XML reindexieren
      @layout_file.reorder_id_list(obj_arr)

      # changed-Flag setzen
      changed_attributes

      # Objekt-Liste aktualisieren
      currentItem = @lf.iconlist_objects.currentItem
      selected_items = @lf.iconlist_objects.map.with_index.select { |i, x| i.selected? }.map(&:last)
      fill_objectlist
      @selected_object_ids = []

      # Cursor in Liste setzen
      notify = true
      if currentItem > 1 && dest == UP
        @lf.iconlist_objects.setCurrentItem(currentItem - 1, notify)
        selected_items.each do |idx|
          @lf.iconlist_objects.selectItem(idx - 1, notify)
        end
      elsif currentItem > 0 && currentItem < @lf.iconlist_objects.numItems && dest == DOWN
        @lf.iconlist_objects.setCurrentItem(currentItem + 1, notify)
        selected_items.each do |idx|
          @lf.iconlist_objects.selectItem(idx + 1, notify)
        end
      end
    end

    # öffnet einen Dialog, mit dem die Textfarbe gewählt werden kann und
    # trägt diese in das Textfeld für die Farbangabe ein
    # zeichnet anschließend die Vorschau neu
    def text_color_dialog(textfield)
      cdlg = FXColorDialog.new(@parent, "Textfarbe")
      if cdlg.execute > 0 && textfield.text != cdlg.rgba
        s = cdlg.rgba.to_i.to_s(16)
        textfield.setText([s[6, 2], s[4, 2], s[2, 2], s[0, 2]].join, true)
      end
    end

    def attr_changed(attr, value)
      if @layout_file.set_attr_value(attr, value)
        changed_attributes
      end
    end

    def obj_attr_changed(attr, value)
      if @layout_file.set_object_by_ids(@selected_object_ids, attr, value.to_s)
        changed_attributes
        fill_objectlist if [GOA_NAME, GOA_TYP].include?(attr)
      end
    end
    #---------------------------------------------------------------------------------------------------------

    # händelt für bestimmte Textfelder das Eintragen des Textes in das jeweilige Attribut in der XML-Struktur
    # setzt das changed-Flag
    # ==== Parameter
    # +sender+::    das Objekt, welches das Ereignis gesendet hat
    # +attr_name+:: der Name des Attributs
    def textfield_exit(sender, attr_name)
      changed = if attr_name == S_CHIPPARAMS
        # aus dem Namen des Textfeldes die ID ermitteln (sind durchnummeriert)
        id = sender.wdg_name.split("_")[-1].to_i

        # den entsprechenden Parameter suchen
        attr_name = "#{S_PARAM}_#{id + 1}"
        @layout_file.set_attr_value(attr_name, sender.text, S_CHIP)
      elsif [S_X_OFFSET, S_Y_OFFSET, S_WIDTH, S_HEIGHT].include?(attr_name)
        @layout_file.set_attr_value(attr_name, sender.text)
      elsif [S_MSSPUR1, S_MSSPUR2, S_MSSPUR3].include?(attr_name)
        @layout_file.set_attr_value(attr_name, sender.text, S_MAGSTRIPEPARAMS)
      else
        # in diesem Zweig werden alle Graphik-Objekte bearbeitet
        # das Attribut suchen
        @layout_file.set_object_by_ids(@selected_object_ids, attr_name, sender.text)
      end
      changed_attributes if changed
    end

    # deaktivieren der Anzeige der Objektattribute, wenn kein Objekt selektiert ist
    def activate_object_tabs(on = true)
      @lf.tabitem_object.shown = on
      @lf.tabitem_posit.shown = on
      @lf.tabitem_font.shown = on
      @lf.tabitem_barcode.shown = on
      @lf.tabitem_box.shown = on
    end

    def activate_job_tabs(on = true)
      @lf.tabitem_allgemein.shown = on
      @lf.tabitem_chip.shown = on
      @lf.tabitem_magstripe.shown = on
    end

    # deaktiviert die Buttons für das Verschieben der Objekte in der Objektliste (zum Beispiel, wenn kein Objekt selektiert ist)
    def activate_up_down(on = true)
      @lf.button_up.enabled = on
      @lf.button_down.enabled = on
    end

    def activate_copy_delete(on = true)
      @lf.button_copy.enabled = on
      @lf.button_delete.enabled = on
      @lf.button_move_up.enabled = on
      @lf.button_move_down.enabled = on
      @lf.button_move_left.enabled = on
      @lf.button_move_right.enabled = on
    end

    def object_selected
      item_ids = @lf.iconlist_objects.select { |i| i.selected? }.map { |i| i.data }
      @layout.selected_object_ids = item_ids
    end

    attr_reader :selected_object_ids
    def selected_object_ids=(ids)
      @selected_object_ids = ids
      object_selection_changed
    end

    # wenn in der Objektliste ein anderes Objekt selektiert wird, dann werden mit dieser Methode die Anzeigen aktualisiert,
    # z.Bsp, nur die Tabs aktiviert, die zum Objekttyp passen, usw.
    def object_selection_changed
      if @selected_object_ids.empty?
        # No object selected
        activate_object_tabs(false)
        activate_up_down(false)
        activate_copy_delete(false)
        @lf.iconlist_objects.killSelection

      elsif @selected_object_ids == [JobSetupObjID]
        # Job-Setup selected
        activate_job_tabs
        @lf.tabbook_objectattributes.current = 0

      else
        # Graphic object selected
        pos = @lf.iconlist_objects.findItemByData(@selected_object_ids.last)
        @lf.iconlist_objects.setCurrentItem(pos) if @lf.iconlist_objects.currentItem == -1
        @lf.iconlist_objects.makeItemVisible(pos)
        @lf.iconlist_objects.killSelection
        @selected_object_ids.each do |id|
          pos = @lf.iconlist_objects.findItemByData(id)
          @lf.iconlist_objects.selectItem(pos)
        end

        # erst einmal alle Objekt-Tabs deaktivieren, damit sicher gestellt ist, dass nur die Objekt-typischen angezeigt werden
        activate_object_tabs(false)
        activate_job_tabs(false)
        activate_copy_delete

        # die Buttons für das Ändern der Reihenfolge aktivieren
        positions = @selected_object_ids.map { |id| @lf.iconlist_objects.findItemByData(id) }
        @lf.button_up.enabled = positions.all? { |po| po > 1 }
        num_objects = @layout_file.sorted_id_list.length
        @lf.button_down.enabled = positions.all? { |po| po < num_objects }

        obj = @layout_file.find_graphic_object_by_id(@selected_object_ids.last)

        # allgemeine Attribute auslesen
        @lf.tabitem_object.shown = true
        @lf.tabitem_posit.shown = true

        # Daten-Attribute
        @lf.textfield_name.text = obj[GOA_NAME]

        # Positionsattribute
        @lf.textfield_x.text = obj[GOA_X]
        @lf.textfield_y.text = obj[GOA_Y]
        @lf.textfield_width.text = obj[GOA_WIDTH]
        @lf.textfield_height.text = obj[GOA_HEIGHT]
        @lf.textfield_rotation.text = obj[GOA_ROTATION]
        @lf.textfield_rotation.text = obj[GOA_ROTATION]
        @lf.spinner_seiten_nr.value = obj[GOA_PAGE_NR].to_i + 1
        @lf.spinner_layer.value = obj[GOA_LAYER].to_i
        #      @lf.iconlist_justify.connect(SEL_CHANGED){iconlist_justify_exit } # todo

        @lf.checkbutton_printlist.state = !(obj[GOA_PRINTLIST] == "false" || obj[GOA_PRINTLIST] == "0")

        # Typ-spezifische Attribute auslesen
        if [BARCODEOBJECT, TEXTOBJECT, PICTUREOBJECT, EMBEDOBJECT].include?(obj[GOA_TYP])
          @lf.textfield_sample_data.text = obj[GOA_SAMPLE_DATA]
          @lf.textfield_data.text = obj[GOA_DATA]
          @lf.textfield_data_non_text.text = obj[GOA_DATA]
        end

        # Attribute, die Barcode und Texte haben
        if obj[GOA_TYP] == TEXTOBJECT || obj[GOA_TYP] == BARCODEOBJECT
          @lf.tabitem_font.shown = true
          @lf.textfield_text_color.text = obj[GOA_FONT_COLOR]

          # den Radiobutton der Ausrichtung setzen
          @lf.radiobutton_just_l.state = false
          @lf.radiobutton_just_m.state = false
          @lf.radiobutton_just_r.state = false
          case obj[GOA_JUSTIFICATION]
          when S_JUST_LEFT
            @lf.radiobutton_just_l.state = true
          when S_JUST_MID
            @lf.radiobutton_just_m.state = true
          when S_JUST_RIGHT
            @lf.radiobutton_just_r.state = true
          end

          fill_font_list
          fill_font_fields(obj)
        end

        # Attribute, die nur Texte haben
        if obj[GOA_TYP] == TEXTOBJECT
          data_block_shown
        end

        # Attribute, die nur Barcodes haben
        if obj[GOA_TYP] == BARCODEOBJECT
          @lf.tabitem_barcode.shown = true
          @lf.spinner_barcode_ratio.value = obj[GOA_BAR_RATIO].to_i
          @lf.spinner_barcode_height.value = obj[GOA_BARCODE_HEIGHT].to_f
          @lf.checkbutton_barcode_optimized.setCheck(obj[GOA_BARCODE_OPTIMIZED] == "true")
          fill_barcode_typ_list
          fill_barcode_fields(obj)
          data_shown
        end

        # Attribute, die nur Bilder haben
        if obj[GOA_TYP] == PICTUREOBJECT
          data_shown
        end

        if obj[GOA_TYP] == BOXOBJECT
          @lf.tabitem_box.shown = true
          @lf.tabitem_box.recalc
          @lf.textfield_box_fill_color.text = obj[GOA_FILL_COLOR]
          @lf.textfield_box_border_color.text = obj[GOA_BORDER_COLOR]
          @lf.textfield_box_border_width.text = obj[GOA_BORDER_WIDTH]
          @lf.textfield_box_corner_radius.text = obj[GOA_CORNER_RADIUS]
          no_data_shown
        end

        if obj[GOA_TYP] == EMBEDOBJECT
          data_shown
        end
      end

      draw_preview(true)
    end
    #---------------------------------------------------------------------------------------------------------

    def sel_list_box_changed(sender)
      # ~ obj[GOA_FONT_HEIGHT] = (fontdesc.size.to_f/10).to_s

      changed = if sender.wdg_name == "listbox_fonts"
        font = @lf.listbox_fonts.getItemData(@lf.listbox_fonts.currentItem)
        @lf.textfield_font_file.enabled = font == "from_file"
        @layout_file.set_object_by_ids(@selected_object_ids, GOA_FONT_TYP, font)
      elsif sender.wdg_name == "listbox_barcode_typ"
        bc = @lf.listbox_barcode_typ.getItemText(@lf.listbox_barcode_typ.currentItem)
        @layout_file.set_object_by_ids(@selected_object_ids, GOA_BARCODE_TYP, bc)
      else
        raise "unbekannter Sender. Eingriff des Programmierers nötig. :-("
      end
      changed_attributes if changed
    end
    #---------------------------------------------------------------------------------------------------------

    # füllt die Barcode-Typ-Auswahlliste mit den möglichen Barcodes
    def fill_barcode_typ_list
      @lf.listbox_barcode_typ.clearItems
      @barcodes.each do |bc|
        @lf.listbox_barcode_typ.appendItem(bc.to_s)
      end
    end
    #---------------------------------------------------------------------------------------------------------

    # füllt die Barcode-spezifischen Felder mit den gewählten Optionen aus dem Layout
    def fill_barcode_fields(obj)
      # den gewählten Parameter in den entsprechenden Listen markieren
      bc_typ = obj[GOA_BARCODE_TYP]
      bc_id = @barcodes.index(bc_typ.to_sym)
      FXFehlerAuswahlDialog.new(@parent.app, "Der Barcode-Typ #{bc_typ} existiert nicht in der Liste der verfügbaren Barcodes. Der Wert wird auf 'NONE' gesetzt.", ["&OK"]) unless bc_id
      @lf.listbox_barcode_typ.currentItem = bc_id if bc_id
    end

    # füllt die Font-Auswahlliste mit den möglichen Fonts
    def fill_font_list
      # Font-Name
      rmfl = Magick.fonts.map { |mf| mf.name }
      rmfl.sort!
      @lf.listbox_fonts.clearItems
      @lf.listbox_fonts.appendItem("")
      idx = @lf.listbox_fonts.appendItem("aus Font-Datei") # humanreadable
      @lf.listbox_fonts.setItemData(idx, "from_file")      # font name or file

      rmfl.each do |rmf|
        idx = @lf.listbox_fonts.appendItem(rmf.tr("-", " ")) # humanreadable
        @lf.listbox_fonts.setItemData(idx, rmf)         # font name or file
      end
    end

    # füllt die Font-spezifischen Felder mit den gewählten Optionen aus dem Layout
    def fill_font_fields(obj)
      # die Schriftgröße zurücklesen
      @lf.textfield_fontsize.text = obj[GOA_FONT_HEIGHT]

      font_typ = obj[GOA_FONT_TYP]
      # den gewählten Parameter in den entsprechenden Listen markieren
      set_listbox_value("listbox_fonts", font_typ)
      @lf.textfield_font_file.enabled = font_typ == "from_file"
      @lf.textfield_font_file.text = obj[GOA_FONT_FILE]
    end

    # selectiert in der über listbox_name angegebenen Listbox den Eintrag, der Value entspricht
    # wird beim Laden benötigt, um aus den Layoutdaten die Einstellungen zu restaurieren
    def set_listbox_value(listbox_name, value)
      ft_idx = nil
      idx = 0
      @lf.send(listbox_name).each do |t, i, d|
        if d == value
          ft_idx = idx
          break
        end
        idx += 1
      end
      if ft_idx
        @lf.send(listbox_name).currentItem = ft_idx
      end
    end

    # aktiviert ein einzeiliges Textfeld für die Eingabe der Daten (wird für Barcode und Bilder gebraucht)
    def data_shown
      @lf.textfield_data.shown = false
      @lf.label_textblock.shown = false
      @lf.textfield_data_non_text.shown = true
      @lf.label_textfield.shown = true
      @lf.menubutton_enhanced_data_edit.shown = true
      @lf.menubutton_enhanced_data_text_edit.shown = false
    end

    # deaktiviert die Textfelder für Dateneingabe
    def no_data_shown
      @lf.textfield_data.shown = false
      @lf.label_textblock.shown = false
      @lf.textfield_data_non_text.shown = false
      @lf.label_textfield.shown = false
      @lf.menubutton_enhanced_data_edit.shown = false
      @lf.menubutton_enhanced_data_text_edit.shown = false
    end

    # aktiviert ein mehrzeiliges Textfeld für die Eingabe der Daten (wird für Text gebraucht)
    def data_block_shown
      @lf.textfield_data.shown = true
      @lf.label_textblock.shown = true
      @lf.textfield_data_non_text.shown = false
      @lf.label_textfield.shown = false
      @lf.menubutton_enhanced_data_edit.shown = false
      @lf.menubutton_enhanced_data_text_edit.shown = true
    end

    # fügt ein GraphicObjekt zur Objektliste hinzu und zeichnet die Vorschau und die Objektliste neu
    # ==== Parameter
    # +typ+:: der Typ des Objekts (Bild, Text, Barcode)
    def manage_objects(action, typ = nil)
      if action == ADD
        @layout_file.add_object(typ)
        changed_attributes
      elsif action == DELETE
        names = @selected_object_ids.map do |id|
          obj = @layout_file.find_graphic_object_by_id(id)
          "'#{obj[GOA_NAME]}'"
        end
        nn = names.join(", ")
        s = "Wollen Sie wirklich #{(names.size > 1) ? "die Objekte" : "das Objekt"} #{nn} löschen?\nDieser Vorgang lässt sich nicht rückgängig machen!"
        error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, s, ["&Löschen", "&Abbrechen"])
        error_WahlMessage.execute
        if error_WahlMessage.selection == 0
          @layout_file.delete_objects(@selected_object_ids)
          changed_attributes
        end
      elsif action == COPY
        @layout_file.copy_objects(@selected_object_ids)
        changed_attributes
      end
      num_objs = @selected_object_ids.size

      @selected_object_ids = []
      fill_objectlist

      if action == ADD || action == COPY
        # neu hinzugefügtes Objekt aktiv schalten
        notify = true
        @lf.iconlist_objects.setCurrentItem(@lf.iconlist_objects.numItems - 1, notify)
        (@lf.iconlist_objects.numItems - num_objs..@lf.iconlist_objects.numItems - 1).each do |pos|
          @lf.iconlist_objects.selectItem(pos, notify)
        end
      end

      draw_preview(true)
    end

    # füllt die Objektliste des Layout-Dialogs mit den Name der graphischen Objekte
    def fill_objectlist
      # Objekt-Liste leeren
      @lf.iconlist_objects.clearItems
      @lf.iconlist_objects.appendItem(["", "", "Job-Einstellungen"].join("\t"), nil, nil, JobSetupObjID)

      if @layout_file
        # Array mit sortierten Objekt-ID's holen
        @layout_file.sorted_id_list.each do |id|
          go = @layout_file.find_graphic_object_by_id(id)
          @lf.iconlist_objects.appendItem([id, go[GOA_NAME], go[GOA_TYP]].join("\t"), nil, nil, id)
        end
      end
    end

    # diese Methode liest die allgemeinen Einstellungen des Layouts aus dem XML aus und befüllt damit die Bearbeitungsfelder im Tab 'Allgemein'
    def fill_layout_attr_tab
      @lf.textfield_x_offset.text = @layout_file.get_attr_value(S_X_OFFSET)
      @lf.textfield_y_offset.text = @layout_file.get_attr_value(S_Y_OFFSET)
      @lf.textfield_page_width.text = @layout_file.get_attr_value(S_WIDTH)
      @lf.textfield_page_height.text = @layout_file.get_attr_value(S_HEIGHT)
      Layout.set_combobox_by_data(@lf.combobox_datasource_typ, @layout_file.get_attr_value(S_DATASOURCETYP))
      Layout.set_combobox_by_data(@lf.combobox_datasource_encoding, @layout_file.get_attr_value(S_DATASOURCEENCODING))
      set_check_button("checkbutton_contactless", @layout_file.get_attr_value(S_CONTACTLESS), true)
      set_check_button("checkbutton_contact", @layout_file.get_attr_value(S_CONTACT), true)
      set_check_button("checkbutton_magstripe", @layout_file.get_attr_value(S_MAGSTRIPE), true)
      set_check_button("checkbutton_duplex", @layout_file.get_attr_value(S_DUPLEX), true)
      set_check_button("checkbutton_flip_front", @layout_file.get_attr_value(S_FRONT_FLIP), true)
      set_check_button("checkbutton_flop_front", @layout_file.get_attr_value(S_FRONT_FLOP), true)
      set_check_button("checkbutton_flip_back", @layout_file.get_attr_value(S_BACK_FLIP), true)
      set_check_button("checkbutton_flop_back", @layout_file.get_attr_value(S_BACK_FLOP), true)
    end

    def set_check_button(objectname, state, enabled)
      @lf.send(objectname).state = state == S_TRUE
      @lf.send(objectname).enabled = enabled
    end

    def move_selected(x, y)
      @selected_object_ids.each do |id|
        next if id < 0
        go = @layout_file.find_graphic_object_by_id(id)
        go[GOA_X] = go[GOA_X].to_f + x
        go[GOA_Y] = go[GOA_Y].to_f + y
      end

      changed_attributes if x != 0 || y != 0
      @layout.set_focus(:preview)
    end

    def draw_preview(immediately = false)
      @layout.draw_preview(immediately)
    end

    def changed_attributes
      @layout.changed_attributes
      draw_preview
    end
  end
end
