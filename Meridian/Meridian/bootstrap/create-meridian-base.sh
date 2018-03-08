#!/bin/bash

currDir=$(dirname $0)
meridianDir=$currDir/../../
baseDir=$currDir/meridian-base/

# amfid (fucker & payload)
mv $meridianDir/amfid/amfid_fucker $baseDir/meridian/amfid
mv $meridianDir/amfid/amfid_payload.dylib $baseDir/meridian/amfid

# injector
mv $meridianDir/injector/injector $baseDir/meridian/

# pspawn_hook.dylib
mv $meridianDir/pspawn_hook/pspawn_hook.dylib $baseDir/meridian

# libjailbreak.dylib
mv $meridianDir/libjailbreak/libjailbreak.dylib $baseDir/usr/lib

# jailbreakd
mv $meridianDir/jailbreakd/jailbreakd $baseDir/meridian/jailbreakd

# TweakLoader.dylib
mv $meridianDir/TweakLoader/TweakLoader.dylib $baseDir/usr/lib

# remove all .DS_Store files
find $baseDir -name '.DS_Store' -delete

# create tar archive
cd $baseDir
tar -cf meridian-base.tar ./*
mv meridian-base.tar $currDir
