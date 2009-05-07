# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'rubygems'
  require 'graphic_object'
end


class BarcodeObject < GraphicObject
  def initialize
    p "BarcodeObject::Initialize"
    super
    @go_attributes[GOA_TYP].attr_value = BARCODEOBJECT
    add_attr(@go_attributes, GOA_BC_TYP, String, "2O5I")
    add_attr(@go_attributes, GOA_HUMAN_READABLE, Integer, true)
    add_attr(@go_attributes, GOA_FONT_HEIGHT, Integer, 10)
    add_attr(@go_attributes, GOA_FONT_TYP, String, "Arial")
    add_attr(@go_attributes, GOA_FONT_COLOR, Integer, 0)
    add_attr(@go_attributes, GOA_BACK_COLOR, Integer, 0)
    add_attr(@go_attributes, GOA_FONT_WEIGHT, Integer, 0)
    add_attr(@go_attributes, GOA_JUSTIFICATION, Integer, 0)
  end
end


if __FILE__ == $0
  bo = BarcodeObject.new
  bo.go_attributes.each{|e| p e}
end
