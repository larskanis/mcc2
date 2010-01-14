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


require "rubygems"

require 'fox16'
require 'fox16/colors'
require 'fox16/responder'
require 'libguib16'

# convert relative image file path to absolute one
# based on dir of this file.
alias loadImage_libguib16 loadImage
def loadImage(file)
  file = File.join( File.dirname(__FILE__), '..', file)
  loadImage_libguib16(file)
end

# die GUI's, alle mit FoxGUI-Builder erstellt
require 'mcc2/mcc2_mainwin'      # das Main-GUI 
require 'mcc2/cc_dialogbox.rb'

require 'mcc2/layout'            # das Kartenlayout
require 'mcc2/magstripe'         # Magnetstreifen
require 'mcc2/chipobjekt'              # Chip
require 'mcc2/debug_tools'

require 'ftools'

require "tempfile"

File.makedirs("./logs", true)

# *****************************************************************************
module Mcc2

# die Haupklasse des Programms
class Mcc2Gui < MainWindow
  include Fox

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
      
      connect_with_accel(@mcmd_new){ new_layout }
      connect_with_accel(@mcmd_open){ open_layout }
      connect_with_accel(@mcmd_close){ close_layout }
      connect_with_accel(@mcmd_save){ save_layout }
      connect_with_accel(@mcmd_save_as){ save_layout(true) }
      connect_with_accel(@mcmd_exit){ @app.stop }
      
      @menutitle_object.text = "Neues &Objekt"
      
      connect_with_accel(@mcmd_text){ new_object(TEXTOBJECT) }
      connect_with_accel(@mcmd_barcode){ new_object(BARCODEOBJECT) }
      connect_with_accel(@mcmd_picture){ new_object(PICTUREOBJECT) }
      connect_with_accel(@mcmd_box){ new_object(BOXOBJECT) }
      
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
    button.text = button.text.gsub('_', '&')
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
    child.userData = Layout.new(child)
    child.create
    child.show
    child.recalc
    child.setFocus
    @mdiclient.setActiveChild(child)
  end
	#---------------------------------------------------------------------------------------------------------
  
  def open_layout(filename=nil)
    unless filename && FileTest.exists?(filename)
      fn = FXFileDialog.getOpenFilename(@topwin, 'Laden', './', patterns = '*.xml', initial = 0)
      filename = fn
    end
    unless File.exist?(filename)
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, "Die Datei '#{}' wurde nicht gefunden. Das Layout wird nicht geöffnet.", 'ok')
      return
    end
    child = FXMDIChild.new(@mdiclient, "Layout", nil, nil, 0, 0, 0, 800, 600)
    child.userData = Layout.new(child, filename)
    child.create
    child.show
    child.recalc
    child.setFocus
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

    begin
      app = FX::App.new("MCC2", "ComCard")
      Fox::FXToolTip.new(app, Fox::TOOLTIP_PERMANENT)

      w = Mcc2Gui.new(app, argv)
      w.topwin.show(Fox::PLACEMENT_SCREEN)

      app.create
      app.run
    rescue Exception => e
      file = File.basename(__FILE__, ".rb")
      DebugTools.write_log_file('main', DebugTools.unkown_error_message(e))
      puts(DebugTools.unkown_error_message(e))
      exit -1
    end

  end
end
end
