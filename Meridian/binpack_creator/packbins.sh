#!/bin/sh

currDir=$(dirname $0)

binCount=$(ls -1q  $currDir/bins | wc -l | sed -e 's/^[ `t]*//')

for file in $currDir/bins/*
do
  jtool --sign sha1 --inplace --ent $currDir/ent.plist $file
  chmod 0755 $file
done

cd $currDir
tar -cf bootstrap.tar ./bins/*

cp $currDir/bootstrap.tar $currDir/../Meridian/bootstrap.tar

rm $currDir/bootstrap.tar
