require "mcc2/printer/base"           # die Basisklasse für die Printer
require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"

module Mcc2
  module Printer
    class Preview < Base
      include RmagickDrawer
      include CardPrinting
      include Fox

      def initialize parent
        super()
        @parent = parent
        @selected_object_id = nil
        @thread = nil

        FXHorizontalFrame.new(parent, opts: LAYOUT_FILL_X) do |frame1|
          @label_zoom = FXLabel.new(frame1, "") do |label_zoom|
            label_zoom.img = "mcc2/images/zoom-in.png"
            label_zoom.tipText = "Hier kann die Vorschau vergrößert oder verkleinert werden. Wird die\ntatsächliche Auflösung des angeschlossenen Bildschirms eingestellt,\nerscheint die Vorschau in Originalgröße."
          end
          @dial_zoom = FXDial.new(frame1, opts: DIAL_HORIZONTAL | LAYOUT_FIX_WIDTH, width: 100) do |dial_zoom|
            dial_zoom.tipText = @label_zoom.tipText
            dial_zoom.connect(SEL_CHANGED) { set_zoom }
            dial_zoom.connect(SEL_LEFTBUTTONRELEASE) { draw_preview(true, @row) }
            dial_zoom.value = @parent.app.reg.readRealEntry("settings", "preview_dpi", 90)
            dial_zoom.range = 1..1000
          end
          @checkbutton_continous_update = FXCheckButton.new(frame1, "Vorschau aktuell halten") do |checkbutton|
            checkbutton.tipText = "Bei Fehlern in den Layout-Einstellungen kann die Vorschau\nabgeschaltet werden, um mehrfache Hinweise zu vermeiden."
            checkbutton.connect(SEL_COMMAND) do
              draw_preview(true, @row) if checkbutton.checked?
              @parent.app.reg.writeBoolEntry("settings", "preview_continous_update", checkbutton.checked?)
            end
            checkbutton.checkState = @parent.app.reg.readBoolEntry("settings", "preview_continous_update", true)
          end
        end

        @image_view = FXImageView.new(parent, opts: LAYOUT_FILL_X | LAYOUT_FILL_Y)

        set_zoom
      end

      attr_writer :layout_file

      def selected_object_id= id
        @selected_object_id = id
        draw_preview false, @row
      end

      # verändert die Zoomstufe, wenn am Rädchen gedreht wird
      def set_zoom
        self.dpi = @dial_zoom.value
        @label_zoom.text = "#{dpi} DPI"
        @parent.app.reg.writeRealEntry("settings", "preview_dpi", dpi)
      end
      #---------------------------------------------------------------------------------------------------------

      # zeichnet die Vorschau im Layout-Modus
      # hier ist noch einiges zu tun, im speziellen sind einige Werte "hart" kodiert,
      # die z.Bsp abhängig von anderen Einstellungen sein sollten
      def draw_preview(immediately = false, row = nil)
        @row = row
        return unless @checkbutton_continous_update.checked?

        @draw_preview_at = Time.now + (immediately ? 0 : 1)
        start_preview_timer
      end

      def start_preview_timer
        return unless @draw_preview_at

        delay = @draw_preview_at - Time.now
        # delay*1010, damit immer etwas größer als Zeitspanne mit Time.now
        @parent.app.addTimeout((delay > 0) ? delay * 1010 : 0) do
          if @draw_preview_at && Time.now >= @draw_preview_at && !@thread
            @draw_preview_at = nil
            @thread = Thread.new do
              draw_preview_now(@row)

              @thread = nil
              # requeue preview generation, when something was changed
              # while the thread was running.
              @parent.runOnUiThread do
                start_preview_timer
              end
            end
          end
        end
      end

      def draw_preview_now(row = nil)
        # allgemeine Einstellungen des Image vornehmen
        width = @layout_file.get_attr_value(S_WIDTH).to_f
        height = @layout_file.get_attr_value(S_HEIGHT).to_f

        preview = true

        card_offset = 0

        image_width = width_with_margins(width)
        image_height = 2 * height_with_margins(height) + card_offset

        rvg = Magick::RVG.new(mm(image_width), mm(image_height)) do |canvas|
          draw_pos_x = 0
          draw_pos_y = 0
          canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
            draw(canvas1, @layout_file, preview, @selected_object_id, row, 0, :all) # Seite 1 drucken
          end

          draw_pos_y = height_with_margins(height) + card_offset
          canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
            draw(canvas1, @layout_file, preview, @selected_object_id, row, 1, :all) # Seite 2 drucken
          end

          canvas.background_fill = "white"
        end

        # ..........................................................................................
        # Image in einen Blob schreiben, damit es dann aus diesem heraus angezeigt werden kann
        data = rvg.draw.to_blob do |image|
          image.format = "PNG"
        end

        @parent.runOnUiThread do
          # das erzeugte Bild als Icon anzeigen
          fx_image = FXPNGImage.new(@parent.app, data)
          fx_image.create
          begin
            @image_view.image = fx_image
            @image_view.show
            @image_view.recalc
          rescue RuntimeError => e
            raise unless /already released/.match?(e.to_s)
          end
        end
      rescue Printer::Base::PrintError => e
        @parent.runOnUiThread do
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen eines Grafikobjekts", e.to_s)
        end
        @printing = false
      rescue => e
        DebugTools.write_log_file("draw_preview_thread", DebugTools.unkown_error_message(e))
        @parent.runOnUiThread do
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen der Layoutvorschau", DebugTools.unkown_error_message(e))
        end
        # rescue
      end
      #---------------------------------------------------------------------------------------------------------

      def check_if_font_exist(fontdesc)
        rmfl = []
        Magick.fonts.each do |mf|
          rmfl << mf.name
        end
        return fontdesc if rmfl.index(fontdesc.face.tr(" ", "-").delete("@"))
        fdlg.execute
      end
      #---------------------------------------------------------------------------------------------------------
    end
  end
end
