require "mcc2/printer/card_printer"
require "mcc2/printer/svg_drawer"

module Mcc2
  module Printer
    class FilePrinter < CardPrinter
      include SvgDrawer

      def initialize
        super
        @image_idx = 0
        @context = nil
      end

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
        chip = layout_file.build_chip_instance
        @layout_file = layout_file
        self.dpi = @layout_file.get_attr_value(S_FILEPRINTER_DPI).to_f

        print_page(row, 0)
        if layout_file.get_attr_value(S_DUPLEX) == S_TRUE
          print_page(row, 1)
        end

        chip&.pers_chip(row)

        @image_idx += 1

        true
      end

      def print_page(row, page_nr)
        page_width = @layout_file.get_attr_value(S_WIDTH).to_f
        page_height = @layout_file.get_attr_value(S_HEIGHT).to_f
        draw_pos_x = @layout_file.get_attr_value(S_X_OFFSET).to_f
        draw_pos_y = @layout_file.get_attr_value(S_Y_OFFSET).to_f
        image_width = mm(page_width).round
        image_height = mm(page_height).round

        row_idx = row["row_number"] if row
        documentName = @layout_file.get_attr_value(S_FILEPRINTER_SAVE_AS).gsub("%i", @image_idx.to_s).gsub("%p", page_nr.to_s).gsub("%d", row_idx.to_s)
        documentName = @layout_file.expand_path(documentName)
        fileext = File.extname(documentName).downcase

        change_context = @last_documentName != documentName
        if @context
          if change_context
            @context.finish_print
            @context = nil
          else
            @context.show_page
          end
        end

        if !@context
          if %w[.pdf].include?(fileext)
            surface = Cairo::PDFSurface.new(documentName, mm_to_pt(page_width), mm_to_pt(page_height))
            surface.set_fallback_resolution(dpi, dpi)
            surface.define_singleton_method(:finish_print){ finish }
          elsif %w[.png].include?(fileext)
            surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, image_width, image_height)
            surface.define_singleton_method(:finish_print) do
              write_to_png(documentName)
              finish
            end
          elsif %w[.svg].include?(fileext)
            surface = Cairo::SVGSurface.new(documentName, image_width, image_height)
            surface.define_singleton_method(:finish_print){ finish }
          else
            require "rmagick"

            surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, image_width, image_height)
            dens = "#{dpi}x#{dpi}"
            surface.define_singleton_method(:finish_print) do
              # Convert to ImageMagick image
              # "BGRA" matches the byte ordering of Cairo's FORMAT_ARGB32
              image = Magick::Image.from_blob(surface.data) do |options|
                options.format = 'BGRA'
                options.size = "#{image_width}x#{image_height}"
                options.depth = 8 # Bits per pixel channel
              end.first
              # Configure and save the image in the requested file format
              image.write(documentName) do |img|
                img.density = dens
              end

              finish
            end
          end
          @context = Cairo::Context.new(surface)
          @context.define_singleton_method(:finish_print) do
            target.finish_print
          end
        end

        # Create an SVG document with all the objects on it
        if @context.target.is_a?(Cairo::PDFSurface)
          # TODO where comes the factor 0.8 from?
          svg_attrs = {width: "#{page_width*0.8}mm", height: "#{page_height*0.8}mm"}
        end
        svg_data = svg_builder(viewBox: "0 0 #{image_width} #{image_height}", **svg_attrs) do |svg|
          tra = Transformation.new
          draw(svg, tra.translate(mm(draw_pos_x).round, mm(draw_pos_y).round), layout_file, false, nil, row, page_nr)
        end
        svg_handle = RSVG::Handle.new_from_data(svg_data)
        @context.render_rsvg_handle(svg_handle)

        @last_documentName = documentName
      end

      def close
        @context&.finish_print
      end
    end
  end
end
