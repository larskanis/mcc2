# -*- coding: UTF-8 -*-

require 'printer/base'           # die Basisklasse für die Printer


module Printer
module CardPrinting
  def default_width; 85.6; end
  def default_height; 53.98; end
  def dpi; 300; end

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

class CardPrinter < Base
  include CardPrinting
end
end

if __FILE__ == $0
end
