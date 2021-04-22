#!/usr/bin/env bash
libraryName=$1
libOutputPath=$2/$3
buildType=$3
publicHeaders=$4
echo ===============================================================

frameworkOutputPath="$libOutputPath/$libraryName.framework"

set -e
rm -rf "$frameworkOutputPath"
mkdir -p "$frameworkOutputPath/Versions/A/Headers"

# # Link the "Current" version to "A"
/bin/ln -sfh A "$frameworkOutputPath/Versions/Current"
/bin/ln -sfh Versions/Current/Headers "$frameworkOutputPath/Headers"
/bin/ln -sfh "Versions/Current/lib$1.a" "$frameworkOutputPath/$1"

# #copy 
/bin/mv "$libOutputPath/lib$1.a" "$frameworkOutputPath/Versions/A/"

while [ "${4}" != "" ]; do
 	fullfile="${4}"

  	filename=$(basename -- "$fullfile")

	cp $fullfile $frameworkOutputPath/Headers/$filename
	echo "#include \"$filename\"" >> $frameworkOutputPath/Headers/library.include.h

	shift
done;


