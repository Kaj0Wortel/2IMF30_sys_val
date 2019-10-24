#!/bin/bash
mcrl22lps -v "../smeltery2_spec.mcrl2" "smeltery2.lps"

(for f in "$@"; do
    echo "$f"
done) | parallel --will-cite -j $(nproc) --results "log_{}/" --timeout 3600 --progress "./gen2.sh"
