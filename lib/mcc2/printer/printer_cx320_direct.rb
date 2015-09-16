# -*- coding: UTF-8 -*-

require 'mcc2/printer/card_printer'
require 'mcc2/printer/rmagick_drawer'
require 'libcx320'


module Mcc2
module Printer
class PrinterCx320Direct < CardPrinter
  include RmagickDrawer

  attr_accessor :layout_file

  # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
  def card_margin_left; 0.8; end
  def card_margin_right; 0.8; end
  def card_margin_top; 0.8; end
  def card_margin_bottom; 0.8; end

  #--------------------------------------------------------------------------------------------------------------

  def print_card(layout_file, row, chip)
    self.dpi = layout_file.get_attr_value(S_EPLPRINTER_DPI).to_f

    page_width =  layout_file.get_attr_value(S_WIDTH).to_f + card_margin_left + card_margin_right
    page_height = layout_file.get_attr_value(S_HEIGHT).to_f + card_margin_top + card_margin_bottom
    draw_pos_x  = layout_file.get_attr_value(S_X_OFFSET).to_f - card_margin_left
    draw_pos_y  = layout_file.get_attr_value(S_Y_OFFSET).to_f - card_margin_top

    # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
    selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
    preview = false          # wird nur für Darstellung auf Bildschirm gebraucht
    img = Magick::RVG.new(mm(page_width - draw_pos_x), mm(page_height - draw_pos_y)) do |canvas|
      canvas.background_fill = 'white'
      draw(canvas, layout_file, preview, selected_object_id, row, 0)
    end

    # das RVG in ein Bitmap konvertieren
    pic = img.draw
    sized_pic = Magick::Image.new(1036, 664)
    sized_pic = sized_pic.composite(pic, Magick::CenterGravity, Magick::OverCompositeOp)

    gradient_pic = Magick::Image.new(256, 1)
    gradient = 0.upto(255).map do |i|
      a = (255-i) / 255.0 * Magick::QuantumRange
      [a, a, a]
    end
    gradient_pic.import_pixels(0, 0, 256, 1, "RGB", gradient.flatten)
    sized_pic = sized_pic.clut_channel(gradient_pic)

    data_c = sized_pic.export_pixels_to_str(0, 0, sized_pic.columns, sized_pic.rows, "R", Magick::CharPixel)
    data_m = sized_pic.export_pixels_to_str(0, 0, sized_pic.columns, sized_pic.rows, "G", Magick::CharPixel)
    data_y = sized_pic.export_pixels_to_str(0, 0, sized_pic.columns, sized_pic.rows, "B", Magick::CharPixel)

    p [data_c[0..60].unpack("H*")[0], data_c.bytesize]
    p [data_m[0..60].unpack("H*")[0], data_m.bytesize]
    p [data_y[0..60].unpack("H*")[0], data_y.bytesize]

    dev = LibCX320::CX320_USB.devices.first
    raise "printer not found" unless dev

    begin
      dev.ready?

      dev.image_out(:C, data_c)
      dev.image_out(:M, data_m)
      dev.image_out(:Y, data_y)

      dev.load_card(:retransfer, false)
      begin
        dev.print([:YMC])
        dev.retransfer_and_eject
      rescue
        dev.move_card(:eject)
      end
    ensure
      dev.close
    end

    return true
  end

end
end
end
