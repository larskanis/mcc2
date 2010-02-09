# -*- coding: UTF-8 -*-

require 'mcc2/layout_objects/go_attribut'       # die Attribut-Klasse für die grafischen Objekte

module Mcc2
class GraphicObject
  attr_accessor :go_attributes
  def initialize(xml_elem=nil)
    @go_attributes = {}
    add_attr(@go_attributes, GOA_ID, Integer, 0)
    add_attr(@go_attributes, GOA_NAME, String, GRAPHICOBJECT) # bekommen erst einmal alle den gleichen Namen, können später durch den Anwender geändert werden
    add_attr(@go_attributes, GOA_TYP, String, GRAPHICOBJECT)
    add_attr(@go_attributes, GOA_X, Integer, 10)
    add_attr(@go_attributes, GOA_Y, Integer, 10)
    add_attr(@go_attributes, GOA_ROTATION, Integer, 0)
    add_attr(@go_attributes, GOA_PAGE_NR, Integer, 0)
    add_attr(@go_attributes, GOA_PRINTLIST, String, 'false')

    @xml_elem = xml_elem
  end

  def add_attr(dest, attr_name, attr_typ, attr_default_value)
    attr = GO_Attribut.new(attr_name, attr_typ, attr_default_value) 
    dest[attr.attr_name] = attr
  end

  def [](attr)
    goattr = @xml_elem.find_first(attr)
    goattr.content if goattr
  end

  def []=(attr, text)
    goattr = @xml_elem.find_first(attr)
    goattr.content = text if goattr
  end

  def self.get_object_by_typ(typ, xml_elem=nil)
    if typ == TEXTOBJECT then TextObject.new xml_elem
    elsif typ == BARCODEOBJECT then BarcodeObject.new xml_elem
    elsif typ == PICTUREOBJECT then PictureObject.new xml_elem
    elsif typ == BOXOBJECT then BoxObject.new xml_elem
    end
  end
end
end

if __FILE__ == $0
  go = GraphicObject.new
  go.go_attributes.each{|e| p e}
end
