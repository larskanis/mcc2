# -*- coding: UTF-8 -*-

require 'mcc2/thread_event_handler'

module Mcc2
require 'mcc2/dataview_dlg'

class Dataview < Dialogbox_dataview
  include Fox
  include ThreadEventHandler

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
    # .............................................................................................
    @printing = false
    disable_all_buttons
    @button_print_all.enabled = true
    @button_select_all.enabled = true

    @verticalframe_datalist.width = 500
    
    event_handler_setup
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
      
      to_utf8 = Iconv.new('UTF-8', @layout_file.get_attr_value(S_DATASOURCEENCODING))
      first_row = @dataman.headers
      felder = if first_row
        first_row.map{|feldname|
          @iconlist_data.appendHeader(feldname, nil, 100)
          begin
            to_utf8.iconv(feldname)
          rescue => e
            FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Einlesen der Daten", "Fehler beim Einlesen der Daten in der Kopfzeile:\n#{e}")
          end
        }
      else
        []
      end

      rows = @dataman.rows
      if rows
        big_icon = nil
        mini_icon = nil
        rows.each_with_index{|row, idx|
          itemtext = "#{idx+1}\t" + felder.map{|feld|
            data = row[feld]
            begin
              to_utf8.iconv(data)
            rescue => e
              FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Einlesen der Daten", "Fehler beim Einlesen der Daten in der Zeile #{idx+1}:\n#{e}")
            end
          }.join("\t")
          @iconlist_data.appendItem(itemtext, big_icon, mini_icon, row)
        }

        update_preview
        @parent.app.show_on_statusline "#{@dataman.rows.length} Datensätze geladen"
      end
    end
    
  end

  def draw_preview(row, immediately=false)
    @layout.draw_preview_with_row(row, immediately)
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
  def enable_disable_print_select_button(selected=nil)
    if selected==true || (selected.nil? && itemsSelected?)
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
    search_text = @textfield_search.text
    if @old_search_text != search_text
      @search_pos = -1
      @old_search_text = search_text
    end

    first_finding = true
    finding_count = 0
    @iconlist_data.each_with_index{|item, itemidx|
      if item.text =~ /#{search_text}/i
        
        @iconlist_data.selectItem(itemidx)
        finding_count += 1

        if first_finding && @search_pos<itemidx
          @iconlist_data.setCurrentItem(itemidx, true)
          @iconlist_data.makeItemVisible(itemidx)

          @search_pos = itemidx
          first_finding = false
        end
      else
        @iconlist_data.deselectItem(itemidx)
      end
    }
    if first_finding
      @parent.app.show_on_statusline "kein #{"weiterer" if finding_count>0} Datensatz gefunden"
    else
      curr_text = "aktueller Datensatz: #{@search_pos+1}" if @search_pos>=0
      @parent.app.show_on_statusline "#{finding_count} Datensätze gefunden \n- #{curr_text}"
    end
    enable_disable_print_select_button( finding_count>0 )
  end
  #---------------------------------------------------------------------------------------------------------

  def set_label_selected(count=nil)
    unless count
      count = @iconlist_data.inject(0){|s,i| s += i.selected? ? 1 : 0 }
    end
    @parent.app.show_on_statusline "#{count} Datensätze markiert"
  end
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
    disable_all_buttons
    @button_stop_printing.enabled = true
    @printing = true
    printer = @layout_file.build_printer_instance
    
    marked_items = []
    (0 ... @iconlist_data.numRows).map{|i|
      if !only_selected || @iconlist_data.itemSelected?(i)
        marked_items << @iconlist_data.getItemData(i)
      end
    }

    Thread.new{
      begin
        chip = layout_file.build_chip_instance
      
        marked_items.each_with_index{|item, itemidx|
          it = nil
          event_handler_push{
            it = @iconlist_data.findItemByData(item)
            @iconlist_data.makeItemVisible(it)
            @iconlist_data.setFocus
            @iconlist_data.setCurrentItem(it, true)
          }
          
          erg = printer.print_card(layout_file, item, chip)
          
          event_handler_push{
            @parent.app.show_on_statusline "#{itemidx+1} von #{marked_items.length} Datensätzen gedruckt"
            # den aktuellen Datensatz deselektieren, wenn er erfolgreich gedruckt wurde
            @iconlist_data.deselectItem(it) if erg
          }

          if !erg || !@printing
            # abbrechen, wenn ein Fehler aufgetreten ist, oder wenn der Bediener es gefordert hat
            break
          end
        }
      rescue Printer::Base::PrintError => e
        event_handler_push{
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen eines Grafikobjekts", e.to_s)
        }
      rescue Exception => e
        DebugTools::write_log_file('print_card_thread', DebugTools::unkown_error_message(e))
        event_handler_push{
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen des Druckbildes", DebugTools::unkown_error_message(e))
        }
      ensure
        @printing = false
        event_handler_push{
          enable_all_buttons
          enable_disable_print_select_button
          @button_stop_printing.enabled = false
        }
        chip.close_reader if chip
      end # rescue
    }
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
