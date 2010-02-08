# -*- coding: UTF-8 -*-

require 'mcc2/dataman/base'
require 'RMagick'           # für das Erzeugen der Druckbilder
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
  def draw(canvas, layout_file, preview, selected_object_id, row, page_nr)
    @magick_font_list ||= Magick.fonts.map{|mf| mf.name }
    
    width =  layout_file.get_attr_value(S_WIDTH).to_f
    height = layout_file.get_attr_value(S_HEIGHT).to_f
    encoding = layout_file.get_attr_value(S_DATASOURCEENCODING)
    if preview
      rx = 10
      # todo -0.5, damit die rechten und unteren Ränder zu sehen sind, jetzt sitzt die Karte aber unsymetrisch auf dem Rechteck
      canvas.rect(mm(width_with_margins(width-0.5)), mm(height_with_margins(height-0.5)) ).styles(:fill=>'none', :stroke=>'black')
    end

    canvas.g.translate(mm(self.card_margin_left), mm(self.card_margin_top)) do |canvas1|
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
      sorted_id_list.each{|id|
        go = layout_file.xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[contains(., #{id.to_s})]").parent
        # nur die Objekte zeichnen, die auf diese Seite sollen
        if go.find(GOA_PAGE_NR).first.content.to_i == page_nr

          # die allgemeinen Attribute ermitteln
#           id = go.find_first(GOA_ID).content.to_i
          x = go.find_first(GOA_X).content.to_f
          y = go.find_first(GOA_Y).content.to_f
          go_width = go.find_first(GOA_WIDTH).content.to_f
          go_height = go.find_first(GOA_HEIGHT).content.to_f
          rotation = go.find_first(GOA_ROTATION).content.to_f
          typ = go.find_first(GOA_TYP).content
          
          if !go.find_first(GOA_DATA)
            data = nil
          elsif row
            data = DataMan.replace_variables(go.find_first(GOA_DATA).content, row, encoding)
          elsif go.find_first(GOA_DATA)
            data_nosub = go.find_first(GOA_DATA).content.to_s
            data = go.find_first(GOA_SAMPLE_DATA).content.to_s
          end

          canvas1.g.translate(mm(x), mm(y)).rotate(rotation) do |body|
            # ............................................................................................................
            # die Objekt-spezifischen Attribute ermitteln
            if typ == TEXTOBJECT
              draw_textobject(body.g, go, go_width, go_height, data.empty? ? data_nosub : data)
            elsif typ == PICTUREOBJECT
              draw_pictureobject(body.g, go, go_width, go_height, data)
            elsif typ == BARCODEOBJECT
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
      }

      # ..........................................................................................
      # Rand zeichnen (für Vorschau)
      if preview
        canvas1.rect(mm(width), mm(height) ).round(rx).styles(:fill=>'none', :stroke=>'blue')
        if page_nr == 1 && layout_file.get_attr_value(S_MAGSTRIPE) == S_TRUE
          canvas1.g.translate(mm(0), mm(4)){|ms_rect|
            ms_rect.rect(mm(width), mm(12.5) ).styles(:fill=>'black', :stroke=>'none', :opacity => 0.5)
            ms_node = layout_file.xml_doc.find_first(S_MAGSTRIPEPARAMS)
            (1..3).each{|spurnr|
              spur_data = ms_node.find_first('ms_spur' + spurnr.to_s).content
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
    font = go.find(GOA_FONT_TYP).first.content
    if font=='from_file'
      font = go.find(GOA_FONT_FILE).first.content
    end
    fontsize = go.find(GOA_FONT_HEIGHT).first.content.to_f
    font_color = ["#", go.find(GOA_FONT_COLOR).first.content].join
#              font_color = Page.check_color_definition(font_color)
    just = go.find(GOA_JUSTIFICATION).first.content.downcase
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
        :font => ["'", font, "'"].join,
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
      go_image = Magick::Image.read(data){|attr|
        # use view DPI for vector-graphics (PDF)
        attr.density = self_dpi
      }.first
      
      # workaround: ImageMagick uses wrong colors when inserting into RVG
      if [Magick::ColorSeparationType, Magick::ColorSeparationMatteType].include?(go_image.image_type)
        go_image.image_type = Magick::TrueColorMatteType
      end
      
      # if object size is not given, try to determine object size based on the DPI of the image
      im_width = go_width == 0 && go_image.x_resolution>0 ? go_image.columns/go_image.x_resolution*25.4 : go_width
      im_height = go_height == 0 && go_image.y_resolution>0 ? go_image.rows/go_image.y_resolution*25.4 : go_height
      
      body.image(go_image, mm(im_width), mm(im_height))
    else
      raise Printer::Base::ResourceNotFoundError, "Das Bild '#{data}' konnte nicht gefunden werden. Der Druck wird angehalten."
    end
  end
  
  def draw_barcode(body, go, go_width, go_height, data, optimized=true)
    return if data.nil? || data.empty?
      
    barcode_typ = go.find(GOA_BARCODE_TYP).first.content
    bar_ratio = go.find(GOA_BAR_RATIO).first.content.to_i
		fontname = go.find(GOA_FONT_TYP).first.content
		if fontname=='from_file'
			fontname = go.find(GOA_FONT_FILE).first.content
		end
		fontsize = go.find(GOA_FONT_HEIGHT).first.content.to_f
		font_color = ["#", go.find(GOA_FONT_COLOR).first.content].join
    
    unless @magick_font_list.index(fontname) || File.exist?(fontname)
      raise Printer::Base::ResourceNotFoundError, "Die Schriftart '#{fontname}' konnte nicht gefunden werden. Der Druck wird angehalten."
    end

    body.styles(
			:fill=>font_color,
			:stroke=>'none',
			:font => ["'", fontname, "'"].join,
			:font_size => pt(fontsize)
		)

    begin
      barcode = Barby.const_get(barcode_typ).new(data)
    rescue => e
      raise Printer::Base::InvalidBarcodeData, "Fehler beim Generieren des Barcodes #{data.inspect}: #{e}"
    else
      if barcode.respond_to?(:wide_width=)
        barcode.narrow_width = 1
        barcode.wide_width = bar_ratio
      end
      bcencoding = barcode.encoding

			eancode = %w[EAN13 EAN8].include?(barcode_typ)
      px_width, px_height = mm(go_width), mm(go_height)-pt(fontsize/5*4)
			
      if barcode.two_dimensional?
        x, y = 0, 0
        xdim, ydim = px_width / bcencoding.first.length, px_height / bcencoding.length
        xdim, ydim = xdim.to_i, ydim.to_i if optimized
        bcencoding.each do |line|
          line.split(//).map{|c| c == '1' }.each do |bar|
            body.rect([0,xdim].max, [0,ydim].max, x, y) if bar
            x += xdim
          end
          x = 0
          y += ydim
        end
      else
        x = 0
        xdim = px_width / bcencoding.length
        xdim = xdim.to_i if optimized
        bcencoding.split(//).map{|c| c == '1' }.each_with_index do |bar, bidx|
  #         puts "#{xdim}, #{px_height}, #{x}" if bar
					h = px_height
					if eancode && (bidx<=3 || bidx>=bcencoding.length-3 || (bidx-bcencoding.length/2).abs<=1)
						h += pt(fontsize/10*4)
					end
          body.rect([0,xdim].max, h, x, 0) if bar
          x += xdim
        end
      end

			# Barcode - text

			if eancode
				data2 = barcode.numbers_with_checksum
				data3 = if barcode_typ=='EAN8'
					[nil, data2[0,4], data2[4,4]]
				elsif barcode_typ=='EAN13'
					[data2[0,1], data2[1,6], data2[7,6]]
				end
				body.text(0, mm(go_height), data3[0]).styles(:text_anchor => 'end') if data[0]
				body.text(xdim * (bcencoding.length/4.0+1), mm(go_height), data3[1]).styles(:text_anchor => 'middle')
				body.text(xdim * (bcencoding.length/4.0*3.0-1), mm(go_height), data3[2]).styles(:text_anchor => 'middle')
			else
				body.text(xdim * (bcencoding.length/2.0), mm(go_height), data).styles(:text_anchor => 'middle')
			end

			

  #               just = go.find(GOA_JUSTIFICATION).first.content.downcase
  #               if just == "links"
  #                 just = EAlLeft
  #               elsif just == "mitte"
  #                 just = EAlCenter
  #               elsif just == "rechts"
  #                 just = EAlRight
  #               else
  #                 just = EAlCenter # falls eine fehlerhafte Ausrichtung eingegeben wurde, wird einfach links ausgerichtet
  #               end
    end
  end

  def draw_boxobject(body, go, go_width, go_height)
    corner_radius = go.find(GOA_CORNER_RADIUS).first.content.to_f
    fill_color = go.find(GOA_FILL_COLOR).first.content
    border_color = go.find(GOA_BORDER_COLOR).first.content
    border_width = go.find(GOA_BORDER_WIDTH).first.content.to_f

    body.rect(mm(go_width), mm(go_height) ).round(mm(corner_radius)).styles(:fill=>'#'+fill_color, :stroke=>'#'+border_color, :stroke_width=>mm(border_width))
  end

  def self.check_color_definition(color)
    # erstellt einen Dummy-Text, um zu testen, ob die Farbdefinition gültig ist
    # liefert die Farbe zurück, wenn sie gültig ist, ansonsten liefert sie vorläufig schwarz als Standard zurück

    begin
      rvg = Magick::RVG.new(1, 1) do |canvas|
        canvas.text(1, 1, "1").styles(
          :font_family => "Arial",
          :font_size => 10,
          :fill => color,
          :font_weight=>'normal',
          :font_style=>'normal')
      end
      rvg.draw.to_blob{
        self.format = 'PNG'
      }
    rescue => e
      return "#000000FF"
    end
    color
  end
  
end
end
