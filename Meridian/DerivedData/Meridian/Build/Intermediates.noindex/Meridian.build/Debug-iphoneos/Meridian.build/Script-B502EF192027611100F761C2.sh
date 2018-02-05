#!/bin/sh
export THEOS=/opt/theos

cd $SRCROOT/sbinject
make
cp .theos/obj/debug/SBInject.dylib .

if [ -e .theos ]; then
  rm -r .theos
fi

if [ -e ./obj ]; then
  rm -r obj
fi

tar -cf SBInject.tar SBInject.dylib
#rm SBInject.dylib

mv SBInject.tar ../Meridian/
