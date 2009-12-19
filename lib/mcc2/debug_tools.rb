# -*- coding: utf-8 Cookie -*-
module DebugTools

  def write_log_file(source, message)
    File.open("logs/#{source}.log","a"){|f_out| 
      f_out.puts "-"*100
      f_out.puts Time.now.strftime("%Y-%m-%d  %H:%M:%S")
      f_out.puts "."*50
      f_out.puts "Dateiversionen:"
      message.split("\n")
      $versions_liste.each_pair{|k,v|
        if message.index(k)
          f_out.puts [k, v].join(" || ")
        end
      }
      f_out.puts "."*50
      f_out.puts message
    }
  end
 	#---------------------------------------------------------------------------------------------------------
  
  def unkown_error_message(e)
    (["Es ist ein unerwarteter Fehler aufgetreten.\nBitte informieren Sie umgehend die EDV!\n\n  #{e.class}:  #{e.to_s}"]+e.backtrace).join("\n")
  end
end
