#!/bin/sh

echo "====== PERFORMING POST BUILD ACTIONS ======"

cd Meridian

xcodebuild -scheme Meridian -archivePath Meridian.xcarchive 

xcodebuild -exportArchive -archivePath Meridian.xcarchive -exportPath Meridian.ipa -exportOptionsPlist exportPlist.plist

rm -r Meridian.xcarchive

ls -l Meridian.ipa

echo $(openssl rand -hex 32) >> key.txt

scp Meridian.ipa key.txt ben@vps.sparkes.zone:/home/ben/MeridianBuilds

echo "====== COMPLETED POST BUILD ACTIONS ======"
