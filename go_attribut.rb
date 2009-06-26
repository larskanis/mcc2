# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

# GraphicObject-Attribut
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
