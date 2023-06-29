
FILES = src/sieb.nim

default: release

autobuild:
	find . -type f -iname \*.nim | entr -c make development

dependencies:
	nimble install --depsOnly

development: ${FILES}
	# can use gdb with this...
	nim --verbosity:2 --debugInfo --assertions:on --stacktrace:on --linedir:on -d:debug -d:nimTypeNames --nimcache:.cache c ${FILES}
	mv src/sieb .

debugger: ${FILES}
	nim --debugger:on --nimcache:.cache c ${FILES}
	mv src/sieb .

release:dependencies ${FILES}
	nim -d:release -d:strip --mm:arc -d:lto --opt:speed --nimcache:.cache c ${FILES}
	mv src/sieb .

docs:
	nim doc ${FILES}
	mv src/htmldocs docs

clean:
	fossil clean --dotfiles -f -v

clobber:
	fossil clean -x -v

