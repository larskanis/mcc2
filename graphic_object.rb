# -*- coding: UTF-8 -*-


if __FILE__ == $0
  require 'mcc2'
end

class GraphicObject
  attr_accessor :go_attributes
  def initialize
    p "GraphicObject::Initialize"
    @go_attributes = {}
    add_attr(@go_attributes, GOA_ID, Integer, 0)
    add_attr(@go_attributes, GOA_DATA, String, "Muster")
    add_attr(@go_attributes, GOA_NAME, String, GRAPHICOBJECT) # bekommen erst einmal alle den gleichen Namen, können später durch den Anwender geändert werden
    add_attr(@go_attributes, GOA_TYP, String, GRAPHICOBJECT)
    add_attr(@go_attributes, GOA_X, Integer, 10)
    add_attr(@go_attributes, GOA_Y, Integer, 10)
    add_attr(@go_attributes, GOA_WIDTH, Integer, 100)
    add_attr(@go_attributes, GOA_HEIGHT, Integer, 100)
    add_attr(@go_attributes, GOA_ROTATION, Integer, 0)
    add_attr(@go_attributes, GOA_PAGE_NR, Integer, 0)
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  def add_attr(dest, attr_name, attr_typ, attr_default_value)
    attr = GO_Attribut.new(attr_name, attr_typ, attr_default_value) 
    dest[attr.attr_name] = attr
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  def self.get_object_by_typ(typ)
    if typ == TEXTOBJECT then TextObject.new
    elsif typ == BARCODEOBJECT then BarcodeObject.new
    elsif typ == PICTUREOBJECT then PictureObject.new
    end
  end
end


if __FILE__ == $0
  go = GraphicObject.new
  go.go_attributes.each{|e| p e}
end
