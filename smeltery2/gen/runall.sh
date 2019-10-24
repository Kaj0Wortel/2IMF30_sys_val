#!/bin/bash
echo "$(ls -bq '../properties' | cut -d'.' -f 1)"
#./run2.sh "$(ls '../properties' | cut -d'.' -f 1)"
