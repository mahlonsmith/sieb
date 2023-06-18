
FILES = src/sieb.nim

default: release

autobuild:
	find . -type f -iname \*.nim | entr -c make development

dependencies:
	nimble install --depsOnly

development: ${FILES}
	# can use gdb with this...
	nim --debugInfo --assertions:on --linedir:on -d:testing -d:nimTypeNames --nimcache:.cache c ${FILES}
	mv src/sieb .

debugger: ${FILES}
	nim --debugger:on --nimcache:.cache c ${FILES}
	mv src/sieb .

release:dependencies ${FILES}
	nim -d:release -d:strip --passc:-flto --opt:speed --nimcache:.cache c ${FILES}
	mv src/sieb .

docs:
	nim doc ${FILES}
	mv src/htmldocs docs

clean:
	fossil clean --dotfiles -f -v

clobber:
	fossil clean -x -v

