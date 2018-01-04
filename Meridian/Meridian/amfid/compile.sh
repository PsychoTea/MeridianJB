currDir=$(dirname $0)

cd $currDir

xcrun -sdk iphoneos gcc -dynamiclib -arch arm64 -framework Foundation -o amfid_payload.dylib amfid_payload.m
jtool --sign sha1 --inplace amfid_payload.dylib
echo "Compiled amfid_payload.dylib"

echo "Compiled and signed all binaries!"
