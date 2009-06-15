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
  require 'fox16'
  require 'fox16/colors'
  require 'fox16/responder'
  include Fox
end

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
      child.userData.manage_objects(ADD, typ)
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
    if @app # für Tests ohne GUI kann parent und app nil gesetzt werden
      unless filename && FileTest.exists?(filename)
        fn = FXFileDialog.getOpenFilename(@topwin, 'Laden', '.', patterns = '*.XML', initial = 0)
        filename = fn
      end
    end
    unless filename 
      child.close
      return 
    end
    child.userData.load_from_xml(filename)
  end
	#---------------------------------------------------------------------------------------------------------
  
  def print_cards
    child = @mdiclient.activeChild
    if child
      child.userData.print_cards
    else
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Wählen Sie erst ein Layout und dann die Aktion, die Sie ausführen wollen!", 'ok')
      error_WahlMessage.execute
    end
  end
end

#*****************************************************************************
# Main

if __FILE__==$0
  Thread.abort_on_exception = true
  #~ set_trace_func proc { |event, file, line, id, binding, classname|
    #~ printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  #~ }
  
	require 'libguib16.rb'
  
  app = FX::App.new("MCC2", "ComCard")
  FXToolTip.new(app, TOOLTIP_PERMANENT)
    
  $pr = PrinterXID.new(app) # todo, muss später vom Anwender ausgewählt werden
	
	w = MCC2GUI.new(app)
  w.topwin.show(Fox::PLACEMENT_SCREEN)
  
	app.create
	app.run

	exit 6
end

