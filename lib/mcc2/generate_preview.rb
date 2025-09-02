require "pmap"

module Mcc2
  class GeneratePreview
    attr_accessor :verbose

    def initialize
      @mcc2print = Mcc2::Mcc2Print.new
    end

    def start!(fnames)
      if fnames.empty?
        fnames = (Dir.glob("*.xml") + Dir.glob("*.mcc2")).sort
      end
      fnames.each do |fname|
        fname_png = "#{fname}.png"
        if File.exist?(fname_png) && File.mtime(fname) <= File.mtime(fname_png)
          puts "Skip #{fname} (is up-to-date)" if verbose
          next
        end

        fna = File.basename(fname)
        kwargs = {
          "//Layout/datasource_typ" => "none",
          "//Layout/datasource" => "3",
          "//Layout/barcode_dpi" => "200",
          "{#{fna}}//Layout/datasource" => "1",
          "{#{fna}}//Layout/printertype" => "FilePrinter",
          "{#{fna}}//Layout/fileprinter_save_as" => fname_png,
          "{#{fna}}//Layout/fileprinter_dpi" => "200",
        }

        begin
          puts "Processing #{fname}" if verbose
          @mcc2print.start!(fname, kwargs)
        rescue => err
          $stderr.puts "#{fname}: #{err}"
        end
      end
    end

    def self.run(argv)
      app = new

      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} <layout.mcc2>* [options]"

        opts.on("-v", "--[no-]verbose", "Run verbosely", &app.method(:verbose=))
      end.parse!

      app.start!(argv)
    end
  end
end
