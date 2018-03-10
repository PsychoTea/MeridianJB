TARGET1 = amfid_fucker
TARGET2 = amfid_payload.dylib
OUTDIR ?= bin

CC      = xcrun -sdk iphoneos gcc -arch arm64
LDID    = ldid
CHMOD   = chmod

all: $(OUTDIR)/$(TARGET1) $(OUTDIR)/$(TARGET2)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET1): amfid_fucker.m | $(OUTDIR)
	$(CC) -framework Foundation -o $@ $^
	$(LDID) -Sentitlements.xml $@
	$(CHMOD) 755 $@

$(OUTDIR)/$(TARGET2): amfid_payload.m | $(OUTDIR)
	$(CC) -dynamiclib -framework Foundation -o $@ $^
	$(LDID) -Sentitlements.xml $@

clean:
	rm -rf $(OUTDIR)
