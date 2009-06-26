# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

# diese Klasse dient als Basis für die Printer, es macht keinen Sinn direkt ein Objekt von dieser Klasse zu erzeugen

#~ if __FILE__ == $0
  #~ require 'mcc2'
#~ end
require 'printer'           # die Basisklasse für die Printer


class CardPrinter < Printer
  def initialize
    super
    @default_width = 85.6
    @default_height = 53.98
    @dpi = 300
  end
  
  
  # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
  #
  def card_margin_left #:nodoc:
    5
  end

  #
  def card_margin_right
    5
  end
  
  #
  def card_margin_top
    5
  end
  
  #
  def card_margin_bottom
    5
  end

  def max_pages
    2
  end
  
end


if __FILE__ == $0
end
