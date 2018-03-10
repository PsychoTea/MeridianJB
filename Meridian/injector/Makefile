TARGET  = injector
OUTDIR ?= bin

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid
CHMOD   = chmod

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): injector.m | $(OUTDIR)
	$(CC) -framework Foundation -o $@ $^
	$(LDID) -Sentitlements.xml $@
	$(CHMOD) 755 $@

clean:
	rm -rf $(OUTDIR)
