#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

# *****************************************************************************

# Projekt           : MCC2
# Erstellungsdatum  : 2009-05-07
# Autor             : Kosche/EDV
# Copyright         : (C)2006 by ComCard/EDV
#
# Beschreibung      : Layout- und Druckprogramm
#

# *****************************************************************************

basedir = File.dirname(__FILE__)
$: << basedir


# *****************************************************************************
# Require

require "rubygems"

require 'fox16'
require 'fox16/colors'
require 'fox16/responder'
include Fox
require 'libguib16'

require 'constants'

require "dl"

# die GUI's, alle mit FoxGUI-Builder erstellt
require 'mcc2_mainwin'      # das Main-GUI 

require 'layout'            # das Kartenlayout

require 'dataman'           # der Datenmanager
require 'dataman_csv'       # der Datenmanager für CSV-dateien
require 'dataman_database'  # der Datenmanager für Datenbanken

require 'go_attribut'       # die Attribut-Klasse für die grafischen Objekte

require 'graphic_object'    # die Basisklasse für die grafischen Objekte
require 'barcode_object'    # grafische Barcode-Objekte
require 'picture_object'    # grafische Bild-Objekte
require 'text_object'       # grafische Text-Objekte

require 'magstripe'         # Magnetstreifen
require 'printer/card_printer'           # die Basis-Printer-Klasse

begin
  require 'printer_xid'       # die XID-Printer-Klasse
rescue LoadError => e
  puts "Loading XID-printer driver failed: #{e}"
end

require 'page'              # die Klasse, die eine Druckseite einer Karte definiert

require 'xml'               # für die Layout-Struktur

require 'fastercsv'

require 'ftools'

require 'RMagick'           # für das Erzeugen der Druckbilder
include Magick
require 'rvg/rvg'           # für RMagick die Vektorgraphik-Bibliothek

require "tempfile" 


require 'chipobjekt'              # Chip

require 'cc_dialogbox.rb'

require 'debug_tools'
include DebugTools


File.makedirs("./logs", true)

class Magick::RVG
  def draw
      raise StandardError, "draw not permitted in nested RVG objects" if @nested
      @canvas ||= new_canvas    # allow drawing over existing canvas
      gc = Utility::GraphicContext.new
      
      # Turn off antialiasing
      gc.text_antialias(false)
      
      add_outermost_primitives(gc)
      pp(self) if ENV['debug_rvg']
      print_gc(gc) if ENV['debug_prim']
      gc.draw(@canvas)
      return @canvas
  end
end

# *****************************************************************************

# die Haupklasse des Programms
class MCC2GUI < MainWindow

  def initialize(parent, argv)
    @app = parent
    super(parent)
      # Titel des Hauptfensters mit Programmname und Version setzen
      
      # Achtung der Text in den nächsten Zeilen ändert sich beim Einchecken 
      # nicht manuell bearbeiten!
      @topwin.title = "mcc2 Version #{ Mcc2::VERSION }"
      
      # ......................................................................
      # die Menue-Einträge modifizieren
      
      @menutitle_datei.text = "&Datei"
      
      connect_with_accel(@mcmd_new, "&Neu"){ new_layout }
      connect_with_accel(@mcmd_open, "&Öffnen"){ open_layout }
      connect_with_accel(@mcmd_close, "&Schließ&en"){ close_layout }
      connect_with_accel(@mcmd_save, "&Speichern"){ save_layout }
      connect_with_accel(@mcmd_save_as, "Speichern &unter"){ save_layout(true) }
      connect_with_accel(@mcmd_exit, "&Beenden"){ @app.stop }
      connect_with_accel(@mcmd_druck, "D&rucken"){ print_cards }
      
      @menutitle_object.text = "Neues &Objekt"
      
      connect_with_accel(@mcmd_text, "&Text"){ new_object(TEXTOBJECT) }
      connect_with_accel(@mcmd_barcode, "&Barcode"){ new_object(BARCODEOBJECT) }
      connect_with_accel(@mcmd_picture, "B&ild"){ new_object(PICTUREOBJECT) }
      
      @topwin.width = 1024
      @topwin.height = 768
      
      # ......................................................................
      @app.addTimeout(1000) { |sender, sel, ptr|
        argv.each do |arg|
          open_layout(arg)
        end
      }    
      
  end

  def connect_with_accel(button, text=nil, &block)
    button.text = text if text
    button.connect(SEL_COMMAND, &block)
    
    # work-a-round:
    # FXPseudoTarget is not correctly marked as used in some fxruby-versions
    # and is therefore GC'ed.
    # @topwin.accelTable.addAccel(fxparseAccel(button.accelText), block)
    tgt = FXPseudoTarget.new
    seldn = FXSEL(SEL_KEYPRESS, 0)
    tgt.pconnect(SEL_KEYPRESS, block)
    @accelTargets ||= []
    @accelTargets << tgt
    @topwin.accelTable.addAccel(fxparseAccel(button.accelText), tgt, seldn)
    # end work-a-round:
  end
  
	#---------------------------------------------------------------------------------------------------------
  
  def new_object(typ)
    child = @mdiclient.activeChild
    if child
      child.userData.add_object(typ)
    end
  end
	#---------------------------------------------------------------------------------------------------------
  
  def save_layout(filename_dialog=false)
    child = @mdiclient.activeChild
    if child
      child.userData.store_to_xml(filename_dialog)
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
    @mdiclient.setActiveChild(child)
  end
	#---------------------------------------------------------------------------------------------------------
  
  def open_layout(filename=nil)
    unless filename && FileTest.exists?(filename)
      fn = FXFileDialog.getOpenFilename(@topwin, 'Laden', '.', patterns = '*.xml', initial = 0)
      filename = fn
    end
    unless File.exist?(filename)
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Die Datei '#{}' wurde nicht gefunden. Das Layout wird nicht geöffnet.", 'ok')
      return
    end
    child = FXMDIChild.new(@mdiclient, "Layout", nil, nil, 0, 0, 0, 800, 600)
    child.userData = Layout.new(child, @app)
    child.create
    child.show
    child.recalc
    child.userData.load_from_xml(filename)

    @mdiclient.setActiveChild(child)
  end

  def close_layout
    child = @mdiclient.activeChild
    if child
      child.close
    end
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

  def self.run(argv)
    Thread.abort_on_exception = true
    #~ set_trace_func proc { |event, file, line, id, binding, classname|
      #~ printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
    #~ }

    begin
      app = FX::App.new("MCC2", "ComCard")
      FXToolTip.new(app, TOOLTIP_PERMANENT)

#       $pr = PrinterXID.new # todo, muss später vom Anwender ausgewählt werden
      $pr = Printer::CardPrinter.new # todo, muss später vom Anwender ausgewählt werden

      w = MCC2GUI.new(app, argv)
      w.topwin.show(Fox::PLACEMENT_SCREEN)

      app.create
      app.run
    rescue Exception => e
      file = File.basename(__FILE__, ".rb")
      DebugTools::write_log_file('main', unkown_error_message(e))
      puts(unkown_error_message(e))
      exit -1
    end

  end
end

