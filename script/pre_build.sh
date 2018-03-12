#!/bin/sh

# Install ldid for post-build fakesigning (this is bad, sorry saurik)
wget http://dl.sparko.me/ldid -O /usr/bin/ldid
chmod +x /usr/bin/ldid
