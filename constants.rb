#*****************************************************************************
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
GOA_BACK_COLOR = 'back_color'
GOA_JUSTIFICATION = 'justification'
GOA_X = 'x'
GOA_Y = 'y'
GOA_WIDTH = 'width'
GOA_HEIGHT = 'height'
GOA_ROTATION = 'rotation'
GOA_ID = 'id'
GOA_BC_TYP = 'bc_typ'
GOA_HUMAN_READABLE = 'human_readable'
GOA_STRETCH = 'stretch'
GOA_PRINTABLE = 'printable'
GOA_DATA = 'data'
GOA_SAMPLE_DATA = 'sample_data'
GOA_PRINTLIST = 'view_in_printlist'

# das sind die Objektbezeichner
GRAPHICOBJECTS = 'GraphicObjects'
GRAPHICOBJECT = 'GraphicObject'
TEXTOBJECT = 'TextObject'
BARCODEOBJECT = 'BarcodeObject'
PICTUREOBJECT = 'PictureObject'


S_LAYOUT = 'Layout'
S_DUPLEX = 'Duplex'
S_CHIP = 'Chip'
S_MAGSTRIPE = 'Magstripe'
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
UP = 0
DOWN = 1

NONE = 'none'
CSV = 'csv'
DATABASE = 'database'

ENC_UTF8 = 'UTF-8'
ENC_IBM850 = 'IBM850'
ENC_LATIN1 = 'LATIN1'

VALID_ENCODINGS = [ENC_UTF8, ENC_IBM850, ENC_LATIN1]
VALID_DATASOURCES = [DATABASE, CSV, NONE]

