#!/bin/sh

export PATH="$PATH:$HOME/bin"

inputFile="pspawn_hook.m"
outputFile="pspawn_hook.dylib"
tarName="pspawn_hook.tar"

currDir=$(dirname $0)

xcrun -sdk iphoneos gcc -arch arm64 -dynamiclib -framework Foundation -o $currDir/$outputFile $currDir/$inputFile
jtool --sign sha1 --inplace --ent $currDir/ent.plist $currDir/$outputFile
chmod 0755 $currDir/$outputFile

tar -cf $currDir/$tarName $currDir/$outputFile

rm $currDir/$outputFile

mv $currDir/$tarName $currDir/../Meridian/$tarName
