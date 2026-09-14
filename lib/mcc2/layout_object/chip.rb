require "mcc2/constants"
require "mcc2/dataman/base"

module Mcc2
  module LayoutObject
    # diese Klasse ist für die Personalisierung der Chips verantwortlich
    class Chip
      class InvalidScriptType < RuntimeError
      end

      def initialize(xml_elem)
        @xml_elem = xml_elem
      end

      # Array of the chip parameters
      def params(row = nil)
        (1..CHIPPARAM_FIELD_COUNT).map do |i|
          param = self["#{S_PARAM}_#{i}"]
          param = DataMan.replace_variables(param, row) if row
          param
        end
      end

      def params_hash(row = nil)
        params.map do |param|
          key, value = param.split("=", 2)
          if key && value
            [key, value]
          else
            nil
          end
        end.compact.to_h
      end

      def [](attr)
        @xml_elem.at_xpath(attr).content
      end

      # personalisiert eine Karte
      # === Parameter
      # +xml_doc+::   die XML-Struktur mit den Definitionen des Kartenlayouts
      # +row+::       ein Datensatz im FasteCSV-Format
      def pers_chip(row)
        require "chipcoding"

        p "pers_chip #{row.inspect}"
        # die Chip-Parameter auslesen
        params = self.params_hash(row)

        Chipcoding::Client.personalize_card( params )
      end
    end
  end
end

if __FILE__ == $0
  # ~ system("ruby mcc2.rb #{ARGV}")
  # ~ exit

  chip = Chip.new

  params = [nil] * chip.anz_params
  params[0] = "ohne"
  params[3] = "31382" # Batch
  params[4] = "413" # Card
  params[7] = "RUBY;i:/THERMO/golf/GOLF_MIF_PLATZREIFE.RB"
  params[10] = "ffffffffffff"
  params[22] = "feigusb"

  if params[7] =~ /^RUBY;(.*)/
    basename = File.basename($1)
    chip_obj = Chip32n::ClassLoader.load(basename)
  end

  chip_obj.personalize(params)
  chip_obj.close

end
