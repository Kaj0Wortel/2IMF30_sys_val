#!/bin/bash
set -x
lps2pbes -v --formula="../properties/$1.mcf" --counter-example "smeltery2.lps" "smeltery2_$1.pbes"
pbessolve -v --strategy=3 --rewriter='jittyc' --evidence-file="evidence/smeltery2_$1.evidence.lps" --search='depth-first' --file="smeltery2.lps" "smeltery2_$1.pbes"
rm -f "smeltery2_$1.pbes"
