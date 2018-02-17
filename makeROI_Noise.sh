#!/bin/bash

########################################################################
# Creates an Anterior and Posterior ROI centered around user-supplied y-coordinates.  Used for SNR calculations.
# Input is an RPI-oriented motion-corrected RestingState EPI set.
########################################################################


Usage() {
	echo "Usage: makeROI_Noise <y-coordinate> <voxel smooth> <input EPI> <output name>"
	exit
}

[ "$1" = "" ] && Usage
[ "$2" = "" ] && Usage
[ "$3" = "" ] && Usage
[ "$4" = "" ] && Usage



# Set input/output images
inputImage=$3
outputImage=$4

# ROI is arbitrarily set to %age of xy voxel dimensions ($2)

fslmaths $inputImage -mul 0 -add 1 -roi 0 -1 ${1} 1 0 -1 0 1 $outputImage -odt float
fslmaths $outputImage -kernel sphere $2 -fmean $outputImage -odt float
fslmaths $outputImage -bin $outputImage
