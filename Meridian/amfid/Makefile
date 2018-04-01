TARGET  = amfid_payload.dylib
OUTDIR ?= bin
SRC     = $(wildcard *.c) $(wildcard *.m) $(wildcard */*.c) $(wildcard */*.m)

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid
CFLAGS  = -dynamiclib -framework Foundation -framework IOKit -lc++

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): $(SRC) | $(OUTDIR)
	$(CC) $(CFLAGS) -o $@ $^
	$(LDID) -S $@

clean:
	rm -rf $(OUTDIR)
