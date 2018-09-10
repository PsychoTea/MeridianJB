TARGET  = pspawn_hook.dylib
OUTDIR ?= bin
SRC     = $(wildcard *.c) $(wildcard *.m) $(wildcard mach/*.c)

CC      = xcrun -sdk iphoneos gcc -arch arm64 -arch armv7 -arch armv7s
LDID    = ldid
CFLAGS  = -dynamiclib -I./mach -framework Foundation

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): $(SRC) | $(OUTDIR)
	$(CC) $(CFLAGS) -o $@ $^
	$(LDID) -S $@

install: all

clean:
	rm -rf $(OUTDIR)
