# -*- coding: UTF-8 -*-

require 'win32api4ruby'
require 'mcc2/printer/gdi_card_printer'			# die Basisklasse für alle CardPrinter

module Mcc2
	module Printer
		# Diese Klasse definiert einen Zebra-Drucker.
		class PrinterZebra < GdiCardPrinter
			def initialize()
				super
			end

			def device_name
				layout_file.get_attr_value(S_ZEBRAPRINTER_NAME)
			end

			def device_initdata
				layout_file.get_binary_attr(S_ZEBRAPRINTER_INITDATA)
			end

			def print_card(layout_file, row, chip)
				#Wird für Chip-Perso benötigt
				@layout_file = layout_file
				@chip = chip

				if chip
					#Karte zum Kontaktlos-Leser fahren
					send_command("MCL")
					begin
						# Kartenpersonalisierung
						chip.pers_card(layout_file, row)

						# Karte vom Leser zum Drucken weiter schicken
						send_command("MIB")
					rescue => e
						#Im Fehlerfall die Karte auswerfen
						send_command("MRB")
						raise
					end
				end

				#Jetzt erst den eigentlichen Druck beginnen
				super
			end

			private
			#Sendet ein Kommando an den Drucker
			def send_command(command)
				open_handle
				send_cmd(command)
				close_handle
			end

			def open_handle(name = nil)
				h_printer = DL.malloc(4)
				h_printer.struct!('L', :handle)

				if (name)
					devicename = name
				else
					devicename = self.device_name
				end

				printer_type = DL.malloc(4)
				printer_type.struct!('L', :type)

				err = DL.malloc(4)
				err.struct!('L', :err)

#				puts("---\nGet handle '#{devicename}'")
				start = Time.now
				result = Win32api4ruby::ZebraDll.get_handle(h_printer, devicename, printer_type, err)

				@handle = h_printer[:handle]
				@type = printer_type[:type]
				error = err[:err]

#				puts("result = #{result}, error = #{error}")
#				puts("type = #{@type}")
#				puts("needed: #{Time.now - start}")

				if (result == 0)
					raise Exception.new("Fehler bei Get Handle (#{error})")
				end
			end

			def send_cmd(command)
				if (!@handle)
					raise Exception.new("Es muss erst ein Drucker-Handle geöffnet werden!")
				end
				err = DL.malloc(4)
				err.struct!('L', :err)
#				puts("---\nSend command #{command}")
				start = Time.now
				result = Win32api4ruby::ZebraDll.send_cmd(@handle, @type, "#{command}\r", err)
				error = err[:err]

#				puts("result = #{result}, error = #{error}")
#				puts("needed: #{Time.now - start}")

				if (result == 0)
					raise Exception.new("Fehler bei Send Cmd (#{error})")
				end
			end

			def close_handle()
				if (@handle)
					err = DL.malloc(4)
					err.struct!('L', :err)
#					puts("---\nClose handle")
					start = Time.now
					result = Win32api4ruby::ZebraDll.close_handle(@handle, err)
					error = err[:err]

#					puts("result = #{result}, error = #{error}")
#					puts("needed: #{Time.now - start}")

					if (result == 0)
						raise Exception.new("Fehler bei Close Handle (#{error})")
					end
					@handle = nil
				end
			end

			if __FILE__ == $0
				printer = PrinterZebra.new()
				printer.open_handle("Zebra P430i Card Printer USB")
				printer.send_cmd("MCL")
				printer.send_cmd("MIB")
				printer.send_cmd("MO")
				printer.close_handle
			end
		end
	end
end