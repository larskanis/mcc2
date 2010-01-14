# -*- coding: UTF-8 -*-

require 'mcc2/layout_objects/graphic_object'


module Mcc2
class BarcodeObject < GraphicObject
  def initialize
    super
    @go_attributes[GOA_TYP].attr_value = BARCODEOBJECT
    add_attr(@go_attributes, GOA_WIDTH, Integer, 30)
    add_attr(@go_attributes, GOA_HEIGHT, Integer, 10)
    add_attr(@go_attributes, GOA_DATA, String, 'Daten')
    add_attr(@go_attributes, GOA_SAMPLE_DATA, String, '12345678')
    add_attr(@go_attributes, GOA_BC_TYP, String, "None")
    add_attr(@go_attributes, GOA_HUMAN_READABLE, Integer, true)
    add_attr(@go_attributes, GOA_FONT_HEIGHT, Integer, 10)
    add_attr(@go_attributes, GOA_FONT_TYP, String, "Arial")
    add_attr(@go_attributes, GOA_FONT_COLOR, String, "000000FF")
    add_attr(@go_attributes, GOA_BACK_COLOR, String, "FFFFFFFF")
    add_attr(@go_attributes, GOA_FONT_WEIGHT, Integer, 0)
    add_attr(@go_attributes, GOA_BC_MODUL_WIDTH, Integer, 1)
    add_attr(@go_attributes, GOA_JUSTIFICATION, Integer, 0)
  end
end
end

if __FILE__ == $0
  bo = BarcodeObject.new
  bo.go_attributes.each{|e| p e}
end
