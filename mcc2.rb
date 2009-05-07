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

require 'constants'

require 'mcc2_mainwin' # die GUI mit FoxGUI-Builder erstellt

require 'layout'         # das Kartenlayout

require 'graphic_object' # die Basisklasse für die grafischen Objekte
require 'barcode_object' # grafische Barcode-Objekte
require 'picture_object' # grafische Bild-Objekte
require 'text_object'    # grafische Text-Objekte

require 'magstripe'      # Magnetstreifen
require 'chip'           # Chip

require 'ruby_print'     # vorläufig
include Win32

require 'printer'        # die Basisklasse für die Printer
require 'printer_xid'    # die XID-Printer-Klasse


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
      @topwin.accelTable.addAccel(fxparseAccel("Ctrl N"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @mcmd_open.text = "&Öffnen"
#      @mcmd_open.connect(SEL_COMMAND){  }
#      @topwin.accelTable.addAccel(fxparseAccel("Ctrl O"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      
      @mcmd_close.text = "Schließ&en"
#      @mcmd_close.connect(SEL_COMMAND){  }

      @mcmd_save.text = "&Speichern"
#      @topwin.accelTable.addAccel(fxparseAccel("Ctrl S"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
#      @mcmd_save.connect(SEL_COMMAND){  }

      @mcmd_save_as.text = "Speichern &als"
#      @mcmd_save_as.connect(SEL_COMMAND){  }

      @mcmd_exit.text = "&Beenden"
      @mcmd_exit.connect(SEL_COMMAND){ @app.stop }
      @topwin.accelTable.addAccel(fxparseAccel("Alt F4"), @app, FXSEL(SEL_COMMAND, FXApp::ID_QUIT))
      # ......................................................................
      
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

