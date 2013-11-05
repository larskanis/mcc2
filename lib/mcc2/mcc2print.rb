#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-


require "rubygems"

require 'mcc2'
require 'mcc2/debug_tools'
require 'ftools'
require "tempfile"
require "optparse"

require 'barby'
%w[
    bookland code_25_iata code_25 code_93 ean_13 gs1_128 qr_code
    code_128 code_25_interleaved code_39 data_matrix ean_8 pdf_417 upc_supplemental
  ].each do |code|
  require "barby/barcode/#{code}"
end

File.makedirs("./logs", true)


module Mcc2
# die Haupklasse des Programms
	class Mcc2Print

		attr_accessor :verbose

		def initialize
			@xpath_changes = []
		end

		def start!(layout_fname)
			lf = Mcc2::LayoutFile.load_from_xml(layout_fname)
			@xpath_changes.each do |xc|
				xpath, value = *xc.split('~', 2)
				lf.change_first_xpath_value(xpath, value)
			end
			printer = lf.build_printer_instance
			chip = lf.build_chip_instance
			dataman = lf.build_dataman_instance
			rows = dataman.rows || [nil]

      begin
        rows.each do |row|
          erg = printer.print_card(lf, row, chip)
        end
      ensure
        chip.close_reader if chip
      end
		end

		def add_xpath_value(param)
			@xpath_changes << param
		end

		def self.run(argv)
			Thread.abort_on_exception = true

			app = self.new

			OptionParser.new do |opts|
				opts.banner = "Usage: #{$0} [options]"

				opts.on("-v", "--[no-]verbose", "Run verbosely", &app.method(:verbose=))
				opts.on("-x", "--xpath-value XPATH~VALUE", "Replace XML-value on the given xpath", &app.method(:add_xpath_value))
				opts.separator "\tExsamples:"
				opts.separator "\t -x Layout/datasource~mydata.csv"
				opts.separator "\t -x Layout/fileprinter_save_as~image_%d_%p.png"
			end.parse!

			begin
				app.start!(argv[0])
			rescue Exception => e
				file = File.basename(__FILE__, ".rb")
				DebugTools.write_log_file('main', DebugTools.unkown_error_message(e))
				puts(DebugTools.unkown_error_message(e))
				exit -1
			end
		end
	end
end