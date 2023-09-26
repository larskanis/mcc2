# -*- coding: UTF-8 -*-

require 'mcc2/cc_dialogbox'
require 'mcc2/layout_file'
require 'mcc2/layoutview'
require 'mcc2/dataview'
require 'mcc2/printerview'
require 'mcc2/printer/preview'

module Mcc2
# definiert ein Clientfenster mit allen Einstellungen und Attributen, die für ein bestimmtes Kartenlayout benötigt werden
class Layout
  include Fox

  # definiert, ob an den Einstellungen seit dem letzten speichern oder laden etwas geändert wurde
  attr_accessor :changed

  # enthält die kompletten Einstellungen des Kartenlayouts
  attr_reader :layout_file

  # der Datamanager
  attr_accessor :dataman

  #---------------------------------------------------------------------------------------------------------

  # initialisiert zusätzliche Elemente im Layout-Dialog, die nicht oder schlecht im Fox-GUI-Builder erzeugt werden können
  # setzt Parameter bei Dialog-Elementen
  # definiert die Aktionen, welche bei bestimmten Ereignissen auf bestimmten Elementen des Dialogs ausgeführt werden sollen
  # ==== Parameter
  # +parent+:: parent-fx-window
  def initialize(parent, filename=nil)
    @parent = parent
    begin
      require 'ruby-zint'
      require 'mcc2/zint_barcode_extensions'
    rescue LoadError => e
      puts "Loading barcode driver failed: #{e}"
    end

    # avoid warnings to uninit values
    @preview = nil

    close_dataman

    FXSplitter.new(parent) do |splitter1|
      FXTabBook.new(splitter1) do |tabbook|
#         %w[SEL_MAP SEL_CONFIGURE SEL_ENTER SEL_FOCUSIN SEL_UPDATE SEL_UNGRABBED SEL_COMMAND].each{|se|
#           tabbook.connect(Fox.const_get(se)){|sender, sel, event|
#             puts "#{se}: #{sender}, #{sel}, #{event}"
#           }
#         }
        tabbook.connect(SEL_COMMAND){|sender, sel, event|
          @layoutview.layoutview_tab_activated( event == 0 )
          @printerview.printerview_tab_activated( event == 1 )
          @dataview.dataview_tab_activated( event == 2 )
        }
        FX::TabItem.new(tabbook) do |tabitem_layoutview|
          tabitem_layoutview.text = "&Entwurf"
          tabitem_layoutview.img = 'mcc2/images/document-edit.png'
        end
        FXVerticalFrame.new(tabbook) do |frame_layoutview|
          @layoutview = Layoutview.new frame_layoutview, self
        end
        FX::TabItem.new(tabbook) do |tabitem_printerview|
          tabitem_printerview.text = "D&rucker"
          tabitem_printerview.img = 'mcc2/images/document-print.png'
        end
        FXVerticalFrame.new(tabbook) do |frame_printerview|
          @printerview = Printerview.new frame_printerview, self
        end
        FX::TabItem.new(tabbook) do |tabitem_dataview|
          tabitem_dataview.text = "Da&ten"
          tabitem_dataview.img = 'mcc2/images/documentation.png'
        end
        FXVerticalFrame.new(tabbook) do |frame_dataview|
          @dataview = Dataview.new frame_dataview, self
        end
      end
      FXVerticalFrame.new(splitter1) do |frame_preview|
        @preview = Printer::Preview.new(frame_preview)
      end
      splitter1.setSplit(0, 400)
    end

    @parent.connect(SEL_CLOSE){|sender, selector, data|
      can_close? ? 0 : 1
    }

    if filename
      load_from_xml(filename)
      @changed = false
    else
      create_xml
      @changed = true
    end

    draw_preview(true)
    set_title
  end
  #---------------------------------------------------------------------------------------------------------


  # schließt den Datenmanager
  def close_dataman
    @dataman = nil
    @current_dataman_settings = {}
  end
  #---------------------------------------------------------------------------------------------------------

  DatamanAttributes = [S_DATASOURCE, S_DATASOURCETYP, S_DATASOURCEENCODING]

  # erzeugt einen Datenmanager abhängig davon welcher Datensourcetyp im Layout definiert ist (momentan DATABASE oder CSV)
  def open_dataman
    begin
      @dataman = @layout_file.build_dataman_instance
      @dataview.dataman = @dataman

      @current_dataman_settings = DatamanAttributes.inject({}){|s,a|
        s[a] = @layout_file.get_attr_value(a)
        s
      }
    rescue => e
      FXMessageBox.error(@parent.app, MBOX_OK, "Fehler bei Datenverbindung", "Die Datenverbindung konnte nicht hergestellt werden.\n\n#{e}")
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # sollte jedesmal dann aufgerufen werden, wenn ein Attribut des Layouts geändert wurde
  # es wird das changed-Flag gesetzt und der Titel aktualisiert und die Vorschau neu gezeichnet
  def changed_attributes
    @changed = true
    set_title

    # Any datasource related values changed? -> reopen
    if DatamanAttributes.find{|a| @current_dataman_settings[a] != @layout_file.get_attr_value(a) }
      close_dataman
      open_dataman
    end
  end
  #---------------------------------------------------------------------------------------------------------

  # aktualisiert den Titel des Layout-Fensters
  # es werden eingetragen
  # * der Dateiname des Layouts
  # * die verbunden Datenquelle (coming soon)
  # * ein Zeichen *, ob das Layout seit dem letzten Laden oder Speichern geändert wurde
  def set_title
    @parent.title = "#{@layout_file.filename} #{@changed ? ' *' : '' }"
  end
  #---------------------------------------------------------------------------------------------------------

  # speichert alle GraphicObjekte und Layout-Einstellungen im XML-File
  def store_to_xml(filename_dialog=false)
    if filename_dialog || !@layout_file.filename
      fn = FXFileDialog.getSaveFilename(@parent, 'Speichern', './', patterns = '*.xml', initial = 0)
      return if fn.empty?
      unless fn.split(".")[-1].downcase == 'xml'
        fn = [fn, 'xml'].join(".")
      end
      @layout_file.filename = fn
    end
    @layout_file.save
    @changed = false
    set_title
  end
  #---------------------------------------------------------------------------------------------------------

  def can_close?
    return true if !changed

    res = FXMessageBox.question( @parent.app, MBOX_YES_NO_CANCEL, 'Datei speichern', "Datei #{@layout_file.filename} speichern ?")
    case res
      when MBOX_CLICKED_YES
        store_to_xml
        changed ? false : true
      when MBOX_CLICKED_NO
        true
      when MBOX_CLICKED_CANCEL
        false
    end
  end

  #
  def load_from_xml(filename)
    self.layout_file = LayoutFile.load_from_xml(filename)
  end
  #---------------------------------------------------------------------------------------------------------

  def layout_file= layout_file
    @layout_file = layout_file
    @preview.layout_file = layout_file
    @layoutview.layout_file = layout_file
    @dataview.layout_file = layout_file
    @printerview.layout_file = layout_file
    open_dataman
  end

  def selected_object_id= id
    @preview.selected_object_id = id if @preview
  end

  #
  def create_xml
    layout_file = LayoutFile.create_xml
    self.layout_file = layout_file
  end

  def add_object(typ)
    @layoutview.manage_objects(ADD, typ)
  end

  #---------------------------------------------------------------------------------------------------------

  def draw_preview_with_row row, immediately=false
    return unless @preview
    @row = row
    @preview.draw_preview immediately, @row
  end

  def draw_preview immediately=false
    return unless @preview
    @preview.draw_preview immediately, nil
  end


  def self.connect_filebutton_to_textfield( button, textfield, filepatterns='*')
    button.connect(SEL_COMMAND){
      execute_filedialog_for_textfield(textfield, filepatterns)
    }
  end

  def self.execute_filedialog_for_textfield(textfield, filepatterns='*')
    filepatterns = filepatterns.join("\n") if filepatterns.kind_of?(Array)
    lds = textfield.text
    if lds =~ /(\.\w+?)$/i
      ext = $1
      pat_idx = nil
      filepatterns.split("\n").each_with_index{|pat, idx|
        if pat =~ /\*#{ext}/i || pat =~ /(\(\*\))/
          pat_idx = idx
          break
        end
      }
    end

    dest = FileTest.exist?(lds) ? lds : '.'
    s = FXFileDialog.getOpenFilename(textfield, textfield.tipText, lds, filepatterns, pat_idx || 0)
    unless s.empty?
      textfield.setText(s, true)
    end
  end

  def self.set_combobox_by_data( combobox, dataval, notify=true )
    idx = -1
    if combobox.find{|text, data| idx+=1; data == dataval }
      combobox.setCurrentItem( idx, notify )
    end
  end
end
end

#*****************************************************************************
# Main

if __FILE__ == $0


  system("ruby mcc2.rb #{ARGV}")
  exit
  lay = Layout.new(nil, nil)

  # ...........................................................
  # Test für das Erstellen einer neune XML-Datei
  lay.filename = 't:\Project\MCC2a\trunk\layouts\test1.xml'
  lay.load_from_xml
  # ...........................................................
  # Test für das Erstellen einer neune XML-Datei
  #~ lay.create_xml

  #~ lay.add_object(TEXTOBJECT)
  #~ lay.add_object(BARCODEOBJECT)
  #~ lay.add_object(PICTUREOBJECT)
  #~ lay.add_object(TEXTOBJECT)
  #~ lay.add_object(BARCODEOBJECT)
  #~ lay.add_object(TEXTOBJECT)


  print lay.xml_doc.to_s
end
