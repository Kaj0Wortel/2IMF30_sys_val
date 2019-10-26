#!/bin/bash

i=0
for file in ../properties/*; do
    if [[ -f $file ]]; then
        file=$(echo $file | awk -F"/" '{ print $NF; }')
        FILES[$i]="${file}"
        ((i++))
    fi
done

./gen.sh ../smeltery2_spec.mcrl2 --verbose --force --no-backup --verify --num-cores 1 --input "${FILES[@]}"
