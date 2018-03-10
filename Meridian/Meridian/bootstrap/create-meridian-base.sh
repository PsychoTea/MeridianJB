#!/bin/bash

currDir=$(dirname $0)
meridianDir=$currDir/../..
baseDir=$currDir/meridian-base

# amfid (fucker & payload)
#mv $meridianDir/amfid/bin/* $baseDir/meridian/amfid

# injector
#mv $meridianDir/injector/bin/* $baseDir/meridian/

# pspawn_hook.dylib
#mv $meridianDir/pspawn_hook/bin/* $baseDir/meridian

# libjailbreak.dylib
#mv $meridianDir/libjailbreak/bin/* $baseDir/usr/lib

# jailbreakd
#mv $meridianDir/jailbreakd/bin/* $baseDir/meridian/jailbreakd

# TweakLoader.dylib
#mv $meridianDir/TweakLoader/bin/* $baseDir/usr/lib

# remove all .DS_Store files
find $baseDir -name '.DS_Store' -delete

# create tar archive
cd $baseDir
tar -cf meridian-base.tar ./*
mv meridian-base.tar $currDir
