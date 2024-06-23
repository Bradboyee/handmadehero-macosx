
COMMON_FLAG=" -framework AppKit -framework AudioToolbox"

mkdir ../../build
pushd ../../build
clang -g -O0 -o handmade ../handmade/code/mac_handmade.mm  $COMMON_FLAG

#mkdir handmade.app
cp handmade handmade.app/handmade
cp ../handmade/resource/Info.plist handmade.app/Info.plist
popd
