require "json"
require "mcc2/printerview_dlg"

module Mcc2
  class Printerview < Dialogbox_printerview
    include Fox

    PrinterDescription = Struct.new :human_name, :class_name, :tab_idx
    PrinterDescriptions = [
      PrinterDescription.new("normaler Windows-Drucker", "GdiPrinter", 0),
      PrinterDescription.new("als Bild speichern", "FilePrinter", 1),
      PrinterDescription.new("Linux-CUPS", "LinuxCupsPrinter", 2),
      PrinterDescription.new("XID-440", "PrinterXID", 3),
      PrinterDescription.new("Zebra", "PrinterZebra", 4),
      PrinterDescription.new("cab Produktionstechnik GmbH", "PrinterCab", 5),
      PrinterDescription.new("EPL-Drucker", "PrinterEpl", 6),
      PrinterDescription.new("CX-320 Direct", "PrinterCx320Direct", 7),
      PrinterDescription.new("TSC TTP 346M PRO", "PrinterTTP34x", 8),
      PrinterDescription.new("CX-320 Spooler", "PrinterCx320Gdi", 0)
    ]

    def initialize parent, layout
      @layout = layout
      @parent = parent
      @layout_file = nil

      super(parent)
      @verticalframe_printersetup.reparent parent, nil
      @dialogbox_printerview.close

      @combobox_printertype.connect(SEL_COMMAND) { combobox_printertype_changed }
      @textfield_file_save_as.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_FILEPRINTER_SAVE_AS, @textfield_file_save_as.text)

      }
      # Button für das Auswählen einer Datenquelle an Textfeld knüpfen
      @layout.connect_filebutton_to_textfield(@button_file_save_as, @textfield_file_save_as,
        filepatterns: ["JPEG 24 Bit (*.jpeg)", "Portable Netork Graphics 24 Bit (*.png)", "TIFF (*.tiff)"])

      @spinner_file_dpi.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_FILEPRINTER_DPI, @spinner_file_dpi.value.to_s)
      }
      @combobox_linux_printer.connect(SEL_COMMAND) do
        prname = @combobox_linux_printer.getItemData(@combobox_linux_printer.currentItem)
        @label_linux_printer_state.text = "Status: #{Cups::Printer.get_destination(prname).state}"
        changed_attributes if @layout_file.set_attr_value(S_LINUX_CUPS_PRINTER, prname)
      end
      @spinner_linux_cups_dpi.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_LINUX_CUPS_DPI, @spinner_linux_cups_dpi.value.to_s)
      }
      @combobox_gdi_printer.connect(SEL_COMMAND) { gdi_combobox_changed(@combobox_gdi_printer, S_GDIPRINTER_NAME, S_GDIPRINTER_INITDATA) }
      @button_gdi_printersetup.connect(SEL_COMMAND) { gdi_printersetup_pressed(@combobox_gdi_printer, S_GDIPRINTER_INITDATA) }
      @combobox_xid_printer.connect(SEL_COMMAND) { gdi_combobox_changed(@combobox_xid_printer, S_XIDPRINTER_NAME, S_XIDPRINTER_INITDATA) }
      @button_xid_printersetup.connect(SEL_COMMAND) { gdi_printersetup_pressed(@combobox_xid_printer, S_XIDPRINTER_INITDATA) }
      @combobox_zebra_printer.connect(SEL_COMMAND) { gdi_combobox_changed(@combobox_zebra_printer, S_ZEBRAPRINTER_NAME, S_ZEBRAPRINTER_INITDATA) }
      @button_zebra_printersetup.connect(SEL_COMMAND) { gdi_printersetup_pressed(@combobox_zebra_printer, S_ZEBRAPRINTER_INITDATA) }

      @button_zebra_reset.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "R") }
      @button_zebra_eject_card.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "MO") }
      @button_zebra_eject_card2.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "ME") }
      @button_zebra_move_contactless.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "MCL") }
      @button_zebra_print_testcard.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "A") }
      @button_zebra_printer_info.connect(SEL_COMMAND) { zebra_send_command(@combobox_zebra_printer, "V") }
      @button_zebra_send.connect(SEL_COMMAND) do
        command = @textfield_zebra_command.text.strip
        if command.length > 0
          zebra_send_command(@combobox_zebra_printer, command)
        end
      end
      @textfield_cab_host.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_CABPRINTER_HOST, @textfield_cab_host.text)
      }
      @spinner_cab_port.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_CABPRINTER_PORT, @spinner_cab_port.value.to_s)
      }
      @spinner_cab_dpi.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_CABPRINTER_DPI, @spinner_cab_dpi.value.to_s)
      }
      @text_cab_page_commands.connect(SEL_CHANGED) {
        changed_attributes if @layout_file.set_attr_value(S_CABPRINTER_PAGE_COMMANDS, @text_cab_page_commands.text)
      }
      @button_cab_info.connect(SEL_COMMAND) { cab_send_command("\es\r\n") { |s| s.read(9) } }
      @button_cab_extended_info.connect(SEL_COMMAND) { cab_send_command("\ez\r\n") { |s| s.gets("\r") } }
      @button_cab_self_test.connect(SEL_COMMAND) { cab_send_command("t\r\n") }
      @button_cab_firmware_version.connect(SEL_COMMAND) { cab_send_command("v\r\n") { |s| s.gets("\r") } }
      @button_cab_cancel_jobs.connect(SEL_COMMAND) { cab_send_command("\et\r\n") }

      @textfield_epl_device.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_EPLPRINTER_DEVICE, @textfield_epl_device.text)
      }
      @text_epl_page_commands.connect(SEL_CHANGED) {
        changed_attributes if @layout_file.set_attr_value(S_EPLPRINTER_PAGE_COMMANDS, @text_epl_page_commands.text)
      }
      @spinner_epl_dpi.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_EPLPRINTER_DPI, @spinner_epl_dpi.value.to_s)
      }


      @textfield_ttp343_device.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_TTP34XPRINTER_DEVICE, @textfield_ttp343_device.text)
      }
      @text_ttp343_page_commands.connect(SEL_CHANGED) {
        changed_attributes if @layout_file.set_attr_value(S_TTP34XPRINTER_PAGE_COMMANDS, @text_ttp343_page_commands.text)
      }
      @spinner_ttp343_dpi.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_TTP34XPRINTER_DPI, @spinner_ttp343_dpi.value.to_s)
      }


      @combobox_cx320_driver.appendItem("LIBUSB", "CX320_USB")
      @combobox_cx320_driver.appendItem("DLL", "CX320_DLL")
      @combobox_cx320_driver.appendItem("Simulation", "CX320_SIMU")
      @combobox_cx320_driver.connect(SEL_COMMAND) { combobox_changed(@combobox_cx320_driver, S_CX320_DRIVER) }
      @spinner_cx320_printer_nr.connect(SEL_COMMAND) {
        changed_attributes if @layout_file.set_attr_value(S_CX320_PRINTER_NR, @spinner_cx320_printer_nr.value.to_s)
      }
      @combobox_cx320_parallel_print.appendItem("Ein", "on")
      @combobox_cx320_parallel_print.appendItem("Aus", "off")
      @combobox_cx320_parallel_print.appendItem("ab zweiter Karte", "second_card")
      @combobox_cx320_parallel_print.connect(SEL_COMMAND) { combobox_changed(@combobox_cx320_parallel_print, S_CX320_PARALLEL_PRINT) }

      @button_cx320_reset.connect(SEL_COMMAND) { cx320_run_command { |printer, dev| dev.rezero_unit } }
      @button_cx320_move_to_0.connect(SEL_COMMAND) { cx320_move_to(0) }
      @button_cx320_move_to_2.connect(SEL_COMMAND) { cx320_move_to(2) }
      @button_cx320_move_to_4.connect(SEL_COMMAND) { cx320_move_to(4) }

      @button_cx320_read_config.connect(SEL_COMMAND) { cx320_read_config }
      @button_cx320_write_config.connect(SEL_COMMAND) { cx320_write_config }
      @button_cx320_set_defaults.connect(SEL_COMMAND) { cx320_set_defaults }

      fill_printertype_list
      combobox_printertype_changed

      FXSeparator.new(@verticalframe_linux_cups)
      @linux_cups_options = []
      FXMatrix.new(@verticalframe_linux_cups, opts: MATRIX_BY_COLUMNS|LAYOUT_FILL|FRAME_GROOVE, vSpacing: 0, hSpacing: 0) do |mat|
        mat.numColumns = 2
        10.times do
          combo_val = nil
          combo_key = FXComboBox.new(mat, 0, nil, 0,
                    COMBOBOX_NO_REPLACE|FRAME_SUNKEN|LAYOUT_SIDE_TOP|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN) do |combo|
            combo.editable = true
            # names = JSON.parse( app.reg.readStringEntry('login', 'usernames', '[]') )
            combo.numVisible = 10
            combo.connect(SEL_COMMAND) do
              combo_val.clearItems
              key = combo.getItemData(combo.currentItem)
              if key
                cs = Cups.constants
                vals = cs.select { |c| c.to_s.start_with?("#{key}_") }
                vals = vals.reject { |c| c.end_with?("_SUPPORTED") }
                cvals = vals.map { |c| [c, Cups.const_get(c)] }
                cvals.each do |name, name_val|
                  combo_val.appendItem("#{name}=#{name_val}", name_val)
                end
              end
              linux_cups_combobox_changed
            end
          end
          combo_val = FXComboBox.new(mat, 0, nil, 0,
                    COMBOBOX_NO_REPLACE|FRAME_SUNKEN|LAYOUT_SIDE_TOP|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN) do |combo|
            combo.editable = true
            # names = JSON.parse( app.reg.readStringEntry('login', 'usernames', '[]') )
            combo.numVisible = 10
            combo.connect(SEL_COMMAND) do
              linux_cups_combobox_changed
            end
          end
          @linux_cups_options << [combo_key, combo_val]
        end
      end
    end

    def linux_cups_combobox_changed
      opts = @linux_cups_options.each.with_object({}) do |(combo_key, combo_val), h|
        text = combo_val.text
        h[combo_key.text] = text unless text.empty?
      end
      changed_attributes if @layout_file.set_attr_value(S_LINUX_CUPS_OPTIONS, JSON.dump(opts))
    end

    def linux_cups_combobox_set
      json_str = @layout_file.get_attr_value(S_LINUX_CUPS_OPTIONS)
      hash = JSON.parse(json_str).to_a
      @linux_cups_options.each_with_index do |(chk, chv), idx|
        chk.text = hash[idx]&.[](0) || ""
        chv.text = hash[idx]&.[](1) || ""
      end
    end

    def combobox_changed(combobox, attr)
      data = combobox.getItemData(combobox.currentItem)
      if @layout_file.set_attr_value(attr, data)
        changed_attributes
      end
    end

    def gdi_combobox_changed(combobox, attr, attr_initdata)
      data = combobox.getItemData(combobox.currentItem)
      @layout_file.set_attr_value(attr, data)
      @layout_file.set_binary_attr(attr_initdata, "")
    end

    def combobox_printertype_changed
      deactivate_printer_tabs
      prdesc = @combobox_printertype.getItemData(@combobox_printertype.currentItem)
      @tabbook_printers.childAtIndex(prdesc.tab_idx * 2).shown = true

      if @layout_file
        if @layout_file.set_attr_value(S_PRINTERTYPE, prdesc.class_name)
          changed_attributes
        end
        send :"selected_#{prdesc.class_name}"
      end

      @tabbook_printers.recalc
    end

    def selected_GdiPrinter(combobox = @combobox_gdi_printer, attr = S_GDIPRINTER_NAME)
      if_driver_loadable("win32api4ruby", "win32api4ruby", "die Windows-Druckerschnittstelle", verify_code: "Win32api4ruby::Winspool") do
        Win32api4ruby::Base.unicode = true

        combobox.clearItems

        flags = Win32api4ruby::Winspool::PRINTER_ENUM_NAME
        flags |= Win32api4ruby::Winspool::PRINTER_ENUM_CONNECTIONS
        name = nil
        level = 4
        infos = Win32api4ruby::Winspool.enum_printers(flags, name, level)
        infos.each { |info|
          prname = info[:pPrinterName].to_s_utf8
          combobox.appendItem(prname, prname)
        }
        prname = @layout_file.get_attr_value(attr)
        Layout.set_combobox_by_data(combobox, prname, false)
      end
    end

    def gdi_printersetup_pressed(combobox, attr)
      if combobox.currentItem && combobox.numItems > 0
        prname = combobox.getItemData(combobox.currentItem)
        initdata = @layout_file.get_binary_attr(attr)

        flags = Win32api4ruby::Winspool::DM_PROMPT | Win32api4ruby::Winspool::DM_OUT_BUFFER
        flags |= Win32api4ruby::Winspool::DM_IN_BUFFER if initdata

        # open setup-dialog
        begin
          devmod = Win32api4ruby::Winspool.document_properties(nil, nil, prname.to_s_win32, initdata, flags)
        rescue => e
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Einrichten des Druckers", e.to_s)
        end
        if devmod
          changed_attributes if @layout_file.set_binary_attr(attr, devmod.pointer.read_bytes(devmod.pointer.size))
        end
      end
    end

    def zebra_send_command(combobox, command)
      @textfield_zebra_answer.text = ""

      printer_name = combobox.getItemData(combobox.currentItem)
      printer = Mcc2::Printer::PrinterZebra.new
      printer.open_handle(printer_name)
      begin
        answer = printer.send_cmd_ex(command).to_s
        if answer.length == 1 && answer[0] == 6
          answer = "<ACK>"
        end
        @textfield_zebra_answer.text = answer
      ensure
        printer.close_handle
      end
    rescue => e
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Senden des Kommandos '#{command}' an den Drucker:", "#{e}\n\n#{e.backtrace.join("\n")}")
    end

    def selected_FilePrinter
    end

    def selected_LinuxCupsPrinter
      if_driver_loadable("ffi-cups", "ffi-cups", "die Linux-Druckerschnittstelle (also libcups2)") do
        combobox = @combobox_linux_printer
        combobox.clearItems

        printers = Cups::Printer.get_destinations
        printers.each { |printer|
          prname = printer.name
          combobox.appendItem(prname, prname)
        }
        prname = @layout_file.get_attr_value(S_LINUX_CUPS_PRINTER)
        Layout.set_combobox_by_data(combobox, prname, false)

        cs = Cups.constants.each.with_object({}){|c,h| h[c] = true }
        keys = cs.select { |c, _| cs["#{c}_SUPPORTED".to_sym] }.keys
        cvals = keys.map { |c| [c, Cups.const_get(c)] }
        @linux_cups_options.each do |combo_key, combo_val|
          combo_key.clearItems
          combo_key.appendItem("", nil)
          cvals.each do |name, val|
            combo_key.appendItem(val, name)
          end
        end
        @spinner_linux_cups_dpi.value = @layout_file.get_attr_value(S_LINUX_CUPS_DPI).to_i
        linux_cups_combobox_set
      end
    end

    def selected_PrinterXID
      selected_GdiPrinter(@combobox_xid_printer, S_XIDPRINTER_NAME)
    end

    def selected_PrinterZebra
      if_driver_loadable("zebra_dll", "zebra_dll", "Zebra-Drucker") do
        selected_GdiPrinter(@combobox_zebra_printer, S_ZEBRAPRINTER_NAME)
      end
    end

    def selected_PrinterCab
    end

    def selected_PrinterEpl
    end

    def selected_PrinterTTP34x; end

    def selected_PrinterCx320Direct
      if_driver_loadable("libcx320", "libcx320", "CX320-Drucker") do
        cx320_update_config_widgets
      end
    end

    def selected_PrinterCx320Gdi
      if_driver_loadable("libcx320", "libcx320", "CX320-Drucker") do
        #       selected_GdiPrinter(@combobox_zebra_printer, S_ZEBRAPRINTER_NAME)
      end
    end

    def if_driver_loadable(gem_name, require_name, human_name, verify_code: nil)
      gem gem_name
      require require_name
      eval(verify_code) if verify_code
    rescue LoadError, RuntimeError => e
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Laden des Treibers für #{human_name}", "Der Treiber für #{human_name} konnte nicht geladen werden.\nBitte stellen Sie sicher, dass das Gem-Paket '#{gem_name}' installiert ist.\n\n#{e.to_s.force_encoding("UTF-8")}")
    else
      yield
    end

    def cab_send_command(data, &)
      cab = Mcc2::Printer::PrinterCab.new
      @text_cab_output.text = cab.send_command(@layout_file, data, &).to_s
    rescue => e
      DebugTools.write_exception("cab_send_command", e)
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Senden", "Das Kommando konnte nicht ausgeführt werden\nBitte stellen Sie sicher, dass die Verbindungsparameter korrekt sind.\n\n" + e.to_s)
    end

    def cx320_run_command(&block)
      printer = Mcc2::Printer::PrinterCx320Direct.new
      printer.layout_file = @layout_file
      printer.run_command do |dev|
        yield printer, dev
      end
    rescue => e
      DebugTools.write_exception("cx320_run_command", e)
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Senden", "Das Kommando konnte nicht ausgeführt werden.\n\n#{e}")
    end

    def cx320_move_to(pos)
      cx320_run_command do |printer, dev|
        dev.move_card(pos)
      rescue LibCX320::ErrorHandling::CommandSequenceError
        dev.load_card(pos)
      end
    end

    def cx320_fill_config(attrs)
      attr_checked = {}
      if c = @packer_cx320_config.children.first
        c.children.each do |w|
          attr, checkbutton = w.userData
          next unless attr

          attr_checked[attr.name.to_s] = checkbutton.checked? if attr.writeable
        end
      end

      @packer_cx320_config.children.each do |ch|
        @packer_cx320_config.removeChild(ch)
      end

      Fox::FXMatrix.new(@packer_cx320_config, 2, Fox::MATRIX_BY_COLUMNS) do |matrix|
        attrs.each do |attr, checked|
          if attr.writeable
            # READ/WRITE parameter

            checkbutton = FXCheckButton.new(matrix, attr.name.to_s)
            checked = attr_checked[attr.name.to_s] if checked.nil?
            checkbutton.setCheck(checked.nil? ? true : checked)
            checkbutton.connect(SEL_COMMAND) { cx320_config_field_changed }

            w = case attr.typ
            when :int
              w = FXSpinner.new(matrix, 19)
              w.range = attr.params
              w.value = attr.value if attr.value
              w.connect(SEL_COMMAND) { cx320_config_field_changed }
              w
            when :set
              w = FXComboBox.new(matrix, 19)
              attr.params.each do |k, v|
                w.appendItem((k == attr.default) ? "#{v} (default)" : v, k)
              end
              idx = -1
              if w.find { |text, data|
                   idx += 1
                   data == attr.value
                 }
                w.setCurrentItem(idx)
              end
              w.numVisible = [attr.params.length, 10].min
              w.editable = false
              w.connect(SEL_COMMAND) { cx320_config_field_changed }
              w
            when :ascii
              w = FXTextField.new(matrix, attr.params)
              w.text = attr.value if attr.value
              w.connect(SEL_COMMAND) { cx320_config_field_changed }
              w
            end

            w.userData = [attr, checkbutton]
          else
            # READ-only parameter

            FXLabel.new(matrix, attr.name.to_s)

            value = case attr.typ
            when :set then attr.params[attr.value]
            else attr.value.to_s
            end

            w = FXLabel.new(matrix, value)
            w.userData = attr
          end
        end

        if matrix.parent.created?
          matrix.create
          matrix.show
          matrix.recalc
        end
      end
    end

    def cx320_config_field_changed
      config = JSON.parse(@layout_file.get_attr_value(S_CX320_CONFIG))

      hash = {}
      @packer_cx320_config.children.first.children.each do |w|
        attr, checkbutton = w.userData
        next unless attr

        if attr.writeable && checkbutton.checked?
          # READ/WRITE parameter

          value = case attr.typ
          when :int
            w.value
          when :set
            w.getItemData(w.currentItem)
          when :ascii
            w.text
          end
          hash[attr.name.to_s] = value
        end
      end

      if hash != config
        changed_attributes if @layout_file.set_attr_value(S_CX320_CONFIG, hash.to_json)
      end
    end

    def cx320_read_config
      cx320_run_command do |printer, dev|
        attrs = dev.mode_sense(:print) + dev.mode_sense(:ink) + dev.mode_sense(:mag) + dev.log_sense(:log)
        cx320_fill_config(attrs.map { |a| [a, true] })
        cx320_config_field_changed
      end
    end

    def cx320_write_config
      cx320_run_command do |printer, dev|
        cx320_config_field_changed
        config = JSON.parse(@layout_file.get_attr_value(S_CX320_CONFIG))
        printer.write_config(config, dev)
      end
    end

    def cx320_set_defaults
      if @layout_file.set_attr_value(S_CX320_CONFIG, "{}")
        cx320_update_config_widgets
        changed_attributes
      end
    end

    def deactivate_printer_tabs
      0.step(@tabbook_printers.numChildren - 1, 2) { |idx|
        @tabbook_printers.childAtIndex(idx).shown = false
      }
    end

    def fill_printertype_list
      l = @combobox_printertype
      l.clearItems
      PrinterDescriptions.sort_by(&:tab_idx).each { |desc|
        l.appendItem(desc.human_name, desc)
      }
    end

    def printerview_tab_activated(active = true)
      combobox_printertype_changed if active
    end

    attr_reader :layout_file
    def layout_file= file
      @layout_file = file
      pd = PrinterDescriptions.find { |d| @layout_file.get_attr_value(S_PRINTERTYPE) == d.class_name }
      Layout.set_combobox_by_data(@combobox_printertype, pd)

      @textfield_file_save_as.text = @layout_file.get_attr_value(S_FILEPRINTER_SAVE_AS)
      @spinner_file_dpi.value = @layout_file.get_attr_value(S_FILEPRINTER_DPI).to_i

      @textfield_cab_host.text = @layout_file.get_attr_value(S_CABPRINTER_HOST)
      @spinner_cab_port.value = @layout_file.get_attr_value(S_CABPRINTER_PORT).to_i
      @spinner_cab_dpi.value = @layout_file.get_attr_value(S_CABPRINTER_DPI).to_i
      @text_cab_page_commands.text = @layout_file.get_attr_value(S_CABPRINTER_PAGE_COMMANDS)

      @textfield_epl_device.text = @layout_file.get_attr_value(S_EPLPRINTER_DEVICE)
      @spinner_epl_dpi.value = @layout_file.get_attr_value(S_EPLPRINTER_DPI).to_i
      @text_epl_page_commands.text = @layout_file.get_attr_value(S_EPLPRINTER_PAGE_COMMANDS)

      # TSC TTP 343M Pro
      @textfield_ttp343_device.text = @layout_file.get_attr_value(S_TTP34XPRINTER_DEVICE)
      @spinner_ttp343_dpi.value = @layout_file.get_attr_value(S_TTP34XPRINTER_DPI).to_i
      @text_ttp343_page_commands.text = @layout_file.get_attr_value(S_TTP34XPRINTER_PAGE_COMMANDS)

      Layout.set_combobox_by_data(@combobox_cx320_driver, @layout_file.get_attr_value(S_CX320_DRIVER))
      @spinner_cx320_printer_nr.value = @layout_file.get_attr_value(S_CX320_PRINTER_NR).to_i
      Layout.set_combobox_by_data(@combobox_cx320_parallel_print, @layout_file.get_attr_value(S_CX320_PARALLEL_PRINT))

      if pd == "PrinterCx320Direct"
        cx320_update_config_widgets
      end
    end

    def cx320_update_config_widgets
      attrs = LibCX320::CX320.mode_sense_attrs(:print) +
        LibCX320::CX320.mode_sense_attrs(:ink) +
        LibCX320::CX320.mode_sense_attrs(:mag) +
        LibCX320::CX320.log_sense_attrs(:log)
      config = JSON.parse(@layout_file.get_attr_value(S_CX320_CONFIG))
      attrs = attrs.map do |attr|
        if value = config[attr.name.to_s]
          attr.value = value
          checked = true
        else
          attr.value = attr.default
          checked = false
        end
        [attr, checked]
      end
      cx320_fill_config(attrs)
    end

    def changed_attributes
      @layout.changed_attributes
    end
  end
end
