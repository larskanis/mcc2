require "mcc2/dataman/base"
require "rmagick"           # für das Erzeugen der Druckbilder

module Mcc2
  module RmagickDrawer
    class ObjRectangle
      def initialize(v1, v2, v3, v4, obj_id)
        @v1 = v1
        @v2 = v2
        @v3 = v3
        @v4 = v4
        @obj_id = obj_id
      end

      private def sign(p1, p2, p3)
        (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
      end

      def point_inside(pt)
        d1 = sign(pt, @v1, @v2);
        d2 = sign(pt, @v2, @v3);
        d3 = sign(pt, @v3, @v4);
        d4 = sign(pt, @v4, @v1);

        has_neg = (d1 < 0) || (d2 < 0) || (d3 < 0) || (d4 < 0);
        has_pos = (d1 > 0) || (d2 > 0) || (d3 > 0) || (d4 > 0);

        return !(has_neg && has_pos);
      end

      attr_reader :obj_id
    end

    class ObjRectangeList
      def initialize
        @objs = []
      end

      def add(rect)
        if rect.is_a?(self.class)
          @objs += rect.objs
        else
          @objs << rect
        end
      end

      def point_inside(pt)
        @objs.select do |obj|
          obj.point_inside(pt)
        end
      end

      attr_reader :objs
    end

    def width_with_margins(width)
      width + card_margin_left + card_margin_right
    end

    def height_with_margins(height)
      height + card_margin_bottom + card_margin_top
    end

    def draw(drawing, transform, layout_file, preview, selected_object_id, row, page_nr, layers: [0])
      @magick_font_list ||= Magick.fonts.map { |mf| mf.name }
      barcode_dpi = layout_file.get_attr_value(S_BARCODE_DPI).to_f
      rect_list = ObjRectangeList.new

      width = layout_file.get_attr_value(S_WIDTH).to_f
      height = layout_file.get_attr_value(S_HEIGHT).to_f
      if preview
        # todo -0.5, damit die rechten und unteren Ränder zu sehen sind, jetzt sitzt die Karte aber unsymetrisch auf dem Rechteck
        drawing.fill('none')
        drawing.stroke('black')
        cpos = transform.translate(mm(width_with_margins(width - 0.5)), mm(height_with_margins(height - 0.5)))
        drawing.rectangle(transform.x, transform.y, cpos.x, cpos.y)
        # canvas.rect(mm(width_with_margins(width - 0.5)), mm(height_with_margins(height - 0.5))).styles(fill: "none", stroke: "black")
      end

      tra = transform.translate(mm(card_margin_left).round, mm(card_margin_top).round)
      # Kartenhintergrund füllen (für Vorschau)
      rx = mm(3)
      if preview
        drawing.fill('lightgray')
        drawing.stroke('none')
        cpos = tra.translate(mm(width), mm(height))
        drawing.roundrectangle(tra.x, tra.y, cpos.x, cpos.y, rx, rx)
        # canvas1.rect(mm(width), mm(height)).round(rx).styles(fill: "lightgray", stroke: "none")
      end
      # die graphischen Elemnte zeichnen

      # Text-Objekte
      sorted_id_list = layout_file.sorted_id_list
      sorted_id_list.each do |id|
        go = layout_file.find_graphic_object_by_id(id)
        # nur die Objekte zeichnen, die auf diese Seite sollen
        if go[GOA_PAGE_NR].to_i == page_nr && (layers == :all || layers.include?(go[GOA_LAYER].to_i))

          # die allgemeinen Attribute ermitteln
          #           id = go[GOA_ID].to_i
          x = go[GOA_X].to_f
          y = go[GOA_Y].to_f
          go_width = go[GOA_WIDTH].to_f
          go_height = go[GOA_HEIGHT].to_f
          rotation = go[GOA_ROTATION].to_f
          typ = go[GOA_TYP]

          if !go[GOA_DATA]
            data = nil
          elsif row && (row.keys - DataMan.meta_headers).any?
            data = DataMan.replace_variables(go[GOA_DATA], row)
          elsif go[GOA_DATA]
            data_nosub = go[GOA_DATA].to_s
            data = go[GOA_SAMPLE_DATA].to_s
          end

          if tra
            rec = tra.translate(mm(x).round, mm(y).round).rotate(rotation)
            # Text is written on top of the basis object point, so add the fontsize to the click box
            text_y = typ == TEXTOBJECT ? pt(go[GOA_FONT_HEIGHT].to_f) : 0
            rec1 = rec.translate(0, -text_y)
            rec2 = rec1.translate(mm(go_width), 0)
            rec3 = rec1.translate(mm(go_width), mm(go_height) + text_y)
            rec4 = rec1.translate(0, mm(go_height) + text_y)
            orec = ObjRectangle.new(rec1.vector2d, rec2.vector2d, rec3.vector2d, rec4.vector2d, id)
            rect_list.add(orec)
          end

          drawing.push
          # die Objekt-spezifischen Attribute ermitteln
          if typ == TEXTOBJECT
            draw_textobject(drawing, rec, go, go_width, go_height, data.empty? ? data_nosub : data)
          elsif typ == PICTUREOBJECT
            draw_pictureobject(drawing, rec, go, go_width, go_height, data)
          elsif typ == BARCODEOBJECT
            data = data.gsub(/\\x([0-9a-f][0-9a-f])/i) { [$1.hex].pack("C") }
            draw_barcode(drawing, rec, go, go_width, go_height, data, barcode_dpi)
          elsif typ == BOXOBJECT
            draw_boxobject(drawing, rec, go, go_width, go_height)
          elsif typ == EMBEDOBJECT
            draw_embedobject(drawing, rec, go, go_width, go_height, data, row ? row['row_number'] : "1", barcode_dpi)
          end
          drawing.pop

          # in Vorschau einen Rahmen um das selektierte Objekt zeichnen
          if preview && selected_object_id == id
            drawing.push
            drawing.fill('none')
            drawing.stroke('red')
            cpos = rec.translate(mm(go_width), mm(go_height))
            drawing.rectangle(rec.x, rec.y, cpos.x, cpos.y)
            # body.rect(mm(go_width), mm(go_height)).styles(fill: "none", stroke: "red")
            drawing.pop
          end
        end
      end

      # Rand zeichnen (für Vorschau)
      if preview
        drawing.fill('none')
        drawing.stroke('blue')
        cpos = tra.translate(mm(width), mm(height))
        drawing.roundrectangle(tra.x, tra.y, cpos.x, cpos.y, rx, rx)
        # canvas1.rect(mm(width), mm(height)).round(rx).styles(fill: "none", stroke: "blue")
        # if page_nr == 1 && layout_file.get_attr_value(S_MAGSTRIPE) == S_TRUE
        #   canvas1.g.translate(mm(0), mm(4)) { |ms_rect|
        #     ms_rect.rect(mm(width), mm(12.5)).styles(fill: "black", stroke: "none", opacity: 0.5)
        #     ms_obj = layout_file.magstripe_object
        #     (1..3).each { |spurnr|
        #       spur_data = ms_obj["ms_spur" + spurnr.to_s]
        #       ms_rect.text(mm(3), mm((3.5 * spurnr) + 0.5), "Spur #{spurnr}: #{spur_data}").styles(
        #         font: "Courier-New-Bold",
        #         font_size: pt(10),
        #         fill: "white"
        #       )
        #     }
        #   }
        # end
        # if page_nr == 0 && layout_file.get_attr_value(S_CONTACTLESS) == S_TRUE
        #   rx = mm(0.5)
        #   canvas1.g.translate(mm(3), mm(3)).rect(mm(5), mm(5)).round(rx).styles(fill: "gray", stroke: "none", opacity: 0.5)
        #   rx = mm(3)
        #   canvas1.g.translate(mm(4), mm(4)).rect(mm(75), mm(45)).round(rx).styles(fill: "none", stroke: "gray", stroke_opacity: 0.5)
        #   canvas1.g.translate(mm(5), mm(5)).rect(mm(73), mm(43)).round(rx).styles(fill: "none", stroke: "gray", stroke_opacity: 0.5)
        #   canvas1.g.translate(mm(6), mm(6)).rect(mm(71), mm(41)).round(rx).styles(fill: "none", stroke: "gray", stroke_opacity: 0.5)
        # end
        # if page_nr == 0 && layout_file.get_attr_value(S_CONTACT) == S_TRUE
        #   rx = mm(2)
        #   canvas1.g.translate(mm(8), mm(18)).rect(mm(13), mm(12)).round(rx).styles(fill: "yellow", stroke: "gray")
        # end
      end

      rect_list
    end

    def draw_textobject(drawing, tra, go, go_width, go_height, data)
      font = go[GOA_FONT_TYP]
      if font == "from_file"
        font = go.layout_file.expand_path(go[GOA_FONT_FILE])
      end
      fontsize = go[GOA_FONT_HEIGHT].to_f
      font_color = ["#", go[GOA_FONT_COLOR]].join
      just = go[GOA_JUSTIFICATION].downcase
      if just == "links"
        text_x = 0
        just = Magick::StartAnchor
      elsif just == "mitte"
        text_x = go_width.to_f / 2
        just = Magick::MiddleAnchor
      elsif just == "rechts"
        text_x = go_width
        just = Magick::EndAnchor
      else
        just = Magick::StartAnchor # falls eine fehlerhafte Ausrichtung eingegeben wurde, wird einfach links ausgerichtet
      end

      unless @magick_font_list.index(font) || File.exist?(font)
        raise Printer::Base::ResourceNotFoundError, "Die Schriftart '#{font}' konnte nicht gefunden werden. Der Druck wird angehalten."
      end

      if data && !data.empty?
        drawing.font font
        drawing.font_size pt(fontsize)
        drawing.fill font_color
        drawing.text_anchor just
        drawing.rotate tra.a
        apos = tra.inverse.translate(mm(text_x), mm(0))
        drawing.text(apos.x, apos.y, data)
        # body.text(mm(text_x), mm(0), data).styles(
        #   font: font,
        #   font_size: pt(fontsize),
        #   fill: font_color,
        #   text_anchor: just
        # )
      end
    end

    def draw_pictureobject(drawing, tra, go, go_width, go_height, data)
      if data.nil? || data.empty? || (data.tr("\\", "/") =~ /\/$/)
        # kein Bildname angegeben -> dieses Objekt ignorieren
      elsif (path=go.layout_file.expand_path(data)) && FileTest.file?(path)
        self_dpi = dpi
        image_page = go[GOA_IMAGE_PAGE].to_i - 1
        go_image = Magick::ImageList.new(path) { |img|
          # use view DPI for vector-graphics (PDF)
          img.density = self_dpi
        }[image_page]

        # workaround: ImageMagick uses wrong colors when inserting into RVG
        if defined?(Magick::ColorSeparationMatteType)
          if [Magick::ColorSeparationType, Magick::ColorSeparationMatteType].include?(go_image.image_type)
            go_image.image_type = Magick::TrueColorMatteType
          end
        end

        # if object size is not given, try to determine object size based on the DPI of the image
        im_width = (go_width == 0 && go_image.x_resolution > 0) ? go_image.columns / go_image.x_resolution * 25.4 : go_width
        im_height = (go_height == 0 && go_image.y_resolution > 0) ? go_image.rows / go_image.y_resolution * 25.4 : go_height

        cpos = tra.translate(mm(im_width), mm(im_height))
        drawing.composite(tra.x, tra.y, cpos.x, cpos.y, go_image)
        # body.image(go_image, mm(im_width), mm(im_height))
      else
        raise Printer::Base::ResourceNotFoundError, "Das Bild '#{path}' konnte nicht gefunden werden. Der Druck wird angehalten."
      end
    end

    BARCODE_ALIAS = {
      EAN13: :Eanx,
      EAN8: :Eanx
    }

    HALIGNMENT = {
      0 => Magick::MiddleAnchor,
      1 => Magick::StartAnchor,
      2 => Magick::EndAnchor
    }

    def draw_barcode(drawing, tra, go, go_width, go_height, data, barcode_dpi)
      return if data.nil? || data.empty?

      barcode_typ = go[GOA_BARCODE_TYP]
      bar_ratio = go[GOA_BAR_RATIO].to_i
      fontname = go[GOA_FONT_TYP]
      if fontname == "from_file"
        fontname = go.layout_file.expand_path(go[GOA_FONT_FILE])
      end
      fontsize = go[GOA_FONT_HEIGHT].to_f
      font_color = ["#", go[GOA_FONT_COLOR]].join

      unless @magick_font_list.index(fontname) || File.exist?(fontname)
        raise Printer::Base::ResourceNotFoundError, "Die Schriftart '#{fontname}' konnte nicht gefunden werden. Der Druck wird angehalten."
      end

      drawing.fill(font_color)
      drawing.stroke('none')
      drawing.font(fontname)
      drawing.font_size(pt(fontsize))

      begin
        barcode = Zint.const_get(BARCODE_ALIAS[barcode_typ.to_sym] || barcode_typ).new(value: data)
      rescue => e
        raise Printer::Base::InvalidBarcodeData, "Fehler beim Generieren des Barcodes #{data.inspect}: #{e}"
      else
        # TODO: bar_ratio wird nicht gesetzt
        # barcode.narrow_width = 1
        # barcode.wide_width = bar_ratio
        barcode.input_mode = Zint::DATA_MODE #  Zint::UNICODE_MODE | Zint::ESCAPE_MODE
        # barcode.output_options = Zint::SMALL_TEXT

        # 50 is the default x-dimension for most of the 1D barcodes:
        barcode.height = go[GOA_BARCODE_HEIGHT].to_f if go[GOA_BARCODE_HEIGHT].to_f.round(3) != 0
        barcode.show_hrt = 0 if fontsize == 0
        # barcode.fontsize = fontsize # not used in zint
        # p [go_height, go_width, barcode.height]
        barcode.whitespace_width = 0
        begin
          bcvector = barcode.to_vector
        rescue Zint::ErrorInvalidData => err
          raise err, "#{err.message} Barcode text: #{data.inspect}"
        end

        eancode = %w[EAN13 EAN8].include?(barcode_typ)

        # bcvector values are always a multiple of 2 or more, but we need a multiple of 1 for to_i below.
        # So all bcvector measurements are divided by 2 or more.
        xgran = bcvector.width.round / barcode.width
        ygran = bcvector.height.round / barcode.rows
        xbars, ybars = bcvector.width / xgran, bcvector.height / ygran
        # p vector_width: bcvector.width, vector_height: bcvector.height

        optimized = (go[GOA_BARCODE_OPTIMIZED] || true).to_s == "true"
        px_width, px_height = barcode_mm_to_px(go_width, barcode_dpi), barcode_mm_to_px(go_height, barcode_dpi)
        xdim, ydim = px_width / xbars, px_height / ybars
        if optimized
          xdim = xdim.to_i
          ydim = ydim.to_i if barcode.rows > 1 # optimize y dimension only on 2D codes
        end
        go_width, go_height = barcode_px_to_mm(xdim * xbars, barcode_dpi), barcode_px_to_mm(ydim * ybars, barcode_dpi)
        px_width, px_height = mm(go_width), mm(go_height)
        xdim, ydim = px_width / xbars, px_height / ybars

        bcvector.each_rectangle do |bar|
          # p [bar.x, bar.y, bar.width, bar.height]
          # p [xdim*bar.width/xgran, ydim*bar.height/ygran, xdim*bar.x/xgran, ydim*bar.y/ygran]
          apos = tra.translate(xdim * bar.x / xgran, ydim * bar.y / ygran)
          cpos = apos.translate([xdim * bar.width / xgran - 1, 0].max, [ydim * bar.height / ygran - 1, 0].max)
          # p [optimized, apos.x, apos.y, cpos.x, cpos.y]
          drawing.rectangle(apos.x, apos.y, cpos.x, cpos.y)
          # body.rect([xdim * bar.width / 2 - 1, 0].max, [ydim * bar.height / 2 - 1, 0].max, xdim * bar.x / 2, ydim * bar.y / 2)
        end
        bcvector.each_string do |str|
          # p [str.x, str.y, str.text, str.halign, str.fsize]
          drawing.text_anchor(HALIGNMENT[str.halign])
          apos = tra.translate(xdim * str.x / xgran, ydim * str.y / ygran)
          drawing.text(apos.x, apos.y, str.text)
          # body.text(xdim * str.x / 2, ydim * str.y / 2, str.text).styles(text_anchor: HALIGNMENT[str.halign])
        end
      end
    end

    def barcode_mm_to_px(l, barcode_dpi)
      barcode_dpi / 25.4 * l
    end

    def barcode_px_to_mm(l, barcode_dpi)
      l / barcode_dpi * 25.4
    end

    def draw_boxobject(drawing, tra, go, go_width, go_height)
      corner_radius = go[GOA_CORNER_RADIUS].to_f
      fill_color = go[GOA_FILL_COLOR]
      border_color = go[GOA_BORDER_COLOR]
      border_width = go[GOA_BORDER_WIDTH].to_f

      drawing.fill "#" + fill_color
      drawing.stroke "#" + border_color
      drawing.stroke_width mm(border_width).round
      drawing.roundrectangle(tra.x, tra.y, tra.x + mm(go_width).round, tra.y + mm(go_height).round, mm(corner_radius), mm(corner_radius))
      # body.rect(mm(go_width).round, mm(go_height).round).round(mm(corner_radius)).styles(fill: "#" + fill_color, stroke: "#" + border_color, stroke_width: mm(border_width).round)
    end

    def draw_embedobject(drawing, tra, go, go_width, go_height, data, row_number, barcode_dpi)
      if data.nil? || data.empty? || (data.tr("\\", "/") =~ /\/$/)
        # kein Layout angegeben -> dieses Objekt ignorieren
      elsif (path=go.layout_file.expand_path(data)) && FileTest.file?(path)
        layout_file = LayoutFile.load_from_xml(path, go.layout_file.xpath_changes)

        barcode_dpi2 = layout_file.get_attr_value(S_BARCODE_DPI).to_f
        unless ((barcode_dpi - 0.01) .. (barcode_dpi + 0.01)) === barcode_dpi2
          raise Printer::Base::DpiDoesntMatch, "Barcode-DPI in der Vorschau (#{format("%0.1f", barcode_dpi)}) und #{go[GOA_NAME].inspect} (#{format("%0.1f", barcode_dpi2)}) sind verschieden. Bitte DPI anpassen und Barcodes neu prüfen!"
        end

        obj_w = layout_file.get_attr_value(S_WIDTH).to_f
        obj_h = layout_file.get_attr_value(S_HEIGHT).to_f

        num_w = (go_width / obj_w).round
        num_h = (go_height / obj_h).round
        num_up = num_h * num_w

        dataman = layout_file.build_dataman_instance
        row_num = row_number.to_i - 1

        page_nr = 0
        num_w.times do |idx_w|
          num_h.times do |idx_h|
            if row_num >= 0
              row = dataman.row(row_num * num_up + idx_h * num_w + idx_w)
              if row
                elpos = tra.translate(mm(idx_w * obj_w).round, mm(idx_h * obj_h).round)
                draw(drawing, elpos, layout_file, false, false, row, page_nr, layers: [0])
                # draw(canvas1, layout_file, false, false, row, page_nr, layers: [0])
              end
            end
          end
        end
      else
        raise Printer::Base::ResourceNotFoundError, "Das Layout '#{path}' konnte nicht gefunden werden. Der Druck wird angehalten."
      end
    end

    def postprocess_image(pic, layout_file, page)
      pic.flip! if page % 2 == 0 && layout_file.get_attr_value(S_FRONT_FLIP) == S_TRUE
      pic.flop! if page % 2 == 0 && layout_file.get_attr_value(S_FRONT_FLOP) == S_TRUE
      pic.flip! if page % 2 != 0 && layout_file.get_attr_value(S_BACK_FLIP) == S_TRUE
      pic.flop! if page % 2 != 0 && layout_file.get_attr_value(S_BACK_FLOP) == S_TRUE
      pic
    end
  end
end
