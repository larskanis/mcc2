# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :bundler

Hoe.spec 'mcc2' do
  developer('Andreas Kosche', 'kosche@comcard.de')
  developer('Lars Kanis', 'kanis@comcard.de')

  extra_deps << ['nokogiri', '>= 1.4']
  extra_deps << ['fastercsv', '>= 1.2']
  extra_deps << ['dbf', '>= 1.2']
  extra_deps << ['rmagick', '>= 2.5']
  extra_deps << ['barby', '>= 0.5']
  extra_deps << ['rqrcode', '>= 0.4']

  # self.rubyforge_name = 'mcc2x' # if different than 'mcc2'
end

# Add ccgems to Gemfile
task "bundler:gemfile" do
  unless File.read("Gemfile") =~ /ccgems/
    File.open("Gemfile","a+") do |gemfile|
      gemfile.puts "source \"http://ccgems\""
    end
  end
end

# vim: syntax=ruby
