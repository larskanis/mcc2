require "pmap"

module Mcc2
  class GeneratePreview
    attr_accessor :verbose
    attr_accessor :dpi
    attr_accessor :skip_when

    def initialize
      @mcc2print = Mcc2::Mcc2Print.new
      @dpi = 200
      @skip_when = "uptodate"
    end

    def start!(fnames)
      if fnames.empty?
        fnames = (Dir.glob("*.xml") + Dir.glob("*.mcc2")).sort
      end
      fnames.each do |fname|
        fname_png = "#{fname}.png"
        sk = case skip_when
        when "existing" then File.exist?(fname_png)
        when "uptodate" then File.exist?(fname_png) && File.mtime(fname) <= File.mtime(fname_png)
        when "none" then false
        else
          raise "invalid skip mode: #{skip_when}"
        end
        if sk
          puts "Skip #{fname} (is #{skip_when})" if verbose
          next
        end

        fna = File.basename(fname)
        kwargs = {
          "//Layout/datasource_typ" => "none",
          "//Layout/datasource" => "3",
          "//Layout/barcode_dpi" => dpi.to_s,
          "{#{fna}}//Layout/datasource" => "1",
          "{#{fna}}//Layout/printertype" => "FilePrinter",
          "{#{fna}}//Layout/fileprinter_save_as" => fname_png,
          "{#{fna}}//Layout/fileprinter_dpi" => dpi.to_s
        }

        begin
          puts "Processing #{fname}" if verbose
          @mcc2print.start!(fname, kwargs)
        rescue => err
          warn "#{fname}: #{err}"
        end
      end
    end

    def self.run(argv)
      app = new

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} <layout.mcc2>* [options]"

        opts.on("-v", "--[no-]verbose", "Run verbosely", &app.method(:verbose=))
        Locales.add_lang_option(opts)
        opts.on("--dpi INT", "Generate previews with INT DPI [#{app.dpi}]", &app.method(:dpi=))
        opts.on("--skip MODE", "Skip files when: uptodate|existing|none [#{app.skip_when}]", &app.method(:skip_when=))
      end.parse!

      app.start!(argv)
    end
  end
end
