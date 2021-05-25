#!/bin/sh

for filename in Resources/SVGs/*.svg; do
  [ -e "$filename" ] || continue
  base64 -i "$filename" -o "${filename}".base64  
done
