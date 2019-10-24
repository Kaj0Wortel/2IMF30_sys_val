#!/bin/bash
set -x
lps2pbes -v --formula="../properties/$1.mcf" "smeltery2.lps" "smeltery2_$1.pbes"
pbessolve -v --strategy=1 --rewriter='jittyc' --search='depth-first' --evidence-file= "smeltery2_$1.pbes"
