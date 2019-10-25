#!/bin/bash
sudo chmod -R 777 .
mcrl22lps -v "../smeltery2_spec.mcrl2" "smeltery2.lps"

rm -fR "out"
rm -fR "evidence"
mkdir "evidence"

(for f in "$@"; do
    echo "$f"
done) | parallel --will-cite -j $(nproc) --results "out/log_{}/" --timeout 3600 --progress "./gen2.sh"

sudo chmod -R 777 .
sudo ./process_results.sh
