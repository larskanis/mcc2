# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class TextObject < GraphicObject
  def initialize
    super
    @go_attributes[GOA_TYP].attr_value = TEXTOBJECT
    add_attr(@go_attributes, GOA_FONT_HEIGHT, Integer, 10)
    add_attr(@go_attributes, GOA_FONT_TYP, String, "Arial")
    add_attr(@go_attributes, GOA_FONT_WEIGHT, String, Font_weight[0])
    add_attr(@go_attributes, GOA_FONT_STYLE, String, Font_style[0])
    add_attr(@go_attributes, GOA_FONT_STRETCH, String, Font_stretch[0])
    add_attr(@go_attributes, GOA_FONT_COLOR, String, "000000FF")
    add_attr(@go_attributes, GOA_BACK_COLOR, String, "FFFFFFFF")
    add_attr(@go_attributes, GOA_JUSTIFICATION, String, "Links")
  end
end


if __FILE__ == $0
  to = TextObject.new
  to.go_attributes.each{|e| p e}
end
