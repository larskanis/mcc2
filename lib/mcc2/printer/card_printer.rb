# -*- coding: UTF-8 -*-

require 'mcc2/printer/base'           # die Basisklasse für die Printer


module Mcc2
module Printer
module CardPrinting
  def default_width; LAYOUT_DEFAULT_WIDTH; end
  def default_height; LAYOUT_DEFAULT_HEIGHT; end
  def max_dpi; 300; end

  # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
  #
  def card_margin_left #:nodoc:
    5.0
  end

  #
  def card_margin_right
    5.0
  end

  #
  def card_margin_top
    5.0
  end

  #
  def card_margin_bottom
    5.0
  end

  def max_pages
    2
  end

end

class CardPrinter < Base
  include CardPrinting
end
end
end
