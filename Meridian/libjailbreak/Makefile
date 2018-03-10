TARGET  = libjailbreak.dylib
OUTDIR ?= bin

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): libjailbreak.m mach/jailbreak_daemonUser.c | $(OUTDIR)
	$(CC) -dynamiclib -o $@ $^
	$(LDID) -S $@

clean:
	rm -rf $(OUTDIR)
