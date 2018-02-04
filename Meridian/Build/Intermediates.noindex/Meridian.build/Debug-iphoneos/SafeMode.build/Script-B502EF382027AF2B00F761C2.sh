#!/bin/sh
ldid -S$SRCROOT/SafeMode/ent.xml $SRCROOT/Build/Products/Debug-iphoneos/SafeMode.app/SafeMode
rm $SRCROOT/Build/Products/Debug-iphoneos/SafeMode.app/embedded.mobileprovision
cd $SRCROOT/Build/Products/Debug-iphoneos/
tar -cf safemode.tar SafeMode.app
mv safemode.tar $SRCROOT/Meridian
