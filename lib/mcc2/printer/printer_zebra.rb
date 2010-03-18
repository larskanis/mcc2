# -*- coding: UTF-8 -*-

require 'win32api4ruby'
require 'mcc2/printer/gdi_card_printer'			# die Basisklasse für alle CardPrinter

module Mcc2
	module Printer
		# Diese Klasse definiert einen Zebra-Drucker.
		class PrinterZebra < GdiCardPrinter
			def initialize
				super
			end

			def device_name
				layout_file.get_attr_value(S_ZEBRAPRINTER_NAME)
			end

			def device_initdata
				layout_file.get_binary_attr(S_ZEBRAPRINTER_INITDATA)
			end

			def send_command(command)
				data = ["1B", command, "0D"].pack("H*a*H*")

				devicename = self.device_name
				h_printer = DL.malloc(4)

				puts("open printer #{devicename}")
				Win32api4ruby::Winspool.open_printer(devicename.to_s_win32, h_printer, nil)

				document_name = "Test Escape"
				docinfo = Win32api4ruby::Gdi.create_DOCINFO
				docinfo[:lpszDocName] = Win32api4ruby::Base.prepare_PtrData(document_name.to_s_win32)

				puts("start doc")
				Win32api4ruby::Winspool.start_doc_printer(h_printer, 1, docinfo)
				puts("start page")
				Win32api4ruby::Winspool.start_page_printer(h_printer)
				puts("write printer")
				Win32api4ruby::Winspool.write_printer(h_printer, data)
				puts("end page")
				Win32api4ruby::Winspool.end_page_printer(h_printer)
				puts("end doc")
				Win32api4ruby::Winspool.end_doc_printer(h_printer)
				puts("close printer")
				Win32api4ruby::Winspool.close_printer(h_printer)

#				PASSTHROUGH
#				Win32api4ruby::Gdi.escape(hdc, Win32api4ruby::Gdi::PASSTHROUGH, [data.length, data].pack('va*'), nil)
			end

			def start_doc(hPrinter, row)
				@pages = []
				super

				if chip
					#Karte zum Kontaktlos-Leser fahren
					send_command("MCL")
				end
			end

			def end_doc(hPrinter, row)
				# Warten, falls Karte laden noch läuft
#				@thread_chipcoding.join if @thread_chipcoding
#				@thread_chipcoding = nil

				if chip
					begin
						# Kartenpersonalisierung
						chip.pers_card(layout_file, row)

						# Karte vom Leser zum Drucken weiter schicken
						send_command("MI")
					rescue => e
						#Im Fehlerfall die Karte auswerfen
						send_command("MRB")
						raise
					end
				end

				# Alle berechneten Seiten ausgeben
				@pages.each{|page| page.draw}

				super
			end
		end

		if __FILE__ == $0
		end
	end
end