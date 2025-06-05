require "mcc2/printer/base"           # die Basisklasse für die Printer
require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"

module Mcc2
  module Printer
    class Preview < Base
      include RmagickDrawer
      include CardPrinting
      include Fox

      def initialize(parent, layout)
        super()
        @parent = parent
        @layout = layout
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
          FXLabel.new(frame1, "Barcodes optimieren auf")
          @textfield_barcode_dpi = FXTextField.new(frame1, 4) do |tf|
            tf.tipText = "DPI des Druckers"
            tf.connect(SEL_COMMAND) do
              @layout_file.set_attr_value(S_BARCODE_DPI, @textfield_barcode_dpi.text.to_f)
              @layout.changed_attributes
              draw_preview(true, @row)
            end
          end
          FXLabel.new(frame1, "DPI")
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
        @image_view.connect(SEL_LEFTBUTTONPRESS, &method(:image_view_clicked))

        set_zoom
      end

      def layout_file=(value)
        super
        @textfield_barcode_dpi.text = @layout_file.get_attr_value(S_BARCODE_DPI) || "203.0"
      end

      def selected_object_id= id
        @selected_object_id = id
        draw_preview false, @row
      end

      # DPI zuweisen ohne Exception wegen Unstimmigkeit
      def dpi=(v)
        v = v.to_f
        @dpi = v
      end

      def image_view_clicked(sender, sel, event)
        # There is no accessor for the content position in FXImageView.
        # So the calculation is a bit awkward.
        if @image_view.viewportWidth >= @image_view.contentWidth
          content_x = (@image_view.viewportWidth - @image_view.contentWidth) / 2
        else
          content_x = @image_view.xPosition
        end
        if @image_view.viewportHeight >= @image_view.contentHeight
          content_y = (@image_view.viewportHeight - @image_view.contentHeight) / 2
        else
          content_y = @image_view.yPosition
        end
        point = Vector2d.new(
          event.win_x - content_x,
          event.win_y - content_y)

        if @rect_list
          rects = @rect_list.point_inside(point)
          @layout.selected_object_id = rects.last&.obj_id
        end
      end

      # verändert die Zoomstufe, wenn am Rädchen gedreht wird
      def set_zoom
        self.dpi = @dial_zoom.value
        @label_zoom.text = "#{dpi} DPI"
        @parent.app.reg.writeRealEntry("settings", "preview_dpi", dpi)
      end

      # zeichnet die Vorschau im Layout-Modus
      # hier ist noch einiges zu tun, im speziellen sind einige Werte "hart" kodiert,
      # die z.Bsp abhängig von anderen Einstellungen sein sollten
      def draw_preview(immediately = false, row = nil)
        @row = row
        return unless @checkbutton_continous_update.checked?

        @draw_preview_at = Time.now + (immediately ? 0 : 0.1)
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

      class Transformation
        def initialize(x = 0.0, y = 0.0, a = 0.0)
          @x = x
          @y = y
          @a = a
        end

        def translate(x, y)
          self.class.new @x + x * Math.cos(@a*Math::PI/180) - y * Math.sin(@a*Math::PI/180),
            @y + y * Math.cos(@a*Math::PI/180) + x * Math.sin(@a*Math::PI/180),
            @a
        end

        def rotate(a)
          self.class.new @x, @y, @a + a
        end

        def vector2d
          Vector2d.new(@x, @y)
        end

        attr_reader :x
        attr_reader :y
        attr_reader :a
      end

      class Vector2d
        def initialize(x, y)
          @x = x
          @y = y
        end

        attr_reader :x
        attr_reader :y
      end

      def draw_preview_now(row = nil)
        # allgemeine Einstellungen des Image vornehmen
        width = @layout_file.get_attr_value(S_WIDTH).to_f
        height = @layout_file.get_attr_value(S_HEIGHT).to_f
        duplex = @layout_file.get_attr_value(S_DUPLEX) == S_TRUE

        preview = true

        card_offset = 0

        image_width = width_with_margins(width)
        image_height = (duplex ? 2 : 1) * height_with_margins(height) + card_offset

        rect_list = nil
        rvg = Magick::RVG.new(mm(image_width), mm(image_height)) do |canvas|

          # Vorderseite
          draw_pos_x = 0
          draw_pos_y = 0
          tra = Transformation.new
          canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
            rect_list = draw(canvas1, @layout_file, preview, @selected_object_id, row, 0, layers: :all,
                 transform: tra.translate(mm(draw_pos_x), mm(draw_pos_y)))
          end

          # Rückseite
          if duplex
            draw_pos_y = height_with_margins(height) + card_offset
            canvas.g.translate(mm(draw_pos_x), mm(draw_pos_y)) do |canvas1|
              rect_list.add draw(canvas1, @layout_file, preview, @selected_object_id, row, 1, layers: :all,
                  transform: tra.translate(mm(draw_pos_x), mm(draw_pos_y)))
            end
          end

          canvas.background_fill = "white"
        end

        # Image in einen Blob schreiben, damit es dann aus diesem heraus angezeigt werden kann
        data = rvg.draw.to_blob do |image|
          image.format = "PNG"
        end

        # das erzeugte Bild als Icon anzeigen
        fx_image = Fox::FXPNGImage.new(@parent.app)
        # in contrast to FXPNGImage.new, loadPixels releases the GVL
        Fox::FXMemoryStream.open(Fox::FXStreamLoad, data) do |infile|
          fx_image.loadPixels(infile)
        end

        @parent.runOnUiThread do
          @rect_list = rect_list
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
        DebugTools.write_exception("draw_preview_thread", e)
        @parent.runOnUiThread do
          FXMessageBox.error(@parent.app, MBOX_OK, "Fehler beim Erstellen der Layoutvorschau", DebugTools.unkown_error_message(e))
        end
        # rescue
      end

      def check_if_font_exist(fontdesc)
        rmfl = []
        Magick.fonts.each do |mf|
          rmfl << mf.name
        end
        return fontdesc if rmfl.index(fontdesc.face.tr(" ", "-").delete("@"))
        fdlg.execute
      end
    end
  end
end
