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
	# ---------------------------------------------------------------------------------------------------------
  def create
    @doc = LibXML::XML::Document.new
    @doc.encoding = XML::Encoding::UTF_8
    @doc.root = XML::Node.new("Root")
    
    # Layout dfinieren
    @doc.root << node = XML::Node.new("Layout")
      node << XML::Node.new("Duplex","0")
      node << XML::Node.new("Width",$pr.default_width.to_s)
      node << XML::Node.new("Height",$pr.default_height.to_s)
    
    # Chip definieren
    @doc.root << node = XML::Node.new("Chip")
    chip = Chip.new
    (1..chip.anz_params).each{|i|
      node << param = XML::Node.new("#{S_PARAM}_#{i}","")
    }
    
    # Magstripe definieren
    @doc.root << node = XML::Node.new("Magstripe")
    
    # Chip definieren definieren
    @doc.root << node = XML::Node.new("GraphicObjects")
    
    #~ print @xmldoc.to_s
  end
	# ---------------------------------------------------------------------------------------------------------
  def save(xmlfilename)
    file = File.new(xmlfilename,"w")
#    print @xmldoc.to_s
    @xmldoc.save(xmlfilename)
    file.close
  end
	# ---------------------------------------------------------------------------------------------------------
  def load(filename)
    @doc = LibXML::XML::Document.file(filename)
  end
end
# ==============================================================================================
if $0  == __FILE__
  x = MyXML.new
  print x.doc.to_s
#  x.save("test.xml")
end
