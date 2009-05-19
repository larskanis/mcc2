# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class MyPrintDialogBox < PrintDialogBox
  def initialize(app, child)
    super(app)
    @app = app
    @matrix2.numColumns = 3
          
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
    child.dataman.rows.each{|row|
      @iconlist_data.appendItem(felder.collect{|feld|
        row[feld.intern]
      }.join("\t"))
      #~ p row
    }
    
    # .............................................................................................
    # alle Aktionen definieren
    
    @button_deselect_all.connect(SEL_COMMAND){ deselect_all }
    @button_print_selected.connect(SEL_COMMAND){ print_selected }
    @button_print_all.connect(SEL_COMMAND){ print_all }
    @button_stop_printing.connect(SEL_COMMAND){ stop_printing }
    @button_exit.connect(SEL_COMMAND){ peng }
    
    # .............................................................................................
  end
 	# ---------------------------------------------------------------------------------------------------------
  def deselect_all
    @iconlist_data.killSelection
  end
 	# ---------------------------------------------------------------------------------------------------------
  def print_selected
    
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
