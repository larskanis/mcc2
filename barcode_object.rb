# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

if __FILE__ == $0
  require 'mcc2'
end


class BarcodeObject < GraphicObject
  def initialize
    super
    @go_attributes[GOA_TYP].attr_value = BARCODEOBJECT
    add_attr(@go_attributes, GOA_BC_TYP, String, "NONE")
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


if __FILE__ == $0
  bo = BarcodeObject.new
  bo.go_attributes.each{|e| p e}
end
