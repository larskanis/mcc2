# -*- coding: UTF-8 -*-

require 'mcc2/printer/card_printer'
require 'mcc2/printer/rmagick_drawer'
require 'socket'


module Mcc2
module Printer
class PrinterEpl < CardPrinter
  include RmagickDrawer

  attr_accessor :layout_file

  # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
  def card_margin_left; 0; end
  def card_margin_right; 0; end
  def card_margin_top; 0; end
  def card_margin_bottom; 0; end

  #--------------------------------------------------------------------------------------------------------------

  def print_card(layout_file, row, chip)
    self.dpi = layout_file.get_attr_value(S_EPLPRINTER_DPI).to_f

    page_commands = layout_file.get_attr_value(S_EPLPRINTER_PAGE_COMMANDS)
    page_width =  layout_file.get_attr_value(S_WIDTH).to_f
    page_height = layout_file.get_attr_value(S_HEIGHT).to_f
    draw_pos_x  = layout_file.get_attr_value(S_X_OFFSET).to_f
    draw_pos_y  = layout_file.get_attr_value(S_Y_OFFSET).to_f

    # ein Bild als RVG (Vektorgraphik) erzeugen, auf dem alle Objekte plaziert sind
    selected_object_id = nil # wird nur für Darstellung auf Bildschirm gebraucht
    preview = false          # wird nur für Darstellung auf Bildschirm gebraucht
    img = Magick::RVG.new(mm(page_width), mm(page_height)) do |canvas|
      canvas.background_fill = 'white'
      draw(canvas, layout_file, preview, selected_object_id, row, 0)
    end

    # das RVG in ein Bitmap konvertieren
    pic = img.draw

    page_commands.gsub!("\\e", "\e")
    page_commands.gsub!("\n", "\r\n")
    page_commands.gsub!("%PAGE_WIDTH%", page_width.to_s)
    page_commands.gsub!("%PAGE_HEIGHT%", page_height.to_s)
    page_commands.gsub!("%PAGE_OFFSET_X%", draw_pos_x.to_s)
    page_commands.gsub!("%PAGE_OFFSET_Y%", draw_pos_y.to_s)

    page_commands.gsub!("%IMAGE_LEN_DATA_PCX%") do
      pic = pic.quantize(2, Magick::RGBColorspace, false)
      pic = pic.level2(1,1)
      data = pic.to_blob do
        self.format='pcx'
      end
      "#{data.bytesize}\r\n#{data}"
    end

    p page_commands

    open_socket(layout_file) do |sock|
      sock.write page_commands
    end

    return true
  end

  #--------------------------------------------------------------------------------------------------------------

  def open_socket(layout_file)
    dev = layout_file.get_attr_value(S_EPLPRINTER_DEVICE)
    sock = File.open(dev, "wb")
    if block_given?
      begin
        return yield(sock)
      ensure
        sock.close
      end
    end
    sock
  end
  private :open_socket

  def send_command(layout_file, data, &block)
    open_socket(layout_file) do |sock|
      sock.write data
      yield sock if block_given?
    end
  end
end
end
end
