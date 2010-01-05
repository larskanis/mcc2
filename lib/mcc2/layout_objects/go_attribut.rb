# -*- coding: UTF-8 -*-

# GraphicObject-Attribut
module Mcc2
class GO_Attribut 
  attr_accessor :attr_name
  attr_accessor :attr_typ
  attr_accessor :attr_value
  
  def initialize(attr_name, attr_typ, attr_default_value)
    @attr_name = attr_name
    @attr_typ = attr_typ
    @attr_value = attr_default_value
  end
  
end
end