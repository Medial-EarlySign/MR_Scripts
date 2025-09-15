#!/bin/bash

TARGET_FOLDER=${1-.}

find $TARGET_FOLDER -name *.html | while read file ; do
	#echo "$file"
	sed -i 's|"[^"]*plotly.min.js"|"W:\\Graph_Infra\\plotly-latest.min.js"|g' "$file"
done
