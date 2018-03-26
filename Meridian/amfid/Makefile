TARGET  = amfid_payload.dylib
OUTDIR ?= bin

CXX     = xcrun -sdk iphoneos clang -arch arm64
LDID    = ldid
CFLAGS  = -dynamiclib -framework Foundation -framework IOKit -lc++

all: $(OUTDIR)/$(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): *.c *.m *.mm *.a | $(OUTDIR)
	$(CXX) $(CFLAGS) -o $@ $^
	$(LDID) -S $@

clean:
	rm -rf $(OUTDIR)
