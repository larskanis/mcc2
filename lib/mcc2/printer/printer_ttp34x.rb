require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"
require "socket"
require "rmagick"

module Mcc2
  module Printer
    class PrinterTTP34x < CardPrinter
      include RmagickDrawer

      # die Ränder außerhalb der Karte, auf den maximal gedruckt werden darf (für vollflächige Bilder notwendig)
      def card_margin_left
        0
      end

      def card_margin_right
        0
      end

      def card_margin_top
        0
      end

      def card_margin_bottom
        0
      end

      #--------------------------------------------------------------------------------------------------------------

      def print_card(layout_file, row)
        self.dpi = layout_file.get_attr_value(S_TTP34XPRINTER_DPI).to_f

        page_commands = layout_file.get_attr_value(S_TTP34XPRINTER_PAGE_COMMANDS)
        page_width = layout_file.get_attr_value(S_WIDTH).to_f
        page_height = layout_file.get_attr_value(S_HEIGHT).to_f
        draw_pos_x = layout_file.get_attr_value(S_X_OFFSET).to_f
        draw_pos_y = layout_file.get_attr_value(S_Y_OFFSET).to_f
        image_width = mm(page_width - draw_pos_x).round
        image_height = mm(page_height - draw_pos_y).round

        surface = Cairo::ImageSurface.new(Cairo::FORMAT_RGB24, image_width, image_height)
        surface.set_fallback_resolution(dpi, dpi)
        Cairo::Context.new(surface) do |context|
          context.set_source_rgb(1.0, 1.0, 1.0) # make white background
          context.paint

          svg_data = Nokogiri::XML::Builder.new do |svg|
            svg.svg(xmlns: 'http://www.w3.org/2000/svg', viewBox: "0 0 #{image_width} #{image_height}") do
              tra = Transformation.new
              draw(svg, tra, layout_file, false, nil, row, 0)
            end
          end.to_xml
          svg_handle = RSVG::Handle.new_from_data(svg_data)
          context.render_rsvg_handle(svg_handle)
        end

        # Convert to ImageMagick image
        # "BGRA" matches the byte ordering of Cairo's FORMAT_ARGB32
        pic = Magick::Image.from_blob(surface.data) do |options|
          options.format = 'BGRA'
          options.size = "#{image_width}x#{image_height}"
          options.depth = 8 # Bits per pixel channel
        end.first

        page_commands.gsub!("\\e", "\e")
        page_commands.gsub!("\n", "\r\n")
        page_commands.gsub!("%PAGE_WIDTH_MM%", page_width.to_s)
        page_commands.gsub!("%PAGE_HEIGHT_MM%", page_height.to_s)
        page_commands.gsub!("%PAGE_WIDTH_PX%", mm(page_width).to_i.to_s)
        page_commands.gsub!("%PAGE_HEIGHT_PX%", mm(page_height).to_i.to_s)
        page_commands.gsub!("%PAGE_OFFSET_X_MM%", draw_pos_x.to_s)
        page_commands.gsub!("%PAGE_OFFSET_Y_MM%", draw_pos_y.to_s)
        page_commands.gsub!("%PAGE_OFFSET_X_PX%", mm(draw_pos_x).to_i.to_s)
        page_commands.gsub!("%PAGE_OFFSET_Y_PX%", mm(draw_pos_y).to_i.to_s)

        page_commands.gsub!("%IMAGE_LEN_DATA_PCX%") do
          pic = pic.quantize(2, Magick::RGBColorspace, false)
          pic = pic.level2(Magick::QuantumRange / 2, Magick::QuantumRange / 2)
          pic = pic.quantize(2, Magick::RGBColorspace, false)
          pic = pic.level2(Magick::QuantumRange / 2, Magick::QuantumRange / 2)
          pic.class_type = Magick::PseudoClass
          pic.image_type = Magick::BilevelType
          # wir müssen die Farben invertieren, da TTP anscheinend das Negativ druckt !!!
          pic_negate = pic.negate
          data = pic_negate.to_blob do |image|
            image.format = "pcx"
          end

          # pic_negate.display # bitte NUR unter LINUX aktivieren
          # File.write("TSC-TTP346M.pcx", data)

          "#{data.bytesize},#{data}"
        end

        open_socket(layout_file) do |sock|
          sock.write page_commands
        end

        true
      end

      #--------------------------------------------------------------------------------------------------------------

      def open_socket(layout_file)
        dev = layout_file.get_attr_value(S_TTP34XPRINTER_DEVICE)
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
          yield sock if block
        end
      end
    end
  end
end
