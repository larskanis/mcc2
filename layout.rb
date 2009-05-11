# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class Layout
  attr_accessor :xml
#  attr_accessor :graphic_objects
#  attr_accessor :duplex
#  attr_accessor :chip
#  attr_accessor :magstripe
#  attr_accessor :height
#  attr_accessor :width
  
 	# ---------------------------------------------------------------------------------------------------------
  def initialize(xmlfile_name)
    @xml = MyXML.new
    @xmlfile_name = xmlfile_name
    #~ @graphic_objects = {}
    #~ @duplex = false
    #~ @height = $pr.default_height
    #~ @width = $pr.default_width
    #~ @chip = Chip.new
    #~ @magstripe = Magstripe.new
  end
  
 	# ---------------------------------------------------------------------------------------------------------
# lädt das INI-File und initialisiert die entsprechenden Variablen und Objekte
	def load_from_xml
  end
 	# ---------------------------------------------------------------------------------------------------------
  # speichert alle GraphicObjekte und Layout-Einstellungen im INI-File
	def store_to_xml
  end
 	# ---------------------------------------------------------------------------------------------------------
	# lädt das INI-File und initialisiert die entsprechenden Variablen und Objekte
	def load_from_ini
		oIni = MyIniFile::new(@inifile_name)
    
    # die Layout-Optionen laden
    @duplex = oIni.get_or_create(S_LAYOUT, S_DUPLEX, false)
    @height = oIni.get_or_create(S_LAYOUT, S_HEIGHT, $pr.default_height)
    @width = oIni.get_or_create(S_LAYOUT, S_WIDTH, $pr.default_width)
    
    # die CHIP-Optionen laden
    @chip = Chip.new
    @chip.params.each_with_index{|param, index|
      @chip.params[index] = oIni.get_or_create(S_CHIP, "#{S_PARAM}_#{index}", "")
    }
    
    # die Magnetstreifen-Optionen laden
    
    # alle Graphicobjekte laden
    oIni.sections.each{|s|
      #~ print "*"*50
      #~ print "\n"
      #~ print "[#{s}]\n"
      a = s.split("_")
      typ = a[0]
      id = a[1].to_i
      next if typ != TEXTOBJECT && typ != BARCODEOBJECT && typ != PICTUREOBJECT # hier nur GraphikObjekte laden

      o = get_object_by_typ(typ)
      o.go_attributes[GOA_ID].attr_value = id
      # je nach Graphicobjekt-Typ die Attribute eines Graphicobjectes durchlaufen diese in das Object laden und falls nicht vorhanden, dann neu anlegen
      o.go_attributes.each_pair{|go_attribute_name, go_attribute|
        unless go_attribute.attr_name == GOA_TYP || go_attribute.attr_name == GOA_ID
          v = oIni.get_or_create(s, go_attribute_name, go_attribute.attr_value)
          o.go_attributes[go_attribute_name].attr_value = v
        end
      }
      #~ oIni[s].each { |k, v|
        #~ print "  #{k} = #{v}\n"
      #~ }
#      o.go_attributes.each{|e| p e }

      o.go_attributes.each_pair{|k, v| print "#{v.attr_name}: #{v.attr_value} \n" }
    }

    oIni.save
	end
  
 	# ---------------------------------------------------------------------------------------------------------
  # speichert alle GraphicObjekte und Layout-Einstellungen im INI-File
	def store_to_ini
		oIni = MyIniFile::new(@inifile_name)
    
    # die Layout-Optionen speichern
    oIni.store(S_LAYOUT, S_DUPLEX, @duplex)
    oIni.store(S_LAYOUT, S_HEIGHT, @height)
    oIni.store(S_LAYOUT, S_WIDTH, @width)
    
    # die CHIP-Optionen speichern
    @chip.params.each_with_index{|param, index|
      oIni.store(S_CHIP, "#{S_PARAM}_#{index}", param)
    }
    
    # die Magnetstreifen-Optionen speichern
    
    # alle Graphicobjekte durchlaufen und speichern
    @graphic_objects.each_pair{|graphic_object_name, graphic_object_attributes|
      graphic_object_attributes.go_attributes.each_pair{|go_attribute_name, go_attribute|
        # alle Attribute, außer Typ und ID (diese stehen schon im Sektor) im INI-File speichern
        unless go_attribute.attr_name == GOA_TYP || go_attribute.attr_name == GOA_ID
          section = graphic_object_name
          key = go_attribute.attr_name
          value = go_attribute.attr_value
          oIni.store(section, key, value)
        end
      }
    }
    
    oIni.save
  end

 	# ---------------------------------------------------------------------------------------------------------
  def get_object_by_typ(typ)
    if typ == TEXTOBJECT then TextObject.new
    elsif typ == BARCODEOBJECT then BarcodeObject.new
    elsif typ == PICTUREOBJECT then PictureObject.new
    end
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  # fügt ein GraphicObjekt zur Objektliste hinzu
  def add_object(typ)
    o = get_object_by_typ(typ)
    id = get_new_id
 		node = @xml.doc.find_first("//Root/GraphicObjects")
    node << go = XML::Node.new(GRAPHICOBJECT)
    go << XML::Node.new(GOA_TYP, typ)
    go << XML::Node.new(GOA_ID, id.to_s)
    o.go_attributes.each_pair{|goa_name, go_attribute|
      unless go_attribute.attr_name == GOA_ID
        go << XML::Node.new(go_attribute.attr_name, go_attribute.attr_value.to_s)
      end
    }

  end
  
 	# ---------------------------------------------------------------------------------------------------------
  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
		@xml.doc.find("//Root/GraphicObjects/#{GRAPHICOBJECT}").each{|go|
      id = go.find(GOA_ID).first.content.to_i+1 if go.find(GOA_ID).first.content.to_i >= id
    }
    id
  end
  
end


if __FILE__ == $0
  lay = Layout.new("layout_test.xml")
  
  lay.add_object(TEXTOBJECT)  
  lay.add_object(BARCODEOBJECT)  
  lay.add_object(PICTUREOBJECT)  
  lay.add_object(TEXTOBJECT)  
  lay.add_object(BARCODEOBJECT)  
  lay.add_object(TEXTOBJECT)  
  print lay.xml.doc.to_s
#  lay.store_to_ini
  #~ lay.load_from_ini
end
