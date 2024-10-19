#!/usr/bin/env bash

set -e

for file in $(find $1 -print | grep ".json"); do
  echo "Prettifying $file"
  jq . < $file > "$file.temp"
  rm $file
  mv "$file.temp" $file
done