#!/bin/sh

export PATH="$PATH:$HOME/bin"

inputFile="injector.m"
outputFile="injector"
tarName="injector.tar"

currDir=$(dirname $0)

cd $currDir

xcrun -sdk iphoneos gcc -arch arm64 -framework Foundation -o $currDir/$outputFile $currDir/$inputFile
jtool --sign sha1 --inplace --ent $currDir/ent.plist $currDir/$outputFile
chmod 0755 $currDir/$outputFile
