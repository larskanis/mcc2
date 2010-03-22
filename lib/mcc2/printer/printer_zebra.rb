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

			def move_to_reject_box()
				if (@type &&
								@type == 420 ||
								@type == 430 ||
								@type == 520 ||
								@type == 720)
					#Bei Druckern mit Ausschuss-Fach, Karte in Ausschuss-Fach
					#TODO geht noch nicht richtig, es werden 2 Karten in das Ausschuss-Fach transportiert
					send_command("MRB")
				else
					#Bei Druckern ohne Ausschuss-Fach, Karte einfach auswerfen
					send_command("MO")
				end
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
					rescue => e
						move_to_reject_box()
						raise e
					end
					# Karte vom Leser zum Drucken weiter schicken
					send_command("MIB")
				end

				#Jetzt erst den eigentlichen Druck beginnen
				super
			end

			#TODO wieder private nach Test!!
#			private
			public
			#Sendet ein Kommando an den Drucker
			def send_command(command)
				puts("Zebra: Send command '#{command}'")
				open_handle
				begin
					send_cmd(command)
				ensure
					close_handle
				end
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
				printer.close_handle

				sleep(5)

				printer.open_handle("Zebra P430i Card Printer USB")
				printer.send_cmd("MRB")
				printer.close_handle
			end
		end
	end
end