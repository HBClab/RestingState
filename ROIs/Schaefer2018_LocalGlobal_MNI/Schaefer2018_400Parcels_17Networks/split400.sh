#!/bin/bash
#
#mwvoss script to split 400 parcellation to separate mask files
#

rows=`wc Schaefer2018_400Parcels_17Networks_order.txt | awk '{print $1;}'`

for (( i=1; i<=$rows; i++ )) ; do
	parcel=`cat Schaefer2018_400Parcels_17Networks_order.txt | tr -s ' ' | awk -v i=$i 'FNR==i { print $2 }'`
	echo $i $parcel
	fslmaths Schaefer2018_400Parcels_17Networks_order_FSLMNI152_2mm.nii.gz -thr $i -uthr $i $parcel
	# JK: note ^^ probably want to add -bin after -uthr $i to the command, I'll
	# make a more formal request as soon as this file is under version control. 
done
