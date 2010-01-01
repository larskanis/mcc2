# -*- coding: UTF-8 -*-

require 'dataview_dlg'

class Dataview < Dialogbox_dataview

  def initialize parent, layout
    @layout = layout
    @parent = parent

    super(parent)
    @splitter_dataview.reparent parent, nil
    @dialogbox_dataview.close

    @matrix_printbuttons.numColumns = 3
    @search_pos = 0

    # .............................................................................................
    # alle Aktionen definieren

    @button_select_all.connect(SEL_COMMAND){ select_all }
    @button_deselect_all.connect(SEL_COMMAND){ deselect_all }
    @button_print_selected.connect(SEL_COMMAND){ print_selected }
    @button_search.connect(SEL_COMMAND){ search }
    @button_print_all.connect(SEL_COMMAND){ print_all }
    @button_stop_printing.connect(SEL_COMMAND){ stop_printing }
#    @button_exit.connect(SEL_COMMAND){ peng }
    @iconlist_data.connect(SEL_CHANGED){ update_preview }
    @iconlist_data.connect(SEL_SELECTED){ print_list_selection_changed }
    @iconlist_data.connect(SEL_DESELECTED){ print_list_deselected }
    @text_field_trigger = SEL_COMMAND
    @textfield_print_from.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, PRINT_FROM) }
    @textfield_print_to.connect(@text_field_trigger){|sender, sel, event| textfield_exit(sender, PRINT_TO) }
    # .............................................................................................
    @printing = false
    disable_all_buttons
    @button_print_all.enabled = true
    @button_exit.enabled = true
    @button_select_all.enabled = true

    @verticalframe_datalist.width = 500
#    @horizontalframe3.height = 0
#    @splitter2.setSplit(0, 500)

    fill_datalist_when_visible
  end

  def dataview_tab_activated
    ensure_datalist_filled
  end

  attr_reader :layout_file
  def layout_file= file
    @layout_file = file
  end

  attr_reader :dataman

  # This method is called whenever the datasource has changed.
  def dataman= v
    @textfield_print_to.text = v.rows.length.to_s
    @dataman = v
    fill_datalist_when_visible
  end

  def fill_datalist_when_visible
    puts "fill_datalist_when_visible"
    @fill_datalist_triggered = true
    if @parent.active?
      ensure_datalist_filled
    end
  end

  def ensure_datalist_filled
    puts "ensure_datalist_filled"
    if @fill_datalist_triggered
      fill_datalist
      @fill_datalist_triggered = false
    end
  end

  def fill_datalist
    puts "fill_datalist"
    # todo im Moment werden in der Liste der zu druckenden Datensätze alle Felder des Datensatzes angezeigt,
    # eigentlichh soll auswählbar sein, welche Felder angezeigt werden sollen, in den graphischen Objekten ist schon ein Feld vorgesehen, welches dieses Verhalten steuern sollen
    # es ist zu überlegen, welche Daten man dort anzeigt
    #~ printlist = xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").collect{|objekt|
      #~ name = objekt.find(GOA_NAME).first.content
    #~ }
    if @dataman && @layout_file
      @iconlist_data.appendHeader("Datensatz", nil, 60)
      felder = @dataman.row(0).map{|e|
        feldname = e[0].to_s
        @iconlist_data.appendHeader(feldname, nil, 100)
        feldname
      }
      big_icon = nil
      mini_icon = nil
      coding = @layout_file.get_attr_value(S_DATASOURCEENCODING)
      encoding = Iconv.new('UTF-8', coding)
      @dataman.rows.each_with_index{|row, idx|
        itemtext = "#{idx+1}\t" + felder.map{|feld|
          data = row[feld]
          encoding.iconv(data)
        }.join("\t")
        @iconlist_data.appendItem(itemtext, big_icon, mini_icon, row)
      }

      update_preview
    end
    
  end
  
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

  def draw_preview(row, immediately=false)
    @layout.draw_preview_with_row(row, immediately)
  end



  def textfield_exit(sender, attr_name)
    anz = @@dataman.rows.length
    if attr_name == PRINT_FROM || attr_name == PRINT_TO
      if sender.text.to_i < 1 || sender.text.to_i > anz
        error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Nur Werte > 0 und <= #{anz} möglich!", 'ok')
        error_WahlMessage.execute
        if attr_name == PRINT_FROM
          sender.text = 1
        elsif attr_name == PRINT_TO
          sender.text = anz
        end
      end
    end
  end
  #---------------------------------------------------------------------------------------------------------

  def itemsSelected?
    if @iconlist_data.numItems > 0
      (0..(@iconlist_data.numItems-1)).each{|it|
        if @iconlist_data.itemSelected?(it)
          return true
        end
      }
    end
    return false
  end

  #---------------------------------------------------------------------------------------------------------

  #
  def enable_disable_print_select_button
    if itemsSelected?
      @button_print_selected.enabled = true
      @button_deselect_all.enabled = true
    else
      @button_print_selected.enabled = false
      @button_deselect_all.enabled = false
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # sucht in allen Feldern nach dem Text, der ins Suchfeld eingegeben wurde
  def search
    anz_items = @iconlist_data.numItems
    @iconlist_data.setFocus
    if anz_items > 0
      # alte Suchposition sichern, damit nur 1 Runde gesucht wird, falls kein Ergebnis gefunden wird
      old_search_pos = @search_pos

      while true
        if @iconlist_data.getItemText(@search_pos) =~ /#{@textfield_search.text}/
          # wenn gefunden
          @iconlist_data.currentItem = @search_pos
          @iconlist_data.makeItemVisible(@search_pos)
          #~ @iconlist_data.anchorItem = @search_pos
          @search_pos += 1
          break
        end

        if @search_pos < anz_items -1
          # solange Tabelelnende noch nicht erreicht
          @search_pos += 1
        else
          # wenn Tabelelnende erreicht, am Anfang fortsetzen
          @search_pos = 0
        end

        if @search_pos == old_search_pos
          # Message ausgeben
            error_WahlMessage = FXFehlerAuswahlDialog.new(@app, 'Der Suchbegriff wurde nicht gefunden.', 'ok')
            error_WahlMessage.execute
          break
        end
      end
    end
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def print_list_selection_changed
    enable_disable_print_select_button
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def print_list_deselected
    enable_disable_print_select_button
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def update_preview
    if @checkbutton2.state && !@printing # Vorschau nicht während dem Druck, da es sonst zu Druckfehlern kommt und der Druck länger dauert
      row_nr = @iconlist_data.currentItem
      @iconlist_data.makeItemVisible(@iconlist_data.currentItem)
      draw_preview @dataman.row(row_nr)
    end
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def deselect_all
    @iconlist_data.killSelection
    @button_select_all.enabled = true
    @button_deselect_all.enabled = false
    @button_print_selected.enabled = false
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def select_all
    (1..@iconlist_data.numItems).each{|itemnr|
      @iconlist_data.selectItem(itemnr-1)
    }
    @button_select_all.enabled = false
    @button_deselect_all.enabled = true
    @button_print_selected.enabled = true
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def print_all
    @button_print_all.enabled = false
    disable_all_buttons

    enable_all_buttons
    enable_disable_print_select_button
    @button_stop_printing.enabled = true
    @button_print_all.enabled = true
    only_selected = false
    print_cards(only_selected)
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def print_selected
    only_selected = true
    print_cards(only_selected)
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def print_cards(only_selected = false)
    range = check_range
    unless range
      return
    end
    von = range[0]
    bis = range[1]
    disable_all_buttons
    @button_stop_printing.enabled = true
    @printing = true
    printer = $pr
    if bis == -1
      bis = @iconlist_data.numRows - 1
    end

    marked_items = []
    (von..bis).map{|i|
      if only_selected == false || only_selected == true && @iconlist_data.itemSelected?(i)
        marked_items << @iconlist_data.getItemData(i)
      end
    }

    layout_file = @@layout_file
    Thread.new{
      begin
        marked_items.each{|item|
          it = @iconlist_data.findItemByData(item)
          @iconlist_data.makeItemVisible(it)
          notify = true
          @iconlist_data.setFocus
          @iconlist_data.setCurrentItem(it, notify)
          erg = printer.print_card(layout_file, item, @chip)
          # den aktuellen Datensatz deselektieren, wenn er erfolgreich gedruckt wurde
          @iconlist_data.deselectItem(it) if erg

          if !erg || !@printing
            # abbrechen, wenn ein Fehler aufgetreten ist, oder wenn der Bediener es gefordert hat
            break
          end
        }
      rescue ResourceNotFoundError => e
        error_WahlMessage = FXFehlerAuswahlDialog.new(@app, e.to_s, 'ok')
        error_WahlMessage.execute
      rescue => e
        DebugTools::write_log_file('print_card_thread', unkown_error_message(e))
        error_WahlMessage = FXFehlerAuswahlDialog.new(@app, unkown_error_message(e), 'ok')
        error_WahlMessage.execute
      ensure
        @printing = false
        enable_all_buttons
        enable_disable_print_select_button
        @button_stop_printing.enabled = false
        @chip.close_reader if @chip
      end # rescue
    }
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def check_range
    textfield_print_from.text != "" ? von = textfield_print_from.text.to_i - 1 : von = nil
    textfield_print_to.text != "" ? bis = textfield_print_to.text.to_i - 1 : bis = nil

    # wenn 'bis' gefüllt, aber 'von' nicht gefüllt -> Fehler
    if von == nil && bis != nil
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Im Textfeld 'Von' ist kein Wert angegeben!", 'ok')
      error_WahlMessage.execute
      return nil
    end

    # wenn 'von' gefüllt, aber 'bis' nicht gefüllt -> Fehler
    if von != nil && bis == nil
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Im Textfeld 'Bis' ist kein Wert angegeben!", 'ok')
      error_WahlMessage.execute
      return nil
    end

    # wenn 'von' größer als 'bis' -> Fehler
    if von && bis && von > bis
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Der Wert im Feld 'Von' ist größer als der Wert im Textfeld 'Bis'!", 'ok')
      error_WahlMessage.execute
      return nil
    end

    # wenn 'von' und 'bis' nicht gefüllt  -> kein Fehler
    if !von && !bis
      return [0, -1]
    end

    # ansonsten -> kein Fehler
    return [von, bis]
  end
  #---------------------------------------------------------------------------------------------------------

  def disable_all_buttons
    @button_print_selected.enabled = false
    @button_print_all.enabled = false
    @button_exit.enabled = false
    @button_select_all.enabled = false
    @button_deselect_all.enabled = false
    @button_stop_printing.enabled = false
  end
  #---------------------------------------------------------------------------------------------------------

  def enable_all_buttons
    @button_print_selected.enabled = true
    @button_print_all.enabled = true
    @button_exit.enabled = true
    @button_select_all.enabled = true
    @button_deselect_all.enabled = true
    @button_stop_printing.enabled = true
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def stop_printing
    @printing = false
  end
  #---------------------------------------------------------------------------------------------------------
  
end
