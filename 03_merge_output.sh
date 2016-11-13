#!/bin/bash

mkdir logs
mv grp2nal.o* logs/

mkdir -p output.grp2nal/pep
mkdir -p output.grp2nal/cds
mkdir -p output.grp2nal/pal
mkdir -p output.grp2nal/nal

cp output.grp2nal.splitted/x*/pep/* output.grp2nal/pep/
cp output.grp2nal.splitted/x*/cds/* output.grp2nal/cds/
cp output.grp2nal.splitted/x*/pal/* output.grp2nal/pal/
cp output.grp2nal.splitted/x*/nal/* output.grp2nal/nal/
