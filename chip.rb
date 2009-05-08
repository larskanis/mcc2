# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Chip
  attr_accessor :params
  
  def initialize
    p "Chip::Initialize"
    @params = []
    (1..anz_params).each{|i|
      @params << ""
    }
  end
  
  def anz_params
    22
  end
end


if __FILE__ == $0
  chip = Chip.new
  p chip.params
end
