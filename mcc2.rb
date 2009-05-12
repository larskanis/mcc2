#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-
#*****************************************************************************
# Projekt           : MCC2
# Erstellungsdatum  : 2009-05-07
# Autor             : Kosche/EDV
# Copyright         : (C)2006 by ComCard/EDV
#
# Beschreibung      : Layout- und Druckprogramm
#
#*****************************************************************************

$stdout.sync = true
$stderr.sync = true

basedir = File.dirname(__FILE__)
$: << basedir


#*****************************************************************************
# Require
require "rubygems"


if __FILE__ == $0
  begin
    require 'fox16'
    require 'fox16/colors'
    require 'fox16/responder'
  rescue LoadError
    require 'fox12'
    require 'fox12/colors'
    $enable_fox12_workaround = true
  end
  include Fox
end

require 'constants'

require 'mcc2_mainwin' # die GUI mit FoxGUI-Builder erstellt

require 'layout'         # das Kartenlayout
require 'layout_win.rb'     # der Kartenlayout-Windows

require 'go_attribut'    # die Attribut-Klasse für die grafischen Objekte

require 'graphic_object' # die Basisklasse für die grafischen Objekte
require 'barcode_object' # grafische Barcode-Objekte
require 'picture_object' # grafische Bild-Objekte
require 'text_object'    # grafische Text-Objekte

require 'magstripe'      # Magnetstreifen
require 'chip'           # Chip

require 'ruby_print'     # vorläufig
include Win32

require 'printer'        # die Basisklasse für die Printer
require 'card_printer'   # die Basisklasse für alle CardPrinter
require 'printer_xid'    # die XID-Printer-Klasse

require 'myxml'          # enthält das Layout inklusive aller graphischen Objekte
#require 'myinifile'

require 'RMagick'
include Magick

require 'rvg/rvg'        # für RMagick

$pr = PrinterXID.new # todo, muss später vom Anwender ausgewählt werden

#*****************************************************************************
class MCC2GUI < MainWindow

  def initialize(parent)
    @app = parent
    super
      # ......................................................................
      # die Menue-Einträge modifizieren
      @menutitle_datei.text = "&Datei"
      
      @mcmd_new.text = "&Neu"
#      @mcmd_new.connect(SEL_COMMAND){  }
      #~ @topwin.accelTable.addAccel(fxparseAccel("Ctrl N"), @app, new_layout)
      @mcmd_new.connect(SEL_COMMAND){ new_layout }
      
      @mcmd_open.text = "&Öffnen"
      @mcmd_open.connect(SEL_COMMAND){ open_layout }
#      @topwin.accelTable.addAccel(fxparseAccel("Ctrl O"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @mcmd_close.text = "Schließ&en"
#      @mcmd_close.connect(SEL_COMMAND){  }

      @mcmd_save.text = "&Speichern"
#      @topwin.accelTable.addAccel(fxparseAccel("Ctrl S"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      @mcmd_save.connect(SEL_COMMAND){ save_layout }

      @mcmd_save_as.text = "Speichern &als"
#      @mcmd_save_as.connect(SEL_COMMAND){  }

      @mcmd_exit.text = "&Beenden"
      @mcmd_exit.connect(SEL_COMMAND){ @app.stop }
      @topwin.accelTable.addAccel(fxparseAccel("Alt F4"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @menutitle_object.text = "&Objekt"
      
      @mcmd_text.connect(SEL_COMMAND){ new_object(TEXTOBJECT) }
      
      @mcmd_barcode.connect(SEL_COMMAND){ new_object(BARCODEOBJECT) }
      
      @mcmd_picture.connect(SEL_COMMAND){ new_object(PICTUREOBJECT) }
      
      @topwin.width = 1024
      @topwin.height = 768
      
      # ......................................................................
      
  end
  
	# ---------------------------------------------------------------------------------------------------------
  def new_object(typ)
    child = @mdiclient.activeChild
    if child
      child.userData.add_object(typ)
    end
  end
	# ---------------------------------------------------------------------------------------------------------
  def save_layout
    child = @mdiclient.activeChild
    if child
      child.userData.store_to_xml
    end
  end
	# ---------------------------------------------------------------------------------------------------------
  def new_layout
    child = FXMDIChild.new(@mdiclient, "Layout", nil, nil, 0, 0, 0, 800, 600)
    child.userData = Layout.new(child, @app)
    child.userData.create_xml
    child.create
    child.show
    child.recalc
  end
	# ---------------------------------------------------------------------------------------------------------
  def open_layout
    child = FXMDIChild.new(@mdiclient, "Layout", nil, nil, 0, 0, 0, 800, 600)
    child.userData = Layout.new(child, @app)
    child.create
    child.show
    child.recalc
    filename = child.userData.load_from_xml
    child.close unless filename
  end
  
end
#*****************************************************************************
# Main

if __FILE__==$0

	require 'libguib16.rb'
  app = FX::App.new("MCC2", "ComCard")
	
	w = MCC2GUI.new(app)
  w.topwin.show(Fox::PLACEMENT_SCREEN)
  
	app.create
	app.run

	exit 6
end

