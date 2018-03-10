TARGET  = jailbreakd
OUTDIR ?= bin

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid
CHMOD   = chmod

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): *.m *.c mach/*.c | $(OUTDIR)
	$(CC) -framework Foundation -framework IOKit -o $@ $^
	$(LDID) -Sentitlements.xml $@
	$(CHMOD) 755 $@

clean:
	rm -rf $(OUTDIR)
