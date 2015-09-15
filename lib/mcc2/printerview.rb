# -*- coding: UTF-8 -*-

module Mcc2
require 'mcc2/printerview_dlg'

class Printerview < Dialogbox_printerview
  include Fox

  PrinterDescription = Struct.new :human_name, :class_name, :tab_idx
  PrinterDescriptions = [
    PrinterDescription.new( 'normaler Windows-Drucker', 'GdiPrinter', 0),
    PrinterDescription.new( 'als Bild speichern', 'FilePrinter', 1),
    PrinterDescription.new( 'XID-440', 'PrinterXID', 2),
    PrinterDescription.new( 'Zebra', 'PrinterZebra', 3),
    PrinterDescription.new( 'cab Produktionstechnik GmbH', 'PrinterCab', 4),
    PrinterDescription.new( 'EPL-Drucker', 'PrinterEpl', 5),
    PrinterDescription.new( 'CX-320 Direct', 'PrinterCx320Direct', 5),
    PrinterDescription.new( 'CX-320 Spooler', 'PrinterCx320Gdi', 5),
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
    @matrix_zebra.numColumns = 3
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
    @combobox_gdi_printer.connect(SEL_COMMAND){ gdi_combobox_changed(@combobox_gdi_printer, S_GDIPRINTER_NAME, S_GDIPRINTER_INITDATA) }
    @button_gdi_printersetup.connect(SEL_COMMAND){ gdi_printersetup_pressed(@combobox_gdi_printer, S_GDIPRINTER_INITDATA) }
    @combobox_xid_printer.connect(SEL_COMMAND){ gdi_combobox_changed(@combobox_xid_printer, S_XIDPRINTER_NAME, S_XIDPRINTER_INITDATA) }
    @button_xid_printersetup.connect(SEL_COMMAND){ gdi_printersetup_pressed(@combobox_xid_printer, S_XIDPRINTER_INITDATA) }
    @combobox_zebra_printer.connect(SEL_COMMAND){ gdi_combobox_changed(@combobox_zebra_printer, S_ZEBRAPRINTER_NAME, S_ZEBRAPRINTER_INITDATA) }
    @button_zebra_printersetup.connect(SEL_COMMAND){ gdi_printersetup_pressed(@combobox_zebra_printer, S_ZEBRAPRINTER_INITDATA) }

    @button_zebra_reset.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "R") }
    @button_zebra_eject_card.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "MO") }
    @button_zebra_eject_card2.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "ME") }
    @button_zebra_move_contactless.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "MCL") }
    @button_zebra_print_testcard.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "A") }
    @button_zebra_printer_info.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "V") }
    @button_zebra_send.connect(SEL_COMMAND) do
      command = @textfield_zebra_command.text.strip
      if(command.length > 0)
        zebra_send_command(@combobox_zebra_printer, command)
      end
    end
    @textfield_cab_host.connect(SEL_COMMAND){ @layout_file.set_attr_value(S_CABPRINTER_HOST, @textfield_cab_host.text); changed_attributes }
    @spinner_cab_port.connect(SEL_COMMAND){ @layout_file.set_attr_value(S_CABPRINTER_PORT, @spinner_cab_port.value.to_s); changed_attributes }
    @spinner_cab_dpi.connect(SEL_COMMAND){
      @layout_file.set_attr_value(S_CABPRINTER_DPI, @spinner_cab_dpi.value.to_s)
      changed_attributes
    }
    @text_cab_page_commands.connect(SEL_CHANGED){ @layout_file.set_attr_value(S_CABPRINTER_PAGE_COMMANDS, @text_cab_page_commands.text); changed_attributes }
    @button_cab_info.connect(SEL_COMMAND){ cab_send_command("\es\r\n"){|s| s.read(9) } }
    @button_cab_extended_info.connect(SEL_COMMAND){ cab_send_command("\ez\r\n"){|s| s.gets("\r") } }
    @button_cab_self_test.connect(SEL_COMMAND){ cab_send_command("t\r\n") }
    @button_cab_firmware_version.connect(SEL_COMMAND){ cab_send_command("v\r\n"){|s| s.gets("\r") } }
    @button_cab_cancel_jobs.connect(SEL_COMMAND){ cab_send_command("\et\r\n") }

    @textfield_epl_device.connect(SEL_COMMAND){ @layout_file.set_attr_value(S_EPLPRINTER_DEVICE, @textfield_epl_device.text); changed_attributes }
    @text_epl_page_commands.connect(SEL_CHANGED){ @layout_file.set_attr_value(S_EPLPRINTER_PAGE_COMMANDS, @text_epl_page_commands.text); changed_attributes }
    @spinner_epl_dpi.connect(SEL_COMMAND){
      @layout_file.set_attr_value(S_EPLPRINTER_DPI, @spinner_epl_dpi.value.to_s)
      changed_attributes
    }

    fill_printertype_list
    combobox_printertype_changed
  end

  def gdi_combobox_changed(combobox, attr, attr_initdata)
    data = combobox.getItemData(combobox.currentItem)
    @layout_file.set_attr_value(attr, data)
    @layout_file.set_binary_attr(attr_initdata, '')
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
    if_driver_loadable('win32api4ruby', "win32api4ruby", "die Windows-Druckerschnittstelle") do
      Win32api4ruby::Base.unicode = true

      combobox.clearItems

      flags = Win32api4ruby::Winspool::PRINTER_ENUM_NAME
      flags |= Win32api4ruby::Winspool::PRINTER_ENUM_CONNECTIONS
      name = nil
      level = 4
      infos = Win32api4ruby::Winspool.enum_printers(flags, name, level)
      infos.each{|info|
        prname = info[:pPrinterName].to_s_utf8
        combobox.appendItem(prname, prname)
      }
      prname = @layout_file.get_attr_value(attr)
      Layout.set_combobox_by_data( combobox, prname, false )
    end
  end

  def gdi_printersetup_pressed(combobox, attr)
    if combobox.currentItem && combobox.numItems>0
      prname = combobox.getItemData(combobox.currentItem)
      initdata = @layout_file.get_binary_attr(attr)

      flags = Win32api4ruby::Winspool::DM_PROMPT|Win32api4ruby::Winspool::DM_OUT_BUFFER
      flags |= Win32api4ruby::Winspool::DM_IN_BUFFER if initdata

      # open setup-dialog
      begin
        devmod = Win32api4ruby::Winspool.document_properties(nil, nil, prname.to_s_win32, initdata, flags)
      rescue => e
        FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Einrichten des Druckers", e.to_s)
      end
      if devmod
        @layout_file.set_binary_attr(attr, devmod.pointer.read_bytes(devmod.pointer.size))
        changed_attributes
      end
    end
  end

  def zebra_send_command(combobox, command)
    begin
      @textfield_zebra_answer.text = ""

      printer_name = combobox.getItemData(combobox.currentItem)
      printer = Mcc2::Printer::PrinterZebra.new()
      printer.open_handle(printer_name)
      begin
        answer = printer.send_cmd_ex(command).to_s
        if(answer.length == 1 && answer[0] == 6)
          answer = "<ACK>"
        end
        @textfield_zebra_answer.text = answer
      ensure
        printer.close_handle
      end
    rescue => e
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Senden des Kommandos '#{command}' an den Drucker:", "#{e.to_s}\n\n#{e.backtrace.join("\n")}")
    end
  end

  def selected_FilePrinter
  end

  def selected_PrinterXID
    selected_GdiPrinter(@combobox_xid_printer, S_XIDPRINTER_NAME)
  end

  def selected_PrinterZebra
    if_driver_loadable('zebra_dll', 'zebra_dll', "Zebra-Drucker") do
      selected_GdiPrinter(@combobox_zebra_printer, S_ZEBRAPRINTER_NAME)
    end
  end

  def selected_PrinterCab
  end

  def selected_PrinterEpl
  end

  def selected_PrinterCx320Direct
    if_driver_loadable('libcx320', 'libcx320', 'CX320-Drucker') do
    end
  end

  def selected_PrinterCx320Gdi
    if_driver_loadable('libcx320', 'libcx320', 'CX320-Drucker') do
#       selected_GdiPrinter(@combobox_zebra_printer, S_ZEBRAPRINTER_NAME)
    end
  end

  def if_driver_loadable(gem_name, require_name, human_name)
    begin
      gem gem_name
      require require_name
    rescue LoadError, RuntimeError => e
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Laden des Treibers für #{human_name}" , "Der Treiber für #{human_name} konnte nicht geladen werden.\nBitte stellen Sie sicher, dass das Gem-Paket '#{gem_name}' installiert ist.\n\n" + e.to_s)
    else
      yield
    end
  end

  def cab_send_command(data, &block)
    begin
      cab = Mcc2::Printer::PrinterCab.new
      @text_cab_output.text = cab.send_command(@layout_file, data, &block).to_s
    rescue => e
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Senden" , "Das Kommando konnte nicht ausgeführt werden\nBitte stellen Sie sicher, dass die Verbindungsparameter korrekt sind.\n\n" + e.to_s)
    end
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

    @textfield_cab_host.text = @layout_file.get_attr_value(S_CABPRINTER_HOST)
    @spinner_cab_port.value = @layout_file.get_attr_value(S_CABPRINTER_PORT).to_i
    @spinner_cab_dpi.value = @layout_file.get_attr_value(S_CABPRINTER_DPI).to_i
    @text_cab_page_commands.text = @layout_file.get_attr_value(S_CABPRINTER_PAGE_COMMANDS)

    @textfield_epl_device.text = @layout_file.get_attr_value(S_EPLPRINTER_DEVICE)
    @spinner_epl_dpi.value = @layout_file.get_attr_value(S_EPLPRINTER_DPI).to_i
    @text_epl_page_commands.text = @layout_file.get_attr_value(S_EPLPRINTER_PAGE_COMMANDS)
  end

  def changed_attributes
    @layout.changed_attributes
  end

end
end
