require "mcc2/layout_object/go_attribut"       # die Attribut-Klasse für die grafischen Objekte

module Mcc2
  module LayoutObject
    class Graphic
      attr_reader :layout_file
      attr_accessor :go_attributes

      def initialize(xml_elem: nil, layout_file: nil)
        @go_attributes = {}
        add_attr(@go_attributes, GOA_ID, Integer, 0)
        add_attr(@go_attributes, GOA_NAME, String, GRAPHICOBJECT) # bekommen erst einmal alle den gleichen Namen, können später durch den Anwender geändert werden
        add_attr(@go_attributes, GOA_TYP, String, GRAPHICOBJECT)
        add_attr(@go_attributes, GOA_X, Integer, 10)
        add_attr(@go_attributes, GOA_Y, Integer, 10)
        add_attr(@go_attributes, GOA_ROTATION, Integer, 0)
        add_attr(@go_attributes, GOA_PAGE_NR, Integer, 0)
        add_attr(@go_attributes, GOA_LAYER, Integer, 0)
        add_attr(@go_attributes, GOA_PRINTLIST, String, "false")

        @xml_elem = xml_elem
        @layout_file = layout_file
      end

      def add_attr(dest, attr_name, attr_typ, attr_default_value)
        attr = GO_Attribut.new(attr_name, attr_typ, attr_default_value)
        dest[attr.attr_name] = attr
      end

      def [](attr)
        goattr = @xml_elem.at_xpath(attr)
        goattr&.content
      end

      def []=(attr, text)
        goattr = @xml_elem.at_xpath(attr)
        goattr.content = text if goattr
      end

      def self.get_object_by_typ(typ, xml_elem: nil, layout_file: nil)
        if typ == TEXTOBJECT then Text.new xml_elem: xml_elem, layout_file: layout_file
        elsif typ == BARCODEOBJECT then Barcode.new xml_elem: xml_elem, layout_file: layout_file
        elsif typ == PICTUREOBJECT then Picture.new xml_elem: xml_elem, layout_file: layout_file
        elsif typ == BOXOBJECT then Box.new xml_elem: xml_elem, layout_file: layout_file
        elsif typ == EMBEDOBJECT then Embed.new xml_elem: xml_elem, layout_file: layout_file
        end
      end
    end
  end
end
