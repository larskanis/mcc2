require "mcc2/printer/base"           # die Basisklasse für die Printer
require "mcc2/printer/card_printer"
require "mcc2/printer/rmagick_drawer"
require "simple_logger"
require 'nokogiri'

module Mcc2
  module Printer
    class Preview < Base
      include RmagickDrawer
      include CardPrinting
      include Fox
      include SimpleLogging

      def initialize(parent, layout)
        super()
        @parent = parent
        @layout = layout
        @selected_object_ids = []
        @render_queue = nil
        @render_thread = nil
        @render_running = false

        FXHorizontalFrame.new(parent, opts: LAYOUT_FILL_X) do |frame1|
          @label_zoom = FXLabel.new(frame1, "") do |label_zoom|
            label_zoom.img = "mcc2/images/zoom-in.png"
            label_zoom.tipText = I18n.t(:preview_label_zoom_tip, default: "Hier kann die Vorschau vergrößert oder verkleinert werden. Wird die\ntatsächliche Auflösung des angeschlossenen Bildschirms eingestellt,\nerscheint die Vorschau in Originalgröße.")
          end
          @dial_zoom = FXDial.new(frame1, opts: DIAL_HORIZONTAL | LAYOUT_FIX_WIDTH, width: 100) do |dial_zoom|
            dial_zoom.tipText = @label_zoom.tipText
            dial_zoom.connect(SEL_CHANGED) { set_zoom }
            dial_zoom.connect(SEL_LEFTBUTTONRELEASE) { draw_preview(true, @row) }
            dial_zoom.value = @parent.app.reg.readRealEntry("settings", "preview_dpi", 90)
            dial_zoom.range = 1..1000
          end
          FXLabel.new(frame1, I18n.t(:preview_optimize_barcodes, default: "Barcodes optimieren auf"))
          @textfield_barcode_dpi = FXTextField.new(frame1, 4) do |tf|
            tf.tipText = I18n.t(:preview_optimize_barcodes_tip, default: "DPI des Druckers")
            tf.connect(SEL_COMMAND) do
              @layout_file.set_attr_value(S_BARCODE_DPI, @textfield_barcode_dpi.text.to_f)
              @layout.changed_attributes
              draw_preview(true, @row)
            end
          end
          FXLabel.new(frame1, "DPI")
          @checkbutton_continous_update = FXCheckButton.new(frame1, I18n.t(:preview_keep_updated, default: "Vorschau aktuell halten")) do |checkbutton|
            checkbutton.tipText = I18n.t(:preview_keep_updated_tip, default: "Bei Fehlern in den Layout-Einstellungen kann die Vorschau\nabgeschaltet werden, um mehrfache Hinweise zu vermeiden.")
            checkbutton.connect(SEL_COMMAND) do
              draw_preview(true, @row) if checkbutton.checked?
              @parent.app.reg.writeBoolEntry("settings", "preview_continous_update", checkbutton.checked?)
            end
            checkbutton.checkState = @parent.app.reg.readBoolEntry("settings", "preview_continous_update", true)
          end
        end

        @image_view = FXImageView.new(parent, opts: LAYOUT_FILL)
        @image_view.connect(SEL_LEFTBUTTONPRESS, &method(:image_view_clicked))
        @image_view.connect(SEL_KEYPRESS, &method(:image_view_keypress))

        @error_view = FXText.new(parent, opts: LAYOUT_FILL|TEXT_WORDWRAP)
        @error_view.editable = false
        enable_error_view(false)
        set_zoom
      end

      def enable_error_view(text = nil, error = nil)
        if text
          @image_view.visible = false
          @error_view.visible = true
          @error_view.text = "#{text}\n\n#{error}"
        else
          @image_view.visible = true
          @error_view.visible = false
          @error_view.text = ""
        end
      end

      def layout_file=(value)
        super
        @textfield_barcode_dpi.text = @layout_file.get_attr_value(S_BARCODE_DPI) || "203.0"
      end

      def selected_object_ids=(ids)
        @selected_object_ids = ids
        draw_preview false, @row
      end

      # DPI zuweisen ohne Exception wegen Unstimmigkeit
      def dpi=(v)
        v = v.to_f
        @dpi = v
      end

      def set_focus(to)
        @image_view.setFocus
      end

      def image_view_clicked(sender, sel, event)
        # There is no accessor for the content position in FXImageView.
        # So the calculation is a bit awkward.
        content_x = if @image_view.viewportWidth >= @image_view.contentWidth
          (@image_view.viewportWidth - @image_view.contentWidth) / 2
        else
          @image_view.xPosition
        end
        content_y = if @image_view.viewportHeight >= @image_view.contentHeight
          (@image_view.viewportHeight - @image_view.contentHeight) / 2
        else
          @image_view.yPosition
        end
        point = Vector2d.new(
          event.win_x - content_x,
          event.win_y - content_y
        )

        if @rect_list
          rect_ids = [@rect_list.point_inside(point).last&.obj_id].compact
          obj_ids = (event.state & Fox::CONTROLMASK != 0) ? @selected_object_ids : []
          @layout.selected_object_ids = obj_ids + rect_ids - (obj_ids & rect_ids)
        end

        @layout.set_focus(:layout)
      end

      def image_view_keypress(sender, sel, event)
        if event.type == 1 # Keypress
          case event.code
          when Fox::KEY_Up
            @layout.move_selected(0, -1, event.state)
          when Fox::KEY_Down
            @layout.move_selected(0, 1, event.state)
          when Fox::KEY_Left
            @layout.move_selected(-1, 0, event.state)
          when Fox::KEY_Right
            @layout.move_selected(1, 0, event.state)
          else
            0
          end
        end
      end

      # verändert die Zoomstufe, wenn am Rädchen gedreht wird
      def set_zoom
        self.dpi = @dial_zoom.value
        @label_zoom.text = "#{dpi} DPI"
        @parent.app.reg.writeRealEntry("settings", "preview_dpi", dpi)
      end

      # zeichnet die Vorschau im Layout-Modus
      def draw_preview(immediately = false, row = nil)
        @row = row
        return unless @checkbutton_continous_update.checked?

        @draw_preview_at = Time.now + (immediately ? 0 : 0.1)
        start_preview_timer
      end

      def start_preview_timer
        return unless @draw_preview_at

        @render_queue ||= Queue.new
        @render_thread ||= Thread.new do
          loop do
            @render_queue.pop

            # require 'ruby-prof'
            # result = RubyProf::Profile.profile do
            draw_preview_now(@row)
            # end
            # printer = RubyProf::GraphPrinter.new(result)
            # printer.print(STDOUT)

            @render_running = false
            # requeue preview generation, when something was changed
            # while the thread was running.
            @parent.runOnUiThread do
              start_preview_timer
            end
          end
        end

        delay = @draw_preview_at - Time.now
        @parent.app.addTimeout((delay > 0) ? delay * 1000 : 0) do
          if @draw_preview_at && !@render_running
            if Time.now >= @draw_preview_at
              @draw_preview_at = nil
              @render_running = true
              @render_queue << true
            else
              # addTimeout didn't wait as long as expected per Time.now -> re-schedule
              start_preview_timer
            end
          end
        end
      end

      attr_reader :font_map

      def draw_preview_now(row = nil)
        require 'rsvg2'
        require 'cairo'
        require 'pango'
        require 'ttfunk'

        @font_map = {}

        # allgemeine Einstellungen des Image vornehmen
        layout_width_mm = @layout_file.get_attr_value(S_WIDTH).to_f
        layout_height_mm = @layout_file.get_attr_value(S_HEIGHT).to_f
        duplex = @layout_file.get_attr_value(S_DUPLEX) == S_TRUE

        preview = true

        card_offset = 0

        image_width_mm = width_with_margins(layout_width_mm)
        image_height_mm = (duplex ? 2 : 1) * height_with_margins(layout_height_mm) + card_offset
        image_width = mm(image_width_mm).round
        image_height = mm(image_height_mm).round

        rect_list = nil

        log.info "rect_list = draw"
        svg_data = svg_builder(viewBox: "0.5 0.5 #{image_width} #{image_height}") do |svg|
          svg.g(transform: "scale(-1 -1) translate(-#{image_width} -#{image_height})") do

            # Front
            draw_pos_x = 0
            draw_pos_y = 0
            tra = Transformation.new
            rect_list = draw(svg, tra.translate(mm(draw_pos_x), mm(draw_pos_y)), @layout_file, preview, @selected_object_ids, row, 0, layers: :all)

            # Rear
            if duplex
              draw_pos_y = height_with_margins(layout_height_mm) + card_offset
              rect_list.add draw(svg, tra.translate(mm(draw_pos_x), mm(draw_pos_y)), @layout_file, preview, @selected_object_ids, row, 1, layers: :all)
            end
          end
        end
        # puts svg_data
        log.info "built svg text"

        svg_handle = RSVG::Handle.new_from_data(svg_data)

        surface = Cairo::ImageSurface.new(Cairo::FORMAT_RGB24, image_width, image_height)
        context = Cairo::Context.new(surface)
        context.render_rsvg_handle(svg_handle)

        log.info "rendered to pixels"

        fx_image = FXImage.new(@parent.app, nil, 0, image_width, image_height)
        argb = surface.data
        # Cairo uses BGRA pixel data memory layout, but FXRuby uses RGBA.
        argb.reverse! # make ARGB, works together with "rotate(180) translate(..)" above
        argb.delete_prefix!(argb[0]) # drop first byte to make RGB
        argb << "\0" # add the missing but ignored alpha byte to make RGBA
        fx_image.pixels = argb

        log.info "update GUI"

        @parent.runOnUiThread do
          enable_error_view(false)
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
          enable_error_view(*I18n.t(:preview_error_printing_object, default: [["Fehler beim Erstellen eines Grafikobjekts", "%{e}"]], e: e.to_s))
        end
        @printing = false
      rescue => e
        DebugTools.write_exception("draw_preview_thread", e)
        @parent.runOnUiThread do
          enable_error_view(*I18n.t(:preview_error_printing_exception, default: [["Fehler beim Erstellen der Layoutvorschau", "%{e}"]], e: DebugTools.unkown_error_message(e)))
        end
      end
    end
  end
end
