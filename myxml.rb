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
  attr_accessor :xmldoc
  def initialize
    @xmldoc = LibXML::XML::Document.new
    @xmldoc.encoding = XML::Encoding::UTF_8
    @xmldoc.root = XML::Node.new("Root")
    
    # Layout dfinieren
    @xmldoc.root << node = XML::Node.new("Layout")
      node << XML::Node.new("Duplex","0")
      node << XML::Node.new("Width",$pr.default_width.to_s)
      node << XML::Node.new("Height",$pr.default_height.to_s)
    
    # Chip definieren
    @xmldoc.root << node = XML::Node.new("Chip")
    chip = Chip.new
    (1..chip.anz_params).each{|i|
      node << param = XML::Node.new("#{S_PARAM}_#{i}","")
    }
    
    # Magstripe definieren
    @xmldoc.root << node = XML::Node.new("Magstripe")
    
    # Chip definieren definieren
    @xmldoc.root << node = XML::Node.new("GraphicObjects")
    
    print @xmldoc.to_s
  end

	# ---------------------------------------------------------------------------------------------------------
  def import_file(xml_doc)
  end
	# ---------------------------------------------------------------------------------------------------------
  def save(xmlfilename)
    file = File.new(xmlfilename,"w")
#    p @xmldoc.to_s
    @xmldoc.save(xmlfilename)
    file.close
  end
	# ---------------------------------------------------------------------------------------------------------
	def store(section, key, value)
#		olni = nil
		self[section][key] = value
		self.save
	end
	# ---------------------------------------------------------------------------------------------------------
  def key_exist?(sector, key)
    self[section][key] ? true : false
  end
	# ---------------------------------------------------------------------------------------------------------
  def get_or_create(section, key, default)
    unless value = self[section][key]
      self[section][key] = default
      value = default
      self.save
    end
    value
  end
	# ---------------------------------------------------------------------------------------------------------
#  alias :save :write
end
# ==============================================================================================
if $0  == __FILE__
  x = MyXML.new
  x.save("test.xml")
end
