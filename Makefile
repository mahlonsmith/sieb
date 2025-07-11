
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
	# Requires href="${url}/file?ci=tip&name=${path}&ln=${line}" modification in nimdoc.cfg
	nim doc --git.url:https://code.martini.nu/fossil/sieb --project --outdir:release/doc src/sieb.nim

clean:
	fossil clean --dotfiles -f -v

clobber:
	fossil clean -x -v

latest: clobber docs
	tar -C .. --exclude .f\* -zcvf ../sieb-latest.tar.gz sieb
	mkdir -p release
	mv ../sieb-latest.tar.gz release
	fossil uv add release/sieb-latest.tar.gz
	find release/doc -type f -print0 | xargs -0 -I% fossil uv add %

