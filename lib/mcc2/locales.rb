require "i18n"

module Mcc2
  module Locales
    @@supported_language_files = nil
    def self.supported_language_files
      @@supported_language_files ||= Dir[File.expand_path("../../locales/*.yml", __dir__)]
    end

    def self.init
      I18n.enforce_available_locales = true
      # I18n.default_locale = :en # (note that `en` is already the default!)
    end

    def self.add_i18n
      I18n.load_path += supported_language_files
    end

    def self.add_lang_option(opts, &block)
      block ||= proc { |o| I18n.locale = o }
      langs = supported_language_files.map{|f| File.basename(f, ".*") }.join(", ")
      opts.on( '-l', '--lang ISO2', "Set language of the UI (#{langs})", &block)
    end

    add_i18n
  end
end
