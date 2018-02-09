#!/bin/sh

export PATH="$PATH:$HOME/bin"

outputFile="pspawn_hook.dylib"
tarName="pspawn_hook.tar"

currDir=$(dirname $0)

cd $currDir

xcrun -sdk iphoneos gcc -arch arm64 -dynamiclib -framework Foundation -o $currDir/$outputFile pspawn_hook.m fishhook.c common.c
jtool --sign sha1 --inplace --ent $currDir/ent.plist $currDir/$outputFile
chmod 0755 $currDir/$outputFile
