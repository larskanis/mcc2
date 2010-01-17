# -*- coding: UTF-8 -*-

module Mcc2
require 'mcc2/printerview_dlg'

class Printerview < Dialogbox_printerview
  include Fox

  PrinterDescription = Struct.new :human_name, :class_name, :tab_idx
  PrinterDescriptions = [
    PrinterDescription.new( 'Generic-Windows-GDI', 'GdiPrinter', 0),
    PrinterDescription.new( 'Print-to-file', 'FilePrinter', 1),
    PrinterDescription.new( 'XID-440', 'PrinterXID', 2),
  ]
  
  def initialize parent, layout
    @layout = layout
    @parent = parent
    @layout_file = nil

    super(parent)
    @verticalframe_printersetup.reparent parent, nil
    @dialogbox_printerview.close

    @matrix_file.numColumns = 3
    @matrix_gdi.numColumns = 3
    @matrix_xid.numColumns = 3
    @combobox_printertype.connect(SEL_COMMAND){ combobox_printertype_changed }
    @textfield_file_save_as.connect(SEL_COMMAND){
      @layout_file.set_attr_value(S_FILEPRINTER_SAVE_AS, @textfield_file_save_as.text)
      changed_attributes
    }
    # Button für das Auswählen einer Datenquelle an Textfeld knüpfen
    Layout.connect_filebutton_to_textfield( @button_file_save_as, @textfield_file_save_as,
          ["JPEG 24 Bit (*.jpeg)", "Portable Netork Graphics 24 Bit (*.png)", "TIFF (*.tiff)"]
    )

    @spinner_file_dpi.connect(SEL_COMMAND){
      @layout_file.set_attr_value(S_FILEPRINTER_DPI, @spinner_file_dpi.value.to_s)
      changed_attributes
    }
    @combobox_gdi_printer.connect(SEL_COMMAND){ combobox_changed(@combobox_gdi_printer, S_GDIPRINTER_NAME) }
    @button_gdi_printersetup.connect(SEL_COMMAND){ gdi_printersetup_pressed(@combobox_gdi_printer, S_GDIPRINTER_INITDATA) }
    @combobox_xid_printer.connect(SEL_COMMAND){ combobox_changed(@combobox_xid_printer, S_XIDPRINTER_NAME) }
    @button_xid_printersetup.connect(SEL_COMMAND){ gdi_printersetup_pressed(@combobox_xid_printer, S_XIDPRINTER_INITDATA) }

    fill_printertype_list
    combobox_printertype_changed
  end

  def combobox_changed(combobox, attr)
    data = combobox.getItemData(combobox.currentItem)
    @layout_file.set_attr_value(attr, data)
  end

  def combobox_printertype_changed
    deactivate_printer_tabs
    prdesc = @combobox_printertype.getItemData(@combobox_printertype.currentItem)
    @tabbook_printers.childAtIndex(prdesc.tab_idx*2).shown = true

    if @layout_file
      if @layout_file.get_attr_value(S_PRINTERTYPE) != prdesc.class_name
        @layout_file.set_attr_value(S_PRINTERTYPE, prdesc.class_name)
        changed_attributes
      end
      send "selected_#{prdesc.class_name}"
    end
    
    @tabbook_printers.recalc
  end

  def selected_GdiPrinter(combobox=@combobox_gdi_printer, attr=S_GDIPRINTER_NAME)
    begin
      require "win32api4ruby"
      Win32api4ruby::Base.unicode = true
    rescue LoadError, RuntimeError => e
      error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Die Windows-Druckerschnittstelle konnte nicht geladen werden.\nBitte stellen Sie sicher, dass das Gem-Paket win32api4ruby installiert ist.\n\n" + e.to_s, 'Abbruch')
      error_WahlMessage.execute
      
    else
      combobox.clearItems
      
      flags = Win32api4ruby::Winspool::PRINTER_ENUM_NAME
      name = nil
      level = 4
      infos = Win32api4ruby::Winspool.enum_printers(flags, name, level)
      infos.each{|info|
        prname = info[:pPrinterName].to_s_utf8
        combobox.appendItem(prname, prname)
      }
      prname = @layout_file.get_attr_value(attr)
      Layout.set_combobox_by_data( combobox, prname )
    end
  end

  def gdi_printersetup_pressed(combobox, attr)
    if combobox.currentItem && combobox.numItems>0
      prname = combobox.getItemData(combobox.currentItem)
      initdata = @layout_file.get_binary_attr(attr)

      flags = Win32api4ruby::Winspool::DM_PROMPT|Win32api4ruby::Winspool::DM_OUT_BUFFER
      flags |= Win32api4ruby::Winspool::DM_IN_BUFFER if initdata

      # open setup-dialog
      devmod = Win32api4ruby::Winspool.document_properties(0, 0, prname.to_s_win32, initdata, flags)

      @layout_file.set_binary_attr(attr, devmod.to_str) if devmod
    end
  end

  def selected_FilePrinter
  end

  def selected_PrinterXID
    selected_GdiPrinter(@combobox_xid_printer, S_XIDPRINTER_NAME)
  end
  
  def deactivate_printer_tabs
    0.step(@tabbook_printers.numChildren-1, 2){|idx|
      @tabbook_printers.childAtIndex(idx).shown = false
    }
  end

  def fill_printertype_list
    l = @combobox_printertype
    l.clearItems
    PrinterDescriptions.sort{|a,b| a.tab_idx<=>b.tab_idx }.each{|desc|
      l.appendItem(desc.human_name, desc)
    }
  end

  def printerview_tab_activated(active=true)
    combobox_printertype_changed if active
  end

  attr_reader :layout_file
  def layout_file= file
    @layout_file = file
    pd = PrinterDescriptions.find{|d| @layout_file.get_attr_value(S_PRINTERTYPE)==d.class_name }
    Layout.set_combobox_by_data( @combobox_printertype, pd)
    
    @textfield_file_save_as.text = @layout_file.get_attr_value(S_FILEPRINTER_SAVE_AS)
    @spinner_file_dpi.value = @layout_file.get_attr_value(S_FILEPRINTER_DPI).to_i
  end

  def changed_attributes
    @layout.changed_attributes
  end

end
end
