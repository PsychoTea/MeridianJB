TARGET  = Unrestrict.dylib
OUTDIR ?= bin
SRC	= $(wildcard *.c helpers/*.c)

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid
CFLAGS  = -I. -Ihelpers -dynamiclib -framework IOKit -framework CoreFoundation

.PHONY: all install clean

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $@

$(OUTDIR)/$(TARGET): $(SRC) | $(OUTDIR)
	$(CC) $(CFLAGS) -o $@ $^
	$(LDID) -S $@

install: all

clean:
	rm -rf $(OUTDIR) $(OBJ)
