# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class MyPrintDialogBox < PrintDialogBox
  def initialize(app, child)
    super(app)
    @app = app
    @matrix2.numColumns = 3
    @button_bottom.img = "t:\Project\Golfverband\Platzreifekarten\prog\batch-29420\dgv-28.jpeg"
    @button_top.img = ""
    @button_next.img = ""
    @button_prev.img = ""
  end
end


if __FILE__ == $0
end
