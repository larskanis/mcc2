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
    @combobox_gdi_printer.connect(SEL_COMMAND){
      prname = @combobox_gdi_printer.getItemData(@combobox_gdi_printer.currentItem)
      @layout_file.set_attr_value(S_GDIPRINTER_NAME, prname)
    }
    @button_gdi_printersetup.connect(SEL_COMMAND){ gdi_printersetup_pressed }

    fill_printertype_list
    combobox_printertype_changed
  end

  def combobox_printertype_changed
    deactivate_printer_tabs
    prdesc = @combobox_printertype.getItemData(@combobox_printertype.currentItem)
    @tabbook_printers.childAtIndex(prdesc.tab_idx*2).shown = true

    if @layout_file
      @layout_file.set_attr_value(S_PRINTERTYPE, prdesc.class_name)
      changed_attributes
      send "selected_#{prdesc.class_name}"
    end
    
    @tabbook_printers.recalc
  end

  def selected_GdiPrinter
    begin
      require "win32api4ruby"
      Win32api4ruby::Winspool
    rescue => e
      error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, "Die Windoes-Druckerschnittstelle konnte nicht geladen werden.\nBitte stellen Sie sicher, dass das Gem-Paket win32api4ruby installiert ist.\n\n" + e.to_s, 'Abbruch')
      error_WahlMessage.execute
      
    else
      l = @combobox_gdi_printer
      l.clearItems
      
      flags = Win32api4ruby::Winspool::PRINTER_ENUM_NAME
      name = nil
      level = 4
      infos = Win32api4ruby::Winspool.enum_printers(flags, name, level)
      infos.each{|info|
        l.appendItem(info[:pPrinterName].to_s, info[:pPrinterName].to_s)
      }
      prname = @layout_file.get_attr_value(S_GDIPRINTER_NAME)
      Layout.set_combobox_by_data( l, prname )
    end
  end

  def gdi_printersetup_pressed
    prname = @combobox_gdi_printer.getItemData(@combobox_gdi_printer.currentItem)
    initdata = @layout_file.get_gdiprinter_initdata
    p initdata

    # open setup-dialog
    devmod = Win32api4ruby::Winspool.document_properties( 0, 0, prname, initdata,
        Win32api4ruby::Winspool::DM_PROMPT|Win32api4ruby::Winspool::DM_OUT_BUFFER )
    
    @layout_file.set_gdiprinter_initdata(devmod) if devmod
  end

  def selected_FilePrinter
  end

  def selected_PrinterXID
    selected_GdiPrinter
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

  def printerview_tab_activated
    combobox_printertype_changed
    ensure_datalist_filled
    update_preview
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
