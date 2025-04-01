require "mcc2/layout_object/graphic"

module Mcc2
  module LayoutObject
    class Picture < Graphic
      def initialize(xml_elem = nil)
        super
        @go_attributes[GOA_TYP].attr_value = PICTUREOBJECT
        add_attr(@go_attributes, GOA_WIDTH, Integer, 20)
        add_attr(@go_attributes, GOA_HEIGHT, Integer, 28)
        add_attr(@go_attributes, GOA_IMAGE_PAGE, Integer, 1)
        add_attr(@go_attributes, GOA_DATA, String, "")
        add_attr(@go_attributes, GOA_SAMPLE_DATA, String, File.join(File.dirname(__FILE__), "../../../test/layouts/bart_simpson.png"))
      end
    end
  end
end

if __FILE__ == $0
  po = PictureObject.new
  po.go_attributes.each { |e| p e }
end
