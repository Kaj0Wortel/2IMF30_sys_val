#!/bin/bash
./run2.sh "$(ls -bq '../properties' | cut -d'.' -f 1)"
