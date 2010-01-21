# -*- coding: UTF-8 -*-

require 'mcc2/dataman/base'

module Mcc2
module DataMan
class None < Base
  def initialize(datasource)
  end
  
  def headers
  end

  # ---------------------------------------------------------------------------------------------------------
  def row(index)
    nil
  end
  # ---------------------------------------------------------------------------------------------------------
  def rows
    [nil]
  end

end
end
end
