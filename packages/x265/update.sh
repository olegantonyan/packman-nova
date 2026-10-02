#!/bin/bash

rm -f x265_*.tar x265_*.tar.*z
osc service ra
version=$(grep ^Version x265.spec|awk '{print $2}')
echo "The new version is:" $version
api=$(tar xafO x265-${version}.tar x265-${version}/source/CMakeLists.txt|grep "set(X265_BUILD"|sed 's/^.* \([1-9][0-9]*\).*$/\1/')
echo "The new api version is:" $api
echo "libx265-${api}" > baselibs.conf
sed -i "
/^%define sover[[:blank:]]/c%define sover   ${api}
 /^%define uver[[:blank:]]/c%define uver    ${version//./_}
" x265.spec
