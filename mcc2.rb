#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-

# *****************************************************************************

# Projekt           : MCC2
# Erstellungsdatum  : 2009-05-07
# Autor             : Kosche/EDV
# Copyright         : (C)2006 by ComCard/EDV
#
# Beschreibung      : Layout- und Druckprogramm
#

# *****************************************************************************


$stdout.sync = true
$stderr.sync = true

basedir = File.dirname(__FILE__)
$: << basedir
$: << 'win32'


# *****************************************************************************
# Require

require "rubygems"

if __FILE__ == $0
  begin
    require 'fox16'
    require 'fox16/colors'
    require 'fox16/responder'
    p "loading fox16"
  rescue LoadError
    p "Error loading fox16 try fox12"
    require 'fox12'
    require 'fox12/colors'
    $enable_fox12_workaround = true
  end
  include Fox
end
  #~ puts ["Name".ljust(30),"Encoding".rjust(20),"Flags".rjust(20),"setwidth".rjust(20),"size".rjust(20),"slant".rjust(20),"weight".rjust(20)].join
  #~ FXFont.listFonts("").each{|font|
    #~ puts [font.face.to_s.ljust(30), font.encoding.to_s.rjust(20),font.flags.to_s.rjust(20),font.setwidth.to_s.rjust(20),font.size.to_s.rjust(20),font.slant.to_s.rjust(20),font.weight.to_s.rjust(20)].join
  #~ }
  
  #~ exit

require 'constants'

require "dl"

# die GUI's, alle mit FoxGUI-Builder erstellt
require 'mcc2_mainwin'      # das Main-GUI 
require 'layout_win.rb'     # die GUI der Kartenlayout-Windows
require 'print_dlg'         # der Print-Dialog

require 'layout'            # das Kartenlayout

require 'my_print_dlg'      # die Ableitung des Print-Dialogs

require 'dataman'           # der Datenmanager
require 'dataman_csv'       # der Datenmanager für CSV-dateien
require 'dataman_database'  # der Datenmanager für Datenbanken

require 'go_attribut'       # die Attribut-Klasse für die grafischen Objekte

require 'graphic_object'    # die Basisklasse für die grafischen Objekte
require 'barcode_object'    # grafische Barcode-Objekte
require 'picture_object'    # grafische Bild-Objekte
require 'text_object'       # grafische Text-Objekte

require 'magstripe'         # Magnetstreifen


require 'printer'           # die Basisklasse für die Printer
require 'card_printer'      # die Basisklasse für alle CardPrinter
require 'printer_xid'       # die XID-Printer-Klasse

require 'page'              # die Klasse, die eine Druckseite einer Karte definiert

require 'xml'               # für die Layout-Struktur

require 'fastercsv'

require 'RMagick'           # für das Erzeugen der Druckbilder
include Magick
require 'rvg/rvg'           # für RMagick die Vektorgraphik-Bibliothek

require "tempfile" 

# die win32api Wrapper laden
require 'Win32API'
#~ include Win32

require 'win32api_base'
#~ require 'win32api_comdlg'
require 'win32api_gdi'
#~ require 'win32api_kernel'
require 'win32api_user'

require 'chipobjekt'              # Chip

require 'cc_dialogbox.rb'


# *****************************************************************************

# die Haupklasse des Programms
class MCC2GUI < MainWindow

  def initialize(parent)
    @app = parent
    super
      # ......................................................................
      # die Menue-Einträge modifizieren
      
      @menutitle_datei.text = "&Datei"
      
      @mcmd_new.text = "&Neu"
      @mcmd_new.connect(SEL_COMMAND){ new_layout }
      #~ @topwin.accelTable.addAccel(fxparseAccel("Ctrl N"), @app, new_layout)
      
      @mcmd_open.text = "&Öffnen"
      @mcmd_open.connect(SEL_COMMAND){ open_layout }
#      @topwin.accelTable.addAccel(fxparseAccel("Ctrl O"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @mcmd_close.text = "Schließ&en"
#      @mcmd_close.connect(SEL_COMMAND){  }

      @mcmd_save.text = "&Speichern"
      @mcmd_save.connect(SEL_COMMAND){ save_layout }
#      @topwin.accelTable.addAccel(fxparseAccel("Ctrl S"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))

      @mcmd_save_as.text = "Speichern &als"
#      @mcmd_save_as.connect(SEL_COMMAND){  }

      @mcmd_exit.text = "&Beenden"
      @mcmd_exit.connect(SEL_COMMAND){ @app.stop }
      @topwin.accelTable.addAccel(fxparseAccel("Alt F4"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @mcmd_druck.text = "Dr&ucken"
      @mcmd_druck.connect(SEL_COMMAND){ print_cards }
#      @topwin.accelTable.addAccel(fxparseAccel("Strg P"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @menutitle_object.text = "&Objekt"
      
      @mcmd_text.connect(SEL_COMMAND){ new_object(TEXTOBJECT) }
      @mcmd_barcode.connect(SEL_COMMAND){ new_object(BARCODEOBJECT) }
      @mcmd_picture.connect(SEL_COMMAND){ new_object(PICTUREOBJECT) }
      
      @topwin.width = 1024
      @topwin.height = 768
      
      # ......................................................................
      @app.addTimeout(1000) { |sender, sel, ptr|
        if ARGV.length > 0
          open_layout(ARGV[0])
        end
      }    
      
  end
	#---------------------------------------------------------------------------------------------------------
  
  def new_object(typ)
    child = @mdiclient.activeChild
    if child
      child.userData.add_object(typ)
    end
  end
	#---------------------------------------------------------------------------------------------------------
  
  def save_layout
    child = @mdiclient.activeChild
    if child
      child.userData.store_to_xml
    end
  end
	#---------------------------------------------------------------------------------------------------------
  
  def new_layout
    child = FXMDIChild.new(@mdiclient, "Layout", nil, nil, 0, 0, 0, 800, 600)
    child.userData = Layout.new(child, @app)
    child.userData.create_xml
    child.create
    child.show
    child.recalc
  end
	#---------------------------------------------------------------------------------------------------------
  
  def open_layout(filename=nil)
    child = FXMDIChild.new(@mdiclient, "Layout", nil, nil, 0, 0, 0, 800, 600)
    child.userData = Layout.new(child, @app)
    child.create
    child.show
    child.recalc
    filename = child.userData.load_from_xml(filename)
    child.close unless filename
  end
	#---------------------------------------------------------------------------------------------------------
  
  def print_cards
    child = @mdiclient.activeChild
    if child
      unless child.userData.get_attr_value(S_DATASOURCE) == ""
        pr_dlg = MyPrintDialogBox.new(@app, child.userData)
        pr_dlg.topwin.show(Fox::PLACEMENT_SCREEN)
        pr_dlg.topwin.execute
      else
        printer = $pr 
        #~ pers_chip = true
        pers_chip = false
        pers_chip ? chip = Chip.new : chip = nil
        printer.print(child.userData, nil, chip)
        chip.close_reader if chip
      end
    end
  end
end

#*****************************************************************************
# Main

if __FILE__==$0

  #~ set_trace_func proc { |event, file, line, id, binding, classname|
    #~ printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  #~ }
  
	require 'libguib16.rb'
  
  app = FX::App.new("MCC2", "ComCard")
    
  $pr = PrinterXID.new(app) # todo, muss später vom Anwender ausgewählt werden
	
	w = MCC2GUI.new(app)
  w.topwin.show(Fox::PLACEMENT_SCREEN)
  
	app.create
	app.run

	exit 6
end

