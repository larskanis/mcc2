# -*- coding: UTF-8 -*-

require 'mcc2/dataman/base'
require 'rmagick'           # für das Erzeugen der Druckbilder
require 'rvg/rvg'           # für RMagick die Vektorgraphik-Bibliothek

# class Numeric
#   def mm
#     self
#   end
#   def pt
#     self * 25.4 / 72.0
#   end
# end

# Workaround for disabling text_antialias
class Magick::RVG
  alias original_draw draw
  def draw
    raise StandardError, "draw not permitted in nested RVG objects" if @nested
    @canvas ||= new_canvas    # allow drawing over existing canvas
    gc = Utility::GraphicContext.new

    # Turn off antialiasing
    gc.text_antialias(false)

    add_outermost_primitives(gc)
    pp(self) if ENV['debug_rvg']
    print_gc(gc) if ENV['debug_prim']
    gc.draw(@canvas)
    return @canvas
  end
end


module Mcc2
module RmagickDrawer
  #
  def width_with_margins(width)
    width + self.card_margin_left + self.card_margin_right
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def height_with_margins(height)
    height + self.card_margin_bottom + self.card_margin_top
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def draw(canvas, layout_file, preview, selected_object_id, row, page_nr, layers=[0])
    @magick_font_list ||= Magick.fonts.map{|mf| mf.name }

    width = layout_file.get_attr_value(S_WIDTH).to_f
    height = layout_file.get_attr_value(S_HEIGHT).to_f
    if preview
      rx = 10
      # todo -0.5, damit die rechten und unteren Ränder zu sehen sind, jetzt sitzt die Karte aber unsymetrisch auf dem Rechteck
      canvas.rect(mm(width_with_margins(width-0.5)), mm(height_with_margins(height-0.5)) ).styles(:fill=>'none', :stroke=>'black')
    end

    canvas.g.translate(mm(self.card_margin_left).round, mm(self.card_margin_top).round) do |canvas1|
      barcodes = nil
      rx = mm(3)
      # ..........................................................................................
      # Kartenhintergrund füllen (für Vorschau)
      if preview
        canvas1.rect(mm(width), mm(height) ).round(rx).styles(:fill=>'lightgray', :stroke=>'none')
      end
      # ..........................................................................................
      # die graphischen Elemnte zeichnen

      # Text-Objekte
      sorted_id_list = layout_file.sorted_id_list
      sorted_id_list.each do |id|
        go = layout_file.find_graphic_object_by_id(id)
        # nur die Objekte zeichnen, die auf diese Seite sollen
        if go[GOA_PAGE_NR].to_i == page_nr && (layers==:all || layers.include?(go[GOA_LAYER].to_i))

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
          elsif row
            data = DataMan.replace_variables(go[GOA_DATA], row)
          elsif go[GOA_DATA]
            data_nosub = go[GOA_DATA].to_s
            data = go[GOA_SAMPLE_DATA].to_s
          end

          canvas1.g.translate(mm(x).round, mm(y).round).rotate(rotation) do |body|
            # ............................................................................................................
            # die Objekt-spezifischen Attribute ermitteln
            if typ == TEXTOBJECT
              draw_textobject(body.g, go, go_width, go_height, data.empty? ? data_nosub : data)
            elsif typ == PICTUREOBJECT
              draw_pictureobject(body.g, go, go_width, go_height, data)
            elsif typ == BARCODEOBJECT
              data = data.gsub(/\\x([0-9a-f][0-9a-f])/i){ [$1.hex].pack("C") }
              draw_barcode(body.g, go, go_width, go_height, data, !preview)
            elsif typ == BOXOBJECT
              draw_boxobject(body.g, go, go_width, go_height)
            end

            # ............................................................................................................

            # in Vorschau einen Rahmen um das selektierte Objekt zeichnen
            if preview && selected_object_id == id
              body.rect(mm(go_width), mm(go_height)).styles(:fill=>'none', :stroke=>'red')
            end

          end
        end
      end

      # ..........................................................................................
      # Rand zeichnen (für Vorschau)
      if preview
        canvas1.rect(mm(width), mm(height) ).round(rx).styles(:fill=>'none', :stroke=>'blue')
        if page_nr == 1 && layout_file.get_attr_value(S_MAGSTRIPE) == S_TRUE
          canvas1.g.translate(mm(0), mm(4)){|ms_rect|
            ms_rect.rect(mm(width), mm(12.5) ).styles(:fill=>'black', :stroke=>'none', :opacity => 0.5)
            ms_obj = layout_file.magstripe_object
            (1..3).each{|spurnr|
              spur_data = ms_obj['ms_spur' + spurnr.to_s]
                ms_rect.text(mm(3), mm((3.5 * spurnr) + 0.5), "Spur #{spurnr}: #{spur_data}").styles(
                  :font => "Courier-New-Bold",
                  :font_size => pt(10),
                  :fill => 'white'
                )
            }
          }
        end
        if page_nr == 0 && layout_file.get_attr_value(S_CONTACTLESS) == S_TRUE
          rx = mm(0.5)
          canvas1.g.translate(mm(3), mm(3)).rect(mm(5), mm(5) ).round(rx).styles(:fill=>'gray', :stroke=>'none', :opacity => 0.5)
          rx = mm(3)
          canvas1.g.translate(mm(4), mm(4)).rect(mm(75), mm(45) ).round(rx).styles(:fill=>'none', :stroke=>'gray', :stroke_opacity => 0.5)
          canvas1.g.translate(mm(5), mm(5)).rect(mm(73), mm(43) ).round(rx).styles(:fill=>'none', :stroke=>'gray', :stroke_opacity => 0.5)
          canvas1.g.translate(mm(6), mm(6)).rect(mm(71), mm(41) ).round(rx).styles(:fill=>'none', :stroke=>'gray', :stroke_opacity => 0.5)
        end
        if page_nr == 0 && layout_file.get_attr_value(S_CONTACT) == S_TRUE
          rx = mm(2)
          canvas1.g.translate(mm(8), mm(18)).rect(mm(13), mm(12) ).round(rx).styles(:fill=>'yellow', :stroke=>'gray')
        end
      end

    end
  end

  def draw_textobject(body, go, go_width, go_height, data)
    font = go[GOA_FONT_TYP]
    if font=='from_file'
      font = go[GOA_FONT_FILE]
    end
    fontsize = go[GOA_FONT_HEIGHT].to_f
    font_color = ["#", go[GOA_FONT_COLOR]].join
    just = go[GOA_JUSTIFICATION].downcase
    if just == "links"
      text_x = 0
      just = 'start'
    elsif just == "mitte"
      text_x = go_width.to_f / 2
      just = 'middle'
    elsif just == "rechts"
      text_x = go_width
      just = 'end'
    else
      just = 'start' # falls eine fehlerhafte Ausrichtung eingegeben wurde, wird einfach links ausgerichtet
    end

    unless @magick_font_list.index(font) || File.exist?(font)
      raise Printer::Base::ResourceNotFoundError, "Die Schriftart '#{font}' konnte nicht gefunden werden. Der Druck wird angehalten."
    end

    if data != ""
      body.text(mm(text_x), mm(0), data).styles(
        :font => font,
        :font_size => pt(fontsize),
        :fill => font_color,
        :text_anchor => just
      )
    end
  end

  def draw_pictureobject(body, go, go_width, go_height, data)
    if data.nil? || data.empty? || (data.gsub("\\","/") =~ /\/$/)
      # kein Bildname angegeben -> dieses Objekt ignorieren
    elsif FileTest.file?(data)
      self_dpi = self.dpi
      image_page = go[GOA_IMAGE_PAGE].to_i - 1
      go_image = Magick::ImageList.new(data){|img|
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
      im_width = go_width == 0 && go_image.x_resolution>0 ? go_image.columns/go_image.x_resolution*25.4 : go_width
      im_height = go_height == 0 && go_image.y_resolution>0 ? go_image.rows/go_image.y_resolution*25.4 : go_height

      body.image(go_image, mm(im_width), mm(im_height))
    else
      raise Printer::Base::ResourceNotFoundError, "Das Bild '#{data}' konnte nicht gefunden werden. Der Druck wird angehalten."
    end
  end

  BARCODE_ALIAS = {
    EAN13: :Eanx,
    EAN8: :Eanx,
  }

  HALIGNMENT = {
    0 => :middle,
    1 => :start,
    2 => :end,
  }

  def draw_barcode(body, go, go_width, go_height, data, optimized=true)
    return if data.nil? || data.empty?

    barcode_typ = go[GOA_BARCODE_TYP]
    bar_ratio = go[GOA_BAR_RATIO].to_i
    fontname = go[GOA_FONT_TYP]
    if fontname=='from_file'
      fontname = go[GOA_FONT_FILE]
    end
    fontsize = go[GOA_FONT_HEIGHT].to_f
    font_color = ["#", go[GOA_FONT_COLOR]].join

    unless @magick_font_list.index(fontname) || File.exist?(fontname)
      raise Printer::Base::ResourceNotFoundError, "Die Schriftart '#{fontname}' konnte nicht gefunden werden. Der Druck wird angehalten."
    end

    body.styles(
      :fill => font_color,
      :stroke => 'none',
      :font => fontname,
      :font_size => pt(fontsize)
    )

    begin
      barcode = Zint.const_get(BARCODE_ALIAS[barcode_typ.to_sym] || barcode_typ).new(value: data)
    rescue => e
      raise Printer::Base::InvalidBarcodeData, "Fehler beim Generieren des Barcodes #{data.inspect}: #{e}"
    else
      if barcode.respond_to?(:wide_width=)
        barcode.narrow_width = 1
        barcode.wide_width = bar_ratio
      end
      barcode.input_mode = Zint::DATA_MODE #  Zint::UNICODE_MODE | Zint::ESCAPE_MODE
      # barcode.output_options = Zint::SMALL_TEXT
      barcode.height = go_height.to_f / go_width.to_f * 20.0 #  50 is the default x-dimension for most of the barcodes
      barcode.show_hrt = 0 if fontsize == 0
      # barcode.fontsize = fontsize # not used in zint
      # p [go_height, go_width, barcode.height]
      barcode.whitespace_width = 0
      bcvector = barcode.to_vector

      eancode = %w[EAN13 EAN8].include?(barcode_typ)

      px_width, px_height = mm(go_width), mm(go_height)
      # bcvector values are always a multiple of 2, but we need a multiple of 1 for to_i below.
      # So all bcvector measurements are divided by 2.
      xbars, ybars = bcvector.width/2, bcvector.height/2
      # p vector_width: bcvector.width, vector_height: bcvector.height
      xdim, ydim = px_width/xbars, px_height/ybars
      if optimized
        xdim = xdim.to_i
        ydim = ydim.to_i if barcode.rows > 1 # optimize y dimension only on 2D codes
      end

      bcvector.each_rectangle do |bar|
        # p [xdim*bar.width/2, ydim*bar.height/2, xdim*bar.x/2, ydim*bar.y/2]
        body.rect([xdim*bar.width/2-1, 0].max, [ydim*bar.height/2-1, 0].max, xdim*bar.x/2, ydim*bar.y/2)
      end
      bcvector.each_string do |str|
        # p [str.x, str.y, str.text, str.halign, str.fsize]
        body.text(xdim*str.x/2, ydim*str.y/2, str.text).styles(text_anchor: HALIGNMENT[str.halign])
      end

      # Barcode - text

      #if eancode
        #data2 = barcode.text.to_s
        #data3 = if barcode.symbology == Zint::BARCODE_EANX && data2.length == 8
          #[nil, data2[0,4], data2[4,4]]
        #elsif barcode.symbology == Zint::BARCODE_EANX && data2.length == 13
          #[data2[0,1], data2[1,6], data2[7,6]]
        #end
        #body.text(0, mm(go_height), data3[0]).styles(:text_anchor => 'end') if data[0]
        #body.text(xdim * (xbars/4.0+1), mm(go_height), data3[1]).styles(:text_anchor => 'middle')
        #body.text(xdim * (xbars/4.0*3.0-1), mm(go_height), data3[2]).styles(:text_anchor => 'middle')
      #else
        #body.text(xdim * (xbars/2.0), mm(go_height), data).styles(:text_anchor => 'middle')
      #end
    end
  end

  def draw_boxobject(body, go, go_width, go_height)
    corner_radius = go[GOA_CORNER_RADIUS].to_f
    fill_color = go[GOA_FILL_COLOR]
    border_color = go[GOA_BORDER_COLOR]
    border_width = go[GOA_BORDER_WIDTH].to_f

    body.rect( mm(go_width).round, mm(go_height).round ).round(mm(corner_radius)).styles(:fill=>'#'+fill_color, :stroke=>'#'+border_color, :stroke_width=>mm(border_width).round)
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
