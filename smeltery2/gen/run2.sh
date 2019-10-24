#!/bin/bash
mcrl22lps -v "../smeltery2_spec.mcrl2" "smeltery2.lps"

rm -fR "out"
rm -fR "evidence"
mkdir "evidence"

(for f in "$@"; do
    echo "$f"
done) | parallel --will-cite -j $(nproc) --results "out/log_{}/" --timeout 3600 --progress "./gen2.sh"

sudo chmod -R 777 .

output_file="result.txt"
rm -f $output_file
for f in "$@"; do
    if "`out/log_$f/1/$f/stdout`"; then
        echo "$f"": true" >> $output_file
        rm -f "evidence/smeltery2_$f.evidence.lps"
    else
        echo "$f"": false" >> $output_file
        lps2lts "evidence/smeltery2_$f.evidence.lps" "evidence/smeltery2_$f.evidence.lts"
    fi
done
rm -f "smeltery2.lps"
less result.txt
