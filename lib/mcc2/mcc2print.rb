#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-


require "rubygems"

require 'mcc2/dataman'           # der Datenmanager
require 'mcc2/dataman_csv'       # der Datenmanager für CSV-dateien
require 'mcc2/dataman_database'  # der Datenmanager für Datenbanken

require 'mcc2/magstripe'         # Magnetstreifen
require 'mcc2/chipobjekt'              # Chip
require 'mcc2/debug_tools'

require 'ftools'
require "tempfile"

File.makedirs("./logs", true)


module Mcc2
# die Haupklasse des Programms
class Mcc2Print

  def self.run(argv)
    Thread.abort_on_exception = true

    begin
      
    rescue Exception => e
      file = File.basename(__FILE__, ".rb")
      DebugTools.write_log_file('main', DebugTools.unkown_error_message(e))
      puts(DebugTools.unkown_error_message(e))
      exit -1
    end

  end
end
end
