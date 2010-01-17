# -*- coding: UTF-8 -*-

#*****************************************************************************

module Mcc2
  # Konstanten-Definition
  TAB = 9.chr

  FRONT = 0
  BACK = 1

  # das sind die Bezeichner von Attributen, die ein grafisches Objekt haben kann
  GOA_NAME = 'object_name'
  GOA_TYP  = 'object_typ'
  GOA_PAGE_NR = 'page_nr'
  GOA_FONT_HEIGHT = 'font_height'
  GOA_FONT_TYP = 'font_typ'
  GOA_FONT_WEIGHT = 'font_weight'
  GOA_FONT_STYLE = 'font_style'
  GOA_FONT_STRETCH = 'font_stretch'
  GOA_FONT_COLOR = 'font_color'
  GOA_FONT_FILE = 'font_file'
  GOA_BACK_COLOR = 'back_color'
  GOA_JUSTIFICATION = 'justification'
  GOA_X = 'x'
  GOA_Y = 'y'
  GOA_WIDTH = 'width'
  GOA_HEIGHT = 'height'
  GOA_ROTATION = 'rotation'
  GOA_ID = 'id'
  GOA_BARCODE_TYP = 'barcode_typ'
  GOA_BAR_RATIO = 'bar_ratio'
  GOA_HUMAN_READABLE = 'human_readable'
  GOA_STRETCH = 'stretch'
  GOA_PRINTABLE = 'printable'
  GOA_DATA = 'data'
  GOA_SAMPLE_DATA = 'sample_data'
  GOA_PRINTLIST = 'view_in_printlist'

  GOA_FILL_COLOR = 'fill_color'
  GOA_BORDER_COLOR = 'border_color'
  GOA_BORDER_WIDTH = 'border_width'
  GOA_CORNER_RADIUS = 'corner_radius'

  # das sind die Objektbezeichner
  GRAPHICOBJECTS = 'GraphicObjects'
  GRAPHICOBJECT = 'GraphicObject'
  TEXTOBJECT = 'TextObject'
  BARCODEOBJECT = 'BarcodeObject'
  PICTUREOBJECT = 'PictureObject'
  BOXOBJECT = 'BoxObject'


  S_LAYOUT = 'Layout'
  S_DUPLEX = 'Duplex'
  S_CONTACTLESS = 'Contactless'
  S_CONTACT = 'Contact'
  S_MAGSTRIPE = 'Magstripe'

  S_CHIP = 'Chip_Params'
  S_MAGSTRIPEPARAMS = 'Magstripe_Params'
  S_HEIGHT = 'Height'
  S_WIDTH = 'Width'
  S_PARAM = 'Param'
  S_ROOT = 'Root'
  S_X_OFFSET = 'x_offset'
  S_Y_OFFSET = 'y_offset'
  S_JUST_LEFT = 'Links'
  S_JUST_MID = 'Mitte'
  S_JUST_RIGHT = 'Rechts'

  S_DATASOURCE = 'datasource'
  S_DATASOURCETYP = 'datasource_typ'
  S_DATASOURCEENCODING = 'datasource_encoding'

  S_CHIPPARAMS = 'chipparams'
  S_PRINTERTYPE = 'printertype'

  S_FILEPRINTER_SAVE_AS = 'fileprinter_save_as'
  S_FILEPRINTER_DPI = 'fileprinter_dpi'

  S_GDIPRINTER_NAME = 'gdiprinter_name'
  S_GDIPRINTER_INITDATA = 'gdiprinter_initdata'
  S_XIDPRINTER_NAME = 'xidprinter_name'
  S_XIDPRINTER_INITDATA = 'xidprinter_initdata'

  UP = 0
  DOWN = 1

  NONE = 'none'
  CSV = 'csv'
  DATABASE = 'database'

  NO = 'no'
  YES = 'yes'

  S_FALSE = 'false'
  S_TRUE = 'true'

  ENC_UTF8 = 'UTF-8'
  ENC_IBM850 = 'IBM850'
  ENC_LATIN1 = 'LATIN1'

  VALID_ENCODINGS = [ENC_UTF8, ENC_IBM850, ENC_LATIN1]
  VALID_DATASOURCES = [DATABASE, CSV, NONE]

  DELETE = 0
  COPY = 1
  ADD = 2

  S_MSSPUR1 = 'ms_spur1'
  S_MSSPUR2 = 'ms_spur2'
  S_MSSPUR3 = 'ms_spur3'

  PRINT_FROM = 0
  PRINT_TO = 1

  LAYOUT_DEFAULT_WIDTH = 85.6
  LAYOUT_DEFAULT_HEIGHT = 53.98
  LAYOUT_DEFAULT_X_OFFSET = 0.0
  LAYOUT_DEFAULT_Y_OFFSET = 0.0
  
end
