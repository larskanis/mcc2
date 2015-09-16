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

  PrintLayers = {
    0 => :YMC,
    1 => :K,
    2 => :UV,
    3 => :PeelOff,
  }

  def print_card(layout_file, row, chip)
    self.dpi = layout_file.get_attr_value(S_EPLPRINTER_DPI).to_f
    duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE

    front_layers = layout_file.get_layers_of_page(0)
    front_planes = generate_image_planes(layout_file, row, 0, front_layers)
    front_layer_syms = front_layers.map{|l| PrintLayers[l] }.uniq

    if duplex
      back_layers = layout_file.get_layers_of_page(1)
      back_planes = generate_image_planes(layout_file, row, 1, back_layers)
      back_layer_syms = back_layers.map{|l| PrintLayers[l] }.uniq
    end

    dev = LibCX320::CX320_USB.devices.first
    raise "Printer not found" unless dev

    begin
      dev.ready?

      if chip
        dev.load_card(:contactless, false)
      else
        dev.load_card(:retransfer, false)
      end

      front_planes.each do |plane, data|
        dev.image_out(plane, data) if data
      end

      if chip
        begin
          # Kartenpersonalisierung
          chip.pers_card(layout_file, row)
        rescue Exception
          dev.move_card(:eject, false)
          raise
        end

        dev.move_card(:retransfer, false)
      end
      begin
        dev.print(front_layer_syms)

        if duplex
          dev.retransfer_and_turn

          back_planes.each do |plane, data|
            dev.image_out(plane, data) if data
          end

          dev.print(back_layer_syms)
          dev.retransfer_and_eject
        else
          dev.retransfer_and_eject
        end
      rescue
        dev.move_card(:eject)
      end
    ensure
      dev.close
    end

    return true
  end

  def generate_image_planes(layout_file, row, page, layers)
    # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
    selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
    preview = false          # wird nur für Darstellung auf Bildschirm gebraucht

    if layers.include?(0)
      img = Magick::RVG.new(1036, 664) do |canvas|
        canvas.background_fill = 'white'
        draw(canvas, layout_file, preview, selected_object_id, row, page, [0])
      end
      # das RVG in ein Bitmap konvertieren
      pic = img.draw

      gradient_pic = Magick::Image.new(256, 1)
      gradient = 0.upto(255).map do |i|
        a = (255-i) / 255.0 * Magick::QuantumRange
        [a, a, a]
      end
      gradient_pic.import_pixels(0, 0, 256, 1, "RGB", gradient.flatten)
      pic = pic.clut_channel(gradient_pic)

      data_c, data_m, data_y = ["R", "G", "B"].map do |color|
        pic.export_pixels_to_str(0, 0, pic.columns, pic.rows, color, Magick::CharPixel)
      end
    end

    if layers.include?(1)
      pic = Magick::RVG.new(1036, 664) do |canvas|
        canvas.background_fill = 'white'
        draw(canvas, layout_file, preview, selected_object_id, row, page, [1])
      end.draw.negate
      data_k = pic.export_pixels_to_str(0, 0, pic.columns, pic.rows, "R", Magick::CharPixel)
    end

    if layers.include?(2)
      pic = Magick::RVG.new(1036, 664) do |canvas|
        canvas.background_fill = 'white'
        draw(canvas, layout_file, preview, selected_object_id, row, page, [2])
      end.draw.negate
      data_uv = pic.export_pixels_to_str(0, 0, pic.columns, pic.rows, "R", Magick::CharPixel)
    end

    if layers.include?(3)
      pic = Magick::RVG.new(1036, 664) do |canvas|
        canvas.background_fill = 'white'
        draw(canvas, layout_file, preview, selected_object_id, row, page, [3])
      end.draw.negate
      data_peeloff = pic.export_pixels_to_str(0, 0, pic.columns, pic.rows, "R", Magick::CharPixel)
    end

    [data_c, data_m, data_y, data_k, data_uv, data_peeloff].each do |data|
      raise "internal error unexpected size #{data.bytesize}" if data && data.bytesize != 1036*664
    end

    return {
      C: data_c,
      M: data_m,
      Y: data_y,
      K: data_k,
      UV: data_uv,
      PeelOff: data_peeloff,
    }
  end

end
end
end
