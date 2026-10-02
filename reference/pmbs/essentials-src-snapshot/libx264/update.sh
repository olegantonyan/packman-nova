#!/bin/sh

rm -rf x264
git clone -b stable https://code.videolan.org/videolan/x264.git
api="$(grep '#define X264_BUILD' < x264/x264.h | sed 's/^.* \([1-9][0-9]*\).*$/\1/')"
rev="$(git --git-dir=x264/.git rev-list HEAD --max-count=1)"
echo "The new api version is:" $api
echo "libx264-$api" > baselibs.conf
sed -i "/^%define soname/c%define sover   $api" libx264.spec
sed -i "
	/revision/s/>.*</>${rev}</
	/versionformat/s/>.*</>%cd.%h</
" _service
osc service disabledrun
