#!/bin/sh

export PATH="$PATH:$HOME/bin"

currDir=$(dirname $0)

xcrun -sdk iphoneos gcc -arch arm64 -framework Foundation -o $currDir/injector $currDir/injector.m
jtool --sign sha1 --inplace --ent $currDir/ent.plist $currDir/amfid_payload
chmod 0755 $currDir/injector

tar -cf $currDir/injector.tar $currDir/injector

rm $currDir/injector

mv $currDir/injector.tar $currDir/../Meridian/injector.tar
