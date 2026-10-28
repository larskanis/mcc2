require "nokogiri"               # für die Layout-Datei
require "mcc2/constants"
require "mcc2/layout_object/go_attribut"
require "mcc2/layout_object/graphic"    # die Basisklasse für die grafischen Objekte
require "mcc2/layout_object/barcode"    # grafische Barcode-Objekte
require "mcc2/layout_object/picture"    # grafische Bild-Objekte
require "mcc2/layout_object/text"       # grafische Text-Objekte
require "mcc2/layout_object/box"
require "mcc2/layout_object/magstripe"
require "mcc2/layout_object/chip"
require "mcc2/layout_object/embed"

module Mcc2
  module Printer
    autoload :PrinterXID, "mcc2/printer/printer_xid"
    autoload :GdiPrinter, "mcc2/printer/gdi_printer"
    autoload :FilePrinter, "mcc2/printer/file_printer"
    autoload :LinuxCupsPrinter, "mcc2/printer/linux_cups_printer"
    autoload :PrinterZebra, "mcc2/printer/printer_zebra"
    autoload :PrinterCab, "mcc2/printer/printer_cab"
    autoload :PrinterEpl, "mcc2/printer/printer_epl"
    autoload :PrinterCx320Direct, "mcc2/printer/printer_cx320_direct"
    autoload :PrinterCx320Gdi, "mcc2/printer/printer_cx320_gdi"
    autoload :PrinterTTP34x, "mcc2/printer/printer_ttp34x"
  end

  module DataMan
    autoload :Database, "mcc2/dataman/database"
    autoload :CSV, "mcc2/dataman/csv"
    autoload :DBF, "mcc2/dataman/dbf"
    autoload :None, "mcc2/dataman/none"
  end

  class LayoutFile
    class Error < RuntimeError
    end

    class WrongDataSourceEncoding < Error
    end

    class WrongDataSourceType < Error
    end

    class InvalidFileVersion < Error
    end

    FILE_VERSION_RANGE = 1..4

    attr_accessor :attributes
    attr_accessor :filename
    attr_reader :warnings
    attr_reader :xpath_changes

    def self.load_from_xml(*args)
      o = new
      o.load_from_xml(*args)
      o
    end
    #---------------------------------------------------------------------------------------------------------

    def self.create_xml(*args)
      o = new
      o.create_xml(*args)
      o
    end
    #---------------------------------------------------------------------------------------------------------

    def initialize
      @changed = true
      @xml_doc = nil
      @attributes = {}
      add_attr(S_DUPLEX, String, false)
      add_attr(S_FRONT_FLIP, String, false)
      add_attr(S_FRONT_FLOP, String, false)
      add_attr(S_BACK_FLIP, String, true)
      add_attr(S_BACK_FLOP, String, true)
      add_attr(S_WIDTH, Integer, LAYOUT_DEFAULT_WIDTH)
      add_attr(S_HEIGHT, Integer, LAYOUT_DEFAULT_HEIGHT)
      add_attr(S_X_OFFSET, Integer, LAYOUT_DEFAULT_X_OFFSET)
      add_attr(S_Y_OFFSET, Integer, LAYOUT_DEFAULT_Y_OFFSET)
      add_attr(S_BARCODE_DPI, Float, 203.2)
      add_attr(S_DATASOURCE, String, "")
      add_attr(S_DATASOURCETYP, String, NONE)
      add_attr(S_DATASOURCEENCODING, String, ENC_UTF8)
      add_attr(S_CONTACTLESS, String, false)
      add_attr(S_CONTACT, String, false)
      add_attr(S_MAGSTRIPE, String, false)
      add_attr(S_PRINTERTYPE, String, "FilePrinter")
      add_attr(S_FILEPRINTER_SAVE_AS, String, "./mcc2_%d_%p.jpeg")
      add_attr(S_FILEPRINTER_DPI, Integer, 300)
      add_attr(S_LINUX_CUPS_PRINTER, String, "")
      add_attr(S_LINUX_CUPS_OPTIONS, String, '{"print-scaling":"none"}')
      add_attr(S_LINUX_CUPS_DPI, Integer, 200)
      add_attr(S_GDIPRINTER_NAME, String, "")
      add_attr(S_GDIPRINTER_INITDATA, String, "")
      add_attr(S_XIDPRINTER_NAME, String, "")
      add_attr(S_XIDPRINTER_INITDATA, String, "")
      add_attr(S_ZEBRAPRINTER_NAME, String, "")
      add_attr(S_ZEBRAPRINTER_INITDATA, String, "")
      add_attr(S_CABPRINTER_HOST, String, "localhost")
      add_attr(S_CABPRINTER_PORT, Integer, 9100)
      add_attr(S_CABPRINTER_DPI, Integer, 300)
      add_attr(S_CABPRINTER_PAGE_COMMANDS, String,
        'ePNG;*
dPNG;pngimg
\e.%IMAGE_DATA_PNG%\e.
mm
zO
J
H125,+0,T,R0
P0.00
O R
Sl1;0.0,0.00,%PAGE_HEIGHT%,%PAGE_HEIGHT%,%PAGE_WIDTH%
I:Field1;%PAGE_OFFSET_X%,%PAGE_OFFSET_Y%,0;pngimg
A1
')
      add_attr(S_EPLPRINTER_DEVICE, String, "/dev/usb/lp0")
      add_attr(S_EPLPRINTER_DPI, Integer, 203)
      add_attr(S_EPLPRINTER_PAGE_COMMANDS, String,
        '
OD
N
D8
S2
q%PAGE_WIDTH_PX%
GK"*"
GM"image1"%IMAGE_LEN_DATA_PCX%
O
JF
WN
ZB
GG%PAGE_OFFSET_X_PX%,%PAGE_OFFSET_Y_PX%,"image1"
P1
')

      add_attr(S_TTP34XPRINTER_DEVICE, String, "/dev/usb/lp0")
      add_attr(S_TTP34XPRINTER_DPI, Integer, 300)
      add_attr(S_TTP34XPRINTER_PAGE_COMMANDS, String,
        'SPEED 8 REM Wertebereich: 1-8
DENSITY 12 REM Wertebereich: 0-15
SIZE %PAGE_WIDTH_MM% mm,%PAGE_HEIGHT_MM% mm
CLS
DOWNLOAD "label.pcx",%IMAGE_LEN_DATA_PCX%
PUTPCX %PAGE_OFFSET_X_PX%,%PAGE_OFFSET_Y_PX%,"label.pcx"
PRINT 1
')

      add_attr(S_CX320_DRIVER, String, "CX320_DLL")
      add_attr(S_CX320_PRINTER_NR, Integer, 0)
      add_attr(S_CX320_PARALLEL_PRINT, String, "second_card")
      add_attr(S_CX320_CONFIG, String, "{}")

      @warnings = []
    end

    private def apply_xpath_changes(xpath_changes)
      xpath_changes.each do |xpath, value|
        if !(m = /^\{(?<filematch>.*)\}(?<xpath>.*)$/.match(xpath)) || (filename && File.fnmatch?(m[:filematch], File.basename(filename)))
          change_first_xpath_value(m&.[](:xpath) || xpath, value)
        end
      end
      @xpath_changes = xpath_changes
    end

    # erzeugt eine neue XML-Datei und initialisiert die entsprechenden Variablen und Objekte
    def create_xml(filename, xpath_changes = {})
      @filename = filename
      @xml_doc = Nokogiri::XML::Document.new
      @xml_doc.encoding = "UTF-8"
      @xml_doc.root = Nokogiri::XML::Node.new(S_ROOT, @xml_doc)

      # Layout definieren
      @xml_doc.root << node = Nokogiri::XML::Node.new(S_LAYOUT, @xml_doc)
      attributes.each_pair do |attr_name, attr|
        n = Nokogiri::XML::Node.new(attr.attr_name, @xml_doc)
        n.content = attr.attr_value.to_s
        node << n
      end

      # Chip definieren
      @xml_doc.root << node = Nokogiri::XML::Node.new(S_CHIP, @xml_doc)
      (1..CHIPPARAM_FIELD_COUNT).each do |i|
        node << Nokogiri::XML::Node.new("#{S_PARAM}_#{i}", @xml_doc)
      end

      # Magstripe definieren
      ensure_magsripe_attrs

      # Container für die GraphikObjekte definieren definieren
      @xml_doc.root << node = Nokogiri::XML::Node.new(GRAPHICOBJECTS, @xml_doc)

      apply_xpath_changes(xpath_changes)

      changed!
    end

    # lädt das XML-File und initialisiert die entsprechenden Variablen und Objekte
    # ==== Parameter
    # +filename+:: der NAme des XML-Files in welchem die Layout-Spezifikation gespeichert werden soll
    def load_from_xml(filename, xpath_changes = {})
      return nil if filename == ""

      @filename = filename
      @changed = false
      @xml_doc = File.open(filename) { |fd| Nokogiri::XML(fd) }

      apply_xpath_changes(xpath_changes)

      @xml_doc.root["version"] ||= "1"
      filever = @xml_doc.root["version"].to_i
      unless FILE_VERSION_RANGE.include?(filever)
        raise InvalidFileVersion, I18n.t(:open_layout_version_error, default: "Die Datei %{filename} ist nach Version %{filever} aufgebaut, dieses Programm kann aber nur die Versionen %{supported} verarbeiten", filename: filename.inspect, filever: , supported: FILE_VERSION_RANGE.inspect)
      end

      if filever == 1 && have_barcode_objects?
        @warnings << I18n.t(:open_layout_old_barby, default: <<~EOT)
          Diese Datei ist noch mit Barby-, statt den neueren Zint-Barcodes aufgebaut.
          Daher müssen alle Barcodes geprüft und ggf. neu justiert werden!
          Diese Warnung entfällt, sobald diese Datei einmal gespeichert wird.
        EOT
      end

      # ................................................................................................................................
      # die allgemeine Layout-Einstellungen auslesen

      # kontrollieren, ob alle Nodes des Layouts existieren, ansonsten anlegen und als 'changed' markieren
      lay_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{S_LAYOUT}")
      @attributes.each_pair do |attr_bez, attr|
        element = lay_attrs.at_xpath(attr.attr_name)
        unless element
          n = Nokogiri::XML::Node.new(attr.attr_name, @xml_doc)
          n.content = attr.attr_value.to_s
          lay_attrs << n
          changed!
        end
      end

      # kontrollieren, ob die Datenquelle eine gültige Angabe ist, wenn nicht, dann den Benutzer informieren und auf Standard setzen
      check_valid_datasourcetyp

      # wenn bei Datensourectyp nicht 'none' eingetrage ist, also eine Datenquelle verwendet wird
      # kontrollieren, ob das eingestellte Encoding eine gültige Angabe ist, wenn nicht, dann den Benutzer informieren und auf Standard setzen
      unless get_attr_value(S_DATASOURCETYP) == NONE
        check_valid_encoding
      end

      # ................................................................................................................................
      # die Chip-Einstellungen auslesen

      # kontrollieren, ob alle Nodes des Chips existieren, ansonsten als 'changed' markieren, da sie angelegt werden
      chip_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{S_CHIP}")
      (1..CHIPPARAM_FIELD_COUNT).each do |i|
        attr_name = "#{S_PARAM}_#{i}"
        element = chip_attrs.at_xpath(attr_name)
        unless element
          changed!
        end

        # Older files store chip params as array.
        # Change them to hash form with the index as the key.
        if filever < 3
          param = element.content
          if i == 8
            if !param.to_s.empty?
              if param =~ /^RUBY;(.*)/
                param = "RubyJobFile=#{$1}"
                set_attr_value(attr_name, param, S_CHIP)
              else
                raise InvalidScriptType, "invalid perso script: #{param.inspect}"
              end
            end
          elsif i == 23
            if !param.to_s.empty?
              param = "OpenReader=#{param}"
              set_attr_value(attr_name, param, S_CHIP)
            end
          elsif !param.to_s.empty?
            param = "#{i}=#{param}"
            set_attr_value(attr_name, param, S_CHIP)
          end
        end
      end

      # Older files don't respect the bounding box of text objects
      # and object's Y means the text baseline, not the bounding box.
      if filever < 4
        @warnings << I18n.t(:open_layout_old_text_box, default: <<~EOT)
          Diese Datei ist noch mit Textobjekten ohne Beachtung der Rahmengröße gespeichert.
          Die Rahmengröße der Textobjekte wurde nun automatisch auf den des Beispieltextes gesetzt.
          Evtl. muss aber eine Anpassung für die variablen Daten erfolgen.

          Bitte prüfen Sie, dass alle Texte an der richtigen Position stehen.
        EOT

        converter = Class.new(Printer::Base) do
          include SvgDrawer

          def pango_font_of(go)
            font = go[GOA_FONT_TYP]
            if font == "from_file"
              font = go.layout_file.expand_path(go[GOA_FONT_FILE])
            end
            fontsize = go[GOA_FONT_HEIGHT].to_f
            begin
              font_info = get_font_info(font, go)
            rescue Printer::Base::ResourceNotFoundError
              # ignore font error in the migration because
              # verification is requested from the user anyway
              _key, font_info = font_map.first
            end
            get_pango_font(font_info, pt(fontsize))
          end

          def get_text_sizes(go)
            data = go[GOA_SAMPLE_DATA].to_s
            if !data.empty?
              pango_font = pango_font_of(go)
              context  = pango_font_map.create_context
              layout   = Pango::Layout.new(context)
              layout.font_description = pango_font
              layout.text = data # set the text to render

              layout.pixel_size.map{|px| px_to_mm(px) }
            end
          end

          def get_new_coods(go)
            x = go[GOA_X].to_f
            y = go[GOA_Y].to_f
            rotation = go[GOA_ROTATION].to_f

            context  = pango_font_map.create_context
            pango_font = pango_font_of(go)
            metrics = context.get_metrics(pango_font, Pango::Language.default)

            descent     = metrics.descent.to_f / Pango::SCALE
            line_height = metrics.height.to_f / Pango::SCALE
            rec = Printer::Base::Transformation.new(x, y).rotate(rotation).translate(0, -px_to_mm(line_height - descent))
            return rec.x, rec.y
          end
        end.new

        converter.add_fonts_from_layout(self)

        # Remove "-" from font names, which was inserted by rmagick
        sorted_id_list.each do |id|
          go = find_graphic_object_by_id(id)
          font = go[GOA_FONT_TYP]
          if font && font != "from_file"
            font = font.tr("-", " ")
            set_object_by_ids([id], GOA_FONT_TYP, font)
          end
        end

        # Set a valid size in all text objects to the boinding box of the sample text
        # and adjust X,Y position to the corner of the box.
        sorted_id_list.each do |id|
          go = find_graphic_object_by_id(id)
          typ = go[GOA_TYP]
          if typ == TEXTOBJECT
            just = go[GOA_JUSTIFICATION]
            just = just.sub("Links", "left")
              .sub("Mitte", "mid")
              .sub("Rechts", "right")

            w, h = converter.get_text_sizes(go)
            # set bounding box and keep a little bit of space for safty
            if just == S_JUST_LEFT
              # Don't change middle or right aligned, they should already be valid
              set_object_by_ids([id], GOA_WIDTH, format("%0.2f", w * 1.1 + 5.0))
            end
            set_object_by_ids([id], GOA_HEIGHT, format("%0.2f", h * 1.1 + 1))

            x, y = converter.get_new_coods(go)
            # move text up, because old old Y means text baseline
            # and new Y means upper left corner of the bounding box
            set_object_by_ids([id], GOA_X, format("%0.2f", x))
            set_object_by_ids([id], GOA_Y, format("%0.2f", y))

            set_object_by_ids([id], GOA_JUSTIFICATION, just)
          end
        end
      end

      ensure_magsripe_attrs

      # ................................................................................................................................
      # die Einstellungen der graphischen Objekte auslesen

      # kontrollieren, ob alle Nodes der GraphicObjects existieren, ansonsten anlegen und als 'changed' markieren
      @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each do |go_struct|
        typ = go_struct.at_xpath(GOA_TYP).content
        go = LayoutObject::Graphic.get_object_by_typ(typ)
        go.go_attributes.each_pair do |go_attrname, go_attr|
          element = go_struct.at_xpath(go_attr.attr_name)
          unless element
            n = Nokogiri::XML::Node.new(go_attr.attr_name, @xml_doc)
            n.content = go_attr.attr_value.to_s
            go_struct << n
            changed!
          end
        end
      end
    end

    def ensure_magsripe_attrs
      # ................................................................................................................................
      # die Magnetstreifen-Einstellungen auslesen

      # kontrollieren, ob alle Nodes des Magstripes existieren, ansonsten anlegen und als 'changed' markieren
      # todo
      node_lay = @xml_doc.at_xpath("//#{S_ROOT}")
      node_ms = node_lay.at_xpath("//#{S_ROOT}//#{S_MAGSTRIPEPARAMS}")
      unless node_ms
        node_ms = Nokogiri::XML::Node.new(S_MAGSTRIPEPARAMS, @xml_doc)
        node_lay << node_ms
        changed!
      end
      unless node_ms.at_xpath(S_MSSPUR1)
        node_ms << Nokogiri::XML::Node.new(S_MSSPUR1, @xml_doc)
        changed!
      end
      unless node_ms.at_xpath(S_MSSPUR2)
        node_ms << Nokogiri::XML::Node.new(S_MSSPUR2, @xml_doc)
        changed!
      end
      unless node_ms.at_xpath(S_MSSPUR3)
        node_ms << Nokogiri::XML::Node.new(S_MSSPUR3, @xml_doc)
        changed!
      end
    end

    def have_barcode_objects?
      sorted_id_list.find do |id|
        go = find_graphic_object_by_id(id)
        go[GOA_TYP] == BARCODEOBJECT
      end
    end

    def find_graphic_object_by_id(id)
      go = get_objectnode_by_id(id)
      typ = go.at_xpath(GOA_TYP).content

      LayoutObject::Graphic.get_object_by_typ(typ, xml_elem: go, layout_file: self)
    end

    def magstripe_object
      ms_node = @xml_doc.at_xpath("//#{S_ROOT}//#{S_MAGSTRIPEPARAMS}")
      LayoutObject::Magstripe.new(ms_node)
    end

    def chip_object
      chip_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{S_CHIP}")
      LayoutObject::Chip.new chip_attrs
    end

    # holt den Zweig mit den Einstellungen eines graphischen Objekts aus dem XML-File mit der Layout-Spezifikation
    # ==== Parameter
    # +id+:: die Nummer, unter welcher das Attribut gespeichert ist
    private def get_objectnode_by_id(id)
      @xml_doc.at_xpath("(//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT})[#{id+1}]")
    end

    def get_layers_of_page(page_nr)
      @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").select do |go_struct|
        go_struct.at_xpath(GOA_PAGE_NR).content.to_i == page_nr
      end.map do |go_struct|
        go_struct.at_xpath(GOA_LAYER).content.to_i
      end.uniq
    end

    def get_object_by_id(obj_id, attr)
      node = get_objectnode_by_id(obj_id)
      node.at_xpath(attr).content if node
    end

    # return true  - etwas verändert
    #        false - nichts verändert
    def set_object_by_ids(obj_ids, attr, value)
      ch = false
      obj_ids.each do |obj_id|
        node = get_objectnode_by_id(obj_id).at_xpath(attr)

        # When multiple objects are selected -> ignore attributes not available for this object
        next if !node && obj_ids.size > 1

        value = value.to_s
        if node.content != value
          node.content = value
          ch ||= changed!
        end
      end
      ch
    end

    # Fügt ein Graphik-Objekt zur Layout-Definition hinzu
    # ==== Parameter
    # +typ+:: Typ (Text, Barcode oder Bild)
    # ==== Return
    # Object [XML-Node]
    def add_object(typ)
      o = LayoutObject::Graphic.get_object_by_typ(typ)
      id = get_new_id
      node = @xml_doc.at_xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}")
      go = Nokogiri::XML::Node.new(GRAPHICOBJECT, @xml_doc)
      node << go
      n = Nokogiri::XML::Node.new(GOA_TYP, @xml_doc)
      n.content = typ
      go << n
      n = Nokogiri::XML::Node.new(GOA_ID, @xml_doc)
      n.content = id.to_s
      go << n
      n = Nokogiri::XML::Node.new(GOA_NAME, @xml_doc)
      n.content = "#{typ}##{id}"
      go << n
      o.go_attributes.each_pair do |goa_name, go_attribute|
        unless [GOA_TYP, GOA_NAME].include?(go_attribute.attr_name)
          n = Nokogiri::XML::Node.new(go_attribute.attr_name, @xml_doc)
          n.content = go_attribute.attr_value.to_s
          go << n
        end
      end
      changed!

      LayoutObject::Graphic.get_object_by_typ(typ, xml_elem: go, layout_file: self)
    end

    # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
    def get_new_id
      @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").size
    end

    # liest die ID's der graphischen Objekte aus der Layout-Definition (XML) aus und
    # sortiert sie
    # ==== Return
    # die sortierte Liste mit ID's [Array]
    def sorted_id_list
      @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").size.times.to_a
    end

    # Reindex the objects according to the passed array of obj_ids
    def reorder_id_list(obj_ids)
      # Die ID's im XML entsprechend des ARRAY-Indexes über die alte ID setzen (ist automatisch eine Re-Indizierung zum Entfernen von Löschern.
      # Dabei alle Objekte durchlaufen und im Array die Position der alten ID suchen und in die ID schreiben.
      # Dies muss so getan werden.
      # Wenn es anders herum versucht wird, d.h. das Array durchlaufen und dann das Objekt im XML gesucht, dann werden die ID's schon verändert und die Suche schlägt dann fehl.
      base = @xml_doc.at_xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}")
      elements = base.elements
      obj_ids.each do |id|
        elements[id].parent = base
      end
      changed!
    end

    # ermittelt den Inhalt eines Attributes des Layout-Abschnittes
    # ==== Return
    # den Inhalt des Attributes [String]
    # ==== Parameter
    # +attr_name+:: der Name des Attributes z.Bsp. 'datasource' Bitte vorwiegend Konstanten verwenden z. Bsp. S_DATASOURCE [String]
    def get_attr_value(attr_name, base = S_LAYOUT)
      lay_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{base}")
      attr = lay_attrs.at_xpath(attr_name)
      attr&.content
    end

    # setzt den Inhalt eines Attributes des Layout-Abschnittes
    # ==== Return
    #   true wenn erfolgreich geändert
    #   false wenn keine Änderung
    # ==== Parameter
    # +attr_name+:: der Name des Attributes z.Bsp. 'datasource' Bitte vorwiegend Konstanten verwenden z. Bsp. S_DATASOURCE [String]
    # +value+:: der Wert der geschrieben werden soll [String]
    def set_attr_value(attr_name, value, base = S_LAYOUT)
      lay_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{base}")
      attr = lay_attrs.at_xpath(attr_name)
      value = value.to_s
      if attr.content != value
        attr.content = value
        changed!
      else
        false
      end
    end

    # fügt ein neues Atrtribut zur Liste der Attribute (@attributes) hinzu
    # ==== Parameter
    # +name+::    der Name, den das Attribut erhalten soll
    # +typ+::     der Typ
    # +default+:: der Wert, mit dem das Attribut vorinitialisiert werden soll
    def add_attr(name, typ, default)
      attr = LayoutObject::GO_Attribut.new(name, typ, default)
      @attributes[attr.attr_name] = attr
    end

    def change_first_xpath_value(xpath, value)
      attr = @xml_doc.at_xpath(xpath)
      raise I18n.t(:set_xpath_no_element_error, default: "Kein Element unter XPath %{xpath} in Datei %{filename} gefunden", xpath: xpath.inspect, filename: @filename) unless attr
      puts I18n.t(:set_xpath_element, default: "Setze Element unter XPath %{xpath} in Datei %{filename} auf %{value}", xpath: xpath.inspect, filename: @filename, value: value.inspect)
      if attr.content != value
        attr.content = value
        changed!
      else
        false
      end
    end

    def save
      # IDs sequenziell nummerieren für Kompatibilität mit älteren mcc2
      @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each_with_index do |go_struct, idx|
        go_struct.at_xpath(GOA_ID).content = idx
      end

      @xml_doc.root["version"] = FILE_VERSION_RANGE.last.to_s
      File.open(@filename, "w") do |fd|
        @xml_doc.write_to(fd, indent: 2)
      end
      @changed = false
    end

    # überprüft, ob der Wert Datasourcetyp in der Layoutdefinition ein gültiger Wert ist.
    # Wenn nicht, wird ein Fehlerdialog angezeigt und der Standardwert gesetzt und das changed-Flag gesetzt
    def check_valid_datasourcetyp
      datasourcetyp = get_attr_value(S_DATASOURCETYP)
      unless DataMan.valid_datasourcetyp?(datasourcetyp)
        default = @attributes[S_DATASOURCETYP].attr_value
        set_attr_value(S_DATASOURCETYP, default)
        raise WrongDataSourceType, I18n.t(:open_layout_invalid_datasource_type, default: <<~EOTXT, datasourcetyp:, valid_types: VALID_DATASOURCES.join("', '"), new: default )
          Der eingestellte Datenquellentyp '%{datasourcetyp}' ist ungültig.

          Gültige Werte sind '%{valid_types}'.

          Der Wert wird jetzt auf den Standardwert '%{new}'  gesetzt.

          Bitte stellen Sie in den Layouteigenschaften den korrekten Datenquellentyp
          ein und speichern Sie die Einstellungen.
        EOTXT
      end
    end

    # überprüft, ob der Wert Datasourcencoding in der Layoutdefinition ein gültiger Wert ist.
    # Wenn nicht, wird ein Fehlerdialog angezeigt und der Standardwert gesetzt und das changed-Flag gesetzt
    def check_valid_encoding
      datasource_encoding = get_attr_value(S_DATASOURCEENCODING)
      unless DataMan.valid_datasource_encoding?(datasource_encoding)
        default = "UTF-8"
        set_attr_value(S_DATASOURCEENCODING, default)
        raise WrongDataSourceEncoding, I18n.t(:open_layout_invalid_datasource_encoding, default: <<-EOTXT, datasource_encoding:, valid_encodings: VALID_ENCODINGS.join("', '"))
        Das eingestellte Encoding der Datenquelle '%{datasource_encoding}' ist ungültig.

        Gültige Werte sind '%{valid_encodings}'.

        Bitte stellen Sie in den Layouteigenschaften das korrekte Encoding
        ein und speichern Sie die Einstellungen.
        EOTXT
      end
    end
    #---------------------------------------------------------------------------------------------------------

    # ersetllt ein neues Graphik-Objekt und kopiert alle Attributte des übergebenen, außer ID, Typ und Name
    # ==== Parameter
    # +node+:: die XML-Node des zu kopierenden Objekts, fals nil übergeben wurde, kehrt die Methode unverrichteter Dinge zurück
    def copy_objects(ids)
      ids.each do |id|
        obj = find_graphic_object_by_id(id)

        o = add_object(obj[GOA_TYP])
        obj.attributes.each do |attr|
          # alle Attribute, außer Typ und Name kopieren, sofern sie vorhanden, ansonsten den Standard lassen
          unless [GOA_TYP, GOA_NAME].include?(attr)
            o[attr] = obj[attr]
          end
        end
      end
      changed!
    end

    def clipboard_copy(ids)
      ids.map do |id|
        get_objectnode_by_id(id).to_xml
      end.join("\n")
    end

    def clipboard_cut(ids)
      xml = clipboard_copy(ids)
      changed  = delete_objects(ids)
      return xml, changed
    end

    def clipboard_paste(xml_data, after_id:)
      frag = Nokogiri::XML.fragment(xml_data)
      num_elements = frag.elements.size
      if after_id
        node = get_objectnode_by_id(after_id)
        if node
          node.add_next_sibling(frag)
        else
          node = @xml_doc.at_xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}")
          node.prepend_child(frag)
        end
      else
        node = @xml_doc.at_xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}")
        after_id = node.elements.size - 1
        node << frag
      end

      changed! if num_elements > 0
      num_elements.times.map {|t| after_id ? t + after_id + 1 : t }
    end

    # löscht sie übergebene XML-Node aus dem Layout ohne Rückfrage, diese muss in der aufrufenden Methode durchgeführt werden
    # ==== Parameter
    def delete_objects(ids)
      changed = false
      ids.sort.reverse.each do |id|
        obj = find_graphic_object_by_id(id)
        obj.delete
        changed = true
      end
      changed! if changed
    end

    def build_printer_instance
      printertype = get_attr_value(S_PRINTERTYPE)
      printerclass = Printer.const_get(printertype)
      printerclass.new
    end

    def build_dataman_instance
      datamantyp = get_attr_value(S_DATASOURCETYP)
      datasource = get_attr_value(S_DATASOURCE)
      encoding = get_attr_value(S_DATASOURCEENCODING)
      # Ruby-1.9 kennt kein LATIN1
      encoding = "iso-8859-1" if /latin1/i.match?(encoding)

      if datamantyp == DATABASE
        DataMan::Database.new(datasource)
      elsif datamantyp == CSV
        datasource = expand_path(datasource)
        DataMan::CSV.new(datasource, encoding)
      elsif datamantyp == DBF
        datasource = expand_path(datasource)
        DataMan::DBF.new(datasource, encoding)
      elsif datamantyp == NONE
        DataMan::None.new(datasource)
      else
        raise "invalid type of datasource #{datamantyp.inspect}"
      end
    end

    def build_chip_instance
      if get_attr_value(S_CONTACTLESS) == S_TRUE || get_attr_value(S_CONTACT) == S_TRUE
        chip_object
      end
    end

    def get_binary_attr(attr)
      initdatahex = get_attr_value(attr)
      if initdatahex && !initdatahex.empty?
        [initdatahex].pack("H*")
      end
    end

    def set_binary_attr(attr, bindata)
      set_attr_value(attr, bindata.unpack1("H*"))
    end

    def expand_path(path)
      path = path.gsub("%D", File.dirname(File.expand_path(@filename))) if @filename
      path = path.gsub("%F", File.basename(@filename, ".*")) if @filename
      pa = File.expand_path(path)
      pa += "/" if path.end_with?("/")
      pa
    end

    def shrink_path(path)
      path = path.tr("\\", "/")
      if @filename
        path = path.sub(File.dirname(File.expand_path(@filename)), "%D")
      end
      if pwd = Dir.pwd
        path = path.sub(pwd + "/", "")
      end
      if home = Dir.home
        path = path.sub(home + "/", "~/")
      end
      path
    end

    def changed?
      @changed
    end

    def changed!
      @changed = true
    end
  end
end
