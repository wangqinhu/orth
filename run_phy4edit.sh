#!/bin/bash

#$ -t 1-3
#$ -cwd
#$ -N phy_edit
#$ -j y

data=("all" "syn" "non")
id=${data[$(expr $SGE_TASK_ID - 1)]}
./phy_edit.pl output_edit/nal data/fg.edit.$id.txt output.$id > phy.$id.txt
