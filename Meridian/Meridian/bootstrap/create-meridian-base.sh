#!/bin/bash

currDir=$(dirname $0)
meridianDir=$currDir/../../
baseDir=$currDir/meridian-base/

# amfid (fucker & payload)
cp $meridianDir/amfid/amfid_fucker $baseDir/meridian/amfid
cp $meridianDir/amfid/amfid_payload.dylib $baseDir/meridian/amfid

# injector
cp $meridianDir/injector/injector $baseDir/meridian/

# pspawn_hook.dylib
cp $meridianDir/pspawn_hook/pspawn_hook.dylib $baseDir/meridian

# libjailbreak.dylib
cp $meridianDir/libjailbreak/libjailbreak.dylib $baseDir/usr/lib

# jailbreakd
cp $meridianDir/jailbreakd/jailbreakd $baseDir/meridian/jailbreakd

# SBInject.dylib
cp $meridianDir/sbinject/SBInject.dylib $baseDir/usr/lib

# create tar archive
cd $baseDir
tar -cf meridian-base.tar ./*
mv meridian-base.tar $currDir
