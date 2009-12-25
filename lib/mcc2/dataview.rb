# -*- coding: UTF-8 -*-

class Dataview

  def initialize parent, layout
    @layout = layout
  end

  def layout_file= file
    @layout_file = file
  end

  #
  def print_cards
    c = @layout_file.get_attr_value(S_CONTACTLESS) == S_TRUE || @layout_file.get_attr_value(S_CONTACT) == S_TRUE
    c ? chip = Chip.new : chip = nil
    if @layout_file.get_attr_value(S_DATASOURCE) == ""
      # nur eine Karte ohne Daten drucken
      printer = $pr
      printer.print_card(@layout_file, nil, chip) # self ???
      chip.close_reader if chip
    else
      # Printdialog um Drucken von Karten mit Daten öffnen
      pr_dlg = MyPrintDialogBox.new(@app, self, chip)
      pr_dlg.topwin.show(Fox::PLACEMENT_SCREEN)
      pr_dlg.topwin.execute
    end
  end
  #---------------------------------------------------------------------------------------------------------

  def draw_preview(immediately=false)
    @layout.draw_preview(nil, immediately)
  end
  
end
