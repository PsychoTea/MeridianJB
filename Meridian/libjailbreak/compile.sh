#!/bin/sh

export PATH="$PATH:$HOME/bin"

currDir=$(dirname $0)

cd $currDir

xcrun -sdk iphoneos gcc -arch arm64 -dynamiclib -framework Foundation -o libjailbreak.dylib main.m mach/jailbreak_daemonUser.c
jtool --sign sha1 --inplace --ent $currDir/ent.plist libjailbreak.dylib
chmod 0755 libjailbreak.dylib
