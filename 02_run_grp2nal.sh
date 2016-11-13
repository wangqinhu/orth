#!/bin/bash

#$ -t 1-166
#$ -cwd
#$ -N grp2nal
#$ -j y

grp=("xaa" "xab" "xac" "xad" "xae" "xaf" "xag" "xah" "xai" "xaj" "xak" "xal" "xam" "xan" "xao" "xap" "xaq" "xar" "xas" "xat" "xau" "xav" "xaw" "xax" "xay" "xaz" "xba" "xbb" "xbc" "xbd" "xbe" "xbf" "xbg" "xbh" "xbi" "xbj" "xbk" "xbl" "xbm" "xbn" "xbo" "xbp" "xbq" "xbr" "xbs" "xbt" "xbu" "xbv" "xbw" "xbx" "xby" "xbz" "xca" "xcb" "xcc" "xcd" "xce" "xcf" "xcg" "xch" "xci" "xcj" "xck" "xcl" "xcm" "xcn" "xco" "xcp" "xcq" "xcr" "xcs" "xct" "xcu" "xcv" "xcw" "xcx" "xcy" "xcz" "xda" "xdb" "xdc" "xdd" "xde" "xdf" "xdg" "xdh" "xdi" "xdj" "xdk" "xdl" "xdm" "xdn" "xdo" "xdp" "xdq" "xdr" "xds" "xdt" "xdu" "xdv" "xdw" "xdx" "xdy" "xdz" "xea" "xeb" "xec" "xed" "xee" "xef" "xeg" "xeh" "xei" "xej" "xek" "xel" "xem" "xen" "xeo" "xep" "xeq" "xer" "xes" "xet" "xeu" "xev" "xew" "xex" "xey" "xez" "xfa" "xfb" "xfc" "xfd" "xfe" "xff" "xfg" "xfh" "xfi" "xfj" "xfk" "xfl" "xfm" "xfn" "xfo" "xfp" "xfq" "xfr" "xfs" "xft" "xfu" "xfv" "xfw" "xfx" "xfy" "xfz" "xga" "xgb" "xgc" "xgd" "xge" "xgf" "xgg" "xgh" "xgi" "xgj")
id=${grp[$(expr $SGE_TASK_ID - 1)]}

if [ -e data/split/$id ]; then
	./group2nal_nc.pl data/split/$id output.grp2nal.splitted/$id
fi
