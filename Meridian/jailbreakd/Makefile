TARGET  = jailbreakd
OUTDIR ?= bin
SRC     = $(wildcard *.c) $(wildcard *.m) $(wildcard */*.c) $(wildcard */*.m)

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid
CHMOD   = chmod
CFLAGS  = -I. -I./helpers -I./mach -framework Foundation -framework IOKit

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): $(SRC) | $(OUTDIR)
	$(CC) $(CFLAGS) -o $@ $^
	$(LDID) -Sentitlements.xml $@
	$(CHMOD) 755 $@

clean:
	rm -rf $(OUTDIR)
