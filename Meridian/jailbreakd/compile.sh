#!/bin/sh

export PATH="$PATH:$HOME/bin"

outputFile="jailbreakd"
tarName="jailbreakd.tar"

currDir=$(dirname $0)

cd $currDir

xcrun -sdk iphoneos gcc -arch arm64 -framework Foundation -framework IOKit -o $currDir/$outputFile kern_utils.m kexecute.c kmem.c main.m offsetof.c osobject.c patchfinder64.c sandbox.c
jtool --sign sha1 --inplace --ent $currDir/ent.plist $currDir/$outputFile
chmod 0755 $currDir/$outputFile

tar -cf $tarName $outputFile

rm $currDir/$outputFile

mv $currDir/$tarName $currDir/../Meridian/$tarName
