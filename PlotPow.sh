#!/bin/bash
#
# Script:   PlotPow.sh
# Purpose:  Plot the average powerspectrum over voxels
# Author:   T. Nichols
# Version: $Id: PlotPow.sh,v 1.4 2012/03/26 18:51:52 nichols Exp $
#


###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null
TmpDir=/tmp
Tmp=$TmpDir/`basename $0`-${$}-
trap CleanUp INT

###############################################################################
#
# Functions
#
###############################################################################

Usage() {
cat <<EOF
Usage: `basename $0` [options] 4Dimage mask PlotNm

Within mask voxels, computes power spectrum at each point in 4Dimage, creating a
plot in file PlotNm.png.  Image is always demeaned before computing the powerspectrum; 
it can optionally be variance-standardized over space (see -std below)

If mask is an integer, it is take to be the threshold applied to the mean image used
to create a mask.

Options
   -std      Standardize each voxel to have unit variance first.
   -tr <tr>  Specify TR, so plots have units of Hz instead of 1/TR
   -detrend  Remove linear trends from each voxel
   -highpass Apply standard FEAT high pass filtering (TR must be set) 
_________________________________________________________________________
\$Id: PlotPow.sh,v 1.4 2012/03/26 18:51:52 nichols Exp $
EOF
exit
}

CleanUp () {
    /bin/rm -f ${Tmp}*
    exit 0
}


###############################################################################
#
# Parse arguments
#
###############################################################################

TR=1
Units=""
while (( $# > 1 )) ; do
    case "$1" in
        "-help")
            Usage
            ;;
        "-std")
            shift
            VarNorm=1
            ;;
        "-tr")
            shift
            TR="$1"
	    Units=" (Hz)"
	    shift
            ;;
        "-detrend")
            shift
            Detrend=1
            ;;
        "-highpass")
            shift
            HighPass=1
            ;;
        -*)
            echo "ERROR: Unknown option '$1'"
            exit 1
            break
            ;;
        *)
            break
            ;;
    esac
done
Tmp=$TmpDir/f2r-${$}-

if (( $# < 1 || $# > 3 )) ; then
    Usage
fi

Img="$1"
Mask="$2"
Plot="$3"

Nvol=$(fslnvols "$Img")

###############################################################################
#
# Script Body
#
###############################################################################

# Compute mean
fslmaths "$Img" -Tmean $Tmp-mean -odt float

# Create a mask on the fly?
if [[ "$Mask" =~ ^[0-9]*$ ]] ; then
    fslmaths "$Img" -thr "$Mask" -bin $Tmp-mask
    Mask=$Tmp-mask
fi

# Detrend ?
if [ "$Detrend" = "1" ] ; then
    touch $Tmp-reg
    for ((i=1;i<=Nvol;i++)) ; do 
	echo $i >> $Tmp-reg
    done
    fsl_glm -i "$Img" -d $Tmp-reg --out_res=$Tmp-Detrend -m $Mask --demean
    Img=$Tmp-Detrend
fi

# High pass?
if [ "$HighPass" = "1" ] ; then
    HPsigma=$(echo 100/2/$TR | bc -l)
    fslmaths "$Img" -bptf "$HPsigma" -1 $Tmp-HPf
    Img=$Tmp-HPf
fi

# Center and possibly variance normalize 
if [ "$VolNorm" = "1" ] ; then
    fslmaths "$Img" -Tstd $Tmp-sd -odt float
    fslmaths "$Img" -sub $Tmp-mean -div $Tmp-sd -mas "$Mask" $Tmp-img -odt float 
else
    fslmaths "$Img" -sub $Tmp-mean              -mas "$Mask" $Tmp-img -odt float 
fi

# Compute power spectrum... the slow part
fslpspec $Tmp-img  $Tmp-pspec

# Make the plot
fslmeants -i $Tmp-pspec -m $Tmp-mean -o "$Plot".txt
Len=$(cat "$Plot".txt | wc -l )
Nyq=$(echo "0.5/$TR/$Len" | bc -l);
fsl_tsplot -i "$Plot".txt -u $Nyq -t "$(basename $Plot)" -y "Power" -x "Frequency$Units" -o "$Plot".png


###############################################################################
#
# Exit & Clean up
#
###############################################################################

CleanUp