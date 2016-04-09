#!/bin/bash

mkdir -p output_edit/pep
mkdir -p output_edit/cds
mkdir -p output_edit/pal
mkdir -p output_edit/nal

cp output/x*/pep/* output_edit/pep/
cp output/x*/cds/* output_edit/cds/
cp output/x*/pal/* output_edit/pal/
cp output/x*/nal/* output_edit/nal/
