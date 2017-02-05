#!/bin/bash

##################################################################################################################
# Motion Correction and Other inital processing for Resting State Analysis
#     1. Motion Correction		
#     2. SNR Estimation
#     4. Spike Detection
#     5. Registration
#       a. T1 to MNI (flirt/fnirt), with/without lesion mask optimization
#       b. EPI to T1 (BBR), with/without FieldMap correction
##################################################################################################################
#Commenting out code I want to remove (RM)
#(RM)scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
#(RM)scriptDir=`dirname $scriptPath`




#clobber default
clob=false
# Parse Command line arguments
while getopts “hE:A:a:l:fb:v:x:D:d:o:m:c” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    A)
      T1_brain=$OPTARG
      ;;
    a)
      T1_head=$OPTARG
      ;;
    m)
      T1_mask=$OPTARG
      ;;
    o)
      outDir=$OPTARG
      ;;
    l)
      #lesionMask=$OPTARG
      lesionMaskFlag=1
      ;;
    f)
      fieldMapFlag=1
      ;;
    b)
      fieldMap=$OPTARG
      ;;
    v)
      fieldMapMagHead=$OPTARG
      ;;
    x)
      fieldMapMagBrain=$OPTARG
      ;;
    D)
      dwellTime=$OPTARG
      ;;
    d)
      peDir=$OPTARG
      ;;
    c)
      clob=true
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done
#############################   HELPER FUNCTIONS   #############################
function printCommandLine {
  echo "Usage: qualityCheck.sh -E restingStateImage -a T1Image -A T1SkullImage -l lesionMask -f -b fieldMapPrepped -v fieldMapMagSkull -x fieldMapMag -D 0.00056 -d PhaseEncDir -c"
  echo ""
  echo "   where:"
  echo "   -E Resting State file"
  echo "   -A T1 file"
  echo "   -a T1 (with skull) file"
  echo "   -o subject base(output) directory"
  echo "     *Both EPI and T1 (with and without skull) should be from output of dataPrep script"
  echo "   -m T1 brain mask"
  echo "   -l Binary lesion mask"
  echo "   -f (fieldMap registration correction)"
  echo "   -b fieldMapPrepped (B0 correction image from dataPrep/fsl_prepare_fieldmap)"
  echo "   -v fieldMapMagSkull (FieldMap Magnitude image, with skull (from dataPrep))"
  echo "   -x fieldMapMag (FieldMap Magnitude image, skull-stripped (from dataPrep))"
  echo "   -D dwell time (in seconds)"
  echo "       *dwell time is from the EPI but is only set if FieldMap correction ('-f') is chosen."
  echo "       *If not set and FieldMap correction is flagged ('-f'), default is 0.00056"
  echo "   -d Phase Encoding Direction (from dataPrep)"
  echo "       *Options are x/y/z/-x/-y/-z"
  echo "   -c clobber/overwrite previous results"
  exit 1
}


##################
#function: clobber
##################
#purpose: checks to see if files exist and overwrites them when clob is set to true
##################
#input: any number of filenames that may or may not exist
##################
#output: a 1 (false) or 0 (true)
##################
#dependencies: None
##################
#Used in: (almost) Everything
##################
function clobber() 
{
#Tracking Variables
local -i num_existing_files=0
local -i num_args=$#

#Tally all existing outputs
for arg in $@; do
if [ -e "${arg}" ] && [ "${clob}" == true ]; then
rm -rf "${arg}"
elif [ -e "${arg}" ] && [ "${clob}" == false ]; then
num_existing_files=$(( ${num_existing_files} + 1 ))
continue
elif [ ! -e "${arg}" ]; then
continue
else
echo "How did you get here?"
fi
done

#see if the command should be run by seeing if the requisite files exist.
#0=true
#1=false
if [ ${num_existing_files} -lt ${num_args} ]; then
return 0
else
return 1
fi

#example usage
#clobber test.nii.gz &&\
#fslmaths input.nii.gz -mul 10 test.nii.gz
}


##################
#function: RPI_orient
##################
#purpose: Checks to see if input is in R->L,P->A,I->S orientation, and switches the image around if it isn't
##################
#input: a 3d nifti image
##################
#output: a 3d nifti image in RPI orientation
##################
#dependencies: FSL
##################
#Used in: lesionMaskprep
##################
function RPI_orient() {
    #JK: probably overkill to check the variable was set without error.
    local infile=$1 &&\
    #-z tests if a string is null, so what I'm saying here is:
    #if the variable ${infile} is not an empty string (return 0) then don't run the following command
    #if the variable ${infile} is an empty string (return 1), then do run the next command.
    [ ! -z  "${infile}" ] ||\
    #I used () brackets, but should be {} I believe.
    { printf '%s\n' "${FUNCNAME[0]}, input not defined" && return 1 ;}

    #Determine qform-orientation to properly reorient file to RPI (MNI) orientation
  xorient=`fslhd ${infile} | grep "^qform_xorient" | awk '{print $2}' | cut -c1`
  yorient=`fslhd ${infile} | grep "^qform_yorient" | awk '{print $2}' | cut -c1`
  zorient=`fslhd ${infile} | grep "^qform_zorient" | awk '{print $2}' | cut -c1`

  native_orient=${xorient}${yorient}${zorient}

  echo "native orientation = ${native_orient}"

  if [ "${native_orient}" != "RPI" ]; then #setting flip flags if native orientaiton is not already RPI

    case ${native_orient} in

    #L PA IS
    LPI)
      flipFlag="-x y z"
      ;;
    LPS)
      flipFlag="-x y -z"
          ;;
    LAI)
      flipFlag="-x -y z"
          ;;
    LAS)
      flipFlag="-x -y -z"
          ;;

    #R PA IS
    RPS)
      flipFlag="x y -z"
          ;;
    RAI)
      flipFlag="x -y z"
          ;;
    RAS)
      flipFlag="x -y -z"
          ;;

    #L IS PA
    LIP)
      flipFlag="-x z y"
          ;;
    LIA)
      flipFlag="-x -z y"
          ;;
    LSP)
      flipFlag="-x z -y"
          ;;
    LSA)
      flipFlag="-x -z -y"
          ;;

    #R IS PA
    RIP)
      flipFlag="x z y"
          ;;
    RIA)
      flipFlag="x -z y"
          ;;
    RSP)
      flipFlag="x z -y"
          ;;
    RSA)
      flipFlag="x -z -y"
          ;;

    #P IS LR
    PIL)
      flipFlag="-z x y"
          ;;
    PIR)
      flipFlag="z x y"
          ;;
    PSL)
      flipFlag="-z x -y"
          ;;
    PSR)
      flipFlag="z x -y"
          ;;

    #A IS LR
    AIL)
      flipFlag="-z -x y"
          ;;
    AIR)
      flipFlag="z -x y"
          ;;
    ASL)
      flipFlag="-z -x -y"
          ;;
    ASR)
      flipFlag="z -x -y"
          ;;

    #P LR IS
    PLI)
      flipFlag="-y x z"
          ;;
    PLS)
      flipFlag="-y x -z"
          ;;
    PRI)
      flipFlag="y x z"
          ;;
    PRS)
      flipFlag="y x -z"
          ;;

    #A LR IS
    ALI)
      flipFlag="-y -x z"
          ;;
    ALS)
      flipFlag="-y -x -z"
          ;;
    ARI)
      flipFlag="y -x z"
          ;;
    ARS)
      flipFlag="y -x -z"
          ;;

    #I LR PA
    ILP)
      flipFlag="-y z x"
          ;;
    ILA)
      flipFlag="-y -z x"
          ;;
    IRP)
      flipFlag="y z x"
          ;;
    IRA)
      flipFlag="y -z x"
          ;;

    #S LR PA
    SLP)
      flipFlag="-y z -x"
          ;;
    SLA)
      flipFlag="-y -z -x"
          ;;
    SRP)
      flipFlag="y z -x"
          ;;
    SRA)
      flipFlag="y -z -x"
          ;;

    #I PA LR
    IPL)
      flipFlag="-z y x"
          ;;
    IPR)
      flipFlag="z y x"
          ;;
    IAL)
      flipFlag="-z -y x"
          ;;
    IAR)
      flipFlag="z -y x"
          ;;

    #S PA LR
    SPL)
      flipFlag="-z y -x"
          ;;
    SPR)
      flipFlag="z y -x"
          ;;
    SAL)
      flipFlag="-z -y -x"
          ;;
    SAR)
      flipFlag="z -y -x"
          ;;
    esac

    echo "flipping by ${flipFlag}"

    #Reorienting image and checking for warning messages
    local warnFlag=`fslswapdim ${infile} ${flipFlag} ${infile%.nii.gz}_RPI.nii.gz`
    local warnFlagCut=`echo ${warnFlag} | awk -F":" '{print $1}'`

    #Reorienting the file may require swapping out the flag orientation to match the .img block
    if [[ $warnFlagCut == "WARNING" ]]; then
    fslorient -swaporient ${infile%.nii.gz}_RPI.nii.gz
    fi

  else

    echo "No need to reorient.  Dataset already in RPI orientation."

    if [ ! -e ${infile%.nii.gz}_RPI.nii.gz ]; then

      cp ${infile} ${infile%.nii.gz}_RPI.nii.gz

    fi

  fi
}


##################
#function: lesionMaskPrep
##################
#purpose: reorients the lesion mask and inverts the mask
##################
#preconditions: Already ran dataPrep.sh
##################
#input (typical):	 lesionMask (from option -m)
#					 ${outDir} (from option -o)
##################
#output: 			 ${outDir}/func/T1forWarp
#					 ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz
#					 ${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz
#					 ${outDir}/func/T1forWarp/LesionWeight.nii.gz
##################
#dependencies: FSL, RPI_Orient, clobber
##################
#Used in: T1ToStd
##################

function lesionMaskPrep()
{
  local lesionMask=$1
  local outDir=$2

  printf "%s\n" "...Prepping the Lesion Mask"

  mkdir -p ${outDir}/func/T1forWarp ||\
  { printf "%s\n" "creation of directory T1forWarp failed, exiting ${FUNCNAME}" && return 1; }

  #Create a temporaray binary lesion mask (in case it's not char, binary format)
  clobber ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz &&\
  { fslmaths ${lesionMask} -bin ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz -odt char ||\
  { printf "%s\n" "creation of ${outDir}/func/T1forWarp/T1_mask.nii.gz failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Orient lesion mask to RPI
  clobber ${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz &&\
  { RPI_Orient ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz ||\
  { printf "%s\n" "creation of ${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz failed, exiting ${FUNCNAME}" && return 1 ;} ;}


  #Invert the lesion mask
  clobber ${outDir}/func/T1forWarp/LesionWeight.nii.gz &&\
  { fslmaths ${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz -mul -1 -add 1 -thr 0.5 -bin ${outDir}/func/T1forWarp/LesionWeight.nii.gz ||\
  { printf "%s\n" "creation of ${outDir}/func/T1forWarp/LesionWeight.nii.gz failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} completed successfully"
}

##################
#function: EPItoT1FieldMap
##################
#purpose: makes the transform from the motion corrected EPI to the T1 (with fieldmap corrections).
##################
#preconditions: dataPrep.sh, motion_correction, tissueSeg
##################
#input (typical):	 ${outDir}/func/mc/mcImgMean.nii.gz (from motion_correct)
#					 T1_brain (from option -A)
#					 T1_head (from option -a)
#					 T1_mask (from option -m)
#					 outDir (from option -o)
#					 #Additional Arguments from Fieldmap data
#					 fieldmapFlag (0 or 1) (from option -f)
#					 fieldmap (from option -b)
#					 fieldmapMagHead (from option -v)
#					 fieldmapMagBrain (from option -x)
#					 dwelltime (from option -D or default)
#					 peDir (from option -d or default)
##################
#output: 			 ${outDir}/func/EPItoT1/EPItoT1_warp.nii.gz
#					 ${outDir}/func/EPItoT1/T1toEPI.mat
#					 ${outDir}/func/EPItoT1/T1toEPI_warp.nii.gz
#					 ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz
#					 ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz
#					 ${outDir}/func/EPItoT1/EPIstrippedtoT1.nii.gz
#					 ${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz
#					 ${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz
#					 ${outDir}/func/EPItoT1/EPItoMNI.nii.gz
##################
#dependencies: FSL, clobber
##################
#Used in: EPItoT1Master
##################
function EPItoT1FieldMap()
{
  #basic args (without fieldmap)
  local mcImgMean=$1
  local T1_brain=$2
  local T1_head=$3
  local T1_mask=$4
  local outDir=$5
  #additional arguments for fieldmap processing
  local fieldmap=$6
  local fieldmapMagHead=$7
  local fieldmapMagBrain=$8
  local dwellTime=$9
  local peDir=$10

  printf "%s\n" "......Registration With FieldMap Correction."

  #Warp using FieldMap correction
  #Output will be a (warp) .nii.gz file
  #epi_reg --epi=${indir}/mcImgMean.nii.gz --t1=${t1SkullData} --t1brain=${t1Data} --wmseg=$epiWarpDir/T1_MNI_brain_wmseg.nii.gz --out=$epiWarpDir/EPItoT1 --fmap=${fieldMap} --fmapmag=${fieldMapMagSkull} --fmapmagbrain=${fieldMapMag} --echospacing=${dwellTime} --pedir=${peDir}

  clobber ${outDir}/func/EPItoT1/EPItoT1_warp.nii.gz &&\
  { epi_reg --epi=${mcImgMean} \
  --t1=${T1_head} \
  --t1brain=${T1_brain} \
  --wmseg=${outDir}/func/T1forWarp/T1_MNI_brain_wmseg.nii.gz \
  --out=${outDir}/func/EPItoT1/EPItoT1 \
  --fmap=${fieldMap} \
  --fmapmag=${fieldMapMagHead} \
  --fmapmagbrain=${fieldMapMagBrain} \
  --echospacing=${dwellTime} \
  --pedir=${peDir} --noclean ||\
  { printf "%s\n" "epi_reg failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the affine registration (to get T1toEPI)
  clobber ${outDir}/func/EPItoT1/T1toEPI.mat &&\
  { convert_xfm -omat ${outDir}/func/EPItoT1/T1toEPI.mat -inverse ${outDir}/func/EPItoT1/EPItoT1.mat ||\
  { printf "%s\n" "convert_xfm failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the nonlinear warp (to get T1toEPI)
  clobber ${outDir}/func/EPItoT1/T1toEPI_warp.nii.gz &&\
  { invwarp -w ${outDir}/func/EPItoT1/EPItoT1_warp.nii.gz -r ${mcImgMean} -o ${outDir}/func/EPItoT1/T1toEPI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the inverted (T1toEPI) warp to the brain mask
  clobber ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz &&\
  { applywarp --ref=${mcImgMean} --in=${T1_mask} --out=${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz --warp=${outDir}/func/EPItoT1/T1toEPI_warp.nii.gz --datatype=char --interp=nn ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

   #Create a stripped version of the EPI (mcImg) file, apply the warp
  clobber ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz &&\
  { fslmaths ${mcImgMean} -mas ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz ||\
  { printf "%s\n" "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${outDir}/func/EPItoT1/EPIstrippedtoT1.nii.gz &&\
  { applywarp --ref=${T1_brain} --in=${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz --out=${outDir}/func/EPItoT1/EPIstrippedtoT1.nii.gz --warp=${outDir}/func/EPItoT1/EPItoT1_warp.nii.gz ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the second nonlinear warp (T1toEPI_warp.nii.gz) to get a warp from MNI to EPI
  clobber ${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz &&\
  { convertwarp \
  --ref=${epiDir}/mcImgMean.nii.gz \
  --warp1=${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz \
  --warp2=${outDir}/func/EPItoT1//T1toEPI_warp.nii.gz \
  --out=${epiWarpDir}/MNItoEPI_warp.nii.gz --relout ||\
  { printf "%s\n" "convertwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the warp to get EPItoMNI_warp.nii.gz
  clobber ${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz &&\
  { invwarp -w ${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz -r $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz -o ${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply EPItoMNI warp to EPI file
  clobber ${outDir}/func/EPItoT1/EPItoMNI.nii.gz &&\
  { applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz --out=${outDir}/func/EPItoT1/EPItoMNI.nii.gz --warp=${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n ${FUNCNAME} successful" && return 0
}

##################
#function: EPItoT1
##################
#purpose: makes the transform from the motion corrected EPI to the T1.
##################
#preconditions: dataPrep.sh, motion_correction, tissueSeg
##################
#input (typical):	 ${outDir}/func/mc/mcImgMean.nii.gz (from motion_correct)
#					 T1_brain (from option -A)
#					 T1_head (from option -a)
#					 T1_mask (from option -m)
#					 outDir (from option -o)
##################
#output: 			 ${outDir}/func/EPItoT1/EPItoT1.mat
#					 ${outDir}/func/EPItoT1/T1toEPI.mat
#					 ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz
#					 ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz
#					 ${outDir}/func/EPItoT1/EPIstrippedtoT1.nii.gz
#					 ${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz
#					 ${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz
#					 ${outDir}/func/EPItoT1/EPItoMNI.nii.gz
##################
#dependencies: FSL, clobber
##################
#Used in: EPItoT1Master
##################

function EPItoT1()
{
  #local variables here
  local mcImgMean=$1 #epi is mcImgMean
  local T1_brain=$2
  local T1_head=$3
  local T1_mask=$4
  local outDir=$5
  printf "%s\n" "......Registration Without FieldMap Correction." 
  #Warp without FieldMap correction

  clobber ${outDir}/func/EPItoT1/EPItoT1.mat &&\
  { epi_reg --epi=${mcImgMean} \
  --t1=${T1_head} \
  --t1brain=${T1_brain} \
  --wmseg=${outDir}/func/T1forWarp/T1_MNI_brain_wmseg.nii.gz \
  --out=${outDir}/func/EPItoT1/EPItoT1 --noclean ||\
  { printf "%s\n" "epi_reg failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the affine registration (to get T1toEPI)
  clobber ${outDir}/func/EPItoT1/T1toEPI.mat &&\
  { convert_xfm -omat ${outDir}/func/EPItoT1/T1toEPI.mat -inverse ${outDir}/func/EPItoT1/EPItoT1.mat ||\
  { printf "%s\n" "convert_xfm failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the inverted (T1toEPI) mat file to the brain mask
  clobber ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz &&\
  { flirt -in ${T1_mask} -ref ${mcImgMean} -applyxfm -init ${outDir}/func/EPItoT1/T1toEPI.mat -out ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz -interp nearestneighbour -datatype char ||\
  { printf "%s\n" "flirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Create a stripped version of the EPI (mcImg) file, apply the mat file
  clobber ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz &&\
  { fslmaths ${mcImgMean} -mas ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz ||\
  { printf "%s\n" "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${outDir}/func/EPItoT1/EPIstrippedtoT1.nii.gz &&\
  { flirt -in ${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz -ref ${T1_brain} -applyxfm -init ${outDir}/func/EPItoT1/EPItoT1.mat -out ${outDir}/func/EPItoT1/EPIstrippedtoT1.nii.gz ||\
  { printf "%s\n" "flirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the affine transform (T1toEPI.mat) to get a warp from MNI to EPI
  clobber ${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz &&\
  { convertwarp --ref=${mcImgMean} --warp1=${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz --postmat=${outDir}/func/EPItoT1/T1toEPI.mat --out=${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz --relout ||\
  { printf "%s\n" "convertwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the warp to get EPItoMNI_warp.nii.gz
  clobber ${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz &&\
  { invwarp -w ${outDir}/func/EPItoT1/MNItoEPI_warp.nii.gz -r $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz -o ${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply EPItoMNI warp to EPI file
  clobber ${outDir}/func/EPItoT1/EPItoMNI.nii.gz &&\
  { applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=${outDir}/func/EPItoT1/mcImgMean_stripped.nii.gz --out=${outDir}/func/EPItoT1/EPItoMNI.nii.gz --warp=${outDir}/func/EPItoT1/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n ${FUNCNAME} successful" && return 0
}

##################
#function: makeROI_Noise
##################
#purpose: Creates an ROI centered around user-supplied y-coordinates
##################
#input:			ydim, integer
#				xydim, integer
#				inputImage, nifti file
#				outputImage, nifti file name	 
##################
#output: 			 outputImage (ROI nifti file)
##################
#dependencies: FSL
##################
#Used in: Estimate_SNR
##################
function makeROI_Noise()
{
  local ydim=$1 
  local xydim=$2
  #Set input/output images
  local inputImage=$3
  local outputImage=$4

  #ROI is arbitrarily set to %age of xy voxel dimensions ($2)
  { fslmaths $inputImage -mul 0 -add 1 -roi 0 -1 ${ydim} 1 0 -1 0 1 $outputImage -odt float ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  { fslmaths $outputImage -kernel sphere ${xydim} -fmean $outputImage -odt float ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  { fslmaths $outputImage -bin $outputImage ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n ${FUNCNAME} successful" && return 0
}

########################  END HELPER FUNCTIONS   #############################



#############################   MAIN FUNCTIONS   #############################

##################
#function: motion_correction
##################
#purpose: Runs motion correction on the raw resting state image.
##################
#preconditions: you have run dataPrep.sh already.
##################
#input (typical): ${outDir}/func/RestingStateRaw.nii.gz
#				  ${outDir}
##################
#output:	${outDir}/func/mc/mcImg.nii.gz
#			${outDir}/func/mc/mcImg_raw.par
#			${outDir}/func/mc/mcImgMean.nii.gz
#			${outDir}/func/mc/mcImg_deg.par
#			${outDir}/func/mc/mcImg.par
#			${outDir}/func/mc/mcImg_mm.par
#			${outDir}/func/mc/mcImg_abs.rms
#			${outDir}/func/mc/mcImg_deriv.par
#			${outDir}/func/mc/mcImg_rel.rms
#			${outDir}/func/mc/rot.png
#			${outDir}/func/mc/trans.png 
#			${outDir}/func/mc/rot_mm.png
#			${outDir}/func/mc/rot_trans.png
#			${outDir}/func/mc/disp.png
##################
#dependencies: FSL, AFNI, clobber
##################
#Used in: MAIN
##################
function motion_correction() 
{ 
  ########## Motion Correction ###################
  #Going to run with AFNI's 3dvolreg over FSL's mcflirt.  Output pics will have same names to be drop-in replacments
  echo "...Applying motion correction."
  local epi=$1
  local outDir=$2

  mkdir -p ${outDir}/func/mc ||\
  { printf "%s\n" "mkdir ${outDir}/func/mc, exiting ${FUNCNAME}" && return 1 ;}
  #Determine halfway point of dataset to use as a target for registration
  local halfPoint=$(fslhd $epi | grep "^dim4" | awk '{print int($2/2)}')

  #Run 3dvolreg, save matrices and parameters
  #Saving "raw" AFNI output for possible use later (motionscrubbing?)
  clobber ${outDir}/func/mc/mcImg.nii.gz &&\
  { 3dvolreg -verbose \
  -tshift 0 \
  -Fourier \
  -zpad 4 \
  -prefix ${outDir}/func/mc/mcImg.nii.gz \
  -base $halfPoint \
  -dfile ${outDir}/func/mc/mcImg_raw.par \
  -1Dmatrix_save ${outDir}/func/mc/mcImg.mat \
  $epi ||\
  { printf "%s\n" "3dvolreg failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Create a mean volume
  clobber ${outDir}/func/mc/mcImgMean.nii.gz &&\
  { fslmaths ${outDir}/func/mc/mcImg.nii.gz -Tmean ${outDir}/func/mc/mcImgMean.nii.gz ||\
  { printf "%s\n" "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Save out mcImg.par (like fsl) with only the translations and rotations
  #mcflirt appears to have a different rotation/translation order.  Reorder 3dvolreg output to match "RPI" FSL ordering
  ##AFNI ordering
  #roll  = rotation about the I-S axis }
  #pitch = rotation about the R-L axis } degrees CCW
  #yaw   = rotation about the A-P axis }
  #dS  = displacement in the Superior direction  }
  #dL  = displacement in the Left direction      } mm
  #dP  = displacement in the Posterior direction }

  awk '{print ($3 " " $4 " " $2 " " $6 " " $7 " " $5)}' ${outDir}/func/mc/mcImg_raw.par > ${outDir}/func/mc/mcImg_deg.par ||\
  { printf "%s\n" "creation of mcImg_deg.par failed, exiting ${FUNCNAME}" && return 1; }

  #Need to convert rotational parameters from degrees to radians
  #rotRad= (rotDeg*pi)/180
  #pi=3.14159

  awk -v pi=3.14159 '{print (($1*pi)/180) " " (($2*pi)/180) " " (($3*pi)/180) " " $4 " " $5 " " $6}' ${outDir}/func/mc/mcImg_deg.par > ${outDir}/func/mc/mcImg.par ||\
  { printf "%s\n" "creation of mcImg.par failed, exiting ${FUNCNAME}" && return 1; }

  #Need to create a version where ALL (rotations and translations) measurements are in mm.  Going by Power 2012 Neuroimage paper, radius of 50mm.
  #Convert degrees to mm, leave translations alone.
  #rotDeg= ((2r*Pi)/360) * Degrees = Distance (mm)
  #d=2r=2*50=100
  #pi=3.14159

  awk -v pi=3.14159 -v d=100 '{print (((d*pi)/360)*$1) " " (((d*pi)/360)*$2) " " (((d*pi)/360)*$3) " " $4 " " $5 " " $6}' ${outDir}/func/mc/mcImg_deg.par > ${outDir}/func/mc/mcImg_mm.par ||\
  { printf "%s\n" "creation of mcImg_mm.par failed, exiting ${FUNCNAME}" && return 1; }

  #Cut motion parameter file into 6 distinct TR parameter files
  for i in {1..6}; do
    awk -v var=${i} '{print $var}' ${outDir}/func/mc/mcImg.par > ${outDir}/func/mc/mc${i}.par ||\
    { printf "%s\n" "creation of mc{$1}.par failed, exiting ${FUNCNAME}" && return 1; }
  done

  ##Need to create the absolute and relative displacement RMS measurement files
  #From the FSL mailing list (https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;2ce58db1.1202):
  #rms = sqrt(0.2*R^2*((cos(theta_x)-1)^2+(sin(theta_x))^2 + (cos(theta_y)-1)^2 + (sin(theta_y))^2 + (cos(theta_z)-1)^2 + (sin(theta_z)^2)) + transx^2+transy^2+transz^2)
  #where R=radius of spherical ROI = 80mm used in rmsdiff; theta_x, theta_y, theta_z are the three rotation angles from the .par file; and transx, transy, transz are the three translations from the .par file.

  #Absolute Displacement
  awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' ${outDir}/func/mc/mcImg.par > ${outDir}/func/mc/mcImg_abs.rms ||\
  { printf "%s\n" "creation of mcImg_abs.rms failed, exiting ${FUNCNAME}" && return 1; }

  #Relative Displacement
  #Create the relative displacement .par file from the input using AFNI's 1d_tool.py to first calculate the derivatives
  1d_tool.py -infile ${outDir}/func/mc/mcImg.par -set_nruns 1 -derivative -write ${outDir}/func/mc/mcImg_deriv.par -overwrite ||\
  { printf "%s\n" "creation of mcImg_deriv.par failed, exiting ${FUNCNAME}" && return 1; }

  awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' ${outDir}/func/mc/mcImg_deriv.par > ${outDir}/func/mc/mcImg_rel.rms ||\
  { printf "%s\n" "creation of mcImg_rel.rms failed, exiting ${FUNCNAME}" && return 1; }


  #Create images of the motion correction (translation, rotations, displacement), mm and radians
    #switched from "MCFLIRT estimated...." title
  fsl_tsplot -i ${outDir}/func/mc/mcImg.par -t '3dvolreg estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o ${outDir}/func/mc/rot.png ||\
  { printf "%s\n" "creation of rot.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mc/mcImg.par -t '3dvolreg estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 800 -h 300 -o ${outDir}/func/mc/trans.png ||\
  { printf "%s\n" "creation of trans.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mc/mcImg_mm.par -t '3dvolreg estimated rotations (mm)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o ${outDir}/func/mc/rot_mm.png ||\
  { printf "%s\n" "creation of rot_mm.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mc/mcImg_mm.par -t '3dvolreg estimated rotations and translations (mm)' -u 1 --start=1 --finish=6 -a "x(rot),y(rot),z(rot),x(trans),y(trans),z(trans)" -w 800 -h 300 -o ${outDir}/func/mc/rot_trans.png ||\
  { printf "%s\n" "creation of rot_trans.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mc/mcImg_abs.rms,${outDir}/func/mc/mcImg_rel.rms -t '3dvolreg estimated mean displacement (mm)' -u 1 -w 800 -h 300 -a absolute,relative -o ${outDir}/func/mc/disp.png ||\
  { printf "%s\n" "creation of dip.png failed, exiting ${FUNCNAME}" && return 1; }


  printf "%s\n" "${FUNCNAME} completed successfully" && return 0
}

##################
#function: TissueSeg
##################
#purpose: Separates the highres image into CSF, GM, WM
##################
#preconditions: dataPrep.sh
##################
#input (typical):	 T1_brain (from option -A)
#					 outDir (from option -o)
##################
#output: 			 ${outDir}/func/T1forWarp/tissueSeg
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_mixeltype.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_pve_0.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_pve_1.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_pve_2.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_pveseg.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_seg_0.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_seg_1.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_seg_2.nii.gz
#					 ${outDir}/func/T1forWarp/tissueSeg/T1_seg.nii.gz
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function TissueSeg() 
{
  local T1_brain=$1
  local outDir=$2

  #Do we need to run fast if epi_reg runs fast?
  ########## Tissue class segmentation ###########
  echo "...Creating Tissue class segmentations."
  mkdir -p ${outDir}/func/T1forWarp/tissueSeg


  #Tissue segment the skull-stripped T1
  echo "......Starting FAST segmentation"
  clobber ${outDir}/func/T1forWarp/T1_MNI_brain_wmseg.nii.gz &&\
  { fast -t 1 -n 3 -g -o ${outDir}/func/T1forWarp/tissueSeg/T1 ${T1_brain} &&\
  cp ${outDir}/func/T1forWarp/tissueSeg/T1_seg_2.nii.gz ${outDir}/func/T1forWarp/T1_MNI_brain_wmseg.nii.gz ||\
  { printf "%s\n" "fast failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n ${FUNCNAME} successful" && return 0
}

##################
#function: T1ToStd
##################
#purpose: Creates the transforms to move the T1 image to MNI space
##################
#preconditions: Already ran dataPrep.sh
##################
#input (typical):	 T1_brain (from option -A)
#					 T1_head (from option -a)
#					 T1_mask (from option -m)
#					 ${outDir}
#					 lesion (0 or 1)
##################
#output: 			 ${outDir}/func/T1forWarp
#					 lesion=1	
#					 	${outDir}/func/T1forWarp/T1_lesionmask.nii.gz
#					 	${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz
#					 	${outDir}/func/T1forWarp/LesionWeight.nii.gz
#					 ${outDir}/func/T1forWarp/T1_to_MNIaff.nii.gz
#					 ${outDir}/func/T1forWarp/T1_to_MNIaff.mat
#					 ${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz
#					 ${outDir}/func/T1forWarp/T1_to_MNI152.nii.gz
#					 ${outDir}/func/T1forWarp/jac_T1_to_MNI152.nii.gz	
#					 ${outDir}/func/T1forWarp/T1_brain_to_MNI152.nii.gz
#					 ${outDir}/func/T1forWarp/"lesion"MasktoMNI.nii.gz
#					 ${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz
##################
#dependencies: FSL, RPI_Orient, clobber, LestionMaskPrep
##################
#Used in: MAIN
##################
function T1ToStd()
{ 
  local T1_brain=$1
  local T1_head=$2
  local T1_mask=$3
  local outDir=$4
  local lesion=$5


  printf "%s\n" "...Optimizing T1 (highres) to MNI (standard) registration."
  if [ ${lesion} -eq 1 ]; then
    lesionMaskPrep ${T1_mask} ${outDir}
    local flirt_transform_option="-inweight ${outDir}/func/T1forWarp/LesionWeight.nii.gz"
    local fnirt_transform_option="--inmask=$t1WarpDir/LesionWeight.nii.gz"
    local maskname="lesion"
  fi

   mkdir -p ${outDir}/func/T1forWarp ||\
  { printf "%s\n" "creation of directory T1forWarp failed, exiting ${FUNCNAME}" && return 1; }

  #T1 to MNI, affine (skull-stripped data)
  clobber ${outDir}/func/T1forWarp/T1_to_MNIaff.nii.gz ${outDir}/func/T1forWarp/T1_to_MNIaff.mat &&\
  { flirt -in ${T1_brain} \
  -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz \
  -out ${outDir}/func/T1forWarp/T1_to_MNIaff.nii.gz \
  -omat ${outDir}/func/T1forWarp/T1_to_MNIaff.mat ${flirt_transform_option} ||\
  { printf "%s\n" "flirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #T1 to MNI, nonlinear (T1 with skull)
  clobber ${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz ${outDir}/func/T1forWarp/T1_to_MNI152.nii.gz ${outDir}/func/T1forWarp/jac_T1_to_MNI152.nii.gz &&\
  { fnirt --in=${T1_head} \
  --aff=${outDir}/func/T1forWarp/T1_to_MNIaff.mat \
  --config=T1_2_MNI152_2mm.cnf \
  --cout=${outDir}/func/T1forWarp/coef_T1_to_MNI152 \
  --iout=${outDir}/func/T1forWarp/T1_to_MNI152.nii.gz \
  --jout=${outDir}/func/T1forWarp/jac_T1_to_MNI152 \
  --jacrange=0.1,10 ${fnirt_transform_option} ||\
  { printf "%s\n" "fnirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the warp to the skull-stripped T1
  clobber ${outDir}/func/T1forWarp/T1_brain_to_MNI152.nii.gz &&\
  { applywarp \
  --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz \
  --in=$T1_brain \
  --out=${outDir}/func/T1forWarp/T1_brain_to_MNI152.nii.gz \
  --warp=${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the warp to the lesion mask or to the T1 mask
  clobber ${outDir}/func/T1forWarp/${maskname}MasktoMNI.nii.gz &&\
  { applywarp \
  --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz \
  --in=$T1_mask \
  --out=${outDir}/func/T1forWarp/${maskname}MasktoMNI.nii.gz \
  --warp=${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz \
  --interp=nn ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the warp (to get MNItoT1)
  clobber ${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz &&\
  { invwarp \
  -w ${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz \
  -r $T1_brain \
  -o ${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} completed successfully"
}


##################
#function: EPItoT1Master
##################
#purpose: makes the transform from the motion corrected EPI to the T1, and skullstrips the mcImg and RestingStateRaw.
##################
#preconditions: dataPrep.sh, motion_correction, tissueSeg
##################
#input (typical):	 ${outDir}/func/mc/mcImgMean.nii.gz (from motion_correct)
#					 T1_brain (from option -A)
#					 T1_head (from option -a)
#					 T1_mask (from option -m)
#					 outDir (from option -o)
#					 #Additional Arguments from Fieldmap data
#					 fieldmapFlag (0 or 1) (from option -f)
#					 fieldmap (from option -b)
#					 fieldmapMagHead (from option -v)
#					 fieldmapMagBrain (from option -x)
#					 dwelltime (from option -D or default)
#					 peDir (from option -d or default)
##################
#output: 			 ${outDir}/func/mc/mcImg_stripped.nii.gz
#					 ${outDir}/func/RestingState.nii.gz
##################
#dependencies: FSL, clobber, EPItoT1FieldMap, EPItoT1
##################
#Used in: MAIN
##################
function EPItoT1Master()
{ 
  #basic args (without fieldmap)
  local mcImgMean=$1
  local T1_brain=$2
  local T1_head=$3
  local T1_mask=$4
  local outDir=$5
  #additional arguments for fieldmap processing
  local fieldmapFlag=$6
  local fieldmap=$7
  local fieldmapMagHead=$8
  local fieldmapMagBrain=$9
  local dwellTime=$10
  local peDir=$11
  #number of arguments to decide which processing stream.
  #local num_args=$#


  printf "%s\n" "...Optimizing EPI (func) to T1 (highres) registration."
  mkdir -p ${outDir}/func/EPItoT1 ||\
  { printf "%s\n" "creation of ${outDir}/func/EPItoT1 failed, exiting ${FUNCNAME}" && return 1; }

  if [ ${fieldMapFlag} -eq 1 ]; then
  	EPItoT1FieldMap $@
  	{ printf "%s\n" "EPItoT1FieldMap failed, exiting ${FUNCNAME}" && return 1 ;}
  elif [ ${fieldMapFlag} -eq 0 ]; then
  	EPItoT1 $@ ||\
  	{ printf "%s\n" "EPItoT1 failed, exiting ${FUNCNAME}" && return 1 ;}
  else
  	printf "%s\n" "fieldmapFlag not set to 1 or 0, exiting EPItoT1Master" && return 1
  fi


  #JK put a pin in this, may fit in another function better
  ########## Skullstrip the EPI data ######################

  #ENTER FUNCTION FOR SKULLSTRIPPING
  #skull-strip mcImgMean volume, write output to rsParams file
  clobber ${outDir}/func/mc/mcImg_stripped.nii.gz &&\
  { fslmaths ${outDir}/func/mc/mcImg.nii.gz -mas ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz ${outDir}/func/mc/mcImg_stripped.nii.gz ||\
  { printf "%s\n" "couldn't make ${outDir}/func/mc/mcImg_stripped.nii.gz, exiting ${FUNCNAME}" && return 1 ;};}

  #Leftover section from dataPrep (to create "RestingState.nii.gz")
  clobber ${outDir}/func/RestingState.nii.gz &&\
  { fslmaths ${outDir}/func/RestingStateRaw.nii.gz -mas ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz ${outDir}/func/RestingState.nii.gz ||\
  { printf "%s\n" "couldn't make ${outDir}/func/RestingState.nii.gz, exiting ${FUNCNAME}" && return 1 ;};}


  printf "%s\n" "${FUNCNAME} completed successfully" && return 0
}

##################
#function: Estimate_SNR
##################
#purpose: Estimates Signal to Noise ratio and does spike detection.
##################
#preconditions: dataPrep.sh, motion_correction, TissueSeg, T1ToStd, EPItoT1Master
##################
#input (typical):	 ${outDir}/func/mc/mcImg.nii.gz (from motion_correction)
#					 ${outDir}/func/mc/mcImgMean.nii.gz (from motion_correction)
#					 ${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz (from EPItoT1Master)
#					 T1toEPI_transform (from EPItoT1Master)
#					 ${outDir}/func/T1forWarp/tissueSeg (from TissueSeg)
#					 fieldMapFlag (0 or 1) (from option -f)
##################
#output: 			${outDir}/func/SNR
#					${outDir}/func/SNR/3dTqual.png
#					${outDir}/func/SNR/analysisResults.html
#					${outDir}/func/SNR/AntNoise_Mean.par
#					${outDir}/func/SNR/evspikes.txt
#					${outDir}/func/SNR/global_mean_ts.dat
#					${outDir}/func/SNR/GM_Mean.par
#					${outDir}/func/SNR/GM_to_RS.nii.gz
#					${outDir}/func/SNR/mcImg_nonfilteredMean.nii.gz
#					${outDir}/func/SNR/mcImg_nonfiltered.nii.gz
#					${outDir}/func/SNR/mcImg_nonfilteredSNR.nii.gz
#					${outDir}/func/SNR/mcImg_nonfilteredSTD.nii.gz
#					${outDir}/func/SNR/NoiseAntMask.nii.gz
#					${outDir}/func/SNR/NoiseAvg.par
#					${outDir}/func/SNR/NoisePlot.png
#					${outDir}/func/SNR/NoisePostMask.nii.gz
#					${outDir}/func/SNR/Normscore.par
#					${outDir}/func/SNR/normscore.png
#					${outDir}/func/SNR/PostNoise_Mean.par
#					${outDir}/func/SNR/RestingState_GM4d.nii.gz
#					${outDir}/func/SNR/RestingState_GMfinal.nii.gz
#					${outDir}/func/SNR/RestingState_GM.nii.gz
#					${outDir}/func/SNR/RestingState_GMsmooth.nii.gz
#					${outDir}/func/SNR/RestingState_NoiseAntMask.nii.gz
#					${outDir}/func/SNR/RestingState_NoisePostMask.nii.gz
#					${outDir}/func/SNR/SigNoise.par
#					${outDir}/func/SNR/SigNoisePlot.png
#					${outDir}/func/SNR/SNRcalc.txt
#					${outDir}/func/SNR/T1_GM.nii.gz
#					${outDir}/func/SNR/testNoise.txt
#					${outDir}/func/SNR/WM_to_RS.nii.gz
##################
#dependencies: FSL, clobber, makeROI_Noise
##################
#Used in: MAIN
##################
function Estimate_SNR()
{
  local mcImg=$1
  local mcImgMean=$2
  local mcImgMean_mask=$3
  local T1toEPI_transform=$4
  local segDir=$5
  local fieldMapFlag=$6
  local outDir=$7

  #putting a sticky note here until I figure out where this code flows the best

  ########## In vs. Out of Brain SNR Calculation #
  echo "...SNR mask creation."

  #Calculate a few dimensions
  xdim=$(fslhd ${mcImg} | grep ^dim1 | awk '{print $2}')
  ydim=$(fslhd ${mcImg} | grep ^dim2 | awk '{print $2}')
  zdim=$(fslhd ${mcImg} | grep ^dim3 | awk '{print $2}')
  tdim=$(fslhd ${mcImg} | grep ^dim4 | awk '{print $2}')
  xydimTenth=$(echo $xdim 0.06 | awk '{print int($1*$2)}')
  ydimMaskAnt=$(echo $ydim 0.93 | awk '{print int($1*$2)}')
  ydimMaskPost=$(echo $ydim 0.07 | awk '{print int($1*$2)}')

  echo "...Estimating SNR."

  #Create a folder to dump temp data into
  mkdir -p ${outDir}/func/SNR


  echo "...Warping GM/WM/CSF mask to EPI space"
    #Warp GM, WM and CSF to EPI space
  ##WM/CSF will be used in MELODIC s/n determination
  clobber ${outDir}/func/SNR/T1_GM.nii.gz &&\
  { fslmaths $segDir/T1_seg_1.nii.gz -bin ${outDir}/func/SNR/T1_GM.nii.gz -odt char ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Check for FieldMap correction.  If used, will have to applywarp, othewise use flirt with the .mat file
  if [[ $fieldMapFlag == 1 ]]; then
    #Apply the warp file
    clobber ${outDir}/func/SNR/RestingState_GM.nii.gz &&\
    { applywarp -i ${outDir}/func/SNR/T1_GM.nii.gz -o ${outDir}/func/SNR/RestingState_GM.nii.gz -r ${mcImgMean} -w ${T1toEPI_warp} --interp=nn --datatype=char ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

    #Transfer over GM/WM/CSF from original segmentation, without binarizing/conversion to 8bit
    clobber ${outDir}/func/SNR/CSF_to_RS.nii.gz &&\
    { applywarp -i $segDir/T1_seg_0.nii.gz -o ${outDir}/func/SNR/CSF_to_RS.nii.gz -r ${mcImgMean} -w ${T1toEPI_transform} --interp=nn ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

    clobber ${outDir}/func/SNR/GM_to_RS.nii.gz &&\
    { applywarp -i $segDir/T1_seg_1.nii.gz -o ${outDir}/func/SNR/GM_to_RS.nii.gz -r ${mcImgMean} -w ${T1toEPI_transform} --interp=nn ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

    clobber ${outDir}/func/SNR/WM_to_RS.nii.gz &&\
    { applywarp -i $segDir/T1_seg_2.nii.gz -o ${outDir}/func/SNR/WM_to_RS.nii.gz -r ${mcImgMean} -w ${T1toEPI_transform} --interp=nn ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  else
    #Apply the affine .mat file
    clobber ${outDir}/func/SNR/RestingState_GM.nii.gz &&\
    { flirt -in ${outDir}/func/SNR/T1_GM.nii.gz -ref ${mcImgMean} -applyxfm -init ${T1toEPI_transform} -out ${outDir}/func/SNR/RestingState_GM.nii.gz -interp nearestneighbour -datatype char ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

    #Transfer over GM/WM/CSF from original segmentation, without binarizing/conversion to 8bit
    clobber ${outDir}/func/SNR/RestingState_GM.nii.gz &&\
    { flirt -in $segDir/T1_seg_0.nii.gz -ref ${mcImgMean} -applyxfm -init ${T1toEPI_transform} -out ${outDir}/func/SNR/CSF_to_RS.nii.gz -interp nearestneighbour ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

    clobber ${outDir}/func/SNR/GM_to_RS.nii.gz &&\
    { flirt -in $segDir/T1_seg_1.nii.gz -ref ${mcImgMean} -applyxfm -init ${T1toEPI_transform} -out ${outDir}/func/SNR/GM_to_RS.nii.gz -interp nearestneighbour ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

    clobber ${outDir}/func/SNR/WM_to_RS.nii.gz &&\
    { flirt -in $segDir/T1_seg_2.nii.gz -ref ${mcImgMean} -applyxfm -init ${T1toEPI_transform} -out ${outDir}/func/SNR/WM_to_RS.nii.gz -interp nearestneighbour ||\
    { printf "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}
  fi


  #smooth output to get rid of pixellation
  clobber ${outDir}/func/SNR/RestingState_GMsmooth.nii.gz &&\
  { 3dmerge -doall -prefix ${outDir}/func/SNR/RestingState_GMsmooth.nii.gz -session ${outDir}/func/SNR -1blur_fwhm 5 ${outDir}/func/SNR/RestingState_GM.nii.gz -overwrite ||\
  { printf "3dmerge failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${outDir}/func/SNR/RestingState_GMfinal.nii.gz &&\
  { fslmaths ${outDir}/func/SNR/RestingState_GMsmooth.nii.gz -add ${outDir}/func/SNR/RestingState_GM.nii.gz -bin ${outDir}/func/SNR/RestingState_GMfinal.nii.gz -odt char ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Strip out GM from EPI
  clobber ${outDir}/func/SNR/RestingState_GM4d.nii.gz &&\
  { fslmaths ${mcImg} -mul ${outDir}/func/SNR/RestingState_GMfinal.nii.gz ${outDir}/func/SNR/RestingState_GM4d.nii.gz ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}


  echo "...Calculating SNR measurements per TR."
  
  #This error test won't work, but I'm too lazy rn (it checks the outcome of redirection not fslstats)
  clobber ${outDir}/func/SNR/GM_Mean.par &&\
  { fslstats -t ${outDir}/func/SNR/RestingState_GM4d.nii.gz -M >> ${outDir}/func/SNR/GM_Mean.par ||\
  { printf "making GM_Mean.par failed, exiting ${FUNCNAME}" ;} ;}


  #Create ROIs for calculating anterior and posterior noise (on Raw EPI) - based on 6% of xydimensions
  clobber ${outDir}/func/SNR/NoiseAntMask &&\
  { makeROI_Noise $ydimMaskAnt $xydimTenth ${mcImgMean} ${outDir}/func/SNR/NoiseAntMask ||\
  { printf "makeROI_Noise failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${outDir}/func/SNR/NoisePostMask &&\
  { makeROI_Noise $ydimMaskPost $xydimTenth ${mcImgMean} ${outDir}/func/SNR/NoisePostMask ||\
  { printf "makeROI_Noise failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Strip out Anterior/Posterior Noise from EPI
  clobber ${outDir}/func/SNR/RestingState_NoiseAntMask.nii.gz &&\
  { fslmaths ${mcImg} -mul ${outDir}/func/SNR/NoiseAntMask.nii.gz ${outDir}/func/SNR/RestingState_NoiseAntMask.nii.gz ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${outDir}/func/SNR/RestingState_NoisePostMask.nii.gz &&\
  { fslmaths ${mcImg} -mul ${outDir}/func/SNR/NoisePostMask.nii.gz ${outDir}/func/SNR/RestingState_NoisePostMask.nii.gz ||\
  { printf "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Calculate Mean value of Noise (Anterior and Posterior) per TR

  clobber ${outDir}/func/SNR/AntNoise_Mean.par &&\
  { fslstats -t ${outDir}/func/SNR/RestingState_NoiseAntMask.nii.gz -M >> ${outDir}/func/SNR/AntNoise_Mean.par ||\
  { printf "fslstats failed, exiting ${FUNCNAME}", && return 1 ;} ;}

  clobber ${outDir}/func/SNR/PostNoise_Mean.par &&\
  { fslstats -t ${outDir}/func/SNR/RestingState_NoisePostMask.nii.gz -M  >> ${outDir}/func/SNR/PostNoise_Mean.par ||\
  { printf "fslstats failed, exiting ${FUNCNAME}", && return 1 ;} ;}
  

  #make arrays from the .par lists
  local PostNoise=($(cat ${outDir}/func/SNR/PostNoise_Mean.par))
  local AntNoise=($(cat ${outDir}/func/SNR/AntNoise_Mean.par))
  local GM=($(cat ${outDir}/func/SNR/GM_Mean.par))
  #Calculate Noise (signal mean), signal to noise for each TR
  
  #JK: not going to error check this, if I do, I'm going to revamp this code.
  for i in $(seq 0 $((${tdim}-1)) ); do
    #AntNoise=`cat AntNoise_Mean.par | head -$i | tail -1`
    #Controlling for 0.0000 to be read as 0 (to avoid division by zero awk errors)
    AntNoisebin=$(echo ${AntNoise[$i]} | awk '{print int($1)}')
    #PostNoise=`cat PostNoise_Mean.par | head -$i | tail -1`
    #Controlling for 0.0000 to be read as 0 (to avoid division by zero awk errors)
    PostNoisebin=$(echo ${PostNoise[$i]} | awk '{print int($1)}')
    echo "antnoise${i} = ${AntNoise[$i]}" >> ${outDir}/func/SNR/testNoise.txt
    echo "postnoise${i} = ${PostNoise[$i]}" >> ${outDir}/func/SNR/testNoise.txt
    NoiseAvg=$(echo ${AntNoise[$i]} ${PostNoise[$i]} | awk '{print (($1+$2)/2)}')
    NoiseAvgbin=$(echo $NoiseAvg | awk '{print int($1)}')
    echo "noiseavg${i} = $NoiseAvg" >> ${outDir}/func/SNR/testNoise.txt
    echo "gmmean${i} = ${GM[$i]}" >> ${outDir}/func/SNR/testNoise.txt

    #Avoid division by zero awk errors
    if [ $AntNoisebin == 0 ]; then
  AntSigNoise=0
    else
  AntSigNoise=`echo ${GM[$i]} ${AntNoise[$i]} | awk '{print $1/$2}'`
    fi
    echo "antsignoise${i} = $AntSigNoise" >> ${outDir}/func/SNR/testNoise.txt

    #Avoid division by zero awk errors
    if [ $PostNoisebin == 0 ]; then
  PostSigNoise=0
    else
  PostSigNoise=`echo ${GM[$i]} ${PostNoise[$i]} | awk '{print $1/$2}'`
    fi
    echo "postsignoise${i} = $PostSigNoise" >> ${outDir}/func/SNR/testNoise.txt

    #Avoid division by zero awk errors
    if [ $NoiseAvgbin == 0 ]; then
  SigNoiseAvg=0
    else
  SigNoiseAvg=`echo $GM[$1] $NoiseAvg | awk '{print $1/$2}'`
    fi
    echo "$AntSigNoise $PostSigNoise $SigNoiseAvg" >> ${outDir}/func/SNR/SigNoise.par
    echo "$NoiseAvg" >> ${outDir}/func/SNR/NoiseAvg.par

  done
  ################################################################



  ########## Plot out Ant/Post Noise, Global SNR #

  fsl_tsplot -i ${outDir}/func/SNR/SigNoise.par -o ${outDir}/func/SNR/SigNoisePlot.png -t 'Signal to Noise Ratio per TR' -a Anterior,Posterior,Average -u 1 --start=1 --finish=3 -w 800 -h 300
  fsl_tsplot -i ${outDir}/func/SNR/AntNoise_Mean.par,${outDir}/func/SNR/PostNoise_Mean.par,${outDir}/func/SNR/NoiseAvg.par -o ${outDir}/func/SNR/NoisePlot.png -t 'Noise (Mean Intensity) per TR' -a Anterior,Posterior,Average -u 1 -w 800 -h 300

  ################################################################



  ########## Temporal filtering (legacy option) ##
    #NOT suggested to run until just before nuisance regression
    #To maintain consistency with previous naming, motion-corrected image is just renamed
  #Updating to call file "nonfiltered" to avoid any confusion down the road
  mcImg_nonfiltered="${outDir}/func/SNR/$(basename ${mcImg/.nii.gz/_nonfiltered.nii.gz})"
  cp ${mcImg} ${mcImg_nonfiltered}
  ################################################################



  ########## Global SNR Estimation ###############
  echo "...Calculating signal to noise measurements"

  clobber ${mcImg_nonfiltered/.nii.gz/Mean.nii.gz} &&\
  { fslmaths ${mcImg_nonfiltered} -Tmean ${mcImg_nonfiltered/.nii.gz/Mean.nii.gz} ||\
  { printf "could not create ${mcImg_nonfiltered/.nii.gz/Mean.nii.gz}, fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${mcImg_nonfiltered/.nii.gz/STD.nii.gz} &&\
  { fslmaths ${mcImg_nonfiltered} -Tstd ${mcImg_nonfiltered/.nii.gz/STD.nii.gz} ||\
  { printf "could not create ${mcImg_nonfiltered/.nii.gz/STD.nii.gz}, fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  
  fslmaths ${mcImg_nonfiltered/.nii.gz/Mean.nii.gz} -div ${mcImg_nonfiltered/.nii.gz/STD.nii.gz} ${mcImg_nonfiltered/.nii.gz/SNR.nii.gz} ||\
  { printf "could not create ${mcImg_nonfiltered/.nii.gz/SNR.nii.gz}, fslmaths failed, exiting ${FUNCNAME}" && return 1 ;}

  fslmaths ${mcImg_nonfiltered/.nii.gz/SNR.nii.gz} -mas ${mcImgMean_mask} ${mcImg_nonfiltered/.nii.gz/SNR.nii.gz} ||\
  { printf "could not create ${mcImg_nonfiltered/.nii.gz/SNR.nii.gz}, fslmaths failed, exiting ${FUNCNAME}" && return 1 ;}

  SNRout=$(fslstats ${mcImg_nonfiltered/.nii.gz/SNR.nii.gz} -M)

  #Get information for timecourse 
  echo "$indir rest $SNRout" >> ${outDir}/func/SNR/SNRcalc.txt

  ################################################################



  ########## Spike Detection #####################
  echo "...Detecting time series spikes"


  ####  CALCULATE SPIKES BASED ON NORMALIZED TIMECOURSE OF GLOBAL MEAN ####
  fslstats -t ${mcImg_nonfiltered} -M > ${outDir}/func/SNR/global_mean_ts.dat
  ImgMean=$(fslstats ${mcImg_nonfiltered} -M)
  echo "Image mean is $ImgMean"
  meanvolsd=$(fslstats ${mcImg_nonfiltered} -S)
  echo "Image standard deviation is $meanvolsd"

  vols=$(cat ${outDir}/func/SNR/global_mean_ts.dat)

  for vol in $vols
  do
    Diffval=`echo "scale=6; ${vol}-${ImgMean}" | bc`
    Normscore=`echo "scale=6; ${Diffval}/${meanvolsd}" | bc`
    echo "$Normscore" >>  ${outDir}/func/SNR/Normscore.par

    echo $Normscore | awk '{if ($1 < 0) $1 = -$1; if ($1 > 3) print 1; else print 0}' >> ${outDir}/func/SNR/evspikes.txt
  done

  fsl_tsplot -i ${outDir}/func/SNR/Normscore.par -t 'Normalized global mean timecourse' -u 1 --start=1 -a normedts -w 800 -h 300 -o ${outDir}/func/SNR/normscore.png

  ################################################################




  ########## AFNI QC tool ########################
    #AFNI graphing tool is fugly.  Replacing with FSL

  3dTqual -range -automask ${mcImg_nonfiltered} >> ${outDir}/func/SNR/tmpPlot
  fsl_tsplot -i ${outDir}/func/SNR/tmpPlot -t '3dTqual Results (Difference From Norm)' -u 1 --start=1 -a quality_index -w 800 -h 300 -o ${outDir}/func/SNR/3dTqual.png
  rm ${outDir}/func/SNR/tmpPlot

  ################################################################



  ########## Spike Report ########################

  spikeCount=$(cat ${outDir}/func/SNR/evspikes.txt | awk '/1/{n++}; END {print n+0}')



  ################################################################
  spikeThreshInt=300
  spikeThresh=$(echo $spikeThreshInt 100 | awk '{print ($1/$2)}')



  ########## Report Output to HTML File ##########

  echo "<h1>Resting State Analysis</h1>" > ${outDir}/func/SNR/analysisResults.html
  echo "<br><b>Directory: </b>$indir" >> ${outDir}/func/SNR/analysisResults.html
  analysisDate=`date`
  echo "<br><b>Date: </b>$analysisDate" >> ${outDir}/func/SNR/analysisResults.html
  user=`whoami`
  echo "<br><b>User: </b>$user<br><hr>" >> ${outDir}/func/SNR/analysisResults.html
  echo "<h2>Motion Results</h2>" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br><img src="rot.png" alt="rotations"><br><br><img src="rot_mm.png" alt="rotations_mm"><br><br><img src="trans.png" alt="translations"><br><br><img src="rot_trans.png" alt="rotations_translations"><br><br><img src="disp.png" alt="displacement"><hr>" >> ${outDir}/func/SNR/analysisResults.html
  echo "<h2>SNR Results</h2>" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br><b>Scan SNR: </b>$SNRout" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br>$spikeCount spikes detected at ${spikeThresh} standard deviation threshold" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br><br><img src="normscore.png"" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br>" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br><b>AFNI 3dTqual Results</b><br><br>" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br><img src="3dTqual.png"" >> ${outDir}/func/SNR/analysisResults.html
  echo "<br>" >> ${outDir}/func/SNR/analysisResults.html

  ################################################################

} #end function


###############################   MAIN   ##################################################

#First check for proper input files
if [ "$epiData" == "" ]; then
  echo "Error: The restingStateImage (-E) is a required option"
  exit 1
fi

if [ "$T1_brain" == "" ]; then
  echo "Error: The T1 data (-a) is a required option"
  exit 1
fi

if [ "$T1_head" == "" ]; then
  echo "Error: The T1 (with skull) data (-A) is a required option"
  exit 1
fi


#A few default parameters (if input not specified, these parameters are assumed)


if [[ $lesionMaskFlag == "" ]]; then
lesionMaskFlag=0
fi

if [[ $fieldMapFlag == "" ]]; then
fieldMapFlag=0
fi

if [[ $peDir == "" ]]; then
peDir="-y"
fi

if [[ $dwellTime == "" ]]; then
dwellTime=0.00056
fi


#If FieldMap correction is chosen, check for proper input files
if [[ $fieldMapFlag == 1 ]]; then
  if [[ "$fieldMap" == "" ]]; then
    echo "Error: The prepared FieldMap from fsl_prepare_fieldmap data (-b) is a required option if you wish to use FieldMap correction (-f)"
    exit 1
  fi
  if [[ "$fieldMapMagSkull" == "" ]]; then
    echo "Error: The FieldMap, Magnitude image (with skull) data (-v) is a required option if you wish to use FieldMap correction (-f)"
    exit 1
  fi
  if [[ "$fieldMapMag" == "" ]]; then
    echo "Error: The FieldMap, Magnitude image (skull-stripped) data (-w) is a required option if you wish to use FieldMap correction (-f)"
    exit 1
  fi
fi

#echo experimental variables to log
printf "%s\n" "------------------------" | tee -a ${outDir}/log/QualityCheck.log
date >> ${outDir}/log/QualityCheck.log
printf "%s\t" "$0 $@" | tee -a ${outDir}/log/QualityCheck.log
printf "%s\ " "$0 $@" | tee -a ${outDir}/log/QualityCheck.log


echo "Running $0 ..."

#perform motion correction on the resting state image
motion_correction "${epiData}" "${outDir}" | tee -a ${outDir}/log/QualityCheck.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "motion_correction failed, exiting script" | tee -a ${outDir}/log/QualityCheck.log && exit 1 ;}

#separate tissue in grey, white, and CSF
TissueSeg "${T1_brain}" "${outDir}" | tee -a ${outDir}/log/QualityCheck.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "TissueSeg failed, exiting script" | tee -a ${outDir}/log/QualityCheck.log && exit 1 ;}

#move subject T1 to standard space
T1ToStd "${T1_brain}" "${T1_head}" "${T1_mask}" "${outDir}" "${lesionMaskFlag}" | tee -a ${outDir}/log/QualityCheck.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "T1toStd failed, exiting script" | tee -a ${outDir}/log/QualityCheck.log && exit 1 ;}

#Move the EPI into T1space (and subsequently standard space)
EPItoT1Master "${outDir}/func/mc/mcImgMean.nii.gz" "${T1_brain}" "${T1_head}" "${T1_mask}" "${outDir}" "${fieldMapFlag}" "${fieldmap}" "${fieldmapMagHead}" "${fieldmapMagBrain}" "${dwellTime}" "${peDir}" | tee -a ${outDir}/log/QualityCheck.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "EPIToT1Master failed, exiting script" | tee -a ${outDir}/log/QualityCheck.log && exit 1 ;}
 
#Whether you used a fieldmap determines what transform you use in SNR calculations
if [ ${fieldMapFlag} -eq 1 ]; then
	T1toEPI_transform=${outDir}/func/EPItoT1/T1toEPI_warp.nii.gz
elif [ ${fieldMapFlag} -eq 0 ]; then
	T1toEPI_transform=${outDir}/func/EPItoT1/T1toEPI.mat
fi

#Estimate the signal to Noise Ratio in the EPI
Estimate_SNR "${outDir}/func/mc/mcImg.nii.gz" "${outDir}/func/mc/mcImgMean.nii.gz"  "${outDir}/func/EPItoT1/mcImgMean_mask.nii.gz" "${T1toEPI_transform}" "${outDir}/func/T1forWarp/tissueSeg" "${fieldMapFlag}" "${outDir}" | tee -a ${outDir}/log/QualityCheck.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "Estimate_SNR failed, exiting script" | tee -a ${outDir}/log/QualityCheck.log && exit 1 ;}



printf "%s\n\n\n" "$0 Complete" | tee -a ${outDir}/log/QualityCheck.log


# test call: ~/RestingState/qualityCheck.sh -E ~/RestingState_dev/data/testOut/func/RestingStateRaw.nii.gz -A ~/RestingState_dev/data/testOut/anat/T1_brain_RPI.nii.gz -a ~/RestingState_dev/data/testOut/anat/T1_head_RPI.nii.gz -m ~/RestingState_dev/data/testOut/anat/brainMask.nii.gz -o ~/RestingState_dev/data/testOut