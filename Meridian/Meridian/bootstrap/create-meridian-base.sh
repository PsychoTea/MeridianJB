#!/bin/bash

currDir=$(dirname $0)
meridianDir=$currDir/../..
baseDir=$currDir/meridian-base

# amfid (fucker & payload)
cp $meridianDir/amfid/bin/* $baseDir/meridian/amfid

# injector
cp $meridianDir/injector/bin/* $baseDir/meridian/

# pspawn_hook.dylib
cp $meridianDir/pspawn_hook/bin/* $baseDir/meridian

# jailbreakd
cp $meridianDir/jailbreakd/bin/* $baseDir/meridian/jailbreakd

# TweakLoader.dylib
cp $meridianDir/TweakLoader/.theos/obj/debug/*.dylib $baseDir/usr/lib

# remove all .DS_Store files
find $baseDir -name '.DS_Store' -delete

# create tar archive
cd $baseDir
tar -cf meridian-base.tar ./*
mv meridian-base.tar $currDir
