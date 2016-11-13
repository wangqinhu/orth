#!/bin/bash

#$ -t 1-2
#$ -cwd
#$ -N phy_edit_rnd
#$ -j y

data=("syn" "non")
id=${data[$(expr $SGE_TASK_ID - 1)]}
./phy_edit.pl output.grp2nal/nal data/rnd.$id.editfmt.txt output.rnd.$id > phy_edit.rnd.$id.txt
