currDir=$(dirname $0)

cd $currDir

xcrun -sdk iphoneos gcc -dynamiclib -arch arm64 -framework Foundation -o amfid_payload.dylib amfid_payload.m
jtool --sign sha1 --inplace amfid_payload.dylib
chmod 0755 amfid_payload.dylib

xcrun -sdk iphoneos gcc -arch arm64 -framework Foundation -o amfid_fucker amfid_fucker.m
jtool --sign sha1 --inplace --ent ent.plist amfid_fucker
chmod 0755 amfid_fucker

tar -cf amfid.tar amfid_fucker amfid_payload.dylib

rm amfid_payload.dylib
rm amfid_fucker

mv amfid.tar ../
