# -*- coding: UTF-8 -*-

require 'nokogiri'               # für die Layout-Datei
require 'mcc2/constants'
require 'mcc2/layout_object/go_attribut'
require 'mcc2/layout_object/graphic'    # die Basisklasse für die grafischen Objekte
require 'mcc2/layout_object/barcode'    # grafische Barcode-Objekte
require 'mcc2/layout_object/picture'    # grafische Bild-Objekte
require 'mcc2/layout_object/text'       # grafische Text-Objekte
require 'mcc2/layout_object/box'
require 'mcc2/layout_object/magstripe'
require 'mcc2/layout_object/chip'

module Mcc2
module Printer
  autoload 'PrinterXID', 'mcc2/printer/printer_xid'
  autoload 'GdiPrinter', 'mcc2/printer/gdi_printer'
  autoload 'FilePrinter', 'mcc2/printer/file_printer'
  autoload 'PrinterZebra', 'mcc2/printer/printer_zebra'
  autoload 'PrinterCab', 'mcc2/printer/printer_cab'
  autoload 'PrinterEpl', 'mcc2/printer/printer_epl'
  autoload 'PrinterCx320Direct', 'mcc2/printer/printer_cx320_direct'
  autoload 'PrinterCx320Gdi', 'mcc2/printer/printer_cx320_gdi'
end

module DataMan
  autoload 'Database', 'mcc2/dataman/database'
  autoload 'CSV', 'mcc2/dataman/csv'
  autoload 'DBF', 'mcc2/dataman/dbf'
  autoload 'None', 'mcc2/dataman/none'
end

class LayoutFile
  class Error < RuntimeError
  end
  class WrongDataSourceEncoding  < Error
  end
  class WrongDataSourceType  < Error
  end
  class InvalidFileVersion < Error
  end

  FILE_VERSION_RANGE = 1..1

  attr_accessor :attributes
  attr_accessor :filename

  def self.load_from_xml(filename)
    o = self.new
    o.load_from_xml(filename)
    return o
  end
  #---------------------------------------------------------------------------------------------------------

  def self.create_xml
    o = self.new
    o.create_xml
    return o
  end
  #---------------------------------------------------------------------------------------------------------

  def initialize
    @xml_doc = nil
    @attributes = {}
    add_attr(S_DUPLEX, String, FALSE)
    add_attr(S_WIDTH, Integer,  LAYOUT_DEFAULT_WIDTH)
    add_attr(S_HEIGHT, Integer, LAYOUT_DEFAULT_HEIGHT)
    add_attr(S_X_OFFSET, Integer, LAYOUT_DEFAULT_X_OFFSET)
    add_attr(S_Y_OFFSET, Integer, LAYOUT_DEFAULT_Y_OFFSET)
    add_attr(S_DATASOURCE, String, "")
    add_attr(S_DATASOURCETYP, String, NONE)
    add_attr(S_DATASOURCEENCODING, String, ENC_UTF8)
    add_attr(S_CONTACTLESS, String, FALSE)
    add_attr(S_CONTACT, String, FALSE)
    add_attr(S_MAGSTRIPE, String, FALSE)
    add_attr(S_PRINTERTYPE, String, 'FilePrinter')
    add_attr(S_FILEPRINTER_SAVE_AS, String, './mcc2_%d_%p.jpeg')
    add_attr(S_FILEPRINTER_DPI, Integer, 300)
    add_attr(S_GDIPRINTER_NAME, String, '')
    add_attr(S_GDIPRINTER_INITDATA, String, '')
    add_attr(S_XIDPRINTER_NAME, String, '')
    add_attr(S_XIDPRINTER_INITDATA, String, '')
    add_attr(S_ZEBRAPRINTER_NAME, String, '')
    add_attr(S_ZEBRAPRINTER_INITDATA, String, '')
    add_attr(S_CABPRINTER_HOST, String, 'localhost')
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
    add_attr(S_EPLPRINTER_DEVICE, String, '/dev/usb/lp0')
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
  end
  #---------------------------------------------------------------------------------------------------------
  def xml_doc
    @xml_doc
  end
  #---------------------------------------------------------------------------------------------------------

  # erzeugt eine neue XML-Datei und initialisiert die entsprechenden Variablen und Objekte
  def create_xml
    @xml_doc = Nokogiri::XML::Document.new
    @xml_doc.encoding = 'UTF-8'
    @xml_doc.root = Nokogiri::XML::Node.new(S_ROOT, @xml_doc)
    @xml_doc.root['version'] = FILE_VERSION_RANGE.last.to_s

    # Layout definieren
    @xml_doc.root << node = Nokogiri::XML::Node.new(S_LAYOUT, @xml_doc)
    attributes.each_pair do |attr_name, attr|
      n = Nokogiri::XML::Node.new(attr.attr_name, @xml_doc)
      n.content = attr.attr_value.to_s
      node << n
    end

    # Chip definieren
    @xml_doc.root << node = Nokogiri::XML::Node.new(S_CHIP, @xml_doc)
    (1 .. CHIPPARAM_FIELD_COUNT).each do |i|
      node << param = Nokogiri::XML::Node.new("#{S_PARAM}_#{i}", @xml_doc)
    end

    # Magstripe definieren
    ensure_magsripe_attrs

    # Container für die GraphikObjekte definieren definieren
    @xml_doc.root << node = Nokogiri::XML::Node.new(GRAPHICOBJECTS, @xml_doc)

  end
  #---------------------------------------------------------------------------------------------------------

  # lädt das XML-File und initialisiert die entsprechenden Variablen und Objekte
  # ==== Parameter
  # +filename+:: der NAme des XML-Files in welchem die Layout-Spezifikation gespeichert werden soll
  def load_from_xml(filename)
    return nil if filename == ""

    @xml_doc = File.open(filename){|fd| Nokogiri::XML(fd) }
    @xml_doc.root['version'] ||= '1'
    unless FILE_VERSION_RANGE.include?(@xml_doc.root['version'].to_i)
      raise InvalidFileVersion, "Die Datei #{filename.inspect} ist nach Version #{@xml_doc.root['version'].to_i} aufgebaut, dieses Programm kann aber nur die Versionen #{FILE_VERSION_RANGE.inspect} verarbeiten"
    end


    @filename = filename
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
        @changed = true
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

    # kontrollieren, ob alle Nodes des Chips existieren, ansonsten anlegen und als 'changed' markieren
    chip_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{S_CHIP}")
    (1 .. CHIPPARAM_FIELD_COUNT).each{|i|
      element = chip_attrs.at_xpath("#{S_PARAM}_#{i}")
      unless element
        #~ chip_attrs << param = Nokogiri::XML::Node.new(attr_name , "")
        @changed = true
      end
    }

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
          @changed = true
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
      @changed = true
    end
    unless node_ms.at_xpath(S_MSSPUR1)
      node_ms << Nokogiri::XML::Node.new(S_MSSPUR1, @xml_doc)
      @changed = true
    end
    unless node_ms.at_xpath(S_MSSPUR2)
      node_ms << Nokogiri::XML::Node.new(S_MSSPUR2, @xml_doc)
      @changed = true
    end
    unless node_ms.at_xpath(S_MSSPUR3)
      node_ms << Nokogiri::XML::Node.new(S_MSSPUR3, @xml_doc)
      @changed = true
    end
  end

  def find_graphic_object_by_id(id)
    go = xml_doc.at_xpath(
      "//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}/#{GOA_ID}[.='#{id.to_s}']").parent
    typ = go.at_xpath(GOA_TYP).content

    LayoutObject::Graphic.get_object_by_typ(typ, go)
  end

  def magstripe_object
    ms_node = xml_doc.at_xpath("//#{S_ROOT}//#{S_MAGSTRIPEPARAMS}")
    LayoutObject::Magstripe.new(ms_node)
  end

  def chip_object
    chip_attrs = xml_doc.at_xpath("//#{S_ROOT}/#{S_CHIP}")
    LayoutObject::Chip.new chip_attrs
  end

  # holt den Zweig mit den Einstellungen eines graphischen Objekts aus dem XML-File mit der Layout-Spezifikation
  # ==== Parameter
  # +id+:: die Nummer, unter welcher das Attribut gespeichert ist
  def get_objectnode_by_id(id)
    @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each do |go_struct|
      if go_struct.at_xpath(GOA_ID).content.to_i == id
        return go_struct
      end
    end
    nil
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

  def set_object_by_id(obj_id, attr, value)
    node = get_objectnode_by_id(obj_id)
    node.at_xpath(attr).content = value if node
  end


  # Fügt ein Graphik-Objekt zur Layout-Definition hinzu
  # ==== Parameter
  # +typ+:: Typ (Text, Barcode oder Bild)
  # ==== Return
  # Object [XML-Node]
  def  add_object(typ)
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
      unless [GOA_ID, GOA_TYP, GOA_NAME].include?(go_attribute.attr_name)
        n = Nokogiri::XML::Node.new(go_attribute.attr_name, @xml_doc)
        n.content = go_attribute.attr_value.to_s
        go << n
      end
    end
    go
  end

  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
    @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
      id = go.at_xpath(GOA_ID).content.to_i+1 if go.at_xpath(GOA_ID).content.to_i >= id
    }
    id
  end

  # liest die ID's der graphischen Objekte aus der Layout-Definition (XML) aus und
  # sortiert sie
  # ==== Return
  # die sortierte Liste mit ID's [Array]
  def sorted_id_list
    @xml_doc.xpath("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").collect{|go_struct|
      go_struct.at_xpath(GOA_ID).content.to_i
    }.sort!
  end

  # ermittelt den Inhalt eines Attributes des Layout-Abschnittes
  # ==== Return
  # den Inhalt des Attributes [String]
  # ==== Parameter
  # +attr_name+:: der Name des Attributes z.Bsp. 'datasource' Bitte vorwiegend Konstanten verwenden z. Bsp. S_DATASOURCE [String]
  def get_attr_value(attr_name)
    lay_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{S_LAYOUT}")
    attr = lay_attrs.at_xpath(attr_name)
    attr ? attr.content : nil
  end
  #---------------------------------------------------------------------------------------------------------

  # setzt den Inhalt eines Attributes des Layout-Abschnittes
  # ==== Return
  # true, wenn erfolgreich, ansonsten false
  # ==== Parameter
  # +attr_name+:: der Name des Attributes z.Bsp. 'datasource' Bitte vorwiegend Konstanten verwenden z. Bsp. S_DATASOURCE [String]
  # +value+:: der Wert der geschrieben werden soll [String]
  def set_attr_value(attr_name, value)
    lay_attrs = @xml_doc.at_xpath("//#{S_ROOT}/#{S_LAYOUT}")
    attr = lay_attrs.at_xpath(attr_name)
    if attr
      attr.content = value
      return true
    end
    return false
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
    raise "Kein Element unter XPath #{xpath.inspect} in Datei #{@filename} gefunden" unless attr
    puts "Setze Element unter XPath #{xpath.inspect} in Datei #{@filename} auf #{value.inspect}"
    attr.content = value
  end

  #
  def save
    File.open(@filename, "w") do |fd|
      @xml_doc.write_to(fd, :indent => 2)
    end
  end

  # überprüft, ob der Wert Datasourcetyp in der Layoutdefinition ein gültiger Wert ist.
  # Wenn nicht, wird ein Fehlerdialog angezeigt und der Standardwert gesetzt und das changed-Flag gesetzt
  def check_valid_datasourcetyp
    datasourcetyp = get_attr_value(S_DATASOURCETYP)
    unless DataMan.valid_datasourcetyp?(datasourcetyp)
      default = @attributes[S_DATASOURCETYP].attr_value
      set_attr_value(S_DATASOURCETYP, default)
      raise WrongDataSourceType, <<-EOTXT
        Der eingestellte Datenquellentyp '#{datasourcetyp}' ist ungültig.

        Gültige Werte sind '#{VALID_DATASOURCES.join("', '")}'.

        Der Wert wird jetzt auf den Standardwert '#{default}'  gesetzt.

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
      default = 'UTF-8'
      set_attr_value(S_DATASOURCEENCODING, default)
      raise WrongDataSourceEncoding, <<-EOTXT
        Das eingestellte Encoding der Datenquelle '#{datasource_encoding}' ist ungültig.

        Gültige Werte sind '#{VALID_ENCODINGS.join("', '")}'.

        Bitte stellen Sie in den Layouteigenschaften das korrekte Encoding
        ein und speichern Sie die Einstellungen.
      EOTXT
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # ersetllt ein neues Graphik-Objekt und kopiert alle Attributte des übergebenen, außer ID, Typ und Name
  # ==== Parameter
  # +node+:: die XML-Node des zu kopierenden Objekts, fals nil übergeben wurde, kehrt die Methode unverrichteter Dinge zurück
  def copy_object(node)
    return unless node
    o = add_object(node.at_xpath(GOA_TYP).content)
    node.children do |element|
      # alle Attribute, außer ID, Typ und Name kopieren, sofern sie vorhanden, ansonsten den Standard lassen
      if element.name != GOA_ID && element.name != GOA_TYP && element.name != GOA_NAME
        o.at_xpath(element.name).content = element.content
      end
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # löscht sie übergebene XML-Node aus dem Layout ohne Rückfrage, diese muss in der aufrufenden Methode durchgeführt werden
  # ==== Parameter
  def delete_object(node)
    node.remove
  end

  def build_printer_instance
    printertype = get_attr_value(S_PRINTERTYPE)
    printerclass = Printer.const_get(printertype)
    return printerclass.new
  end

  def build_dataman_instance
    datamantyp =  get_attr_value(S_DATASOURCETYP)
    datasource =  get_attr_value(S_DATASOURCE)
    encoding =  get_attr_value(S_DATASOURCEENCODING)
    # Ruby-1.9 kennt kein LATIN1
    encoding = 'iso-8859-1' if encoding=~/latin1/i

    dataman = if datamantyp == DATABASE
      DataMan::Database.new(datasource)
    elsif datamantyp == CSV
      DataMan::CSV.new(datasource, encoding)
    elsif datamantyp == DBF
      DataMan::DBF.new(datasource, encoding)
    elsif datamantyp == NONE
      DataMan::None.new(datasource)
    else
      raise "falscher datasourcetyp '#{datamantyp}' angegeben!"
    end

    return dataman
  end

  def build_chip_instance
    chip = if get_attr_value(S_CONTACTLESS) == S_TRUE || get_attr_value(S_CONTACT) == S_TRUE
      chip_object
    else
      nil
    end

    return chip
  end


  def get_binary_attr(attr)
    initdatahex = get_attr_value(attr)
    if initdatahex && !initdatahex.empty?
      [initdatahex].pack("H*")
    end
  end

  def set_binary_attr(attr, bindata)
    set_attr_value(attr, bindata.unpack("H*")[0])
  end

end
end
