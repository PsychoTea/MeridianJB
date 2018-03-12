#!/bin/sh

# Install ldid for post-build fakesigning 
cd ~
git clone git://git.saurik.com/ldid.git
cd ldid
git submodule update --init
./make.sh
cp -f ./ldid /usr/bin/ldid
cd ..
rm -r ldid
