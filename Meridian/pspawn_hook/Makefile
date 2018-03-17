TARGET  = pspawn_hook.dylib
OUTDIR ?= bin

CC      = xcrun -sdk iphoneos gcc -arch arm64 -arch armv7 -arch armv7s
LDID    = ldid

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): *.m *.c mach/*.c | $(OUTDIR)
	$(CC) -dynamiclib -framework Foundation -o $@ $^
	$(LDID) -S $@

clean:
	rm -rf $(OUTDIR)
