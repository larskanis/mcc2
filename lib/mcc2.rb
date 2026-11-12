module Mcc2
  autoload :DebugTools, "mcc2/debug_tools"
  autoload :Dataview, "mcc2/dataview"
  autoload :FXSelectionDialog, "mcc2/fxselection_dialog"
  autoload :FxColoredItem, "mcc2/fx_colored_item"
  autoload :GeneratePreview, "mcc2/generate_preview"
  autoload :LayoutFile, "mcc2/layout_file"
  autoload :Layout, "mcc2/layout"
  autoload :Layoutview, "mcc2/layoutview"
  autoload :Locales, "mcc2/locales"
  autoload :Mcc2Gui, "mcc2/mcc2gui"
  autoload :Mcc2Print, "mcc2/mcc2print"
  autoload :Printerview, "mcc2/printerview"
  autoload :VERSION, "mcc2/version"

  module Printer
    autoload :Base, "mcc2/printer/base"
    autoload :CardPrinter, "mcc2/printer/card_printer"
    autoload :CardPrinting, "mcc2/printer/card_printer"
    autoload :GdiPrinter, "mcc2/printer/gdi_printer"
    autoload :FilePrinter, "mcc2/printer/file_printer"
    autoload :LinuxCupsPrinter, "mcc2/printer/linux_cups_printer"
    autoload :PrinterZebra, "mcc2/printer/printer_zebra"
    autoload :PrinterCab, "mcc2/printer/printer_cab"
    autoload :PrinterEpl, "mcc2/printer/printer_epl"
    autoload :PrinterCx320Direct, "mcc2/printer/printer_cx320_direct"
    autoload :PrinterCx320Gdi, "mcc2/printer/printer_cx320_gdi"
    autoload :PrinterTTP34x, "mcc2/printer/printer_ttp34x"
    autoload :Preview, "mcc2/printer/preview"
    autoload :SvgDrawer, "mcc2/printer/svg_drawer"
  end

  module DataMan
    autoload :Base, "mcc2/dataman/base"
    autoload :Database, "mcc2/dataman/database"
    autoload :CSV, "mcc2/dataman/csv"
    autoload :DBF, "mcc2/dataman/dbf"
    autoload :None, "mcc2/dataman/none"

    # ermittelt, ob der übergebene String eine erlaubtes Encoding ist
    # === Return
    # true oder false
    # === Paramter
    # +encoding+::    das Encoding [String]
    def self.valid_datasource_encoding?(encoding)
      VALID_ENCODINGS.include?(encoding.upcase)
    end

    # ermittelt, ob der übergebene String eine erlaubte Datenquelle ist
    # === Return
    # true oder false
    # === Paramter
    # +datasource+::    der Datenquellentyp [String]
    def self.valid_datasourcetyp?(datasource)
      VALID_DATASOURCES.include?(datasource)
    end

    # ersetzt die Felder in data, welche dem Muster {feldname[pos,anz]} entsprechen, durch ihren Inhalt
    # === Paramter
    # +data+::   die im Layut definierten Daten für dieses Objekt
    # +row+::    ein Datensatz im FasteCSV-Format
    def self.replace_variables(data, row)
      return data unless row # die unveränderten Daten zurückgeben, wenn kein Datensatz übergeben wurde
      pattern = /\{ *([-\._\w]*)\[ *(\d{1,5}) *, *(\d{1,5}) *\] *\}/
          data.gsub(pattern) {
            feld = $1
          von = $2.to_i
          anz = $3.to_i
          vardata = row[feld].to_s[von, anz].strip
          if row.to_hash.has_key?(feld)
          vardata
          else
          $& # die unveränderten Daten zurückgeben, wenn kein passendes Feld im Datensatz gefunden wurde
          end
          }
    end

    def self.meta_headers
      ["row_number"]
    end
  end

  module LayoutObject
    autoload :GO_Attribut, "mcc2/layout_object/go_attribut"
    autoload :Graphic,  "mcc2/layout_object/graphic"
    autoload :Barcode,  "mcc2/layout_object/barcode"
    autoload :Picture,  "mcc2/layout_object/picture"
    autoload :Text,  "mcc2/layout_object/text"
    autoload :Box,  "mcc2/layout_object/box"
    autoload :Magstripe,  "mcc2/layout_object/magstripe"
    autoload :Chip,  "mcc2/layout_object/chip"
    autoload :Embed,  "mcc2/layout_object/embed"
  end

  # Konstanten-Definition
  TAB = 9.chr

  FRONT = 0
  BACK = 1

  # das sind die Bezeichner von Attributen, die ein grafisches Objekt haben kann
  GOA_NAME = "object_name"
  GOA_TYP = "object_typ"
  GOA_PAGE_NR = "page_nr"
  GOA_LAYER = "layer"
  GOA_FONT_HEIGHT = "font_height"
  GOA_FONT_TYP = "font_typ"
  GOA_FONT_COLOR = "font_color"
  GOA_FONT_FILE = "font_file"
  GOA_BACK_COLOR = "back_color"
  GOA_JUSTIFICATION = "justification"
  GOA_JUSTIFICATION_BLOCK = "justification_block"
  GOA_LINE_SPACING = "line_spacing"
  GOA_X = "x"
  GOA_Y = "y"
  GOA_WIDTH = "width"
  GOA_HEIGHT = "height"
  GOA_ROTATION = "rotation"
  GOA_ID = "id"
  GOA_BARCODE_TYP = "barcode_typ"
  GOA_BARCODE_HEIGHT = "barcode_height"
  GOA_BARCODE_OPTIMIZED = "barcode_optimized"
  GOA_BARCODE_OPTION_1 = "barcode_option_1"
  GOA_BARCODE_OPTION_2 = "barcode_option_2"
  GOA_BARCODE_OPTION_3 = "barcode_option_3"
  GOA_DATA = "data"
  GOA_SAMPLE_DATA = "sample_data"
  GOA_PRINTLIST = "view_in_printlist"
  GOA_IMAGE_PAGE = "image_page"

  GOA_FILL_COLOR = "fill_color"
  GOA_BORDER_COLOR = "border_color"
  GOA_BORDER_WIDTH = "border_width"
  GOA_CORNER_RADIUS = "corner_radius"

  # das sind die Objektbezeichner
  GRAPHICOBJECTS = "GraphicObjects"
  GRAPHICOBJECT = "GraphicObject"
  TEXTOBJECT = "TextObject"
  BARCODEOBJECT = "BarcodeObject"
  PICTUREOBJECT = "PictureObject"
  BOXOBJECT = "BoxObject"
  EMBEDOBJECT = "EmbedObject"

  S_LAYOUT = "Layout"
  S_DUPLEX = "Duplex"
  S_CONTACTLESS = "Contactless"
  S_CONTACT = "Contact"
  S_MAGSTRIPE = "Magstripe"

  S_CHIP = "Chip_Params"
  S_MAGSTRIPEPARAMS = "Magstripe_Params"
  S_HEIGHT = "Height"
  S_WIDTH = "Width"
  S_PARAM = "Param"
  S_ROOT = "Root"
  S_X_OFFSET = "x_offset"
  S_Y_OFFSET = "y_offset"
  S_JUST_LEFT = "left"
  S_JUST_MID = "mid"
  S_JUST_RIGHT = "right"
  S_BARCODE_DPI = "barcode_dpi"

  S_DATASOURCE = "datasource"
  S_DATASOURCETYP = "datasource_typ"
  S_DATASOURCEENCODING = "datasource_encoding"

  S_CHIPPARAMS = "chipparams"
  S_PRINTERTYPE = "printertype"

  S_FILEPRINTER_SAVE_AS = "fileprinter_save_as"
  S_FILEPRINTER_DPI = "fileprinter_dpi"

  S_LINUX_CUPS_PRINTER = "linux_cups_printer"
  S_LINUX_CUPS_DPI = "linux_cups_dpi"
  S_LINUX_CUPS_OPTIONS = "linux_cups_options"

  S_GDIPRINTER_NAME = "gdiprinter_name"
  S_GDIPRINTER_INITDATA = "gdiprinter_initdata"
  S_ZEBRAPRINTER_NAME = "zebraprinter_name"
  S_ZEBRAPRINTER_INITDATA = "zebraprinter_initdata"
  S_CABPRINTER_HOST = "cabprinter_host"
  S_CABPRINTER_PORT = "cabprinter_port"
  S_CABPRINTER_DPI = "cabprinter_dpi"
  S_CABPRINTER_PAGE_COMMANDS = "cabprinter_page_commands"
  S_EPLPRINTER_DEVICE = "eplprinter_device"
  S_EPLPRINTER_DPI = "eplprinter_dpi"
  S_EPLPRINTER_PAGE_COMMANDS = "eplprinter_page_commands"

  # TSC TTP 343M Pro
  S_TTP34XPRINTER_DEVICE = "ttp34xprinter_device"
  S_TTP34XPRINTER_DPI = "ttp34xprinter_dpi"
  S_TTP34XPRINTER_PAGE_COMMANDS = "ttp34xprinter_page_commands"

  S_CX320_DRIVER = "cx320_driver"
  S_CX320_PRINTER_NR = "cx320_printer_nr"
  S_CX320_PARALLEL_PRINT = "cx320_parallel_print"
  S_CX320_CONFIG = "cx320_config"

  S_FRONT_FLIP = "front_flip"
  S_FRONT_FLOP = "front_flop"
  S_BACK_FLIP = "back_flip"
  S_BACK_FLOP = "back_flop"

  UP = 0
  DOWN = 1

  NONE = "none"
  CSV = "csv"
  DBF = "dbf"
  DATABASE = "database"

  NO = "no"
  YES = "yes"

  S_FALSE = "false"
  S_TRUE = "true"

  ENC_UTF8 = "UTF-8"
  ENC_IBM850 = "IBM850"
  ENC_LATIN1 = "LATIN1"

  VALID_ENCODINGS = [ENC_UTF8, ENC_IBM850, ENC_LATIN1]
  VALID_DATASOURCES = [DATABASE, CSV, DBF, NONE]

  DELETE = 0
  COPY = 1
  ADD = 2

  S_MSSPUR1 = "ms_spur1"
  S_MSSPUR2 = "ms_spur2"
  S_MSSPUR3 = "ms_spur3"

  PRINT_FROM = 0
  PRINT_TO = 1

  LAYOUT_DEFAULT_WIDTH = 85.6
  LAYOUT_DEFAULT_HEIGHT = 53.98
  LAYOUT_DEFAULT_X_OFFSET = 0.0
  LAYOUT_DEFAULT_Y_OFFSET = 0.0

  CHIPPARAM_FIELD_COUNT = 23
end
