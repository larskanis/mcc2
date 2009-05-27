# -*- coding: UTF-8 -*-

if __FILE__ == $0
  require 'mcc2'
end


class DataMan
  def initialize
  end
  
  # ersetzt die Felder in data, welche dem Muster {feldname[pos,anz]} entsprechen, durch ihren Inhalt
  # === Paramter
  # +data+::   die im Layut definierten Daten für dieses Objekt
  # +row+::    ein Datensatz im FasteCSV-Format
  def self.replace_variables(data, row)
    return data unless row # die unveränderten Daten zurückgeben, wenn kein Datensatz übergeben wurde
    pattern = /\{ *([-\._\w]*)\[ *(\d{1,3}) *, *(\d{1,3}) *\] *\}/
    data.gsub(pattern){
      feld = $1
      von = $2.to_i
      anz = $3.to_i
      row[feld.intern].to_s[von, anz]
    }
  end
 	#---------------------------------------------------------------------------------------------------------

end


if __FILE__ == $0
end
