#!/bin/bash

split -l 100 data/groups.txt
mkdir -p data/split
mv x* data/split/
