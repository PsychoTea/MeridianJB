#!/bin/sh

echo "====== PERFORMING POST BUILD ACTIONS ======"

cd Meridian

xcodebuild -scheme Meridian -archivePath Meridian.xcarchive 

xcodebuild -exportArchive -archivePath Meridian.xcarchive -exportPath Meridian.ipa -exportOptionsPlist exportPlist.plist

rm -r Meridian.xcarchive

ls -l Meridian.ipa
scp Meridian.ipa ben@vps.sparkes.zone:/var/www/dl.sparko.me/Meridian.ipa

echo "====== COMPLETED POST BUILD ACTIONS ======"
