# -*- coding: UTF-8 -*-

require 'mcc2/printer/gdi_printer'
require 'mcc2/printer/card_printer'


module Mcc2
module Printer
class GdiCardPrinter < GdiPrinter
  include CardPrinting
  
  def initialize
    super
  end
  
end
end
end
