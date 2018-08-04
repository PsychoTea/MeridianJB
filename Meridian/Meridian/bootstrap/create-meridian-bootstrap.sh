#!/bin/bash

currDir=$(dirname $0)
meridianDir=$currDir/../..
baseDir=$currDir/meridian-bootstrap

# amfid_payload.dylib 
cp $meridianDir/amfid/bin/* $baseDir/meridian/

# pspawn_hook.dylib
cp $meridianDir/pspawn_hook/bin/* $baseDir/usr/lib/

# jailbreakd
cp $meridianDir/jailbreakd/bin/* $baseDir/meridian/jailbreakd/

# remove all .DS_Store files
find $baseDir -name '.DS_Store' -delete

# create tar archive
cd $baseDir
COPYFILE_DISABLE=1 tar -cf meridian-bootstrap.tar ./*
mv meridian-bootstrap.tar $currDir
