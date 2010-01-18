# -*- coding: UTF-8 -*-

require 'mcc2/printer/base'           # die Basisklasse für die Printer
require 'mcc2/printer/card_printer'
require 'mcc2/printer/rmagick_drawer'
require 'mcc2/thread_event_handler'


module Mcc2
module Printer
class Preview < Base
  include RmagickDrawer
  include CardPrinting
  include Fox
  include ThreadEventHandler
  
  def initialize parent
    super()
    @parent = parent
    @selected_object_id = nil

    FXHorizontalFrame.new(parent, :opts=>LAYOUT_FILL_X) do |frame1|
      @label_zoom = FXLabel.new(frame1, "") do |label_zoom|
        label_zoom.img = 'mcc2/images/zoom-in.png'
        label_zoom.tipText = "Hier kann die Vorschau vergrößert oder verkleinert werden. Wird die\ntatsächliche Auflösung des angeschlossenen Bildschirms eingestellt,\nerscheint die Vorschau in Originalgröße."
      end
      @dial_zoom = FXDial.new(frame1, :opts=>DIAL_HORIZONTAL|LAYOUT_FIX_WIDTH, :width=>100) do |dial_zoom|
        dial_zoom.tipText = @label_zoom.tipText
        dial_zoom.connect(SEL_CHANGED){ set_zoom }
        dial_zoom.connect(SEL_LEFTBUTTONRELEASE){ draw_preview(true, @row) }
        dial_zoom.value = @parent.app.reg.readRealEntry('settings', 'preview_dpi', 90)
        dial_zoom.range = 1..1000
      end
    end

    @image_view = FXImageView.new(parent, :opts => LAYOUT_FILL_X | LAYOUT_FILL_Y)

    event_handler_setup
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
    self.dpi = @dial_zoom.value
    @label_zoom.text = "#{self.dpi} DPI"
    @parent.app.reg.writeRealEntry('settings', 'preview_dpi', self.dpi)
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
        width =  @layout_file.get_attr_value(S_WIDTH).to_f
        height = @layout_file.get_attr_value(S_HEIGHT).to_f

#        Magick::RVG.dpi = dpi

        preview = true

        card_offset = 0

        image_width = width_with_margins(width)
        image_height = 2 * height_with_margins(height) + card_offset

        begin
          rvg = Magick::RVG.new(mm(image_width), mm(image_height)) do |canvas|
            draw_pos_x = 0
            draw_pos_y = 0
            canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
              draw(canvas1, @layout_file, preview, @selected_object_id, row, 0) # Seite 1 drucken
            end

            draw_pos_y = height_with_margins(height) + card_offset
            canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
              draw(canvas1, @layout_file, preview, @selected_object_id, row, 1) # Seite 2 drucken
            end

            canvas.background_fill = 'white'
          end

          # ..........................................................................................
          # Image in einen Blob schreiben, damit es dann aus diesem heraus angezeigt werden kann
          data = rvg.draw.to_blob{
            self.format = 'PNG'
          }

          event_handler_push{
            # das erzeugte Bild als Icon anzeigen
            fx_image = FXPNGImage.new(@parent.app, data)
            fx_image.create
            @image_view.image = fx_image
            @image_view.show
            @image_view.recalc
          }
        rescue RmagickDrawer::ResourceNotFoundError => e
          event_handler_push{
            FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen eines Grafikobjekts", e.to_s)
          }
          @printing = false
        end
      rescue => e
        DebugTools::write_log_file('draw_preview_thread', DebugTools::unkown_error_message(e))
        event_handler_push{
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen der Layoutvorschau", DebugTools::unkown_error_message(e))
        }
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
end
