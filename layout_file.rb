
class LayoutFile
  class WrongDataSourceEncoding  < RuntimeError
  end
  
  class WrongDataSourceType  < RuntimeError
  end
  
  attr_accessor :attributes
  attr_reader :filename
  
  def self.load_from_xml(filename)
    o = self.new
    o.load_from_xml(filename)
    return o
  end
 	#---------------------------------------------------------------------------------------------------------
  
  def self.create_xml
    o = self.new
    o.create_xml
    p "hier"
    return o
  end
 	#---------------------------------------------------------------------------------------------------------
  
  def initialize
    @xml_doc = nil
    @attributes = {}
    add_attr(S_DUPLEX, Integer, 0)
    add_attr(S_WIDTH, Integer, $pr.default_width)
    add_attr(S_HEIGHT, Integer, $pr.default_height)
    add_attr(S_X_OFFSET, Integer, $pr.default_x_offset)
    add_attr(S_Y_OFFSET, Integer, $pr.default_y_offset)
    add_attr(S_DATASOURCE, String, "")
    add_attr(S_DATASOURCETYP, String, NONE)
    add_attr(S_DATASOURCEENCODING, String, ENC_IBM850)
  end
  
 	#---------------------------------------------------------------------------------------------------------
  def xml_doc
    @xml_doc
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # erzeugt eine neue XML-Datei und initialisiert die entsprechenden Variablen und Objekte
	def create_xml
    @xml_doc = LibXML::XML::Document.new
    @xml_doc.encoding = XML::Encoding::UTF_8
    @xml_doc.root = XML::Node.new(S_ROOT)
    
    # Layout definieren
    @xml_doc.root << node = XML::Node.new(S_LAYOUT)
    attributes.each_pair{|attr_name, attr|
      node << XML::Node.new(attr.attr_name, attr.attr_value.to_s)
    }
    
    # Chip definieren
    @xml_doc.root << node = XML::Node.new(S_CHIP)
    chip = Chip.new
    (1..chip.anz_params).each{|i|
      node << param = XML::Node.new("#{S_PARAM}_#{i}", "")
    }
    
    # Magstripe definieren
    @xml_doc.root << node = XML::Node.new(S_MAGSTRIPE)
    
    # Container für die GraphikObjekte definieren definieren
    @xml_doc.root << node = XML::Node.new(GRAPHICOBJECTS)
    
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # lädt das XML-File und initialisiert die entsprechenden Variablen und Objekte
  # ==== Parameter
  # +filename+:: der NAme des XML-Files in welchem die Layout-Spezifikation gespeichert werden soll
	def load_from_xml(filename)
    XML.indent_tree_output = true
    return nil if filename == ""
    
    @xml_doc = LibXML::XML::Document.file(filename, :options => XML::Parser::Options::NOBLANKS )
    
    @filename = filename
    # ................................................................................................................................
    # die allgemeine Layout-Einstellungen auslesen
    
    # kontrollieren, ob alle Nodes des Layouts existieren, ansonsten anlegen und als 'changed' markieren
    lay_attrs = @xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
    @attributes.each_pair{|attr_bez, attr|
      element = lay_attrs.find_first(attr.attr_name)
      unless element
        lay_attrs << XML::Node.new(attr.attr_name, attr.attr_value.to_s)
        @changed = true
      end
    }
    
    # kontrollieren, ob die Datenquelle eine gültige Angabe ist, wenn nicht, dann den Benutzer informieren und auf Standard setzen
    check_valid_datasourcetyp
    
    # wenn bei Datensourectyp nicht 'none' eingetrage ist, also eine Datenquelle verwendet wird
    # kontrollieren, ob das eingestellte Encoding eine gültige Angabe ist, wenn nicht, dann den Benutzer informieren und auf Standard setzen
    unless get_attr_value(S_DATASOURCETYP) == NONE
      check_valid_encoding
    end
    
    #~ fill_layout_attr_tab
    
    # ................................................................................................................................
    # die Chip-Einstellungen auslesen
    
    # kontrollieren, ob alle Nodes des Chips existieren, ansonsten anlegen und als 'changed' markieren
    chip = Chip.new
    chip_attrs = @xml_doc.find_first("//#{S_ROOT}/#{S_CHIP}")
    (1..chip.anz_params).each{|i|
      attr_name = "#{S_PARAM}_#{i}"
      element = chip_attrs.find_first(attr_name)
      unless element
        #~ chip_attrs << param = XML::Node.new(attr_name , "")
        @changed = true
      end
    }
    
    # ................................................................................................................................
    # die Magnetstreifen-Einstellungen auslesen
    
    # kontrollieren, ob alle Nodes des Magstripes existieren, ansonsten anlegen und als 'changed' markieren
    # todo
    
    # ................................................................................................................................
    # die Einstellungen der graphischen Objekte auslesen
    
    # kontrollieren, ob alle Nodes der GraphicObjects existieren, ansonsten anlegen und als 'changed' markieren
    @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
      typ = go_struct.find(GOA_TYP).first.content
      go = GraphicObject.get_object_by_typ(typ)
      go.go_attributes.each_pair{|go_attrname, go_attr|
        element = go_struct.find_first(go_attr.attr_name)
        unless element
          go_struct << XML::Node.new(go_attr.attr_name, go_attr.attr_value.to_s)
          @changed = true
        end
      }
    }
    

  end
	#---------------------------------------------------------------------------------------------------------
  
  # holt den Zweig mit den Einstellungen eines graphischen Objekts aus dem XML-File mit der Layout-Spezifikation
  # ==== Parameter
  # +id+:: die Nummer, unter welcher das Attribut gespeichert ist
  def get_objectnode_by_id(id)
    @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
      if go_struct.find(GOA_ID).first.content.to_i == id
        return go_struct
      end
    }
    nil
  end
	#---------------------------------------------------------------------------------------------------------
  
  def  add_object(typ)
    o = GraphicObject.get_object_by_typ(typ)
    id = get_new_id
 		node = @xml_doc.find_first("//#{S_ROOT}/#{GRAPHICOBJECTS}")
    node << go = XML::Node.new(GRAPHICOBJECT)
    go << XML::Node.new(GOA_TYP, typ)
    go << XML::Node.new(GOA_ID, id.to_s)
    o.go_attributes.each_pair{|goa_name, go_attribute|
      if go_attribute.attr_name != GOA_ID && go_attribute.attr_name != GOA_TYP
        go << XML::Node.new(go_attribute.attr_name, go_attribute.attr_value.to_s)
      end
    }
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
		@xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go|
      id = go.find(GOA_ID).first.content.to_i+1 if go.find(GOA_ID).first.content.to_i >= id
    }
    id
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # ließt die ID's der graphischen Objekte aus der Layout-Definition (XML) aus und
  # sortiert sie
  # ==== Return
  # die sortierte Liste mit ID's [Array]
  def sorted_id_list
    @xml_doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").collect{|go_struct|
      go_struct.find(GOA_ID).first.content.to_i
    }.sort!
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # ermittelt den Inhalt eines Attributes des Layout-Abschnittes
  # ==== Return
  # den Inhalt des Attributes [String]
  # ==== Parameter
  # +attr_name+:: der Name des Attributes z.Bsp. 'datasource' Bitte vorwiegend Konstanten verwenden z. Bsp. S_DATASOURCE [String]
  def get_attr_value(attr_name)
    lay_attrs = @xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
    attr = lay_attrs.find_first(attr_name)
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
    lay_attrs = @xml_doc.find_first("//#{S_ROOT}/#{S_LAYOUT}")
    attr = lay_attrs.find_first(attr_name)
    if attr 
      attr.content = value
      return true
    end
    return false
  end
  #---------------------------------------------------------------------------------------------------------
  
  # fügt ein neues Atrtribut zur Liste der Attribute (@attributes) hinzu 
  # ==== Parameter
  # +name+::    der Name, den das Attribut erhalten soll
  # +typ+::     der Typ 
  # +default+:: der Wert, mit dem das Attribut vorinitialisiert werden soll
  def add_attr(name, typ, default)
    attr = GO_Attribut.new(name, typ, default) 
    @attributes[attr.attr_name] = attr
  end

 	#---------------------------------------------------------------------------------------------------------
  
  #
  def save
    @xml_doc.save(@filename)
  end
 	#---------------------------------------------------------------------------------------------------------

  # überprüft, ob der Wert Datasourcetyp in der Layoutdefinition ein gültiger Wert ist.
  # Wenn nicht, wird ein Fehlerdialog angezeigt und der Standardwert gesetzt und das changed-Flag gesetzt
  def check_valid_datasourcetyp
    datasourcetyp = get_attr_value(S_DATASOURCETYP)
    unless DataMan.valid_datasourcetyp?(datasourcetyp)
      default = @attributes[S_DATASOURCETYP].attr_value
      set_attr_value(S_DATASOURCETYP, default)
      raise WrongDataSourceType.new(<<-EOTXT)
        Der eingestellte Datenquellentyp '#{datasourcetyp}' ist ungültig.
        
        Gültige Werte sind '#{VALID_DATASOURCES.join("', '")}'.
        
        Der Wert wird jetzt auf den Standardwert '#{default}'  gesetzt.
        
        Bitte stellen Sie in den Layouteigenschaften den korrekten Datenquellentyp
        ein und speichern Sie die Einstellungen.
      EOTXT
    end
  end
 	#---------------------------------------------------------------------------------------------------------

  # überprüft, ob der Wert Datasourcencoding in der Layoutdefinition ein gültiger Wert ist.
  # Wenn nicht, wird ein Fehlerdialog angezeigt und der Standardwert gesetzt und das changed-Flag gesetzt
  def check_valid_encoding
    datasource_encoding = get_attr_value(S_DATASOURCEENCODING)
    unless DataMan.valid_datasource_encoding?(datasource_encoding)
      default = @layout_file.attributes[S_DATASOURCEENCODING].attr_value
      set_attr_value(S_DATASOURCEENCODING, default)
      raise WrongDataSourceEncoding.new(<<-EOTXT)
        Das eingestellte Encoding der Datenquelle '#{datasource_encoding}' ist ungültig.
        
        Gültige Werte sind '#{VALID_ENCODINGS.join("', '")}'.
        
        Der Wert wird jetzt auf den Standardwert '#{default}'  gesetzt.
        
        Bitte stellen Sie in den Layouteigenschaften das korrekte Encoding
        ein und speichern Sie die Einstellungen.
      EOTXT
    end
  end
end