module Mcc2
  module DebugTools
    def self.write_log_file(source, message)
      f_out = $stderr
      f_out.puts "-" * 100
      f_out.puts Time.now.strftime("%Y-%m-%d  %H:%M:%S")
      f_out.puts "Programmversion: #{Mcc2::VERSION}"
      f_out.puts "." * 50
      f_out.puts message
    end

    def self.unkown_error_message(e)
      I18n.t(:unknwon_error_message, default: "Es ist leider ein Fehler aufgetreten:\n\n%{e} %{klass}", e:, klass: e.class)
    end

    def self.write_exception(source, e)
      write_log_file(source, I18n.t(:unknwon_error_message_exc, default: "Es ist leider ein Fehler aufgetreten:\n\n%{e} (%{klass})\n%{backtrace}", e:, klass: e.class, backtrace: e.backtrace.join("\n")))
    end
  end
end
