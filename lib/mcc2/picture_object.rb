# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class PictureObject < GraphicObject
  def initialize
    super
    @go_attributes[GOA_TYP].attr_value = PICTUREOBJECT
    add_attr(@go_attributes, GOA_WIDTH, Integer, 20)
    add_attr(@go_attributes, GOA_HEIGHT, Integer, 28)
    add_attr(@go_attributes, GOA_STRETCH, Integer, false)
    add_attr(@go_attributes, GOA_PRINTABLE, Integer, true)
  end
end


if __FILE__ == $0
  po = PictureObject.new
  po.go_attributes.each{|e| p e}
end
