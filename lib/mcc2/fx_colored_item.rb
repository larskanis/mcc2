# This is a Ruby translation of FXIconItem::drawDetails in C++.
# It is extended by the possibility to set the text colors per item.
# And it does a log(n) search for text size rather than a linear search.

require "fox16"

module Mcc2
  class FxColoredItem < Fox::FXIconItem
    MyColor = Struct.new :f, :b

    attr_accessor :on_color_requested

    SIDE_SPACING = 4              # Left or right spacing between items
    DETAIL_TEXT_SPACING = 2       # Spacing between text and icon in detail icon mode

    def draw(list, dc, x, y, w, h)
      color = on_color_requested&.call(list, self)

      # For unknown reason a seperate FXDC is required in order to see any drawings.
      dc = Fox::FXDCWindow.new list
      dc.font = list.font

      header = list.header
      font = list.font
      return if header.numItems == 0

      iw = 0
      if selected?
        dc.foreground = list.selBackColor
        dc.fillRectangle(x, y, header.totalSize, h)
      elsif color
        dc.foreground = color.b
        dc.fillRectangle(x, y, header.totalSize, h)
      end
      if hasFocus?
        dc.drawFocusRectangle(x + 1, y + 1, header.totalSize - 2, h - 2)
      end
      xx = x + SIDE_SPACING / 2
      if miniIcon
        iw = miniIcon.width
        ih = miniIcon.height
        dc.setClipRectangle(x, y, header.itemSize(0), h)
        dc.drawIcon(miniIcon, xx, y + (h - ih) / 2)
        dc.clearClipRectangle
        xx += iw + DETAIL_TEXT_SPACING
      end
      label = text
      unless label.empty?
        th = font.fontHeight
        dw = font.getTextWidth("...")
        yt = y + (h - th - 4) / 2
        dc.foreground = if !enabled?
          makeShadowColor(list.backColor)
        elsif selected?
          list.selTextColor
        elsif color
          color.f
        else
          list.textColor
        end
        used = iw + DETAIL_TEXT_SPACING + SIDE_SPACING / 2
        label.split("\t")[0...header.numItems].each_with_index do |snip, hi|
          space = header.getItemSize(hi) - used
          if text_width_bigger_than?(font, snip, space - 4)
            pos = find_edge_false_to_true(0, snip.length) do |len|
              text_width_bigger_than?(font, snip[0, len], space - 4 - dw)
            end
            snip = snip[0, pos] << "..."
            dc.setClipRectangle(xx, y, space, h)
            dc.drawText(xx + 2, yt + font.fontAscent + 2, snip)
            dc.clearClipRectangle
          #           puts "drawText(#{xx+2},#{yt+font.fontAscent+2},#{snip.inspect})"
          else
            dc.drawText(xx + 2, yt + font.fontAscent + 2, snip)
            #           puts "drawText(#{xx+2},#{yt+font.fontAscent+2},#{snip.inspect})"
          end
          xx += space
          used = 0
        end
      end
    end

    private

    def text_width_bigger_than?(font, text, max_size)
      # work around of int16 limitation to getTextWidth return value
      (text.length > 4000) ? true : (font.getTextWidth(text) > max_size)
    end

    def find_edge_false_to_true(pos_false, pos_true, delta = 1, &block)
      pos = (pos_false + pos_true) / 2
      return pos if pos <= pos_false && pos >= pos_true - delta

      if block.call(pos)
        find_edge_false_to_true(pos_false, pos, delta, &block)
      else
        find_edge_false_to_true(pos, pos_true, delta, &block)
      end
    end
  end
end
