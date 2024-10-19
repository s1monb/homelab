#!/usr/bin/env bash

set -e

rm -rf infra/terraform/generated/clusters
mkdir -p infra/terraform/generated/clusters

for file in "$1"/*; do
  echo "Processing $file"

  if [ -f "$file" ]; then
    filename=$(basename $file)

    cue import "$file" -p clusters -o templates/clusters/clusters.cue -f || (echo "Failed importing. Exiting" && exit 1)
    cd templates/clusters || (echo "Directory not found. Exiting" && exit 1)
    cue cmd gen || (echo "Failed generating. Exiting" && exit 1)
    rm clusters.cue

    # Jump back to the root
    cd ../..

  fi
done
