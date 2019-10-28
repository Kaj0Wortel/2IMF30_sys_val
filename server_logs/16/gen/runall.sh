#!/bin/bash
./run2.sh "$(ls -q '../properties' | cut -d'.' -f 1)"
