# -*- coding: UTF-8 -*-

require 'myinifile'

if __FILE__ == $0
  require 'rubygems'
end

require 'constants'

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

class GraphicObject
  attr_accessor :go_attributes
  def initialize
    p "GraphicObject::Initialize"
    @go_attributes = {}
    add_attr(@go_attributes, GOA_ID, Integer, 0)
    add_attr(@go_attributes, GOA_DATA, String, "Muster")
    add_attr(@go_attributes, GOA_NAME, String, GRAPHICOBJECT)
    add_attr(@go_attributes, GOA_TYP, Integer, 0)
    add_attr(@go_attributes, GOA_WIDTH, Integer, 100)
    add_attr(@go_attributes, GOA_HEIGHT, Integer, 100)
    add_attr(@go_attributes, GOA_ROTATION, Integer, 0)
    add_attr(@go_attributes, GOA_SORTORDER, Integer, 0)
  end
  
  def add_attr(dest, attr_name, attr_typ, attr_default_value)
    attr = GO_Attribut.new(attr_name, attr_typ, attr_default_value) 
    dest[attr.attr_name] = attr
  end
  
  def get_human_readable_typ
    if @go_attributes[GOA_TYP].attr_value == BARCODEOBJECT then "BarcodeObject"
    elsif @go_attributes[GOA_TYP].attr_value == BARCODEOBJECT then "BarcodeObject"
    elsif @go_attributes[GOA_TYP].attr_value == GRAPHICOBJECT then "GraphicObject"
    elsif @go_attributes[GOA_TYP].attr_value == TEXTOBJECT then "TextObject"
    elsif @go_attributes[GOA_TYP].attr_value == PICTUREOBJECT then "PictureObject"
    else "unknown_object"
    end
  end
end


if __FILE__ == $0
  go = GraphicObject.new
  go.go_attributes.each{|e| p e}
end
