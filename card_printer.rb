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
end


if __FILE__ == $0
end
