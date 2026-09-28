require "mcc2/dataman/base"
require "i18n"
require "ttfunk"
require "pango"

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
        d1 = sign(pt, @v1, @v2)
        d2 = sign(pt, @v2, @v3)
        d3 = sign(pt, @v3, @v4)
        d4 = sign(pt, @v4, @v1)

        has_neg = (d1 < 0) || (d2 < 0) || (d3 < 0) || (d4 < 0)
        has_pos = (d1 > 0) || (d2 > 0) || (d3 > 0) || (d4 > 0)

        !(has_neg && has_pos)
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

    FontInfo = Data.define :font_family, :font_weight, :font_style

    private def fontinfo_from_file(font_path)
      ttf = TTFunk::File.open(font_path)

      # Extract names from the 'name' table
      # ttfunk groups strings by name_id. We fetch the English (US) strings primarily.
      names = ttf.name

      # Helper to get the English string for a specific Name ID
      get_name = lambda do |instances|
        return nil if instances.empty?

        # Try to find English (Language ID 1033 or 0)
        raw_string = instances.find { |s| s.language_id == 1033 || s.language_id == 0 } || instances.first
        # Determine Ruby-compatible encoding based on TTF Platform Specs
        ruby_encoding = case raw_string.platform_id
                        when 0, 3 # Unicode (0) or Microsoft (3) use UTF-16BE/UCS-2
                          'UTF-16BE'
                        when 1    # Macintosh (1) typically uses MacRoman
                          'MacRoman'
                        else
                          'ASCII-8BIT' # Fallback for raw byte manipulation
                        end
        utf8_string = raw_string.encode('UTF-8', ruby_encoding, invalid: :replace, undef: :replace)
        # Strip null bytes that occasionally bleed through from malformed sub-tables
        utf8_string.gsub("\u0000", '').strip
      end

      # Fetch the specific Name IDs
      font_family_id1       = get_name.call(names.font_family)  # Font Family Name (Legacy)
      font_subfamily_id2    = get_name.call(names.font_subfamily)  # Font Subfamily Name (Legacy)
      pref_family_id16      = get_name.call(names.preferred_family) # Typographic/Preferred Family
      pref_subfamily_id17   = get_name.call(names.preferred_subfamily) # Typographic/Preferred Subfamily

      # 1. Map font-family (Prefer ID 16, fallback to ID 1)
      css_family = pref_family_id16 || font_family_id1

      # 2. Map font-weight (Read directly from the numeric OS/2 table usWeightClass)
      # Fallback to checking the Subfamily strings if OS/2 table is missing
      css_weight = 400
      if ttf.os2
        css_weight = ttf.os2.weight_class
      else
        subfamily_str = (pref_subfamily_id17 || font_subfamily_id2 || '').downcase
        css_weight = 700 if subfamily_str.include?('bold')
        css_weight = 300 if subfamily_str.include?('light')
      end

      # 3. Map font-style (Check head table macStyle or parse Subfamily strings)
      if ttf.header.mac_style
        is_italic = (ttf.header.mac_style & 2) != 0 # Bit 1 represents Italic
      else
        subfamily_str = (pref_subfamily_id17 || font_subfamily_id2 || '').downcase
        is_italic = subfamily_str.include?('italic') || subfamily_str.include?('oblique')
      end
      css_style = is_italic ? 'italic' : 'normal'

      FontInfo.new(css_family, css_weight, css_style)
    end

    @@builtin_fonts = nil
    def self.builtin_font_names
      @@builtin_fonts ||= begin
        fm = PangoCairo::FontMap.default
        fm.families.flat_map do |f|
          f.faces.map do |ff|
            ["#{f.name} #{ff.face_name}", FontInfo.new(f.name, ff.describe.weight.to_i, ff.describe.style.name.delete_prefix("PANGO_STYLE_").downcase)]
          end
        end.to_h.freeze
      end
    end

    @@font_map = RmagickDrawer.builtin_font_names.dup
    @@pango_font_map = Pango::CairoFontMap.default

    def draw(drawing, transform, layout_file, preview, selected_object_ids, row, page_nr, layers: [0])
      @font_map = @@font_map

      layout_file.sorted_id_list.each do |id|
        go = layout_file.find_graphic_object_by_id(id)
        font = go[GOA_FONT_TYP]
        if font == "from_file"
          font_path = go.layout_file.expand_path(go[GOA_FONT_FILE])

          @font_map[font_path] ||= begin
            @@pango_font_map.add_font_file(font_path)
            fontinfo_from_file(font_path)
          end
        end
      end

      barcode_dpi = layout_file.get_attr_value(S_BARCODE_DPI).to_f
      rect_list = ObjRectangeList.new

      width = layout_file.get_attr_value(S_WIDTH).to_f
      height = layout_file.get_attr_value(S_HEIGHT).to_f
      if preview
        # todo -0.5, damit die rechten und unteren Ränder zu sehen sind, jetzt sitzt die Karte aber unsymetrisch auf dem Rechteck
        # drawing.fill("none")
        # drawing.stroke("black")
        drawing.rect(x: transform.x, y: transform.y, width: mm(width_with_margins(width)).round-1, height: mm(height_with_margins(height)).round-1, fill: "white", stroke: "black", "stroke-width": 1)
        # drawing.rectangle(transform.x, transform.y, cpos.x, cpos.y)
        # canvas.rect(mm(width_with_margins(width - 0.5)), mm(height_with_margins(height - 0.5))).styles(fill: "none", stroke: "black")
      end

      tra = transform.translate(mm(card_margin_left).round, mm(card_margin_top).round)
      # Fill card background for preview
      rx = mm(3).round
      if preview
        # drawing.fill("lightgray")
        # drawing.stroke("none")
        drawing.rect(x: tra.x, y: tra.y, width: mm(width).round, height: mm(height).round, fill: "lightgray", rx: , stroke: "blue", "stroke-width": 1)
        # drawing = drawing.draw_rect([200,200,200], tra.x, tra.y, cpos.x-tra.x, cpos.y-tra.y, fill: true)
        # drawing.roundrectangle(tra.x, tra.y, cpos.x, cpos.y, rx, rx)
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
            text_y = (typ == TEXTOBJECT) ? pt(go[GOA_FONT_HEIGHT].to_f) : 0
            rec1 = rec.translate(0, -text_y)
            rec2 = rec1.translate(mm(go_width), 0)
            rec3 = rec1.translate(mm(go_width), mm(go_height) + text_y)
            rec4 = rec1.translate(0, mm(go_height) + text_y)
            orec = ObjRectangle.new(rec1.vector2d, rec2.vector2d, rec3.vector2d, rec4.vector2d, id)
            rect_list.add(orec)
          end

          drawing.g transform: "rotate(#{rec.a})" do
            opos = rec.inverse

            begin
              # die Objekt-spezifischen Attribute ermitteln
              if typ == TEXTOBJECT
                draw_textobject(drawing, opos, go, go_width, go_height, data.empty? ? data_nosub : data)
              elsif typ == PICTUREOBJECT
                draw_pictureobject(drawing, opos, go, go_width, go_height, data)
              elsif typ == BARCODEOBJECT
                data = data.gsub(/\\x([0-9a-f][0-9a-f])/i) { [$1.hex].pack("C") }
                draw_barcode(drawing, opos, go, go_width, go_height, data, barcode_dpi)
              elsif typ == BOXOBJECT
                draw_boxobject(drawing, opos, go, go_width, go_height)
              elsif typ == EMBEDOBJECT
                draw_embedobject(drawing, opos, go, go_width, go_height, data, row ? row["row_number"] : "1", barcode_dpi)
              end
            rescue => err
              raise err, "#{go[GOA_NAME]}: #{err}"
            end

            # in Vorschau einen Rahmen um das selektierte Objekt zeichnen
            if preview && selected_object_ids.include?(id)
              # drawing.fill("none")
              # drawing.stroke("red")
              # drawing.stroke_width(1)
              # cpos = opos.translate(mm(go_width), mm(go_height))
              # drawing.rectangle(opos.x, opos.y, cpos.x, cpos.y)
              drawing.rect(x: opos.x, y: opos.y, width: [mm(go_width), 0.5].max, height: [mm(go_height), 0.5].max, fill: "none", stroke: "red", "stroke-width": 1)
              # body.rect(mm(go_width), mm(go_height)).styles(fill: "none", stroke: "red")
            end
          end
        end
      end

      if preview
        # paint magstripe for preview
        if page_nr == 1 && layout_file.get_attr_value(S_MAGSTRIPE) == S_TRUE
          rs_rect = tra.translate(mm(0), mm(4))
          drawing.rect(x: rs_rect.x, y: rs_rect.y, width: mm(width).round, height: mm(12.5).round, fill: "black", stroke: "none", opacity: 0.5)

          ms_obj = layout_file.magstripe_object
          (1..3).each do |spurnr|
            spur_data = ms_obj["ms_spur" + spurnr.to_s]
            spurpos = rs_rect.translate(mm(3), mm((3.5 * spurnr) + 0.5))
            drawing.text_("Mag #{spurnr}: #{spur_data}",
                          x: spurpos.x, y: spurpos.y,
                          "font-family": "Courier-New Bold Mono",
                          "font-size": pt(10),
                          fill: "white")
          end
        end
        # paint contactless chip for preview
        if page_nr == 0 && layout_file.get_attr_value(S_CONTACTLESS) == S_TRUE
          clpa = tra.translate(mm(3), mm(3))
          drawing.rect(x: clpa.x, y: clpa.y, width: mm(5), height: mm(5), rx: mm(0.5), fill: "gray", stroke: "none", opacity: 0.5)
          clpa = tra.translate(mm(4), mm(4))
          drawing.rect(x: clpa.x, y: clpa.y, width: mm(75), height: mm(45), rx: mm(3), fill: "none", stroke: "gray", stroke_opacity: 0.5)

          clpa = tra.translate(mm(5), mm(5))
          drawing.rect(x: clpa.x, y: clpa.y, width: mm(73), height: mm(43), rx: mm(3), fill: "none", stroke: "gray", stroke_opacity: 0.5)

          clpa = tra.translate(mm(6), mm(6))
          drawing.rect(x: clpa.x, y: clpa.y, width: mm(71), height: mm(41), rx: mm(3), fill: "none", stroke: "gray", stroke_opacity: 0.5)
        end
        # paint contact chip for preview
        if page_nr == 0 && layout_file.get_attr_value(S_CONTACT) == S_TRUE
          clpa = tra.translate(mm(8), mm(18))
          drawing.rect(x: clpa.x, y: clpa.y, width: mm(13), height: mm(12), rx: mm(2), fill: "yellow", stroke: "gray")
        end
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
        just = :start
      elsif just == "mitte"
        text_x = go_width.to_f / 2
        just = :middle
      elsif just == "rechts"
        text_x = go_width
        just = :end
      else
        just = :start # falls eine fehlerhafte Ausrichtung eingegeben wurde, wird einfach links ausgerichtet
      end

      check_font(font, go)

      if data && !data.empty?
        # drawing.font font
        # drawing.font_size pt(fontsize)
        # drawing.fill font_color
        # drawing.text_anchor just
        apos = tra.translate(mm(text_x), mm(0))
        # drawing.text(apos.x, apos.y, data)
        # body.text(mm(text_x), mm(0), data).styles(
        #   font: font,
        #   font_size: pt(fontsize),
        #   fill: font_color,
        #   text_anchor: just
        # )

        drawing.text_(data, x: apos.x, y: apos.y,
                      fill: font_color,
                      'text-anchor': just,
                      'font-size': pt(fontsize),
                      'font-family': font_map[font]&.font_family || font,
                      'font-weight': font_map[font]&.font_weight || font,
                      'font-style': font_map[font]&.font_style || font,
                      'xml:space': "preserve")
      end
    end

    def draw_pictureobject(drawing, tra, go, go_width, go_height, data)
      if data.nil? || data.empty? || (data.tr("\\", "/") =~ /\/$/)
        # kein Bildname angegeben -> dieses Objekt ignorieren
      elsif (path = go.layout_file.expand_path(data)) && FileTest.file?(path)
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

        aspect_ratio_img = go_image.columns.to_f / go_image.rows.to_f
        aspect_ratio_box = im_width / im_height
        if aspect_ratio_box > aspect_ratio_img
          # box is wider than image -> add space left and right
          space = im_width - aspect_ratio_img * im_height
          im_width -= space
          apos = tra.translate(mm(space / 2.0), 0.0)

        elsif aspect_ratio_box < aspect_ratio_img
          # image is wider than box -> add space top and bottom
          space = im_height - im_width / aspect_ratio_img
          im_height -= space
          apos = tra.translate(0.0, mm(space / 2.0))

        else
          apos = tra
        end

        cpos = apos.translate(mm(im_width), mm(im_height))
        # drawing.composite(apos.x.round, apos.y.round, (cpos.x - apos.x).round, (cpos.y - apos.y).round, go_image)
        # body.image(go_image, mm(im_width), mm(im_height))
        pngdata = go_image.to_blob do |i|
          i.format = "PNG"
        end
        drawing.image(x: apos.x.round, y: apos.y.round, width: mm(im_width), height: mm(im_height), "href": "data:image/png;base64,#{[pngdata].pack("m")}")
      else
        raise Printer::Base::ResourceNotFoundError, I18n.t(:image_not_found, default: "Das Bild '%{path}' konnte nicht gefunden werden.", path: )
      end
    end

    BARCODE_ALIAS = {
      EAN13: :Eanx,
      EAN8: :Eanx
    }

    HALIGNMENT = {
      0 => :middle,
      1 => :start,
      2 => :end
    }

    def draw_barcode(drawing, tra, go, go_width, go_height, data, barcode_dpi)
      return if data.nil? || data.empty?

      barcode_typ = go[GOA_BARCODE_TYP]
      go[GOA_BAR_RATIO].to_i
      font = go[GOA_FONT_TYP]
      if font == "from_file"
        font = go.layout_file.expand_path(go[GOA_FONT_FILE])
      end
      fontsize = go[GOA_FONT_HEIGHT].to_f
      font_color = ["#", go[GOA_FONT_COLOR]].join

      check_font(font, go)

      begin
        barcode = Zint.const_get(BARCODE_ALIAS[barcode_typ.to_sym] || barcode_typ).new(value: data)
      rescue => e
        raise Printer::Base::InvalidBarcodeData, I18n.t(:error_generating_barcode, default: "Fehler beim Generieren des Barcodes %{data}: %{e}", data: data.inspect, e: )
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

        %w[EAN13 EAN8].include?(barcode_typ)

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
        xdim = px_width / xbars / xgran
        ydim = px_height / ybars / ygran

        pathd = +""
        bcvector.each_rectangle do |bar|
          # p [bar.x, bar.y, bar.width, bar.height]
          # p [xdim*bar.width, ydim*bar.height, xdim*bar.x, ydim*bar.y]
          x = tra.x + xdim * bar.x
          y = tra.y + ydim * bar.y
          # drawing.rectangle(
          #   x,
          #   y,
          #   x + [xdim * bar.width - 1, 0].max,
          #   y + [ydim * bar.height - 1, 0].max
          # )
          # drawing.rect(x: x, y: y, width: xdim * bar.width, height: ydim * bar.height, fill: font_color, stroke: "none")
          # body.rect([xdim * bar.width / 2 - 1, 0].max, [ydim * bar.height / 2 - 1, 0].max, xdim * bar.x / 2, ydim * bar.y / 2)
          w = xdim * bar.width
          h = ydim * bar.height
          pathd << "M#{x} #{y}h#{w}v#{h}h-#{w}Z"
        end
        drawing.path(d: pathd, stroke: "none", fill: font_color)
        bcvector.each_string do |str|
          # p [str.x, str.y, str.text, str.halign, str.fsize]
          # drawing.text_anchor(HALIGNMENT[str.halign])
          # apos = tra.translate(xdim * str.x / xgran, )
          # drawing.text(tra.x + xdim * str.x, tra.y + ydim * str.y, str.text)
          # body.text(xdim * str.x / 2, ydim * str.y / 2, str.text).styles(text_anchor: HALIGNMENT[str.halign])
          drawing.text_(str.text, x: tra.x + xdim * str.x, y: tra.y + ydim * str.y,
                        'text-anchor': HALIGNMENT[str.halign],
                        fill: font_color,
                        'font-size': pt(fontsize),
                        'font-family': font_map[font]&.font_family || font,
                        'font-weight': font_map[font]&.font_weight || font,
                        'font-style': font_map[font]&.font_style || font,
                        'xml:space': "preserve")
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

      drawing.rect(
        fill: "#" + fill_color,
        stroke: "#" + border_color,
        "stroke-width": mm(border_width).round,
        x: tra.x, y: tra.y, width: mm(go_width).round, height: mm(go_height).round,
        rx: mm(corner_radius), ry: mm(corner_radius))
    end

    def draw_embedobject(drawing, tra, go, go_width, go_height, data, row_number, barcode_dpi)
      if data.nil? || data.empty? || (data.tr("\\", "/") =~ /\/$/)
        # kein Layout angegeben -> dieses Objekt ignorieren
      elsif (path = go.layout_file.expand_path(data)) && FileTest.file?(path)
        layout_file = LayoutFile.load_from_xml(path, go.layout_file.xpath_changes)

        barcode_dpi2 = layout_file.get_attr_value(S_BARCODE_DPI).to_f
        unless ((barcode_dpi - 0.01)..(barcode_dpi + 0.01)) === barcode_dpi2
          raise Printer::Base::DpiDoesntMatch, I18n.t(:embedded_object_dpi_differs, default: "Barcode-DPI in der Vorschau (%{document_dpi}) und %{obj} (%{embedded_obj_dpi}) sind verschieden. Bitte DPI anpassen und Barcodes neu prüfen!", document_dpi: format("%0.1f", barcode_dpi), obj: go[GOA_NAME].inspect, embedded_obj_dpi: format("%0.1f", barcode_dpi2))
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
              end
            end
          end
        end
      else
        raise Printer::Base::ResourceNotFoundError, I18n.t(:embedded_object_not_found, default: "Das Layout '%{path}' konnte nicht gefunden werden.", path: )
      end
    end

    def check_font(font, obj)
      unless @font_map[font]
        raise Printer::Base::ResourceNotFoundError, I18n.t(:font_not_found, default: "Die Schriftart '%{font}' in Object %{obj} konnte nicht gefunden werden.", font:, obj: obj[GOA_NAME].inspect )
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
