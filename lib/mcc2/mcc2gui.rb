#!/usr/bin/env ruby
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

require "fox16"
require "fox16/colors"
require "fox16/responder"
require "libguib16"

# convert relative image file path to absolute one
# based on dir of this file.
alias loadImage_libguib16 loadImage
def loadImage(file)
  file = File.join(File.dirname(__FILE__), "..", file)
  loadImage_libguib16(file)
end

# die GUI's, alle mit FoxGUI-Builder erstellt
require "mcc2/mcc2_mainwin"      # das Main-GUI
require "mcc2/cc_dialogbox"

require "mcc2/layout"            # das Kartenlayout
require "mcc2/debug_tools"

require "tempfile"

# *****************************************************************************
module Mcc2
  # die Haupklasse des Programms
  class Mcc2Gui < MainWindow
    include Fox

    def initialize(parent, argv)
      @app = parent
      super(parent)
      # Titel des Hauptfensters mit Programmname und Version setzen

      @topwin.title = "mcc2 Version #{Mcc2::VERSION}"

      @mdimenu = FXMDIMenu.new(@topwin, @mdiclient)
      FXMDIWindowButton.new(@menubar, @mdimenu, @mdiclient, FXMDIClient::ID_MDI_MENUWINDOW, LAYOUT_LEFT)
      FXMDIDeleteButton.new(@menubar, @mdiclient, FXMDIClient::ID_MDI_MENUCLOSE, FRAME_RAISED | LAYOUT_RIGHT)
      FXMDIRestoreButton.new(@menubar, @mdiclient, FXMDIClient::ID_MDI_MENURESTORE, FRAME_RAISED | LAYOUT_RIGHT)
      FXMDIMinimizeButton.new(@menubar, @mdiclient, FXMDIClient::ID_MDI_MENUMINIMIZE, FRAME_RAISED | LAYOUT_RIGHT)

      # ......................................................................
      # die Menue-Einträge modifizieren

      @menutitle_datei.text = "&Datei"

      connect_with_accel(@mcmd_new) { new_layout }
      connect_with_accel(@mcmd_open) { open_layout }
      connect_with_accel(@mcmd_close) { close_layout }
      connect_with_accel(@mcmd_save) { save_layout }
      connect_with_accel(@mcmd_save_as) { save_layout(true) }
      connect_with_accel(@mcmd_exit) { @app.stop if can_close? }

      @menutitle_object.text = "Neues &Objekt"

      connect_with_accel(@mcmd_text) { new_object(TEXTOBJECT) }
      connect_with_accel(@mcmd_barcode) { new_object(BARCODEOBJECT) }
      connect_with_accel(@mcmd_picture) { new_object(PICTUREOBJECT) }
      connect_with_accel(@mcmd_box) { new_object(BOXOBJECT) }

      @topwin.width = 1020
      @topwin.height = 748

      # ......................................................................
      @app.addChore {
        argv.each do |arg|
          open_layout(arg)
        end
      }

      @topwin.connect(SEL_CLOSE) { |sender, selector, data|
        can_close? ? 0 : 1
      }

      class << @app
        attr_writer :statusline
        def show_on_statusline(text)
          @statusline.text = text
          @statusline.normalText = text
        end
      end
      @app.statusline = @statusbar.statusLine
      @statusbar.statusLine.textHighlightColor = FXRGB(255, 0, 0)
      @statusbar.statusLine.normalText = ""
    end

    def can_close?
      @mdiclient.each_child { |child|
        res = child.userData.can_close?
        return false unless res
      }
      true
    end

    def connect_with_accel(button, text = nil, &block)
      button.text = text if text
      button.text = button.text.tr("_", "&")
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

    def save_layout(filename_dialog = false)
      child = @mdiclient.activeChild
      if child
        child.userData.store_to_xml(filename_dialog)
      end
    end
    #---------------------------------------------------------------------------------------------------------

    def new_layout
      child = FXMDIChild.new(@mdiclient, "Layout", nil, @mdimenu, 0, 0, 0, 800, 600)
      child.userData = Layout.new(child)
      child.create
      child.show
      child.recalc
      child.setFocus
      @mdiclient.setActiveChild(child)
    end
    #---------------------------------------------------------------------------------------------------------

    def open_layout(filename = nil)
      unless filename && FileTest.exist?(filename)
        filename = FXFileDialog.getOpenFilename(@topwin, "Laden", "./", patterns = "*.xml", initial = 0)
      end
      unless filename.to_s.empty?
        child = FXMDIChild.new(@mdiclient, "Layout", nil, @mdimenu, 0, 0, 0, 800, 600)
        begin
          child.userData = Layout.new(child, filename)
        rescue LayoutFile::Error => e
          FXMessageBox.error(@topwin.app, MBOX_OK, "Fehler beim Laden der Datei", e.to_s)
        else
          child.create
          child.show
          child.recalc
          child.setFocus
          @mdiclient.setActiveChild(child)
        end
      end
    end

    def close_layout
      child = @mdiclient.activeChild
      if child && child.userData.can_close?
        child.close
      end
    end

    def self.run(argv)
      Thread.abort_on_exception = true

      begin
        app = FX::App.new("MCC2", "ComCard-Mcc2")
        Fox::FXToolTip.new(app, Fox::TOOLTIP_PERMANENT)

        w = Mcc2Gui.new(app, argv)
        w.topwin.show(Fox::PLACEMENT_SCREEN)

        app.create
        app.run
      rescue Exception => e
        DebugTools.write_exception("main", e)
        exit(-1)
      end
    end
  end
end
