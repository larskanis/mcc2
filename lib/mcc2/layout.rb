# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

if __FILE__ == $0
  require 'mcc2'
end

require 'cc_dialogbox'
require 'layout_file'
require 'layoutview'
require 'dataview'
require 'printerview'
require 'printer/preview'

# definiert ein Clientfenster mit allen Einstellungen und Attributen, die für ein bestimmtes Kartenlayout benötigt werden
class Layout

  # definiert, ob an den Einstellungen seit dem letzten speichern oder laden etwas geändert wurde
  attr_accessor :changed
  
  # enthält die kompletten Einstellungen des Kartenlayouts
  attr_accessor :layout_file
  
  # der Datamanager
  attr_accessor :dataman
  
 	#---------------------------------------------------------------------------------------------------------
  
  # initialisiert zusätzliche Elemente im Layout-Dialog, die nicht oder schlecht im Fox-GUI-Builder erzeugt werden können
  # setzt Parameter bei Dialog-Elementen
  # definiert die Aktionen, welche bei bestimmten Ereignissen auf bestimmten Elementen des Dialogs ausgeführt werden sollen
  # ==== Parameter
  # +parent+:: ??
  # +app+::    die Applikation
  def initialize(parent, app)
    @parent = parent
    begin
      # Achtung! Nicht das Verzeichnis 'printer' in den Pfad einbinden. Dort befindet sich eine printer.rb, die nichts mit der printer.rb dieses Projektes zu tun hat.
      require 'libs/printer/tbarcode_api'
    rescue LoadError => e
      puts "Loading barcode driver failed: #{e}"
    end

    close_dataman
    
    @changed = false

    FXSplitter.new(parent) do |splitter1|
      FXTabBook.new(splitter1) do |tabbook|
#         %w[SEL_MAP SEL_CONFIGURE SEL_ENTER SEL_FOCUSIN SEL_UPDATE SEL_UNGRABBED SEL_COMMAND].each{|se|
#           tabbook.connect(Fox.const_get(se)){|sender, sel, event|
#             puts "#{se}: #{sender}, #{sel}, #{event}"
#           }
#         }
        tabbook.connect(SEL_COMMAND){|sender, sel, event|
          @layoutview.layoutview_tab_activated( event == 0 )
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
          tabitem_dataview.text = "D&aten"
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
  end
  #---------------------------------------------------------------------------------------------------------


  # schließt den Datenmanager
  def close_dataman
    @dataman = nil
  end
  #---------------------------------------------------------------------------------------------------------
  

  # erzeugt einen Datenmanager abhängig davon welcher Datensourcetyp im Layout definiert ist (momentan DATABASE oder CSV)
  def open_dataman
    
    @open_datamantyp = datamantyp =  @layout_file.get_attr_value(S_DATASOURCETYP)
    @open_datasource = datasource =  @layout_file.get_attr_value(S_DATASOURCE)
    
    if datamantyp == DATABASE
      @dataman = DataManDatabase.new(datasource)
    elsif datamantyp == CSV
      @dataman = DataManCSV.new(datasource)
    elsif datamantyp == NONE
      @dataman = nil
    else
      raise "falscher datasourcetyp '#{datamantyp}' angegeben!"
    end
    @dataview.dataman = @dataman
  end
  #---------------------------------------------------------------------------------------------------------
  
  
  # sollte jedesmal dann aufgerufen werden, wenn ein Attribut des Layouts geändert wurde
  # es wird das changed-Flag gesetzt und der Titel aktualisiert und die Vorschau neu gezeichnet
  def changed_attributes
    @changed = true
    set_title

    # Any datasource related values changed? -> reopen
    if  @open_datamantyp!=@layout_file.get_attr_value(S_DATASOURCETYP) ||
        @open_datasource!=@layout_file.get_attr_value(S_DATASOURCE)
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
    @parent.title = "#{@layout_file.filename} #{@dataman.filename.to_s if @dataman}  #{@changed ? ' *' : '' }"
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # speichert alle GraphicObjekte und Layout-Einstellungen im XML-File
	def store_to_xml(filename_dialog=false)
    if filename_dialog || !@layout_file.filename
      fn = FXFileDialog.getSaveFilename(@parent, 'Speichern', '.', patterns = '*.xml', initial = 0)
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
  
  
  #
  def load_from_xml(filename)
    begin
      @layout_file = LayoutFile.load_from_xml(filename)
    rescue LayoutFile::WrongDataSourceEncoding, LayoutFile::WrongDataSourceType => e
      changed_attributes 
      error_WahlMessage = FXFehlerAuswahlDialog.new(@app, e.to_s, 'ok')
      error_WahlMessage.execute
      # error_WahlMessage.selection # enthält die Nummer der gewählten Taste
    end
    open_dataman

    self.layout_file = @layout_file
    draw_preview(true)
    set_title
  end
 	#---------------------------------------------------------------------------------------------------------

  def layout_file= layout_file
    @preview.layout_file = @layout_file
    @layoutview.layout_file = @layout_file
    @dataview.layout_file = @layout_file
    @printerview.layout_file = @layout_file
  end

  def selected_object_id= id
    @preview.selected_object_id = id if @preview
  end
  
  #
  def create_xml
    @layout_file = LayoutFile.create_xml
    self.layout_file = @layout_file
    draw_preview(true)
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
    filepatterns = filepatterns.join("\n") if filepatterns.kind_of?(Array)
    button.connect(SEL_COMMAND){
      lds = textfield.text
      ldsd = File.join(File.dirname(lds), '')
      dest = FileTest.exists?(ldsd) ? ldsd : '.'
      s = FXFileDialog.getOpenFilename(button, textfield.tipText, dest, filepatterns)
      unless s.empty?
        textfield.setText(s, true)
      end
    }
  end

  def self.set_combobox_by_data( combobox, dataval, notify=true )
    idx = -1
    if combobox.find{|text, data| idx+=1; data == dataval }
      combobox.setCurrentItem( idx, notify )
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
