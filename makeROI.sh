#!/bin/bash

#to check how big the ROI is that you made, use fslstats with -V option, this gives you number of voxels in anatomical space
#using a 14mm diameter with this script will give you ~125 voxel ROI, which generally works well

Usage() {
	echo "Usage: makeROI <x y z> <mm or vox> <diameter of ROI (6, 10, 14, 18, 22mm)> <sphere or box> <output name>"
	exit
}

[ "$1" = "" ] && Usage
[ "$2" = "" ] && Usage
[ "$3" = "" ] && Usage
[ "$4" = "" ] && Usage
[ "$5" = "" ] && Usage
[ "$6" = "" ] && Usage
[ "$7" = "" ] && Usage

echo $1 $2 $3 $4 $5 $6 $7



#Assumes you are running this from the RestingState Scripts folder
myscriptdir=`perl -e 'use Cwd "abs_path";print abs_path(shift)'`
myROIdir=${myscriptdir}/ROIs
fslstdimage='MNI152_T1_2mm_brain'


if [ $4 = "vox" ]
then
	fslmaths ${FSLDIR}/data/standard/${fslstdimage} -roi ${1} 1 ${2} 1 ${3} 1 0 1 ${myROIdir}/${7}
	if [ $6 = "box" ]
	then
	fslmaths ${myROIdir}/${7} -kernel ${6} ${5} -fmean ${myROIdir}/${7} 
	fslmaths ${myROIdir}/${7} -bin ${myROIdir}/${7}
	fi

	if [ $6 = "sphere" ]
	then
	n1=`expr ${5} - 2`
	n2=`expr ${n1} / 2`
	fslmaths ${myROIdir}/${7} -kernel ${6} ${n2} -fmean ${myROIdir}/${7}
	fslmaths ${myROIdir}/${7} -bin ${myROIdir}/${7}
	fi

elif [ $4 = "mm" ]
then
	echo ${1} ${2} ${3} > ${myROIdir}/tmp.txt
	newvox=`std2imgcoord -img ${FSLDIR}/data/standard/${fslstdimage} -std ${FSLDIR}/data/standard/${fslstdimage} ${myROIdir}/tmp.txt -vox | head -1`
	echo $newvox > ${myROIdir}/tmp.txt
	newx=`cat ${myROIdir}/tmp.txt | cut -f1 -d " "`
	newy=`cat ${myROIdir}/tmp.txt | cut -f2 -d " "`
	newz=`cat ${myROIdir}/tmp.txt | cut -f3 -d " "`	
	echo "The voxel coordinates are: $newx $newy $newz"
	fslmaths ${FSLDIR}/data/standard/${fslstdimage} -roi ${newx} 1 ${newy} 1 ${newz} 1 0 1 ${myROIdir}/${7}

	if [ $6 = "box" ]
        then
        fslmaths ${myROIdir}/${7} -kernel ${6} ${5} -fmean ${myROIdir}/${7}
        fslmaths ${myROIdir}/${7} -bin ${myROIdir}/${7}
        fi

        if [ $6 = "sphere" ]
        then
        n1=`expr ${5} - 2`
        n2=`expr ${n1} / 2`
        fslmaths ${myROIdir}/${7} -kernel ${6} ${n2} -fmean ${myROIdir}/${7}
        fslmaths ${myROIdir}/${7} -bin ${myROIdir}/${7}
        fi

	rm -r ${myROIdir}/tmp.txt
fi
echo "Finished!"

