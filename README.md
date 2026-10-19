# Mcc2

* https://github.com/larskanis/mcc2

Layout editor and card printer GUI

## Features

* Simple GUI to edit the layout
* Variable data input from CSV and DBF file
* Pure desktop GUI, no web server necessary
* Supports magstripe encoding and contact+contactless chip encoding
* Use of font files independent from system installed fonts
* Vector output formats (SVG and searchable PDF)
* Various raster image output formats (PNG, JPEG etc.)
* Headless print per command line and Ruby API
* Stores all printer settings in the layout file for headless print (Duplex, tray selection, DPI, etc.)

## Installation

Install mcc2 on Debian/Ubuntu Linux as:

    $ sudo apt install libcairo2-dev libgdk-pixbuf-2.0-dev libmagickwand-dev g++ libxrandr-dev libfox-1.6-dev
    $ sudo apt install ruby-dev  # in case you want to use system ruby
    $ gem install mcc2

On Windows install the RubyInstaller including Devkit, then run:

    $ gem install mcc2

This should

## Usage

Run the GUI

    $ mcc2

## Development

To install all necessary gems onto your local machine, run `bundle update`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/larskanis/mcc2 .


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

