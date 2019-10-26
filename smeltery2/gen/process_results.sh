#!/bin/bash

output_file="result.txt"
rm -f $output_file
for f in ../properties/*; do
    f="${f//.mcf/''}"
    f="${f//..\/properties\//''}"
    file="out/log_""$f""/1/""$f""/stdout"
    if [[ ! -f "$file" ]]; then
        echo "error: $f" >> $output_file
    else
        result=$(cat "$file")
        if [[ $result == "true" ]]; then
            echo "true : $f" >> $output_file
            #rm -f "evidence/smeltery2_$f.evidence.lps"
        else
            echo "false: $f" >> $output_file
            lps2lts "evidence/smeltery2_$f.evidence.lps" "evidence/smeltery2_$f.evidence.lts"
        fi
    fi
done
less result.txt
rm -f "smeltery2.lps"
