rmdir ruby_doc /S /Q
::rdoc --op ruby_doc --diagram --image-format jpg  --exclude .*\.h(.rb)?$ --exclude test --exclude devel --line-numbers --all --include win32 --charset utf8
rdoc --op ruby_doc --exclude .*\.h(.rb)?$ --exclude test --exclude devel --line-numbers --all --include win32 --charset utf8