# -*- coding: UTF-8 -*-

module Mcc2
require 'mcc2/dataview_dlg'

class Dataview < Dialogbox_dataview
  include Fox

  def initialize parent, layout
    @layout = layout
    @parent = parent

    super(parent)
    @splitter_dataview.reparent parent, nil
    @dialogbox_dataview.close

    @matrix_printbuttons.numColumns = 3
    @search_pos = 0
    @visible = false

    # .............................................................................................
    # alle Aktionen definieren

    @textfield_datasource.connect(SEL_COMMAND){
      @layout_file.set_attr_value(S_DATASOURCE, @textfield_datasource.text)
      changed_attributes
    }
    # Button für das Auswählen einer Datenquelle an Textfeld knüpfen
    Layout.connect_filebutton_to_textfield( @button_datasource, @textfield_datasource,
          ["Semicolon seperated file (*.csv)", "All Files (*)"]
    )
    
    @button_select_all.connect(SEL_COMMAND){ select_all }
    @button_deselect_all.connect(SEL_COMMAND){ deselect_all }
    @button_print_selected.connect(SEL_COMMAND){ print_selected }
    @textfield_search.connect(SEL_COMMAND){ search; @textfield_search.setFocus }
    @button_print_all.connect(SEL_COMMAND){ print_all }
    @button_stop_printing.connect(SEL_COMMAND){ stop_printing }
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
    @button_select_all.enabled = true

    @verticalframe_datalist.width = 500

    fill_datalist_when_visible
  end

  def dataview_tab_activated(active=true)
    @visible = active
    if @visible
      ensure_datalist_filled
      update_preview
    end
  end

  attr_reader :layout_file
  def layout_file= file
    @layout_file = file
    @textfield_datasource.text = @layout_file.get_attr_value(S_DATASOURCE)
  end

  attr_reader :dataman

  # This method is called whenever the datasource has changed.
  def dataman= v
    if v && v.rows
      @textfield_print_from.text = 1
      @textfield_print_to.text = v.rows.length.to_s
    end
    @dataman = v
    fill_datalist_when_visible
  end

  def fill_datalist_when_visible
    @fill_datalist_triggered = true
    if @visible
      ensure_datalist_filled
    end
  end

  def ensure_datalist_filled
    if @fill_datalist_triggered
      fill_datalist
      @fill_datalist_triggered = false
    end
  end

  def fill_datalist
    # todo im Moment werden in der Liste der zu druckenden Datensätze alle Felder des Datensatzes angezeigt,
    # eigentlichh soll auswählbar sein, welche Felder angezeigt werden sollen, in den graphischen Objekten ist schon ein Feld vorgesehen, welches dieses Verhalten steuern sollen
    # es ist zu überlegen, welche Daten man dort anzeigt
    @iconlist_data.clearItems
    @iconlist_data.header.clearItems
    
    if @dataman && @layout_file
      @iconlist_data.appendHeader("Datensatz", nil, 60)
      
      first_row = @dataman.row(0)
      felder = if first_row
        first_row.map{|e|
          feldname = e[0].to_s
          @iconlist_data.appendHeader(feldname, nil, 100)
          feldname
        }
      else
        []
      end
      
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

  def draw_preview(row, immediately=false)
    @layout.draw_preview_with_row(row, immediately)
  end



  def textfield_exit(sender, attr_name)
    anz = @dataman.rows.length
    if attr_name == PRINT_FROM || attr_name == PRINT_TO
      if sender.text.to_i < 1 || sender.text.to_i > anz
        error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Nur Werte > 0 und <= #{anz} möglich!", 'ok')
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
        if @search_pos<anz_items && @iconlist_data.getItemText(@search_pos) =~ /#{@textfield_search.text}/i
          # wenn gefunden
          @iconlist_data.setCurrentItem(@search_pos, true)
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
            error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, 'Der Suchbegriff wurde nicht gefunden.', 'ok')
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
    if !@printing # Vorschau nicht während dem Druck, da es sonst zu Druckfehlern kommt und der Druck länger dauert
      row_nr = @iconlist_data.currentItem
      if row_nr>=0
        @iconlist_data.makeItemVisible(row_nr)
        draw_preview @dataman.row(row_nr)
      end
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
    printer = @layout_file.build_printer_instance
    
    if bis == -1
      bis = @iconlist_data.numRows - 1
    end

    marked_items = []
    (von..bis).map{|i|
      if !only_selected || @iconlist_data.itemSelected?(i)
        marked_items << @iconlist_data.getItemData(i)
      end
    }

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
      rescue RmagickDrawer::ResourceNotFoundError => e
        FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen eines Grafikobjekts", e.to_s)
      rescue => e
        DebugTools::write_log_file('print_card_thread', DebugTools::unkown_error_message(e))
        FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen des Druckbildes", DebugTools::unkown_error_message(e))
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
      error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Im Textfeld 'Von' ist kein Wert angegeben!", 'ok')
      error_WahlMessage.execute
      return nil
    end

    # wenn 'von' gefüllt, aber 'bis' nicht gefüllt -> Fehler
    if von != nil && bis == nil
      error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Im Textfeld 'Bis' ist kein Wert angegeben!", 'ok')
      error_WahlMessage.execute
      return nil
    end

    # wenn 'von' größer als 'bis' -> Fehler
    if von && bis && von > bis
      error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Der Wert im Feld 'Von' ist größer als der Wert im Textfeld 'Bis'!", 'ok')
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
    @button_select_all.enabled = false
    @button_deselect_all.enabled = false
    @button_stop_printing.enabled = false
  end
  #---------------------------------------------------------------------------------------------------------

  def enable_all_buttons
    @button_print_selected.enabled = true
    @button_print_all.enabled = true
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

  def changed_attributes(update_preview=true)
    @layout.changed_attributes
    self.update_preview if update_preview
  end
  
end
end
