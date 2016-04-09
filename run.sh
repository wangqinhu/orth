#!/bin/bash

#$ -t 1-263
#$ -cwd
#$ -N grp2nal
#$ -j y

grp=("xaa" "xab" "xac" "xad" "xae" "xaf" "xag" "xah" "xai" "xaj" "xak" "xal" "xam" "xan" "xao" "xap" "xaq" "xar" "xas" "xat" "xau" "xav" "xaw" "xax" "xay" "xaz" "xba" "xbb" "xbc" "xbd" "xbe" "xbf" "xbg" "xbh" "xbi" "xbj" "xbk" "xbl" "xbm" "xbn" "xbo" "xbp" "xbq" "xbr" "xbs" "xbt" "xbu" "xbv" "xbw" "xbx" "xby" "xbz" "xca" "xcb" "xcc" "xcd" "xce" "xcf" "xcg" "xch" "xci" "xcj" "xck" "xcl" "xcm" "xcn" "xco" "xcp" "xcq" "xcr" "xcs" "xct" "xcu" "xcv" "xcw" "xcx" "xcy" "xcz" "xda" "xdb" "xdc" "xdd" "xde" "xdf" "xdg" "xdh" "xdi" "xdj" "xdk" "xdl" "xdm" "xdn" "xdo" "xdp" "xdq" "xdr" "xds" "xdt" "xdu" "xdv" "xdw" "xdx" "xdy" "xdz" "xea" "xeb" "xec" "xed" "xee" "xef" "xeg" "xeh" "xei" "xej" "xek" "xel" "xem" "xen" "xeo" "xep" "xeq" "xer" "xes" "xet" "xeu" "xev" "xew" "xex" "xey" "xez" "xfa" "xfb" "xfc" "xfd" "xfe" "xff" "xfg" "xfh" "xfi" "xfj" "xfk" "xfl" "xfm" "xfn" "xfo" "xfp" "xfq" "xfr" "xfs" "xft" "xfu" "xfv" "xfw" "xfx" "xfy" "xfz" "xga" "xgb" "xgc" "xgd" "xge" "xgf" "xgg" "xgh" "xgi" "xgj" "xgk" "xgl" "xgm" "xgn" "xgo" "xgp" "xgq" "xgr" "xgs" "xgt" "xgu" "xgv" "xgw" "xgx" "xgy" "xgz" "xha" "xhb" "xhc" "xhd" "xhe" "xhf" "xhg" "xhh" "xhi" "xhj" "xhk" "xhl" "xhm" "xhn" "xho" "xhp" "xhq" "xhr" "xhs" "xht" "xhu" "xhv" "xhw" "xhx" "xhy" "xhz" "xia" "xib" "xic" "xid" "xie" "xif" "xig" "xih" "xii" "xij" "xik" "xil" "xim" "xin" "xio" "xip" "xiq" "xir" "xis" "xit" "xiu" "xiv" "xiw" "xix" "xiy" "xiz" "xja" "xjb" "xjc" "xjd" "xje" "xjf" "xjg" "xjh" "xji" "xjj" "xjk" "xjl" "xjm" "xjn" "xjo" "xjp" "xjq" "xjr" "xjs" "xjt" "xju" "xjv" "xjw" "xjx" "xjy" "xjz" "xka" "xkb" "xkc")
id=${grp[$(expr $SGE_TASK_ID - 1)]}

if [ -e data/$id ]; then
	./group2nal.pl data/$id output/$id
fi
