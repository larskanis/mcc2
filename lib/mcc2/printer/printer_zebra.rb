require "win32api4ruby"
require "zebra_dll"
require "mcc2/printer/gdi_card_printer"			# die Basisklasse für alle CardPrinter

module Mcc2
  module Printer
    # Diese Klasse definiert einen Zebra-Drucker.
    class PrinterZebra < GdiCardPrinter
      attr_accessor :name

      def initialize
        super
      end

      def device_name
        layout_file.get_attr_value(S_ZEBRAPRINTER_NAME)
      end

      def device_initdata
        layout_file.get_binary_attr(S_ZEBRAPRINTER_INITDATA)
      end

      def move_to_reject_box
        if @type &&
            @type == 420 ||
            @type == 430 ||
            @type == 520 ||
            @type == 720
          # Bei Druckern mit Ausschuss-Fach, Karte in Ausschuss-Fach
          # TODO geht noch nicht richtig, es werden 2 Karten in das Ausschuss-Fach transportiert
          send_command("MRB", "Karte in Ausschuss-Fach")
        else
          # Bei Druckern ohne Ausschuss-Fach, Karte einfach auswerfen
          send_command("MO", "Karte auswerfen (Ausschuss)")
        end
      end

      def print_card(layout_file, row, chip)
        # Wird für Chip-Perso benötigt
        @layout_file = layout_file
        @chip = chip

        # Warte, bis Durck der vorherigen Karte beendet ist.
        st = Time.now
        begin
          puts "Zebra-Drucker: #{send_command_ex("V", "Firmware-Version ermitteln")}"
        rescue ZebraException => e
          raise if Time.now - st > 30
          sleep 1
          retry
        end

        if chip
          send_command("MCL", "Karte zum Kontaktlos-Leser fahren")
          begin
            # Kartenpersonalisierung
            chip.pers_card(layout_file, row)
          rescue => e
            puts "Fehler bei Chip-Personalisierung: #{e} #{e.class} #{e.backtrace.join("\n")}"
            begin
              move_to_reject_box
            rescue => e1
              raise("Fehler bei Chip-Personalisierung, Karte ausgeschleust: #{e}\nFehler beim Ausschleusen: #{e1}")
            end
            raise("Fehler bei Chip-Personalisierung, Karte ausgeschleust: #{e}")
          end
          send_command("MIB", "Karte vom Leser zum Drucken weiter schicken")
        end

        # Jetzt erst den eigentlichen Druck beginnen
        super
      end

      # Sendet ein Kommando an den Drucker
      def send_command(command, msg = nil)
        puts("Zebra: Send command '#{command}' #{msg}")
        open_handle
        begin
          send_cmd(command, msg)
        ensure
          close_handle
        end
      end

      # Sendet ein Kommando an den Drucker
      def send_command_ex(command, msg = nil)
        puts("Zebra: Send command ex '#{command}' #{msg}")
        ret = ""
        open_handle
        begin
          ret = send_cmd_ex(command, msg)
        ensure
          close_handle
        end
        ret
      end

      def open_handle(name = nil)
        h_printer = DL.malloc(4)
        h_printer.struct!("L", :handle)

        devicename = name || device_name

        printer_type = DL.malloc(4)
        printer_type.struct!("L", :type)

        err = DL.malloc(4)
        err.struct!("L", :err)

        #				puts("---\nGet handle '#{devicename}'")
        start = Time.now
        result = ZebraDll.get_handle(h_printer, devicename, printer_type, err)

        @handle = h_printer[:handle]
        @type = printer_type[:type]
        error = err[:err]

        #				puts("result = #{result}, error = #{error}")
        #				puts("type = #{@type}")
        #				puts("needed: #{Time.now - start}")

        if result == 0
          raise ZebraException.new(error, "Fehler bei Get Handle")
        end
      end

      def send_cmd(command, msg = nil)
        if !@handle
          raise StandardError.new("Es muss erst ein Drucker-Handle geöffnet werden!")
        end
        err = DL.malloc(4)
        err.struct!("L", :err)
        #				puts("---\nSend command #{command}")
        start = Time.now
        result = ZebraDll.send_cmd(@handle, @type, "#{command}\r", err)
        error = err[:err]

        #				puts("result = #{result}, error = #{error}")
        #				puts("needed: #{Time.now - start}")

        if result == 0
          raise ZebraException.new(error, "Fehler bei Druckerkommando #{command} #{msg}")
        end
      end

      def send_cmd_ex(command, msg = nil)
        response = DL.malloc(1024)
        #			response.struct!('S', :response)

        resp_size = DL.malloc(4)
        resp_size.struct!("L", :size)

        err = DL.malloc(4)
        err.struct!("L", :err)

        #				puts("---\nSend Command Ex: #{command}")
        #				result = ZebraDll.send_cmdex(@handle, @type, "#{command.to_s_win32}\r", response, resp_size, err)
        result = ZebraDll.send_cmdex(@handle, @type, "#{command}\r", response, resp_size, err)

        size = resp_size[:size]
        error = err[:err]

        #				puts("result = #{result}")
        #				puts("response size = #{size}")
        #				puts("response = #{response} (#{response[0, size].inspect})")
        #				puts("result = #{result}")
        #				puts("error = #{error}")
        #				puts("needed: #{Time.now - start}")

        if result == 0
          raise ZebraException.new(error, "Fehler bei Druckerkommando #{command} #{msg}")
        end
        response
      end

      def close_handle
        if @handle
          err = DL.malloc(4)
          err.struct!("L", :err)
          #					puts("---\nClose handle")
          start = Time.now
          result = ZebraDll.close_handle(@handle, err)
          error = err[:err]

          #					puts("result = #{result}, error = #{error}")
          #					puts("needed: #{Time.now - start}")

          if result == 0
            raise ZebraException.new(error, "Fehler bei Close Handle")
          end
          @handle = nil
        end
      end
    end

    class ZebraException < RuntimeError
      ERRORS = {
        -1 => "ZBR_ERROR_PRINTER_MECHANICAL_ERROR - Mechanical error",
        1 => "ZBR_ERROR_BROKEN_RIBBON - Indicates a broken ribbon",
        2 => "ZBR_ERROR_TEMPERATURE - Print head temperature is too high",
        3 => "ZBR_ERROR_MECHANICAL_ERROR Mechanical error",
        4 => "ZBR_ERROR_OUT_OF_CARD Printer is out of cards, or unable to feed the card",
        5 => "ZBR_ERROR_CARD_IN_ENCODER Unable to encode magnetic or smart card encoder",
        6 => "ZBR_ERROR_CARD_NOT_IN_ENCODER Unable to encode the card because it is not in the encoder",
        7 => "ZBR_ERROR_PRINT_HEAD_OPEN Print head is up",
        8 => "ZBR_ERROR_OUT_OF_RIBBON Out of ribbon",
        9 => "ZBR_ERROR_REMOVE_RIBBON Ribbon needs to be removed",
        10 => "ZBR_ERROR_PARAMETERS_ERROR Wrong number of parameters or a value is incorrect",
        11 => "ZBR_ERROR_INVALID_COORDINATES Invalid coordinates while trying to draw a barcode or graphics",
        12 => "ZBR_ERROR_UNKNOWN_BARCODE Undefined barcode type",
        13 => "ZBR_ERROR_UNKNOWN_TEXT Text for magnetic encoding or bar code drawing is invalid",
        14 => "ZBR_ERROR_COMMAND_ERROR Invalid command",
        20 => "ZBR_ERROR_BARCODE_DATA_SYNTAX Syntax error in the barcode command or parameters",
        21 => "ZBR_ERROR_TEXT_DATA_SYNTAX General text data error",
        22 => "ZBR_ERROR_GRAPHIC_DATA_SYNTAX Syntax error in the graphic command data",
        30 => "ZBR_ERROR_GRAPHIC_IMAGE_INITIALIZATION Unable to initialize the graphics buffer",
        31 => "ZBR_ERROR_GRAPHIC_IMAGE_MAXIMUM_WIDTH_EXCEEDED Graphic object to be drawn exceeds the X range",
        32 => "ZBR_ERROR_GRAPHIC_IMAGE_MAXIMUM_HEIGHT_EXCEEDED Graphic object to be drawn exceeds the Y range",
        33 => "ZBR_ERROR_GRAPHIC_IMAGE_DATA_CHECKSUM_ERROR Graphic data checksum error",
        34 => "ZBR_ERROR_DATA_TRANSFER_TIME_OUT Data time-out error, usually happens when the USB cable is taken out while printing",
        35 => "ZBR_ERROR_CHECK_RIBBON Incorrect ribbon installed",
        40 => "ZBR_ERROR_INVALID_MAGNETIC_DATA Invalid magnetic encoding data",
        41 => "ZBR_ERROR_MAG_ENCODER_WRITE Error while encoding a magnetic stripe",
        42 => "ZBR_ERROR_READING_ERROR Error while reading a magnetic stripe",
        43 => "ZBR_ERROR_MAG_ENCODER_MECHANICAL Magnetic encoder mechanical error",
        44 => "ZBR_ERROR_MAG_ENCODER_NOT_RESPONDING Magnetic encoder not responding",
        45 => "ZBR_ERROR_MAG_ENCODER_MISSING_OR_CARD_JAM Magnetic encoder is missing or the card is jammed before reaching the encoder",
        47 => "ZBR_ERROR_ROTATION_ERROR Error while trying to flip the card",
        48 => "ZBR_ERROR_COVER_OPEN Feeder Cover Lid is open (P110 and P120 only)",
        49 => "ZBR_ERROR_ENCODING_ERROR Error while trying to encode on a magnetic stripe",
        50 => "ZBR_ERROR_MAGNETIC_ERROR Magnetic encoder error",
        51 => "ZBR_ERROR_BLANK_TRACK One or more of the tracks of the magnetic stripe are blank",
        52 => "ZBR_ERROR_FLASH_ERROR Flash memory error",
        53 => "ZBR_ERROR_NO_ACCESS Cannot access the printer",
        54 => "ZBR_ERROR_SEQUENCE_ERROR Reception timeout, protocol errors",
        55 => "ZBR_ERROR_PROX_ERROR Reception timeout, protocol errors",
        56 => "ZBR_ERROR_CONTACT_DATA_ERROR Parameter error",
        57 => "ZBR_ERROR_PROX_DATA_ERROR Parameter error",
        60 => "ZBR_SDK_ERROR_PRINTER_NOT_SUPPORTED Printer not supported",
        61 => "ZBR_SDK_ERROR_CANNOT_GET_PRINTER_HANDLE Unable to open handle to Zebra printer driver\nIst der Drucker korrekt installiert und eingeschaltet? Falls ja, bitte den Drucker ein- und ausschalten.",
        62 => "ZBR_SDK_ERROR_CANNOT_GET_PRINTER_DRIVER Cannot open printer driver",
        63 => "ZBR_SDK_ERROR_INVALID_PARAMETER One of the arguments is invalid",
        64 => "ZBR_SDK_ERROR_PRINTER_BUSY Printer is in use",
        65 => "ZBR_SDK_ERROR_INVALID_PRINTER_HANDLE Invalid printer handle",
        66 => "ZBR_SDK_ERROR_CLOSE_HANDLE_ERROR Error closing printer driver handle",
        67 => "ZBR_SDK_ERROR_COMMUNICATION_ERROR Command failed due to communication error",
        68 => "ZBR_SDK_ERROR_BUFFER_OVERFLOW Response too large for buffer",
        69 => "ZBR_SDK_ERROR_READ_DATA_ERROR Error reading data",
        70 => "ZBR_SDK_ERROR_WRITE_DATA_ERROR Error writing data",
        71 => "ZBR_SDK_ERROR_LOAD_LIBRARY_ERROR Error loading SDK",
        72 => "ZBR_SDK_ERROR_INVALID_STRUCT_ALIGNMENT Invalid structure alignment",
        73 => "ZBR_SDK_ERROR_GETTING_DEVICE_CONTEXT Unable to create the device context for the driver",
        74 => "ZBR_SDK_ERROR_SPOOLER_ERROR Print spooler error",
        75 => "ZBR_SDK_ERROR_OUT_OF_MEMORY Operating system is out of memory",
        76 => "ZBR_SDK_ERROR_OUT_OF_DISK_SPACE Operating system is out of disk space",
        77 => "ZBR_SDK_ERROR_USER_ABORT Print job aborted by the user",
        78 => "ZBR_SDK_ERROR_APPLICATION_ABORT Application aborted",
        79 => "ZBR_SDK_ERROR_CREATE_FILE_ERROR Error creating file",
        80 => "ZBR_SDK_ERROR_WRITE_FILE_ERROR Error writing file",
        81 => "ZBR_SDK_ERROR_READ_FILE_ERROR Error reading file",
        82 => "ZBR_SDK_ERROR_INVALID_MEDIA Invalid media",
        8001 => "ZBR_GDI_ERROR_GENERIC_ERROR Window API error, call GetLastError() function from Win32 API for error information",
        8002 => "ZBR_GDI_ERROR_INVALID_PARAMETER One of the arguments is invalid",
        8003 => "ZBR_GDI_ERROR_OUT_OF_MEMORY Operating system is out of memory",
        8004 => "ZBR_GDI_ERROR_OBJECT_BUSY One of the objects specified in the API call is in use",
        8005 => "ZBR_GDI_ERROR_INSUFFICIENT_BUFFER A buffer specified as an argument in the API call is not large enough",
        8006 => "ZBR_GDI_ERROR_NOT_IMPLEMENTED Method is not implemented ",
        8007 => "ZBR_GDI_ERROR_WIN32_ERROR Method generated a Win32 error, call GetLastError() function from Win32 API for error information",
        8008 => "ZBR_GDI_ERROR_WRONG_STATE Object called by the API is in an invalid state",
        8009 => "ZBR_GDI_ERROR_ABORTED Method aborted",
        8010 => "ZBR_GDI_ERROR_FILE_NOT_FOUND File not found",
        8011 => "ZBR_GDI_ERROR_VALUE_OVERFLOW Arithmetic operation in the method caused a numeric overflow",
        8012 => "ZBR_GDI_ERROR_ACCESS_DENIED Access denied to the specified file ",
        8013 => "ZBR_GDI_ERROR_UNKNOWN_IMAGE_FORMAT Specified image file format is unknown",
        8014 => "ZBR_GDI_ERROR_FONT_FAMILY_NOT_FOUND Specified font is not installed",
        8015 => "ZBR_GDI_ERROR_FONT_STYLE_NOT_FOUND Invalid font style",
        8016 => "ZBR_GDI_ERROR_NOT_TRUE_TYPE_FONT Specified font is not a True Type font and cannot be used with GDI+",
        8017 => "ZBR_GDI_ERROR_UNSUPPORTED_GDIPLUS_VERSION Installed GDI+ version",
        8018 => "ZBR_GDI_ERROR_GDIPLUS_NOT_INITIALIZED The GDI+ API is not initialized",
        8019 => "ZBR_GDI_ERROR_PROPERTY_NOT_FOUND Specified property does not exist in the image",
        8020 => "ZBR_GDI_ERROR_PROPERTY_NOT_SUPPORTED Specified property is not supported by the image format",
        8021 => "ZBR_GDI_ERROR_GRAPHICS_ALREADY_INITIALIZED Graphic buffer has already been initialized",
        8022 => "ZBR_GDI_ERROR_NO_GRAPHIC_DATA No data in the graphic buffer to print",
        8023 => "ZBR_GDI_ERROR_GRAPHICS_NOT_INITIALIZED Graphics buffer has not been initialized",
        8024 => "ZBR_GDI_ERROR_GETTING_DEVICE_CONTEXT Unable to create the device context for the driver",
        8025 => "ZBR_DLG_ERROR_DLG_CANCELED User closed or canceled the DLG window",
        8026 => "ZBR_DLG_ERROR_SETUP_FAILURE PrintDlg function failed to load the required resources",
        8027 => "ZBR_DLG_ERROR_PARSE_FAILURE PrintDlg function failed to parse the strings in the [devices] section of the WIN.INI file",
        8028 => "ZBR_DLG_ERROR_RET_DEFAULT_FAILUREPD_RETURNDEFAULT flag was specified in the Flags member of the PRINTDLG structure, but the hDevMode or hDevNames member was not NULL",
        8029 => "ZBR_DLG_ERROR_LOAD_DRV_FAILURE PrintDlg function failed to load the device driver for the specified printer",
        8030 => "ZBR_DLG_ERROR_GET_DEVMODE_FAIL Printer driver failed to initialize a DEVMODE structure",
        8031 => "ZBR_DLG_ERROR_INIT_FAILURE PrintDlg function failed during initialization, and there is no more specific extended error code to describe the failure",
        8032 => "ZBR_DLG_ERROR_NO_DEVICES No printer drivers were found",
        8033 => "ZBR_DLG_ERROR_NO_DEFAULT_PRINTER A default printer does not exist",
        8034 => "ZBR_DLG_ERROR_DN_DM_MISMATCH Data in the DEVMODE and DEVNAMES structures describes two different printers",
        8035 => "ZBR_DLG_ERROR_CREATE_IC_FAILURE PrintDlg function failed when it attempted to create an information context",
        8036 => "ZBR_DLG_ERROR_PRINTER_NOT_FOUND The [devices] section of the WIN.INI file did not contain an entry for the requested printer",
        8037 => "ZBR_DLG_ERROR_DEFAULT_DIFFERENT Error occurs when you store the DEVNAMES structure, and the user changes the default printer by using the Control Panel"
      }

      def initialize(error_code, message)
        error_message = ZebraException.get_message(error_code)
        super("#{message} (#{error_code} - #{error_message})")
      end

      def self.get_message(error_code)
        ERRORS[error_code]
      end
    end

    if __FILE__ == $0
      printer = PrinterZebra.new
      printer.open_handle("Zebra P430i Card Printer USB")
      printer.send_cmd("MCL")
      printer.close_handle

      sleep(5)

      printer.open_handle("Zebra P430i Card Printer USB")
      printer.send_cmd("MRB")
      printer.close_handle
    end
  end
end
