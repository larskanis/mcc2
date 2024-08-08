class ::String
  # Add String#encode to ruby-1.8.x
  unless method_defined?(:encode)
    require "iconv"

    def encode(nach, von, options = {})
      nach += "//IGNORE" if options[:invalid]
      nach += "//TRANSLIT" if options[:undef]
      Iconv.iconv(nach, von, self)
    end
  end
end
