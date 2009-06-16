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
      child.dataman.row(0).each{|e| 
        feldname = e[0].to_s
        @iconlist_data.appendHeader(feldname, nil, 100)
        felder << feldname
      }
      big_icon = nil
      mini_icon = nil
      child.dataman.rows.each{|row|
        @iconlist_data.appendItem(felder.collect{|feld|
          data = row[feld]
          coding = child.layout_file.get_attr_value(S_DATASOURCEENCODING)
          encoding = Iconv.new('UTF-8', coding)
          encoding.iconv(data)
        }.join("\t"),
          big_icon,
          mini_icon,
          row
        )
      }
    end
    
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
    @child.row_nr = @iconlist_data.currentItem
    @child.draw_card
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
  def print_selected
    disable_all_buttons
    @button_stop_printing.enabled = true
    @printing = true
    printer = $pr 
    anzahl = @iconlist_data.numRows
    begin
      (0..(anzahl-1)).each{|i|
        item = @iconlist_data.getItem(i)
        erg = printer.print(@child, @iconlist_data.getItemData(i), @chip) if @iconlist_data.itemSelected?(i)
        if !erg && !@printing
          # abbrechen, wenn ein Fehler aufgetreten ist
          break 
        end
      }
    rescue ResourceNotFoundError => e
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, e.to_s, 'ok')
      error_WahlMessage.execute
      @printing = false
    end
    @chip.close_reader if @chip
    @printing = false
    enable_all_buttons
    enable_disable_print_select_button
    @button_stop_printing.enabled = false
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
  def print_all
    @button_print_all.enabled = false
    disable_all_buttons
    
    enable_all_buttons
    enable_disable_print_select_button
    @button_stop_printing.enabled = false
    @button_print_all.enabled = true
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
