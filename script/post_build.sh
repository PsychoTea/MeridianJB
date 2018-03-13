#!/bin/sh

echo "====== PERFORMING POST BUILD ACTIONS ======"

cd Meridian

xcodebuild -scheme Meridian -archivePath Meridian.xcarchive -allowProvisioningUpdates CODE_SIGNING_IDENTITY="" CODE_SIGNING_REQUIRED=NO

xcodebuild -exportArchive -archivePath Meridian.xcarchive -exportPath Meridian.ipa -exportOptionsPlist exportPlist.plist -allowProvisioningUpdates

rm -r Meridian.xcarchive

ls -l Meridian.ipa

ssh -o StrictHostKeyChecking=no -l ben vps.sparkes.zone
scp Meridian.ipa ben@vps.sparkes.zone:/home/ben/MeridianBuilds

echo "====== COMPLETED POST BUILD ACTIONS ======"
