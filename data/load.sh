#!/bin/bash

if [ $# -ne 1 ]; then
        echo "Usage: load.sh <version-number>"
fi

gawk -f workify.awk input.txt > work$1.txt
gawk -f planify.awk work$1.txt > plan$1.txt
