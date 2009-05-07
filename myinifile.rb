# -*- coding: utf-8 Cookie -*-

require "inifile"

class MyIniFile < IniFile
  def initialize(inifilename)
    super(inifilename)
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
  alias :save :write
end
# ==============================================================================================
if $0  == __FILE__
end
