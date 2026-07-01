#!/usr/bin/env bash

path="$1"

if [ "$path" = "/" ]; then
  echo "/"
  exit 0
fi

current=$(basename "$path")

parent_dir=$(dirname "$path")
parent=$(basename "$parent_dir")

if [ "$parent" = "/" ] || [ "$parent" = "." ]; then
  echo "${current:0:10}"
else
  echo "${parent:0:10}/${current:0:10}"
fi
