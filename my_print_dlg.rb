# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end

require 'iconv'

class MyPrintDialogBox < PrintDialogBox

  def initialize(app, child, chip)
    super(app)
    @app = app
    @chip = chip
    @matrix2.numColumns = 3
    @child = child

    # todo im Moment werden in der Liste der zu druckenden Datensätze alle Felder des Datensatzes angezeigt,
    # eigentlichh soll auswählbar sein, welche Felder angezeigt werden sollen, in den graphischen Objekten ist schon ein Feld vorgesehen, welches dieses Verhalten steuern sollen
    # es ist zu überlegen, welche Daten man dort anzeigt
    #~ printlist = xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").collect{|objekt|
      #~ name = objekt.find(GOA_NAME).first.content
    #~ }
    felder = []
    if child.dataman
      @iconlist_data.appendHeader("Datensatz", nil, 60)
      child.dataman.row(0).each{|e| 
        feldname = e[0].to_s
        @iconlist_data.appendHeader(feldname, nil, 100)
        felder << feldname
      }
      big_icon = nil
      mini_icon = nil
      child.dataman.rows.each_with_index{|row, idx|
        @iconlist_data.appendItem([idx + 1, felder.collect{|feld|
          data = row[feld]
          coding = child.layout_file.get_attr_value(S_DATASOURCEENCODING)
          encoding = Iconv.new('UTF-8', coding)
          encoding.iconv(data)
        }.join("\t")].join("\t"),
          big_icon,
          mini_icon,
          row
        )
      }
    end
    
    @label_rows.text = child.dataman.rows.length.to_s
    
    # .............................................................................................
    # alle Aktionen definieren
    
    @button_select_all.connect(SEL_COMMAND){ select_all }
    @button_deselect_all.connect(SEL_COMMAND){ deselect_all }
    @button_print_selected.connect(SEL_COMMAND){ print_selected }
    @button_print_all.connect(SEL_COMMAND){ print_all }
    @button_stop_printing.connect(SEL_COMMAND){ stop_printing }
#    @button_exit.connect(SEL_COMMAND){ peng }
    @iconlist_data.connect(SEL_CHANGED){ preview }
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
    @horizontalframe3.height = 0

  end
 	#---------------------------------------------------------------------------------------------------------
  def textfield_exit(sender, attr_name)
    anz = @child.dataman.rows.length
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
  def preview
    if @checkbutton2.state && !@printing # Vorschau nicht während dem Druck, da es sonst zu Druckfehlern kommt und der Druck länger dauert
      @child.row_nr = @iconlist_data.currentItem
      @iconlist_data.makeItemVisible(@iconlist_data.currentItem)
      @child.draw_preview
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

    layout_file = @child.layout_file
    Thread.new{
      begin
        marked_items.each{|item|
          it = @iconlist_data.findItemByData(item)
          @iconlist_data.makeItemVisible(it)
          notify = true
          @iconlist_data.setFocus
          @iconlist_data.setCurrentItem(it, notify)
          erg = printer.print_card(layout_file, item, @chip)
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


if __FILE__ == $0
  system("ruby mcc2.rb #{ARGV}")
end
