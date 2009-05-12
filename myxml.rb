# -*- coding: utf-8 Cookie -*-

require 'xml'
#~ require 'libxml'
#~ include LibXML 

#~ require 'rexml/document'
#~ include REXML

if __FILE__ == $0
  require 'mcc2'
end


class MyXML
  attr_accessor :doc
  attr_accessor :changed
  def initialize
    @changed = false
  end
	# ---------------------------------------------------------------------------------------------------------
  def create
    @doc = LibXML::XML::Document.new
    @doc.encoding = XML::Encoding::UTF_8
    @doc.root = XML::Node.new(S_ROOT)
    
    # Layout dfinieren
    @doc.root << node = XML::Node.new(S_LAYOUT)
      node << XML::Node.new(S_DUPLEX, '0')
      node << XML::Node.new(S_WIDTH,$pr.default_width.to_s)
      node << XML::Node.new(S_HEIGHT,$pr.default_height.to_s)
    
    # Chip definieren
    @doc.root << node = XML::Node.new(S_CHIP)
    chip = Chip.new
    (1..chip.anz_params).each{|i|
      node << param = XML::Node.new("#{S_PARAM}_#{i}", "")
    }
    
    # Magstripe definieren
    @doc.root << node = XML::Node.new(S_MAGSTRIPE)
    
    # Chip definieren definieren
    @doc.root << node = XML::Node.new(GRAPHICOBJECTS)
    
  end
	# ---------------------------------------------------------------------------------------------------------
  def save(xmlfilename)
    file = File.new(xmlfilename,'w')
    @xmldoc.save(xmlfilename)
    file.close
  end
	# ---------------------------------------------------------------------------------------------------------
  def load(filename)
#    @doc = LibXML::XML::Document.file(filename, :options => XML::Parser::Options::NOBLANKS | XML::Parser::Options::PEDANTIC | XML::Parser::Options::COMPACT)
    @doc = LibXML::XML::Document.file(filename, :options => XML::Parser::Options::NOBLANKS )
   
    # kontrollieren, ob alle Nodes des Layouts existieren, ansonsten anlegen und als 'changed' markieren
    # todo
    
    # kontrollieren, ob alle Nodes des Chips existieren, ansonsten anlegen und als 'changed' markieren
    # todo
    
    # kontrollieren, ob alle Nodes des Magstripes existieren, ansonsten anlegen und als 'changed' markieren
    # todo
    
    # kontrollieren, ob alle Nodes der GraphicObjects existieren, ansonsten anlegen und als 'changed' markieren
    # 
    @doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
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
	# ---------------------------------------------------------------------------------------------------------
  def get_objectnode_by_id(id)
    @doc.find("//#{S_ROOT}/#{GRAPHICOBJECTS}/#{GRAPHICOBJECT}").each{|go_struct|
      p "struct_id: #{go_struct.find(GOA_ID).first.content}"
      p "needed_id: #{id.inspect}"
      if go_struct.find(GOA_ID).first.content.to_i == id
        p "found"
        return go_struct
      end
    }
    nil
  end
end
# ==============================================================================================
if $0  == __FILE__
  x = MyXML.new
  #~ x.create
  x.load('test5.XML')
  print x.doc.to_s
#  x.save("test.xml")
end
