# -*- coding: UTF-8 -*-

module Mcc2
class MagstripeObject
  def initialize(xml_elem=nil)
    @xml_elem = xml_elem
  end

  def [](attr)
    @xml_elem.find_first(attr).content
  end
  
end
end
