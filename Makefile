
FILES = src/sieb.nim

default: release

autobuild:
	find . -type f -iname \*.nim | entr -c make development

dependencies:
	nimble install --depsOnly

development: ${FILES}
	# can use gdb with this...
	nim --debugInfo --assertions:on --linedir:on -d:testing -d:nimTypeNames --nimcache:.cache c ${FILES}

debugger: ${FILES}
	nim --debugger:on --nimcache:.cache c ${FILES}

release:dependencies ${FILES}
	nim -d:release -d:nimDebugDlOpen --opt:speed --parallelBuild:0 --nimcache:.cache c ${FILES}
	mv src/sieb .

docs:
	nim doc ${FILES}
	#nim buildIndex ${FILES}

clean:
	fossil clean --dotfiles -f -v

clobber:
	fossil clean -x -v

