require "mcc2/layout_object/graphic"

module Mcc2
  module LayoutObject
    class Barcode < Graphic
      def initialize(xml_elem = nil)
        super
        @go_attributes[GOA_TYP].attr_value = BARCODEOBJECT
        add_attr(@go_attributes, GOA_WIDTH, Integer, 30)
        add_attr(@go_attributes, GOA_HEIGHT, Integer, 15)
        add_attr(@go_attributes, GOA_DATA, String, "")
        add_attr(@go_attributes, GOA_SAMPLE_DATA, String, "123456789012")
        add_attr(@go_attributes, GOA_BARCODE_TYP, String, "EAN13")
        add_attr(@go_attributes, GOA_BARCODE_HEIGHT, Integer, 50)
        add_attr(@go_attributes, GOA_BARCODE_OPTIMIZED, String, true)
        add_attr(@go_attributes, GOA_FONT_HEIGHT, Integer, 10)
        add_attr(@go_attributes, GOA_FONT_TYP, String, "Arial")
        add_attr(@go_attributes, GOA_FONT_COLOR, String, "000000FF")
        add_attr(@go_attributes, GOA_FONT_FILE, String, "")
        add_attr(@go_attributes, GOA_BACK_COLOR, String, "FFFFFFFF")
        add_attr(@go_attributes, GOA_FONT_WEIGHT, Integer, 0)
        add_attr(@go_attributes, GOA_BAR_RATIO, Integer, 2)
        add_attr(@go_attributes, GOA_JUSTIFICATION, Integer, 0)
      end
    end
  end
end

if __FILE__ == $0
  bo = BarcodeObject.new
  bo.go_attributes.each { |e| p e }
end
