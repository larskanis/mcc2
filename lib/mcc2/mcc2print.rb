#!/usr/bin/env ruby

require "mcc2"
require "fileutils"
require "tempfile"
require "optparse"
require "i18n"
require "ruby-zint"

module Mcc2
  # die Haupklasse des Programms
  class Mcc2Print
    attr_accessor :verbose

    def initialize
      @xpath_changes = {}
    end

    def start!(layout_fname, xpath_changes = {})
      lf = Mcc2::LayoutFile.load_from_xml(layout_fname, @xpath_changes.merge(xpath_changes))
      printer = lf.build_printer_instance
      dataman = lf.build_dataman_instance
      rows = dataman.rows || [nil]

      rows.each do |row|
        printer.print_card(lf, row)
      end
    end

    def add_xpath_value(param)
      xpath, value = param.split("~", 2)
      @xpath_changes[xpath] = value
    end

    @@supported_language_files = nil
    def self.supported_language_files
      @@supported_language_files ||= Dir[File.expand_path("../../locales/*.yml", __dir__)]
    end

    def self.init_i18n
      I18n.load_path = supported_language_files
      I18n.enforce_available_locales = true
      I18n.default_locale = :en # (note that `en` is already the default!)
    end

    def self.run(argv)
      Thread.abort_on_exception = true
      Mcc2Print.init_i18n

      app = new

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} <layout.mcc2>* [options]"

        opts.on("-v", "--[no-]verbose", "Run verbosely", &app.method(:verbose=))
        langs = Mcc2Print.supported_language_files.map{|f| File.basename(f, ".*") }.join(", ")
        opts.on( '-l', '--lang ISO2', "Set language of the UI (#{langs})"){|o| I18n.locale = o }
        opts.on("-x", "--xpath-value XPATH~VALUE", "Replace XML-value on the given xpath", &app.method(:add_xpath_value))
        opts.separator "\tExamples:"
        opts.separator "\t -x //Layout/datasource~mydata.csv"
        opts.separator "\t -x {layout.mcc2}//Layout/fileprinter_save_as~image_%d_%p.png"
      end.parse!

      app.start!(argv[0])
    end
  end
end
