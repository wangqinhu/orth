#!/bin/bash

#$ -t 1-2
#$ -cwd
#$ -N phy_edit_red
#$ -j y

data=("syn" "non")
id=${data[$(expr $SGE_TASK_ID - 1)]}
./phy_edit.pl output.grp2nal/nal data/red.$id.editfmt.txt output.red.$id > phy_edit.red.$id.txt
