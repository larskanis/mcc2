# -*- coding: UTF-8 -*-
require 'inifile'

if __FILE__ == $0
  require 'mcc2'
end


class Layout
  attr_accessor :graphic_objects
  attr_accessor :duplex
  attr_accessor :chip
  attr_accessor :magstripe
  attr_accessor :height
  attr_accessor :width
  
  def initialize(inifile_name)
    @inifile_name = inifile_name
    @graphic_objects = {}
  end
  
  def load(filename)
  end
  
  	# ---------------------------------------------------------------------------------------------------------
	# lädt das INI-File und initialisiert die entsprechenden Variablen
	def load_from_ini
		oIni = MyIniFile::new(@inifile_name)
#    oIni.get_or_create(section, key, default)
			
    oIni.sections.each{|s|
      print "[#{s}]\n"
      oIni[s].each { |k, v|
        print "  #{k} = #{v}\n"
        # je nach Graphicobjekt-Typ die Attribute eines Graphicobjectes durchlaufen diese in das Object laden und falls nicht vorhanden, dann neu anlegen
        
      }
    }

    oIni.save
	end
  
	def store_to_ini
		oIni = MyIniFile::new(@inifile_name)
    
    # alle Graphicobjekte durchlaufen und speichern
    @graphic_objects.each_pair{|graphic_object_name, graphic_object_attributes|
      graphic_object_attributes.go_attributes.each_pair{|go_attribute_name, go_attribute|
        section = graphic_object_name
        key = go_attribute.attr_name
        value = go_attribute.attr_value
        oIni.store(section, key, value)
      }
    }
    
    oIni.save
  end
  
  # fügt ein GraphicObjekt zur Objektliste hinzu
  def add_object(typ)
    p "*"*50
    if typ == TEXTOBJECT then o = TextObject.new
    elsif typ == BARCODEOBJECT then o = BarcodeObject.new
    elsif typ == PICTUREOBJECT then o = PictureObject.new
    end
    id = get_new_id
    o.go_attributes[GOA_ID].attr_value = id
    #~ o.go_attributes.each{|e| p e}
    @graphic_objects["#{o.go_attributes[GOA_TYP].attr_value}_#{id}"] = o
  end
  
  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
    @graphic_objects.each_pair{|go_name, go|
      p "go: #{go.inspect}"
      go.go_attributes[GOA_ID].attr_value
      id = (go.go_attributes[GOA_ID].attr_value)+1 if go.go_attributes[GOA_ID].attr_value >= id
    }
    p "ID: #{id}"
    id
  end
  
end


if __FILE__ == $0
  lay = Layout.new("test.ini")
  lay.add_object(TEXTOBJECT)  
  lay.add_object(BARCODEOBJECT)  
  lay.add_object(PICTUREOBJECT)  
  lay.add_object(TEXTOBJECT)  
  lay.add_object(BARCODEOBJECT)  
  lay.add_object(TEXTOBJECT)  
  lay.store_to_ini
  #~ lay.load_from_ini
end
