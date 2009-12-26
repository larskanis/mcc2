# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

if __FILE__ == $0
  require 'mcc2'
end


class TextObject < GraphicObject
  def initialize
    super
    @go_attributes[GOA_TYP].attr_value = TEXTOBJECT
    add_attr(@go_attributes, GOA_WIDTH, Integer, 30)
    add_attr(@go_attributes, GOA_HEIGHT, Integer, 0)
    add_attr(@go_attributes, GOA_FONT_HEIGHT, Integer, 10)
    add_attr(@go_attributes, GOA_FONT_TYP, String, "Helvetica")
    add_attr(@go_attributes, GOA_FONT_COLOR, String, "000000FF")
    add_attr(@go_attributes, GOA_FONT_FILE, String, "")
    add_attr(@go_attributes, GOA_BACK_COLOR, String, "FFFFFFFF")
    add_attr(@go_attributes, GOA_JUSTIFICATION, String, "Links")
  end
end


if __FILE__ == $0
  to = TextObject.new
  to.go_attributes.each{|e| p e}
end
