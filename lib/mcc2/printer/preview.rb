# -*- coding: UTF-8 -*-

require 'printer/base'           # die Basisklasse für die Printer
require 'printer/card_printer'
require 'printer/rmagick_drawer'


module Printer
class Preview < Base
  include RmagickDrawer
  include CardPrinting
  
  class ResourceNotFoundError < RuntimeError
  end
  
  def initialize parent
    super()
    @parent = parent

    FXHorizontalFrame.new(parent) do |frame1|
      @label_zoom = FXLabel.new(frame1, "") do |label_zoom|
        label_zoom.img = 'mcc2/images/zoom-in.png'
        label_zoom.tipText="Hier kann die Anzeige vergr\303\266\303\237ert oder verkleinert werden. Achtung, bei vergr\303\266\303\237erter Anzeige werden viele Operationen deutlich langsamer ausgef\303\274hrt."
      end
      @dial_zoom = FXDial.new(frame1, :opts=>DIAL_HORIZONTAL) do |dial_zoom|
        dial_zoom.tipText="Hier kann die Anzeige vergr\303\266\303\237ert oder verkleinert werden. Achtung, bei vergr\303\266\303\237erter Anzeige werden viele Operationen deutlich langsamer ausgef\303\274hrt."
        
        dial_zoom.connect(SEL_CHANGED){ set_zoom }
        dial_zoom.connect(SEL_LEFTBUTTONRELEASE){ draw_preview(true, @row) }
        dial_zoom.value = 100
        dial_zoom.range = (1..1000)
      end
    end

    @image_view = FXImageView.new(parent, :opts => LAYOUT_FILL_X | LAYOUT_FILL_Y)

    # Zoom
    set_zoom
  end

  def layout_file= file
    @layout_file = file
  end

  def selected_object_id= id
    @selected_object_id = id
    draw_preview false, @row
  end
  
  # verändert die Zoomstufe, wenn am Rädchen gedreht wird
  def set_zoom
    @zoom = (@dial_zoom.value).to_f / 100
    @label_zoom.text = "#{@zoom}"
    #~ p "@zoom: #{@zoom}"
    #~ p "@scale: #{@scale}"
  end
  #---------------------------------------------------------------------------------------------------------

  # zeichnet die Vorschau im Layout-Modus
  # hier ist noch einiges zu tun, im speziellen sind einige Werte "hart" kodiert,
  # die z.Bsp abhängig von anderen Einstellungen sein sollten
  def draw_preview(immediately = false, row = nil)
    @row = row
    
    @last_change = Time.now
    @last_change -= 5 if immediately
    return if @thread && @thread.alive?

    @thread = Thread.new{
      begin
        while Time.now-@last_change < 1
          sleep 0.1
        end

        # allgemeine Einstellungen des Image vornehmen
        dpi = 90
        width =  @layout_file.get_attr_value(S_WIDTH).to_f
        height = @layout_file.get_attr_value(S_HEIGHT).to_f

        Magick::RVG.dpi = dpi

        preview = true

        card_offset = 0

        image_width = width_with_margins(width) * @zoom
        image_height = ((2 * height_with_margins(height) + card_offset) * @zoom )

        scale_width = width_with_margins(width).mm
        scale_height = (2 * height_with_margins(height) + card_offset).mm

        begin
          rvg = Magick::RVG.new(image_width.mm, image_height.mm).viewbox(0, 0, scale_width, scale_height) do |canvas|
            # Verhältnis zwischen Viewbox und Größe im RVG entspricht einem Zoom (je größer die viewbox-Werte desto weiter weg erscheint das Bild)

            draw_pos_x = 0
            draw_pos_y = 0
            canvas.g.translate(draw_pos_x.mm, draw_pos_y.mm) do |canvas1|
              draw(canvas1, @layout_file, preview, @selected_object_id, row, 0) # Seite 1 drucken
            end

            draw_pos_y = height_with_margins(height) + card_offset
            canvas.g.translate(draw_pos_x.mm, draw_pos_y.mm) do |canvas1|
              draw(canvas1, @layout_file, preview, @selected_object_id, row, 1) # Seite 2 drucken
            end

            canvas.background_fill = 'white'
          end

          # ..........................................................................................
          # Image in einen Blob schreiben, damit es dann aus diesem heraus angezeigt werden kann
          data = rvg.draw.to_blob{
            self.format = 'PNG'
          }

          # ..........................................................................................
          # das erzeugte Bild als Icon anzeigen
          fx_image = FXPNGImage.new(@parent.app, data)
          fx_image.create
          @image_view.image = fx_image
          @image_view.show
          @image_view.recalc
        rescue ResourceNotFoundError => e
          error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, e.to_s, 'ok')
          error_WahlMessage.execute
          @printing = false
        end
      rescue => e
        DebugTools::write_log_file('draw_preview_thread', unkown_error_message(e))
        error_WahlMessage = FXFehlerAuswahlDialog.new(@parent.app, unkown_error_message(e), 'ok')
        error_WahlMessage.execute
      end # rescue
    }
  end
  #---------------------------------------------------------------------------------------------------------

  #
  def check_if_font_exist(fontdesc)
    rmfl = []
    Magick.fonts.each{|mf|
      rmfl << mf.name
    }
    return fontdesc if rmfl.index(fontdesc.face.gsub(" ","-").gsub("@",""))
    fdlg.execute
  end
  #---------------------------------------------------------------------------------------------------------

end
end
