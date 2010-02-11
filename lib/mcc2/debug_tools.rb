# -*- coding: utf-8 -*-

module Mcc2
module DebugTools

  def self.write_log_file(source, message)
    File.open("logs/#{source}.log","a"){|f_out| 
      f_out.puts "-"*100
      f_out.puts Time.now.strftime("%Y-%m-%d  %H:%M:%S")
      f_out.puts "Programmversion: #{Mcc2::VERSION}"
      f_out.puts "."*50
      f_out.puts message
    }
  end
  
  def self.unkown_error_message(e)
    (["Es ist leider ein Fehler aufgetreten:\n\n#{e.to_s} #{e.class}\n"]+e.backtrace).join("\n")
  end
end
end
