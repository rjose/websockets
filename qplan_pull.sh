#!/bin/zsh

cat source.ini | gcat.py | tee data.txt | qplan_condition.awk | \
        tee conditioned_data.txt | qplan_updater.lua
