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
        # je nach Graphicobjekt-Typ die Attribute eines frischen Graphicobjectes durchlaufen diese in das Object laden und falls nicht vorhanden, dann neu anlegen
        
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
  
  def add_text
    o = TextObject.new
    #~ o.go_attributes.each{|e| p e}
    @graphic_objects["#{o.go_attributes[GOA_TYP].attr_value}_1"] = o
  end

  def add_picture
    o = PictureObject.new
    #~ o.go_attributes.each{|e| p e}
    @graphic_objects["#{o.go_attributes[GOA_TYP].attr_value}_1"] = o
  end

  def add_barcode
    o = BarcodeObject.new
    #~ o.go_attributes.each{|e| p e}
    @graphic_objects["#{o.go_attributes[GOA_TYP].attr_value}_1"] = o
  end

end


if __FILE__ == $0
  lay = Layout.new("test.ini")
  lay.add_text
  lay.add_barcode
  lay.add_picture
  lay.store_to_ini
  #~ lay.load_from_ini
end
