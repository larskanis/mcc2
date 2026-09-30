require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"
require "socket"
require "rmagick"

module Mcc2
  module Printer
    class PrinterCab < CardPrinter
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
        self.dpi = layout_file.get_attr_value(S_CABPRINTER_DPI).to_f

        page_commands = layout_file.get_attr_value(S_CABPRINTER_PAGE_COMMANDS)
        page_width = layout_file.get_attr_value(S_WIDTH).to_f
        page_height = layout_file.get_attr_value(S_HEIGHT).to_f
        draw_pos_x = layout_file.get_attr_value(S_X_OFFSET).to_f
        draw_pos_y = layout_file.get_attr_value(S_Y_OFFSET).to_f
        image_width = mm(page_width).round
        image_height = mm(page_height).round

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
        page_commands.gsub!("%PAGE_WIDTH%", page_width.to_s)
        page_commands.gsub!("%PAGE_HEIGHT%", page_height.to_s)
        page_commands.gsub!("%PAGE_OFFSET_X%", draw_pos_x.to_s)
        page_commands.gsub!("%PAGE_OFFSET_Y%", draw_pos_y.to_s)

        page_commands.gsub!("%IMAGE_DATA_PNG%") do
          pic = pic.quantize(2, Magick::RGBColorspace, false)
          data = pic.to_blob do |image|
            image.format = "png8"
          end
          data.gsub("\e", "\e\e")
        end

        page_commands.gsub!("%IMAGE_DATA_PCX%") do
          pic = pic.quantize(2, Magick::RGBColorspace, false)
          data = pic.to_blob do |image|
            image.format = "pcx"
          end
          data.gsub("\e", "\e\e")
        end

        open_socket(layout_file) do |sock|
          sock.write page_commands
        end

        true
      end

      #--------------------------------------------------------------------------------------------------------------

      def open_socket(layout_file)
        host = layout_file.get_attr_value(S_CABPRINTER_HOST)
        port = layout_file.get_attr_value(S_CABPRINTER_PORT).to_i
        sock = TCPSocket.open(host, port)
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
