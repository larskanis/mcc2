# -*- coding: UTF-8 -*-

require 'json'
require 'libcx320'
require 'mcc2/printer/card_printer'
require 'mcc2/printer/rmagick_drawer'


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

  def initialize(*args)
    super
    @first_card = true
  end

  def print_card(layout_file, row, chip)
    self.dpi = layout_file.get_attr_value(S_EPLPRINTER_DPI).to_f
    duplex = layout_file.get_attr_value(S_DUPLEX) == S_TRUE
    x_offset = layout_file.get_attr_value(S_X_OFFSET).to_f
    y_offset = layout_file.get_attr_value(S_Y_OFFSET).to_f
    parallel = case layout_file.get_attr_value(S_CX320_PARALLEL_PRINT)
      when 'off' then false
      when 'on' then true
      when 'second_card' then !@first_card
      else raise("invalid value for attr #{S_CX320_PARALLEL_PRINT}")
    end

    config = JSON.parse(layout_file.get_attr_value(S_CX320_CONFIG))

    front_layers = layout_file.get_layers_of_page(0)
    front_planes = generate_image_planes(layout_file, row, 0, front_layers, x_offset, y_offset)
    front_layer_syms = front_layers.map{|l| PrintLayers[l] }.compact.uniq

    if duplex
      back_layers = layout_file.get_layers_of_page(1)
      back_planes = generate_image_planes(layout_file, row, 1, back_layers, x_offset, y_offset)
      back_layer_syms = back_layers.map{|l| PrintLayers[l] }.compact.uniq
    end

    open_printer(layout_file) do |dev|
      # Aktuelle Konfig auslesen und mit gespeicherter Konfig vergleichen
      attrs = dev.mode_sense(:all) + dev.log_sense(:log)
      config_changed = attrs.find do |attr|
        value = config[attr.name.to_s]
        value && value != attr.value
      end
      if config_changed
        dev.mode_select(:print, config.select{|k,v| k.to_s =~ /^print_/ })
        dev.mode_select(:mag, config.select{|k,v| k.to_s =~ /^mag_/ })

        dev.rezero_unit
      end

      while_busy do
        dev.load_card(chip ? :contactless : :retransfer, false, false, parallel)
      end

      begin
        front_planes.each do |plane, data|
          dev.image_out(plane, data, 0) if data
        end

        if parallel
          # run printing in parallel to load_card and chip
          while_busy do
            dev.print(front_layer_syms, 0, parallel)
          end
        end

        if chip
          wait_for_card_position(dev, :contactless)
          begin
            # Kartenpersonalisierung
            chip.pers_card(layout_file, row)
          rescue Exception
            ignore_all_errors do
              while_busy do
                dev.move_card(:eject, false, false, true)
              end
            end
            raise
          end

          while_busy do
            dev.move_card(:retransfer, false)
          end
        end

        if !parallel
          dev.print(front_layer_syms, 0)
        end

        if duplex
          while_busy do
            dev.retransfer_and_turn(parallel)
          end

          back_planes.each do |plane, data|
            dev.image_out(plane, data, 1) if data
          end

          while_busy do
            dev.print(back_layer_syms, 1, parallel)
          end
          while_busy do
            dev.retransfer_and_eject(parallel)
          end
        else
          while_busy do
            dev.retransfer_and_eject(parallel)
          end
        end
      rescue
        ignore_all_errors do
          while_busy do
            dev.move_card(:eject, false, false, true)
          end
        end
        raise
      end
    end

    @first_card = false
    return true
  end

  def draw_rvg_image(layout_file, row, page, layers, x_offset, y_offset)
    Magick::RVG.new(1036, 664) do |canvas|
      canvas.background_fill = 'white'
      canvas.g.translate(mm(x_offset).round, mm(y_offset).round) do |canvas1|
        selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
        preview = false          # wird nur für Darstellung auf Bildschirm gebraucht

        draw(canvas1, layout_file, preview, selected_object_id, row, page, layers)
      end
    end.draw
  end

  def generate_image_planes(layout_file, row, page, layers, x_offset, y_offset)
    if layers.include?(0)
      pic = draw_rvg_image(layout_file, row, page, [0], x_offset, y_offset)

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
      pic = draw_rvg_image(layout_file, row, page, [1], x_offset, y_offset).negate
      data_k = pic.export_pixels_to_str(0, 0, pic.columns, pic.rows, "R", Magick::CharPixel)
    end

    if layers.include?(2)
      pic = draw_rvg_image(layout_file, row, page, [2], x_offset, y_offset).negate
      data_uv = pic.export_pixels_to_str(0, 0, pic.columns, pic.rows, "R", Magick::CharPixel)
    end

    if layers.include?(3)
      pic = draw_rvg_image(layout_file, row, page, [3], x_offset, y_offset).negate
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

  def while_busy
    begin
      yield
    rescue LibCX320::ErrorHandling::BusyError
      puts "Printer busy"
      sleep 0.1
      retry
    end
  end

  def ignore_all_errors
    begin
      yield
    rescue => e
      puts "Ignore error: #{e.class} #{e}"
    end
  end

  def wait_for_card_position(dev, pos)
    while dev.get_current_card_position[:position] != pos
      puts "Wait for card position #{pos}"
      sleep 0.1
    end
  end

  def open_printer(layout_file)
    printer_klass = LibCX320.const_get(layout_file.get_attr_value(S_CX320_DRIVER))
    printer_nr = layout_file.get_attr_value(S_CX320_PRINTER_NR).to_i
    dev = printer_klass.devices[printer_nr]
    raise "Printer #{printer_nr} not found" unless dev

    begin
      dev.ready?
      yield dev
    ensure
      dev.close
    end
  end

  def run_command(&block)
    open_printer(layout_file, &block)
  end

end
end
end
