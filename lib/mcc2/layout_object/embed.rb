module Mcc2
  module LayoutObject
    class Embed < Graphic
      def initialize(xml_elem: nil, layout_file: nil)
        super
        @go_attributes[GOA_TYP].attr_value = EMBEDOBJECT
        add_position_fields
        add_attr(@go_attributes, GOA_WIDTH, Float, 30)
        add_attr(@go_attributes, GOA_HEIGHT, Float, 20)
        add_attr(@go_attributes, GOA_DATA, String, "")
        add_attr(@go_attributes, GOA_SAMPLE_DATA, String, "%D/")
      end
    end
  end
end
