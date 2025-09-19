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
require "optparse"

# convert relative image file path to absolute one
# based on dir of this file.
alias loadImage_libguib16 loadImage
def loadImage(file)
  file = File.join(File.dirname(__FILE__), "..", file)
  i = loadImage_libguib16(file)
  i.scale($gui_scale * i.width, $gui_scale * i.height)
  i.create
  i
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

    def initialize(parent, gui_scale)
      @app = parent
      @gui_scale = gui_scale
      @xpath_changes = {}

      super(parent)
      # Titel des Hauptfensters mit Programmname und Version setzen

      @topwin.title = "mcc2 Version #{Mcc2::VERSION}"

      @mdimenu = FXMDIMenu.new(@topwin, @mdiclient)
      FXMDIWindowButton.new(@menubar, @mdimenu, @mdiclient, FXMDIClient::ID_MDI_MENUWINDOW, LAYOUT_LEFT)
      @mdititle = FXMenuCommand.new(@menubar, "", target: @mdiclient, selector: FXMDIClient::ID_MDI_MENUMINIMIZE, opts: FRAME_SUNKEN)
      FXMDIDeleteButton.new(@menubar, @mdiclient, FXMDIClient::ID_MDI_MENUCLOSE, FRAME_RAISED | LAYOUT_RIGHT)
      FXMDIRestoreButton.new(@menubar, @mdiclient, FXMDIClient::ID_MDI_MENURESTORE, FRAME_RAISED | LAYOUT_RIGHT)
      FXMDIMinimizeButton.new(@menubar, @mdiclient, FXMDIClient::ID_MDI_MENUMINIMIZE, FRAME_RAISED | LAYOUT_RIGHT)

      @mdiclient.connect(SEL_CHANGED) do |sender, sel, mdichild|
        @mdititle.text = mdichild.title
      end
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
      connect_with_accel(@mcmd_embed) { new_object(EMBEDOBJECT) }

      @topwin.width = (1020 * @gui_scale).to_i
      @topwin.height = (748 * @gui_scale).to_i

      @topwin.connect(SEL_CLOSE) do |sender, selector, data|
        can_close? ? 0 : 1
      end

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
      @mdiclient.each_child do |child|
        res = child.userData.can_close?
        return false unless res
      end
      true
    end

    def connect_with_accel(button, text = nil, &block)
      button.text = text if text
      button.text = button.text.tr("_", "&")
      button.connect(SEL_COMMAND, &block)

      @topwin.accelTable.addAccel(fxparseAccel(button.accelText), block)
    end

    def add_xpath_value(param)
      xpath, value = param.split("~", 2)
      @xpath_changes[xpath] = value
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

    def new_layout(filename = nil, xpath_changes = nil)
      child = FXMDIChild.new(@mdiclient, "Layout", nil, @mdimenu, 0, 0, 0, 800 * @gui_scale, 600 * @gui_scale)
      child.userData = Layout.new(child, @mdititle, filename: filename, xpath_changes: @xpath_changes, new_file: true)
      child.create
      child.show
      child.recalc
      child.setFocus
      @mdiclient.setActiveChild(child)
    end
    #---------------------------------------------------------------------------------------------------------

    def open_layout(filename = nil)
      unless filename
        if child = @mdiclient.activeChild
          dest = child.userData.layout_file.expand_path("%D/")
        end
        filename = FXFileDialog.getOpenFilename(@topwin, "Laden", dest || "./", "*.mcc2,*.xml", 0)
      end
      return if filename.empty?
      unless FileTest.exist?(filename)
        return new_layout(filename, @xpath_changes)
      end
      unless filename.to_s.empty?
        child = FXMDIChild.new(@mdiclient, "Layout", nil, @mdimenu, 0, 0, 0, 800 * @gui_scale, 600 * @gui_scale)
        begin
          child.userData = Layout.new(child, @mdititle, filename: filename, xpath_changes: @xpath_changes, new_file: false)
        rescue LayoutFile::Error => e
          FXMessageBox.error(@topwin.app, MBOX_OK, "Fehler beim Laden der Datei", e.to_s)
        else
          if @topwin.created?
            child.create
            child.show
            child.recalc
            child.setFocus
          end
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

    def self.hidpi_scale(fxapp)
      fxapp.create

      if (s = ENV["FOXSCALE"].to_f) > 0
        s
      elsif fxapp.rootWindow.width >= 3500 && fxapp.rootWindow.height >= 2000
        2.0
      else
        1.0
      end
    end

    def self.enable_hidpi(fxapp)
      scale = hidpi_scale(fxapp)

      fd = fxapp.normalFont.fontDesc
      fd.size *= scale
      fxapp.normalFont.destroy
      fxapp.normalFont.fontDesc = fd
      fxapp.normalFont.create

      scale
    end

    def self.run(argv)
      Thread.abort_on_exception = true

      app = FX::App.new("MCC2", "ComCard-Mcc2")
      Fox::FXToolTip.new(app, Fox::TOOLTIP_PERMANENT)
      $gui_scale = enable_hidpi(app)

      w = Mcc2Gui.new(app, $gui_scale)

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} <layout.mcc2>* [options]"

        opts.on("-x", "--xpath-value XPATH~VALUE", "Replace XML-value on the given xpath", &w.method(:add_xpath_value))
        opts.separator "\tExamples:"
        opts.separator "\t -x //Layout/datasource~mydata.csv"
        opts.separator "\t -x {layout.mcc2}//Layout/fileprinter_save_as~image_%d_%p.png"
      end.parse!(argv)

      begin
        w.topwin.create
        w.topwin.show(Fox::PLACEMENT_SCREEN)

        app.create
        argv.each do |arg|
          w.open_layout(arg)
        end

        app.run
      rescue Exception => e
        DebugTools.write_exception("main", e)
        exit(-1)
      end
    end
  end
end
