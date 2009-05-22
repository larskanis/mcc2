# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class MyPrintDialogBox < PrintDialogBox
  def initialize(app, child)
    super(app)
    @app = app
    @matrix2.numColumns = 3
    @child = child
          
    #~ printlist = xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").collect{|objekt|
      #~ name = objekt.find(GOA_NAME).first.content
    #~ }
    felder = []
    child.dataman.row(0).each{|e| 
      #~ p e[0].to_s
      feldname = e[0].to_s
      @iconlist_data.appendHeader(feldname, nil, 30)
      felder << feldname
    }
    big_icon = nil
    mini_icon = nil
    child.dataman.rows.each{|row|
      @iconlist_data.appendItem(felder.collect{|feld|
        row[feld.intern]
      }.join("\t"),
        big_icon,
        mini_icon,
        row
      )
      #~ p row
    }
    
    # .............................................................................................
    # alle Aktionen definieren
    
    @button_deselect_all.connect(SEL_COMMAND){ deselect_all }
    @button_print_selected.connect(SEL_COMMAND){ print_selected }
    @button_print_all.connect(SEL_COMMAND){ print_all }
    @button_stop_printing.connect(SEL_COMMAND){ stop_printing }
    @button_exit.connect(SEL_COMMAND){ peng }
    @iconlist_data.connect(SEL_CHANGED){ preview }
    # .............................................................................................
  end
 	# ---------------------------------------------------------------------------------------------------------
  def preview
    @child.row_nr = @iconlist_data.currentItem
    @child.draw_card
  end
 	# ---------------------------------------------------------------------------------------------------------
  def deselect_all
    @iconlist_data.killSelection
  end
 	# ---------------------------------------------------------------------------------------------------------
  def print_selected
    printer = $pr 
    anzahl = @iconlist_data.numRows
    (0..(anzahl-1)).each{|i|
      item = @iconlist_data.getItem(i)
      printer.print(@child, @iconlist_data.getItemData(i)) if @iconlist_data.itemSelected?(i)
    }
  end
 	# ---------------------------------------------------------------------------------------------------------
  def print_all
    
  end
 	# ---------------------------------------------------------------------------------------------------------
  def stop_printing
    
  end
 	# ---------------------------------------------------------------------------------------------------------
  
end


if __FILE__ == $0
  system("ruby mcc2.rb #{ARGV}")
end
