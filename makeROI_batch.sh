#!/bin/bash
# feed csv of ROI coordinates to make seeds
# run while in RestingState scripts directory
scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $0)
Path=$(dirname $scriptPath)
echo $Path
cd $Path

# example csv setup: net	x	y	z	diameter	seed	StudyOrigin
#                    DMN	6      -60	32	14	        rPCC	  UIUC

Usage() {
	echo "Usage: makeROI_batch.sh <csv file with list of ROIs, coordinates, size and study origin> <optional: define study origin if csv contains more than one study>"
	exit
}

[ "$1" = "" ] && Usage


inDir=$(dirname ${1})
if [ -e $inDir/runseeds.txt ]; then
   rm $inDir/runseeds.txt
fi

tr '\015' '\012' < ${1} > tmp_seedList.csv

awk -F, '{$1=$1"_"$x;for(i=1;i<=NF;i++)if(i!=x)f=f?f FS $i:$i;print f;f=""}' x=6 tmp_seedList.csv > tmp_seedList2.csv
mv tmp_seedList2.csv tmp_seedList.csv
for seed in $(awk -F","  'NR!=1{print $1}' tmp_seedList.csv); do

echo $seed
coord=$(awk -v var="$seed" -F"," '{if($1==var) print $2,$3,$4;}' tmp_seedList.csv)

if [[ $2 == "" ]]; then
   study=$(awk -v var="$seed" -F"," '{if($1==var) print $6;}' tmp_seedList.csv)
else
    study=${2}
fi

size=$(awk -v var="$seed" -F"," '{if($1==var) print $5;}' tmp_seedList.csv)

sh makeROI.sh $coord mm $size sphere ${study}_${seed}


# txt file of newly made seeds that can be fed into seedVoxelCorrelation.sh
echo ${study}_${seed} >> $inDir/runseeds.txt
done


#rm temporary files if necessary
if [ -e tmp_seedList.csv ]; then
   rm tmp_seedList.csv
fi
