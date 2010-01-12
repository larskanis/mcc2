# -*- coding: UTF-8 -*-

require 'printer/gdi_printer'
require 'printer/card_printer'


module Printer
class GdiCardPrinter < GdiPrinter
  include CardPrinting
  
  def initialize
    super
  end
  
end
end
