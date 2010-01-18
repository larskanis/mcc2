#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-


require "rubygems"

require 'mcc2/magstripe'         # Magnetstreifen
require 'mcc2/chipobjekt'              # Chip
require 'mcc2/debug_tools'
require 'barby'
require 'ftools'
require "tempfile"
require "optparse"

File.makedirs("./logs", true)


module Mcc2
# die Haupklasse des Programms
class Mcc2Print

  attr_accessor :verbose

  def initialize
    @xpath_changes = []
  end

  def start!(layout_fname)
    lf = LayoutFile.load_from_xml(layout_fname)
    @xpath_changes.each{|xc|
      xpath, value = *xc.split('~', 2)
      lf.change_first_xpath_value(xpath, value)
    }
    printer = lf.build_printer_instance
    dataman = lf.build_dataman_instance
    rows = dataman.rows || [nil]
    rows.each do |row|
      erg = printer.print_card(lf, row, @chip)
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
