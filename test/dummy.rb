require "chipcoding"

class Dummy < ChipSystemReader
  def personalize_card(card)
    log.debug("Personalisiere Karte...")
    sleep(5)
    log.debug("Karte personalisiert")
  end
end

# Simulation der Maschinenaufrufe bei direktem Start der Datei
if __FILE__ == $0
  cs = AtrTest.new
  # Einstellung Kartenleser fuer Simulation
  cs.on_open_reader { Grinsen::Target::Towitoko.new }

  if true
    # Simulation MCES-Aufruf
    cs.host_name, cs.port_no = "192.168.1.1", "5001"
    cs.startEncoding("2142", ["Beispielparameter>Wert"])
  else
    # Simulation Chip32-Aufruf
    cs.personalize(%w[1 2 3 4])
  end
end
