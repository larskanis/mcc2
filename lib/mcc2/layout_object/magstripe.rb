# -*- coding: UTF-8 -*-

module Mcc2
module LayoutObject
class Magstripe
  def initialize(xml_elem=nil)
    @xml_elem = xml_elem
  end

  def [](attr)
    @xml_elem.at_xpath(attr).content
  end
end
end
end
