.POSIX:
CC        = clang
OBJCFLAGS = -fobjc-arc -Wall -O3
LDLIBS    = -framework Foundation
PREFIX    = /usr/local

all: hasher

install: hasher
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	cp -f hasher $(DESTDIR)$(PREFIX)/bin
	gzip < hasher.1 > $(DESTDIR)$(PREFIX)/share/man/man1/hasher.1.gz

hasher: hasher.o
	$(CC) $(OBJCFLAGS) $(LDFLAGS) -o hasher hasher.o $(LDLIBS)

hasher.o: hasher.m

clean:
	rm -f hasher hasher.o
