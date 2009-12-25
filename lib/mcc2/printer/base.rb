# -*- coding: UTF-8 -*-

module Printer
class Base
  attr_reader :default_width
  attr_reader :default_height
  attr_reader :default_x_offset
  attr_reader :default_y_offset
  attr_reader :dpi

  #
  def initialize
    @dpi = 300
    @default_x_offset = 0
    @default_y_offset = 0
  end

  #
  def print_page(hPrinter, layout_file, row, page_nr , page_width = default_width, page_height = default_height)

    raise "not implemented"
  end

  def max_pages
    1
  end

  def can_duplex?
    false
  end

  def has_magstripe_engine?
    false
  end
  #--------------------------------------------------------------------------------------------------------------

  def has_contactless_engine?
    false
  end
  #--------------------------------------------------------------------------------------------------------------

  def has_contact_engine?
    false
  end
  #--------------------------------------------------------------------------------------------------------------

  # dies ist nur ein Platzhalter, die eigentlichen Methoden müssen bei den jeweiligen Druckern definiert werden
  def personalize_ms(hPrinter)
    #
  end
  #--------------------------------------------------------------------------------------------------------------

  def set_duplex(hPrinter, state)
    raise "not implemented"
  end
end
end
