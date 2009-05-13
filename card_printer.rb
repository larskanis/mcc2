# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class CardPrinter < Printer
  attr_reader :default_width
  attr_reader :default_height
  def initialize
    super
    @default_width = 85.6
    @default_height = 53.98
  end
  
  def dpi
    300
  end
  
  # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
  def card_margin_left
    5
  end

  def card_margin_right
    5
  end
  
  def card_margin_top
    5
  end

  def card_margin_bottom
    5
  end

end


if __FILE__ == $0
end
