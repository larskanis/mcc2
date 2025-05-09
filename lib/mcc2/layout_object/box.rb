require "mcc2/layout_object/graphic"

module Mcc2
  module LayoutObject
    class Box < Graphic
      def initialize(xml_elem: nil, layout_file: nil)
        super
        @go_attributes[GOA_TYP].attr_value = BOXOBJECT
        add_attr(@go_attributes, GOA_WIDTH, Float, 30)
        add_attr(@go_attributes, GOA_HEIGHT, Float, 20)
        add_attr(@go_attributes, GOA_FILL_COLOR, String, "ffff00ff")
        add_attr(@go_attributes, GOA_BORDER_COLOR, String, "ff00ffff")
        add_attr(@go_attributes, GOA_BORDER_WIDTH, Float, 1)
        add_attr(@go_attributes, GOA_CORNER_RADIUS, Float, 4)
      end
    end
  end
end
