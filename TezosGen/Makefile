.PHONY : clean superclean build install dev

default: clean build

dev:
	swift package generate-xcodeproj

clean:
	swift package clean

superclean: clean
	rm -rf .build

build:
	swift build

install: clean
	swift build -c release -Xswiftc -static-stdlib
	mv .build/release/tezosgen /usr/local/bin/tezosgen
	mkdir -p /usr/local/share/tezosgen
	rm -rf /usr/local/share/tezosgen/templates
	cp -R templates /usr/local/share/tezosgen/templates
	rm -f /usr/local/share/tezosgen/Rakefile
	cp Rakefile /usr/local/share/tezosgen/Rakefile
	bundle install
	
