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
  def initialize
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
