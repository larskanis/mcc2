# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end

require 'iconv'
require 'picture_data_edit_dlg'

class MyPictureDataEditDialogBox < PictureDataEditDialogBox

  def initialize(app, child)
    super(app)
    @app = app
    @child = child

    
    # .............................................................................................
    # alle Aktionen definieren
    
    @button_select_all.connect(SEL_COMMAND){ select_all }
    # .............................................................................................
    @printing = false
    disable_all_buttons
    @button_print_all.enabled = true
    @button_exit.enabled = true
    @button_select_all.enabled = true

  end
  
  #
  def preview
    @child.row_nr = @iconlist_data.currentItem
    @child.draw_card
  end
 	#---------------------------------------------------------------------------------------------------------
  
end


if __FILE__ == $0
  system("ruby mcc2.rb #{ARGV}")
end
