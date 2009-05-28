# -*- coding: UTF-8 -*-

##############################################################################

# FehlerAuswahlDialog mit variablen Buttons zur Eingabe der Batchnummer
class FXFehlerAuswahlDialog < FXDialogBox
  attr_accessor :selection
  
  def initialize(owner, message, buttonlist)
    # Invoke base class initialize function first
    super(owner, "Modusauswahl (bitte unterstrichenen Buchstabe drücken)", DECOR_TITLE|DECOR_BORDER)
    
    # Bottom buttons
    FXVerticalFrame.new(self,
                        LAYOUT_SIDE_BOTTOM|FRAME_NONE|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH,
                        0, 0, 0, 0, 40, 40, 20, 20) do |vf|
      
      @l = FXLabel.new(vf, message)
      
      buttonsfr = FXHorizontalFrame.new(vf,
                                        FRAME_NONE|LAYOUT_FILL_X|PACK_UNIFORM_WIDTH,
                                        0, 0, 0, 0, 40, 40, 20, 40)
      
      
      
      buttonlist.each_with_index{|button,button_idx|
        FXButton.new(buttonsfr, button, nil, self, ID_CANCEL,
                     FRAME_RAISED|FRAME_THICK|LAYOUT_CENTER_Y){|this|
          this.connect(SEL_COMMAND){|sender, sel, event|
            handle(self, MKUINT(FXDialogBox::ID_ACCEPT, SEL_COMMAND),nil)
            @selection = button_idx
          }
          if button_idx == 0
            this.setFocus 
            this.connect(SEL_KEYPRESS){|sender, sel, event|
              if event.code == KEY_Escape
                handle(self, MKUINT(FXDialogBox::ID_ACCEPT, SEL_COMMAND), nil)
                @selection = 0
              else
                buttonlist.each_with_index{|button,button_idx|
                  if button =~ /&(\w)/
                    keycode = eval("KEY_#{$1.downcase}")
                    if keycode == event.code
                      handle(self, MKUINT(FXDialogBox::ID_ACCEPT, SEL_COMMAND),nil)
                      @selection = button_idx
                    end
                  end
                }
              end
            }
          end          
        }
      }
    end
  end
end # Ende Klasse 'FXFehlerAuswahlDialog'
##############################################################################
