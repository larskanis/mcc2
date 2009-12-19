# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

# diese Klasse dient als Basis für die Printer, es macht keinen Sinn direkt ein Objekt von dieser Klasse zu erzeugen

#~ if __FILE__ == $0
  #~ require 'mcc2'
#~ end
require 'gdi_printer'           # die Basisklasse für die Printer
require 'card_printer'


class GdiCardPrinter < GdiPrinter
  include CardPrinting
  
  def initialize
    super
  end
  
end


if __FILE__ == $0
end
