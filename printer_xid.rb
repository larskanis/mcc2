# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'rubygems'
  require 'printer'
end


class PrinterXID < Printer
  def load_card
  end
  
  def unload_card
  end

end


if __FILE__ == $0
  pr = PrinterXID.new
  pr.load_card
  pr.unload_card
end
