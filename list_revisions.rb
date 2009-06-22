# alle rb-Files durch SubWCRev.exe leiern
# alle SVN-Tags werden ersetzt und nach *.ver geschrieben
rb_files = Dir[File.join("*.rb".gsub(/[a-z]/i){|c|"["+c.upcase+c.downcase+"]"})]
rb_files.each{|file|
  #~ p `SubWCRev.exe . #{file} versions/#{file}.ver`
}

# alle ver-Files scannen und die Zeile mit "Revision ="  und die Datei revisions.txt schreiben
files = Dir[File.join("versions/*.ver".gsub(/[a-z]/i){|c|"["+c.upcase+c.downcase+"]"})]
File.open("versions.rb","w"){|f_out|
  f_out.puts "$versions_liste = {}"

  files.each{|file|
    f = file.split("/")[-1].gsub(".ver","")
    lines = IO.readlines(file)
    lines.each{|line|
      #~ p __FILE__
      #~ p f
      if line =~ /# (Revision = .*)/ && f != __FILE__
        version = $1
        f_out.puts "$versions_liste['#{f.gsub(".rb","")}'] = '#{version}'"
      end
    }
  }
}
