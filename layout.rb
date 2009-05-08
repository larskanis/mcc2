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
  
 	# ---------------------------------------------------------------------------------------------------------
  def initialize(inifile_name)
    @inifile_name = inifile_name
    @graphic_objects = {}
  end
  
 	# ---------------------------------------------------------------------------------------------------------
	# lädt das INI-File und initialisiert die entsprechenden Variablen
	def load_from_ini
		oIni = MyIniFile::new(@inifile_name)
#    oIni.get_or_create(section, key, default)
			
    oIni.sections.each{|s|
      print "*"*50
      print "\n"
      print "[#{s}]\n"
      a = s.split("_")
      typ = a[0]
      id = a[1].to_i
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
  # speichert alle GraphicObjekte im INI-File
	def store_to_ini
		oIni = MyIniFile::new(@inifile_name)
    
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
    #~ p "*"*50
    o = get_object_by_typ(typ)
    id = get_new_id
    o.go_attributes[GOA_ID].attr_value = id
    typ = o.go_attributes[GOA_TYP].attr_value
    #~ o.go_attributes.each{|e| p e}
    @graphic_objects["#{typ}_#{id}"] = o
  end
  
 	# ---------------------------------------------------------------------------------------------------------
  # ermittelt die nächst höhere ID (beeinflusst die Darstellungsebene)
  def get_new_id
    id = 0
    @graphic_objects.each_pair{|go_name, go|
      #~ p "go: #{go.inspect}"
      go.go_attributes[GOA_ID].attr_value
      id = (go.go_attributes[GOA_ID].attr_value)+1 if go.go_attributes[GOA_ID].attr_value >= id
    }
    #~ p "ID: #{id}"
    id
  end
  
end


if __FILE__ == $0
  lay = Layout.new("test.ini")
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(PICTUREOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.add_object(BARCODEOBJECT)  
  #~ lay.add_object(TEXTOBJECT)  
  #~ lay.store_to_ini
  lay.load_from_ini
end
