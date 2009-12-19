# -*- coding: UTF-8 -*-

# Revision = "$WCREV$"; Modified = "$WCMODS?Modified:Not modified$"; Date = "$WCDATE$"; RevRange = "$WCRANGE$"

if __FILE__ == $0
  require 'mcc2'
end

require 'iconv'
require 'constants'

class BadEncodingError < RuntimeError
end

class DataMan
  attr_reader :filename
  
 	#---------------------------------------------------------------------------------------------------------
  
  # ermittelt, ob der übergebene String eine erlaubtes Encoding ist
  # === Return
  # true oder false
  # === Paramter
  # +encoding+::    das Encoding [String]
  def self.valid_datasource_encoding?(encoding)
    VALID_ENCODINGS.index(encoding)
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # ermittelt, ob der übergebene String eine erlaubte Datenquelle ist
  # === Return
  # true oder false
  # === Paramter
  # +datasource+::    der Datenquellentyp [String]
  def self.valid_datasourcetyp?(datasource)
    VALID_DATASOURCES.index(datasource)
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # === Paramter
  # +text+::        der zu konvertierende Text
  # +encoding+::    das Encoding der Quelle
  def self.convert_encoding(text, encoding)
    unless VALID_ENCODINGS.index(encoding)
      raise BadEncodingError, "falsches Encoding angegeben! Erlaubte Begriffe: #{VALID_ENCODINGS.join(", ")}. Auf Groß- Kleinschreibung achten!"
    end
    encoding = Iconv.new('latin1', encoding)
    encoding.iconv(text)
  end
 	#---------------------------------------------------------------------------------------------------------
  
  # ersetzt die Felder in data, welche dem Muster {feldname[pos,anz]} entsprechen, durch ihren Inhalt
  # === Paramter
  # +data+::   die im Layut definierten Daten für dieses Objekt
  # +row+::    ein Datensatz im FasteCSV-Format
  def self.replace_variables(data, row, encoding)
    return data unless row # die unveränderten Daten zurückgeben, wenn kein Datensatz übergeben wurde
    pattern = /\{ *([-\._\w]*)\[ *(\d{1,3}) *, *(\d{1,3}) *\] *\}/
    data.gsub(pattern){
      feld = $1
      von = $2.to_i
      anz = $3.to_i
      vardata = row[feld].to_s[von, anz].strip
      unless row.to_hash.has_key?(feld)
        $& # die unveränderten Daten zurückgeben, wenn kein passendes Feld im Datensatz gefunden wurde
      else
        DataMan.convert_encoding(vardata, encoding)
      end
    }
  end
 	#---------------------------------------------------------------------------------------------------------
end


if __FILE__ == $0
end
