#!/bin/bash

##################################################################################################################
# Motion Correction and Other inital processing for Resting State Analysis
#     1. Motion Correction
#     2. SNR Estimation
#     4. Spike Detection
#     5. Registration
#       a. T1 to MNI (flirt/fnirt), with/without lesion mask optimization
#       b. EPI to T1 (BBR or 6DOF), with/without FieldMap correction
##################################################################################################################

########## FSL's arg parsing functions ###################
get_opt1() {
    arg=$(echo $1 | sed 's/=.*//')
    echo $arg
}

get_imarg1() {
    arg=$(get_arg1 $1);
    arg=$($fslDir/bin/remove_ext $arg);
    echo $arg
}

get_arg1() {
    if [ X`echo $1 | grep '='` = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    else
	arg=`echo $1 | sed 's/.*=//'`
	if [ X$arg = X ] ; then
	    echo "Option $1 requires an argument" 1>&2
	    exit 1
	fi
	echo $arg
    fi
}

function Usage {
  echo "Usage: qualityCheck.sh --epi=restingStateImage --t1=T1withSkull --t1brain=T1brain --lesionmask=lesionMask --regmode=6dof --fmap=fieldMapPrepped --fmapmag=fieldMapMagSkull --fmapmagbrain=fieldMapMagbrain --dwelltime=0.00056 --pedir=PhaseEncDir -c"
  echo ""
  echo "   where:"
  echo "   --epi Resting State file"
  echo "   --t1brain T1 file"
  echo "   --t1 T1 (with skull) file"
  echo "     *Both EPI and T1 (with and without skull) should be from output of dataPrep script"
  echo "   --lesionmask Binary lesion mask"
  echo "   --regmode registration mode (BBR or 6DOF)"
  echo "   --fmap fieldMapPrepped (B0 correction image from dataPrep/fsl_prepare_fieldmap)"
  echo "   --fmapmag fieldMapMagSkull (FieldMap Magnitude image, with skull (from dataPrep))"
  echo "   --fmapmagbrain fieldMapMag (FieldMap Magnitude image, skull-stripped (from dataPrep))"
  echo "   --dwell dwell time (in seconds)"
  echo "       *dwell time is from the EPI but is only set if FieldMap correction ('-f') is chosen."
  echo "       *dwell time is the echoSpacing corrected by Acceleration Factor."
  echo "       *If not set and FieldMap correction is flagged ('-f'), default is 0.00056"
  echo "   --pedir Phase Encoding Direction (from dataPrep)"
  echo "       *Options are x/y/z/-x/-y/-z"
  echo "   -c clobber/overwrite previous results"
  exit 1
}

function motionCorrection {
  local epiData=$1
  local indir
  indir=$(dirname ${epiData})

  ########## Motion Correction ###################
  # Going to run with AFNI's 3dvolreg over FSL's mcflirt.  Output pics will have same names to be drop-in replacments
  echo "...Applying motion correction."
  cd "$indir" || exit

  # Determine halfway point of dataset to use as a target for registration
  halfPoint=$(fslhd $epiData | grep "^dim4" | awk '{print int($2/2)}')

  # Run 3dvolreg, save matrices and parameters
  # Saving "raw" AFNI output for possible use later (motionscrubbing?)
  clobber "$indir"/mcImg.nii.gz &&\
  3dvolreg -verbose -tshift 0 -Fourier -zpad 4 -prefix mcImg.nii.gz -base $halfPoint -dfile mcImg_raw.par -1Dmatrix_save mcImg.mat $epiData

  # Create a mean volume
  clobber mcImgMean.nii.gz &&\
  fslmaths mcImg.nii.gz -Tmean mcImgMean.nii.gz

  # Save out mcImg.par (like fsl) with only the translations and rotations
  # mcflirt appears to have a different rotation/translation order.  Reorder 3dvolreg output to match "RPI" FSL ordering
  # AFNI ordering
   # roll  = rotation about the I-S axis }
   # pitch = rotation about the R-L axis } degrees CCW
   # yaw   = rotation about the A-P axis }
   # dS  = displacement in the Superior direction  }
   # dL  = displacement in the Left direction      } mm
   # dP  = displacement in the Posterior direction }
  clobber mcImg_deg.par &&\
  cat mcImg_raw.par | awk '{print ($3 " " $4 " " $2 " " $6 " " $7 " " $5)}' >> mcImg_deg.par

  # Need to convert rotational parameters from degrees to radians
  # rotRad= (rotDeg*pi)/180
  # pi=3.14159

  clobber mcImg.par &&\
  cat mcImg_deg.par | awk -v pi=3.14159 '{print (($1*pi)/180) " " (($2*pi)/180) " " (($3*pi)/180) " " $4 " " $5 " " $6}' > mcImg.par

  # Need to create a version where ALL (rotations and translations) measurements are in mm.  Going by Power 2012 Neuroimage paper, radius of 50mm.
  # Convert degrees to mm, leave translations alone.
  # rotDeg= ((2r*Pi)/360) * Degrees = Distance (mm)
  # d=2r=2*50=100
  # pi=3.14159

  clobber mcImg_mm.par &&\
  cat mcImg_deg.par | awk -v pi=3.14159 -v d=100 '{print (((d*pi)/360)*$1) " " (((d*pi)/360)*$2) " " (((d*pi)/360)*$3) " " $4 " " $5 " " $6}' > mcImg_mm.par


  # Cut motion parameter file into 6 distinct TR parameter files
  for i in 1 2 3 4 5 6; do
    clobber mc${i}.par &&\
     cat mcImg.par | awk -v var=${i} '{print $var}' > mc${i}.par
  done

  # Need to create the absolute and relative displacement RMS measurement files
  # From the FSL mailing list (https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;2ce58db1.1202):
  # rms = sqrt(0.2*R^2*((cos(theta_x)-1)^2+(sin(theta_x))^2 + (cos(theta_y)-1)^2 + (sin(theta_y))^2 + (cos(theta_z)-1)^2 + (sin(theta_z)^2)) + transx^2+transy^2+transz^2)
  # where R=radius of spherical ROI = 80mm used in rmsdiff; theta_x, theta_y, theta_z are the three rotation angles from the .par file; and transx, transy, transz are the three translations from the .par file.

  # Absolute Displacement
  cat mcImg.par | awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' >> mcImg_abs.rms

  # Relative Displacement
  # Create the relative displacement .par file from the input using AFNI's 1d_tool.py to first calculate the derivatives
  1d_tool.py -infile mcImg.par -set_nruns 1 -derivative -write mcImg_deriv.par
  cat mcImg_deriv.par | awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' >> mcImg_rel.rms


  # Create images of the motion correction (translation, rotations, displacement), mm and radians
  # switched from "MCFLIRT estimated...." title
  fsl_tsplot -i mcImg.par -t '3dvolreg estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o rot.png
  fsl_tsplot -i mcImg.par -t '3dvolreg estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 800 -h 300 -o trans.png
  fsl_tsplot -i mcImg_mm.par -t '3dvolreg estimated rotations (mm)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o rot_mm.png
  fsl_tsplot -i mcImg_mm.par -t '3dvolreg estimated rotations and translations (mm)' -u 1 --start=1 --finish=6 -a "x(rot),y(rot),z(rot),x(trans),y(trans),z(trans)" -w 800 -h 300 -o rot_trans.png
  fsl_tsplot -i mcImg_abs.rms,mcImg_rel.rms -t '3dvolreg estimated mean displacement (mm)' -u 1 -w 800 -h 300 -a absolute,relative -o disp.png

}

# Overwrites material or skips
function clobber()
{
	# Tracking Variables
	local -i num_existing_files=0
	local -i num_args=$#

	# Tally all existing outputs
	for arg in "$@"; do
		if [ -s "${arg}" ] && [ "${clob}" == true ]; then
			rm -rf "${arg}"
		elif [ -s "${arg}" ] && [ "${clob}" == false ]; then
			num_existing_files=$(( ${num_existing_files} + 1 ))
			continue
		elif [ ! -s "${arg}" ]; then
			continue
		else
			echo "How did you get here?"
		fi
	done

	# see if the command should be run by seeing if the requisite files exist.
	# 0=true
	# 1=false
	if [ ${num_existing_files} -lt ${num_args} ]; then
		return 0
	else
		return 1
	fi

	# example usage
	# clobber test.nii.gz &&\
	# fslmaths input.nii.gz -mul 10 test.nii.gz
}
#default
clob=false
export -f clobber


########## T1 to MNI registration ##############
function T1toMNIreg()
{


clobber $t1WarpDir/T1_brain_to_MNI152.nii.gz &&\
echo "...Optimizing T1 (highres) to MNI (standard) registration."

# Look for output directory for T1 to MNI (create if necessary).
if [[ ! -e $t1Dir/T1forWarp ]]; then
  mkdir -p $t1Dir/T1forWarp
fi

# Check for use of a lesion mask
if [[ $lesionMaskFlag == 1 ]]; then
  # Registration with a binary lesion mask to aid in registration

  # Create a temporaray binary lesion mask (in case it's not char, binary format)
  fslmaths $lesionMask -bin $t1WarpDir/tmpLesionMask.nii.gz -odt char

  # Orient lesion mask to RPI
  $scriptDir/fslreorient.sh $t1WarpDir/tmpLesionMask.nii.gz
  mv $t1WarpDir/tmpLesionMask_MNI.nii.gz $t1WarpDir/tmpLesionMask.nii.gz

  # Invert the lesion mask
  fslmaths $t1WarpDir/tmpLesionMask.nii.gz -mul -1 -add 1 -thr 0.5 -bin $t1WarpDir/LesionWeight.nii.gz

  # T1 to MNI, affine (skull-stripped data)
  flirt -in $t1Data -inweight $t1WarpDir/LesionWeight.nii.gz -ref $fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz -out $t1WarpDir/T1_to_MNIaff.nii.gz -omat $t1WarpDir/T1_to_MNIaff.mat

  # T1 to MNI, nonlinear (T1 with skull)
  fnirt --in=$t1SkullData --inmask=$t1WarpDir/LesionWeight.nii.gz --aff=$t1WarpDir/T1_to_MNIaff.mat --config=T1_2_MNI152_2mm.cnf --cout=$t1WarpDir/coef_T1_to_MNI152 --iout=$t1WarpDir/T1_to_MNI152.nii.gz --jout=$t1WarpDir/jac_T1_to_MNI152 --jacrange=0.1,10

  # Apply the warp to the skull-stripped T1
  applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz --in=$t1Data --out=$t1WarpDir/T1_brain_to_MNI152.nii.gz --warp=$t1WarpDir/coef_T1_to_MNI152.nii.gz

  # Apply the warp to the lesion mask (and remove the temporary mask)
  applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz --in=$t1WarpDir/tmpLesionMask.nii.gz --out=$t1WarpDir/lesionMasktoMNI.nii.gz --warp=$t1WarpDir/coef_T1_to_MNI152.nii.gz --interp=nn

  rm $t1WarpDir/tmpLesionMask.nii.gz

  # Invert the warp (to get MNItoT1)
  invwarp -w $t1WarpDir/coef_T1_to_MNI152.nii.gz -r $t1Data -o $t1WarpDir/MNItoT1_warp.nii.gz

  # Echo out warp files to log
  echo "MNItoT1IWarp=${t1WarpDir}/MNItoT1_warp.nii.gz" >> $logDir/rsParams
  echo "T1toMNI=${t1WarpDir}/T1_brain_to_MNI152.nii.gz" >> $logDir/rsParams
  echo "T1toMNIWarp=${t1WarpDir}/coef_T1_to_MNI152.nii.gz" >> $logDir/rsParams

else
  # Registration without a lesion mask

  # T1 to MNI, affine (skull-stripped data)
  clobber $t1WarpDir/T1_to_MNIaff.mat &&\
  flirt -in $t1Data -ref $fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz -out $t1WarpDir/T1_to_MNIaff.nii.gz -omat $t1WarpDir/T1_to_MNIaff.mat

  # T1 to MNI, nonlinear (T1 with skull)
  clobber $t1WarpDir/jac_T1_to_MNI152.nii.gz &&\
  fnirt --in=$t1SkullData --aff=$t1WarpDir/T1_to_MNIaff.mat --config=T1_2_MNI152_2mm.cnf --cout=$t1WarpDir/coef_T1_to_MNI152 --iout=$t1WarpDir/T1_to_MNI152.nii.gz --jout=$t1WarpDir/jac_T1_to_MNI152 --jacrange=0.1,10

  # Apply the warp to the skull-stripped T1
  clobber $t1WarpDir/T1_brain_to_MNI152.nii.gz &&\
  applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz --in=$t1Data --out=$t1WarpDir/T1_brain_to_MNI152.nii.gz --warp=$t1WarpDir/coef_T1_to_MNI152.nii.gz

  # Invert the warp (to get MNItoT1)
  clobber $t1WarpDir/MNItoT1_warp.nii.gz &&\
  invwarp -w $t1WarpDir/coef_T1_to_MNI152.nii.gz -r $t1Data -o $t1WarpDir/MNItoT1_warp.nii.gz

  # Echo out warp files to log
  echo "MNItoT1IWarp=${t1WarpDir}/MNItoT1_warp.nii.gz" >> $logDir/rsParams
  echo "T1toMNI=${t1WarpDir}/T1_brain_to_MNI152.nii.gz" >> $logDir/rsParams
  echo "T1toMNIWarp=${t1WarpDir}/coef_T1_to_MNI152.nii.gz" >> $logDir/rsParams
fi
}


########## Tissue class segmentation ###########
function tissueSeg() {
echo "...Creating Tissue class segmentations."


if [[ ! -e $segDir ]]; then
  mkdir $segDir
fi

# Tissue segment the skull-stripped T1
clobber $segDir/T1_seg_2.nii.gz &&\
echo "......Starting FAST segmentation" &&\
fast -t 1 -n 3 -g -o $segDir/T1 $t1Data
cp $segDir/T1_seg_2.nii.gz $t1Dir/T1_MNI_brain_wmseg.nii.gz

}

########## Preprocess Fieldmaps ###########
# function modified from $(which mainfeatreg) beginning at L102
preprocessFieldmaps() { # $1 fmap $2 mag_brain $3 mag
echo "......Preprocessing fieldmaps."

cd "$(dirname $1)" || exit
${fslDir}/bin/fslmaths $1 FM_UD_fmap
${fslDir}/bin/fslmaths $2 FM_UD_fmap_mag_brain
${fslDir}/bin/fslmaths $3 FM_UD_fmap_mag

# generate mask for fmap_mag (accounting for the fact that either mag or phase might have been masked in some pre-processing before being enter to FEAT)
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain -bin FM_UD_fmap_mag_brain_mask -odt short
# remask by the non-zero voxel mask of the fmap_rads image (as prelude may have masked this differently before)
# NB: need to use cluster to fill in holes where fmap=0
${fslDir}/bin/fslmaths FM_UD_fmap -abs -bin -mas FM_UD_fmap_mag_brain_mask -mul -1 -add 1 -bin FM_UD_fmap_mag_brain_mask_inv
${fslDir}/bin/cluster -i FM_UD_fmap_mag_brain_mask_inv -t 0.5 --no_table -o FM_UD_fmap_mag_brain_mask_idx
maxidx=$(${fslDir}/bin/fslstats FM_UD_fmap_mag_brain_mask_idx -R | awk '{ print $2 }')
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain_mask_idx -thr $maxidx -bin -mul -1 -add 1 -bin -mas FM_UD_fmap_mag_brain_mask FM_UD_fmap_mag_brain_mask

# refine mask (remove edge voxels where signal is poor)
meanValue=$(${fslDir}/bin/fslstats FM_UD_fmap -k FM_UD_fmap_mag_brain_mask -P 50)
${fslDir}/bin/fslmaths FM_UD_fmap -sub $meanValue -mas FM_UD_fmap_mag_brain_mask FM_UD_fmap
thresh50=$(${fslDir}/bin/fslstats FM_UD_fmap_mag_brain -P 98)

thresh50=$(awk "BEGIN {print $thresh50 / 2.0}")
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain -thr $thresh50 -bin FM_UD_fmap_mag_brain_mask50
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain_mask -ero FM_UD_fmap_mag_brain_mask_ero
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain_mask_ero -add FM_UD_fmap_mag_brain_mask50 -thr 0.5 -bin FM_UD_fmap_mag_brain_mask
${fslDir}/bin/fslmaths FM_UD_fmap -mas FM_UD_fmap_mag_brain_mask FM_UD_fmap
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain -mas FM_UD_fmap_mag_brain_mask FM_UD_fmap_mag_brain
# run despiking filter just on the edge voxels
${fslDir}/bin/fslmaths FM_UD_fmap_mag_brain_mask -ero FM_UD_fmap_mag_brain_mask_ero
$fslDir/bin/fugue --loadfmap=FM_UD_fmap --savefmap=FM_UD_fmap_tmp_fmapfilt --mask=FM_UD_fmap_mag_brain_mask --despike --despikethreshold=2.1
$fslDir/bin/fslmaths FM_UD_fmap -sub FM_UD_fmap_tmp_fmapfilt -mas FM_UD_fmap_mag_brain_mask_ero -add FM_UD_fmap_tmp_fmapfilt FM_UD_fmap
/bin/rm -f FM_UD_fmap_tmp_fmapfilt* FM_UD_fmap_mag_brain_mask_ero* FM_UD_fmap_mag_brain_mask50* FM_UD_fmap_mag_brain_i*

# now demedian
medianValue=$(${fslDir}/bin/fslstats FM_UD_fmap -k FM_UD_fmap_mag_brain_mask -P 50)
${fslDir}/bin/fslmaths FM_UD_fmap -sub $medianValue -mas FM_UD_fmap_mag_brain_mask FM_UD_fmap

# create report picture of fmap overlaid onto whole-head mag image
fmapmin=$(${fslDir}/bin/fslstats FM_UD_fmap -R | awk '{ print $1 }')
${fslDir}/bin/fslmaths FM_UD_fmap -sub $fmapmin -add 10 -mas FM_UD_fmap_mag_brain_mask grot
fmapminmax=$(${fslDir}/bin/fslstats grot -l 1 -p 0.1 -p 95)
${fslDir}/bin/overlay 0 0 FM_UD_fmap_mag -a grot $fmapminmax fmap+mag

${fslDir}/bin/slicer fmap+mag  -s 3 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; ${fslDir}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png fmap+mag.png; rm sl?.png

# get a sigloss estimate and make a siglossed mag for forward warp
# TODO: assumes TE=30 now
${fslDir}/bin/sigloss -i FM_UD_fmap --te=.03 -m FM_UD_fmap_mag_brain_mask -s FM_UD_fmap_sigloss
siglossthresh=$(awk "BEGIN {print 1.0 - ( 10 / 100.0 )}")
${fslDir}/bin/fslmaths FM_UD_fmap_sigloss -mul FM_UD_fmap_mag_brain FM_UD_fmap_mag_brain_siglossed -odt float


${fslDir}/bin/fslmaths FM_UD_fmap_sigloss -thr $siglossthresh FM_UD_fmap_sigloss -odt float
${fslDir}/bin/overlay 1 0 FM_UD_fmap_mag_brain -a FM_UD_fmap_sigloss 0 1 FM_UD_sigloss+mag

${fslDir}/bin/slicer FM_UD_sigloss+mag  -s 3 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; ${fslDir}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png FM_UD_sigloss+mag.png; rm sl?.png

}


########## EPI to T1 (BBR) w/wo FieldMap #######
function EPItoT1reg() {
  echo "...Optimizing EPI (func) to T1 (highres) registration."


  # Look for output directory for EPI to T1 (create if necessary).
  if [[ ! -d ${epiWarpDir} ]]; then
    mkdir -p ${epiWarpDir}
  fi


  cp $t1Dir/T1_MNI_brain_wmseg.nii.gz ${epiWarpDir}/EPItoT1_wmseg.nii.gz
  # epi_reg will not link to this file well, have epi_reg create it from T1_brain

  # Source the T1 brain mask (to warp and apply to the EPI image)
  T1mask=$t1Dir/brainMask.nii.gz

  # Check for use of a FieldMap correction

  if [[ $fieldMapFlag == 1 ]]; then  ########## Process WITH field map ##########
    echo "......Registration With FieldMap Correction."

    preprocessFieldmaps ${fieldMap} ${fieldMapMag} ${fieldMapMagSkull}
    
    cp "$(dirname "${fieldMap}")"/FM_UD* ${epiWarpDir}/
    cp "$(dirname "${fieldMap}")"/fmap* ${epiWarpDir}/
    cp "$(dirname "${fieldMap}")"/grot.nii.gz ${epiWarpDir}/
    # Warp using FieldMap correction
    # Output will be a (warp) .nii.gz file


    if [[ "${regMode}" == "BBR" ]]; then
      echo "......Registration With BBR."
      clobber $epiWarpDir/EPItoT1.nii.gz &&\
      epi_reg --epi=${indir}/mcImgMean.nii.gz \
      --t1=${t1SkullData} \
      --t1brain=${t1Data} \
      --out=$epiWarpDir/EPItoT1 \
      --fmap=FM_UD_fmap_mag \
      --fmapmag=FM_UD_fmap_mag \
      --fmapmagbrain=FM_UD_fmap_mag_brain \
      --echospacing=${dwellTime} \
      --pedir=${peDir} --noclean -v
    else
      echo "......Registration With 6 DOF Rigid Body Trasformation."
      clobber ${epiWarpDir}/EPItoT1.mat &&\
      flirt -in ${indir}/mcImgMean.nii.gz \
      -ref ${t1Data} \
      -out ${epiWarpDir}/EPItoT1 \
      -omat ${epiWarpDir}/EPItoT1.mat \
      -cost corratio \
      -dof 6 \
      -searchrx -90 90 -searchry -90 90 -searchrz -90 90 \
      -interp trilinear

      #  epi_reg L127-L136:
      # These are consistent with the ones used in FUGUE (this has been checked)
      if [ $peDir = "x" ] ; then fdir="x"; fi
      if [ $peDir = "y" ] ; then fdir="y"; fi
      if [ $peDir = "z" ] ; then fdir="z"; fi
      if [ $peDir = "-x" ] ; then fdir="x-"; fi
      if [ $peDir = "-y" ] ; then fdir="y-"; fi
      if [ $peDir = "-z" ] ; then fdir="z-"; fi
      if [ $peDir = "x-" ] ; then fdir="x-"; fi
      if [ $peDir = "y-" ] ; then fdir="y-"; fi
      if [ $peDir = "z-" ] ; then fdir="z-"; fi


      cd ${epiWarpDir} || exit

      # epi_reg L284-L300
      # register fmap to structural image
      clobber EPItoT1_fieldmap2str &&\
      $fslDir/bin/flirt -in FM_UD_fmap_mag_brain -ref ${t1Data} -dof 6 -omat EPItoT1_fieldmap2str_init.mat &&\
      $fslDir/bin/flirt -in FM_UD_fmap_mag -ref ${t1SkullData} -dof 6 -init EPItoT1_fieldmap2str_init.mat -omat EPItoT1_fieldmap2str.mat -out EPItoT1_fieldmap2str -nosearch

      # unmask the fieldmap (necessary to avoid edge effects)
      $fslDir/bin/fslmaths FM_UD_fmap_mag_brain -abs -bin EPItoT1_fieldmaprads_mask
      $fslDir/bin/fslmaths FM_UD_fmap_mag -abs -bin -mul EPItoT1_fieldmaprads_mask EPItoT1_fieldmaprads_mask
      $fslDir/bin/fugue --loadfmap=FM_UD_fmap --mask=EPItoT1_fieldmaprads_mask --unmaskfmap --savefmap=EPItoT1_fieldmaprads_unmasked --unwarpdir=${fdir}   # the direction here should take into account the initial affine (it needs to be the direction in the EPI)

      # the following is a NEW HACK to fix extrapolation when fieldmap is too small
      clobber EPItoT1_fieldmaprads2str_pad0.nii.gz &&\
      $fslDir/bin/applywarp -i EPItoT1_fieldmaprads_unmasked -r ${t1SkullData} --premat=EPItoT1_fieldmap2str.mat -o EPItoT1_fieldmaprads2str_pad0
      $fslDir/bin/fslmaths EPItoT1_fieldmaprads2str_pad0 -abs -bin EPItoT1_fieldmaprads2str_innermask
      $fslDir/bin/fugue --loadfmap=EPItoT1_fieldmaprads2str_pad0 --mask=EPItoT1_fieldmaprads2str_innermask --unmaskfmap --unwarpdir=${fdir} --savefmap=EPItoT1_fieldmaprads2str_dilated
      $fslDir/bin/fslmaths EPItoT1_fieldmaprads2str_dilated EPItoT1_fieldmaprads2str

      # epi_reg L308-L315:
      echo "......Making warp fields and applying registration to EPI series"
      $fslDir/bin/convert_xfm -omat EPItoT1_inv.mat -inverse EPItoT1.mat
      $fslDir/bin/convert_xfm -omat EPItoT1_fieldmaprads2epi.mat -concat EPItoT1_inv.mat EPItoT1_fieldmap2str.mat
      $fslDir/bin/applywarp -i EPItoT1_fieldmaprads_unmasked -r ${indir}/mcImgMean.nii.gz --premat=EPItoT1_fieldmaprads2epi.mat -o EPItoT1_fieldmaprads2epi
      $fslDir/bin/fslmaths EPItoT1_fieldmaprads2epi -abs -bin EPItoT1_fieldmaprads2epi_mask
      $fslDir/bin/fugue --loadfmap=EPItoT1_fieldmaprads2epi --mask=EPItoT1_fieldmaprads2epi_mask --saveshift=EPItoT1_fieldmaprads2epi_shift --unmaskshift --dwell=${dwellTime} --unwarpdir=${fdir}
      clobber EPItoT1_warp.nii.gz &&\
      $fslDir/bin/convertwarp -r ${t1SkullData} -s EPItoT1_fieldmaprads2epi_shift --postmat=EPItoT1.mat -o EPItoT1_warp --shiftdir=${fdir} --relout
      $fslDir/bin/applywarp -i ${indir}/mcImgMean.nii.gz -r ${t1SkullData} -o EPItoT1 -w EPItoT1_warp --interp=spline --rel
    fi

    # Invert the affine registration (to get T1toEPI)
    clobber $epiWarpDir/T1toEPI.mat &&\
    convert_xfm -omat $epiWarpDir/T1toEPI.mat -inverse $epiWarpDir/EPItoT1.mat

    # Invert the nonlinear warp (to get T1toEPI)
    clobber $epiWarpDir/T1toEPI_warp.nii.gz &&\
    invwarp -w $epiWarpDir/EPItoT1_warp.nii.gz -r ${indir}/mcImgMean.nii.gz -o $epiWarpDir/T1toEPI_warp.nii.gz

    # Apply the inverted (T1toEPI) warp to the brain mask
    clobber ${indir}/mcImgMean_mask.nii.gz &&\
    applywarp --ref=${indir}/mcImgMean.nii.gz --in=${T1mask} --out=${indir}/mcImgMean_mask.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --datatype=char --interp=nn

    # Create a stripped version of the EPI (mcImg) file, apply the warp
    clobber ${indir}/mcImgMean_stripped.nii.gz &&\
    fslmaths ${indir}/mcImgMean.nii.gz -mas ${indir}/mcImgMean_mask.nii.gz ${indir}/mcImgMean_stripped.nii.gz
    clobber $epiWarpDir/EPIstrippedtoT1.nii.gz &&\
    applywarp --ref=${t1Data} --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPIstrippedtoT1.nii.gz --warp=$epiWarpDir/EPItoT1_warp.nii.gz

    # Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the second nonlinear warp (T1toEPI_warp.nii.gz) to get a warp from MNI to EPI
    clobber ${epiWarpDir}/MNItoEPI_warp.nii.gz &&\
    convertwarp --ref=${indir}/mcImgMean.nii.gz --warp1=${t1WarpDir}/MNItoT1_warp.nii.gz --warp2=${epiWarpDir}/T1toEPI_warp.nii.gz --out=${epiWarpDir}/MNItoEPI_warp.nii.gz --relout

    # Invert the warp to get EPItoMNI_warp.nii.gz
    clobber ${epiWarpDir}/EPItoMNI_warp.nii.gz &&\
    invwarp -w ${epiWarpDir}/MNItoEPI_warp.nii.gz -r $fslDir/data/standard/MNI152_T1_2mm.nii.gz -o ${epiWarpDir}/EPItoMNI_warp.nii.gz

    # Apply EPItoMNI warp to EPI file
    clobber $epiWarpDir/EPItoMNI.nii.gz &&\
    applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm.nii.gz --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz

    # Echo out warp files, wmedge to log
    echo "epiMask=${indir}/mcImgMean_mask.nii.gz" >> $logDir/rsParams
    echo "t1WMedge=${epiWarpDir}/EPItoT1_fast_wmedge.nii.gz" >> $logDir/rsParams
    echo "T1toEPIWarp=${epiWarpDir}/T1toEPI_warp.nii.gz" >> $logDir/rsParams
    echo "EPItoT1=${epiWarpDir}/EPIstrippedtoT1.nii.gz" >> $logDir/rsParams
    echo "EPItoT1Warp=${epiWarpDir}/EPItoT1_warp.nii.gz" >> $logDir/rsParams
    echo "MNItoEPIWarp=${epiWarpDir}/MNItoEPI_warp.nii.gz" >> $logDir/rsParams
    echo "EPItoMNI=${epiWarpDir}/EPItoMNI.nii.gz" >> $logDir/rsParams
    echo "EPItoMNIWarp=${epiWarpDir}/EPItoMNI_warp.nii.gz" >> $logDir/rsParams

  else
    echo "......Registration Without FieldMap Correction."

    if [[ "${regMode}" == "BBR" ]]; then
      echo "......Registration With BBR."
      clobber $epiWarpDir/EPItoMNI.nii.gz &&\
      epi_reg --epi=${indir}/mcImgMean.nii.gz \
      --t1=${t1SkullData} \
      --t1brain=${t1Data} \
      --out=$epiWarpDir/EPItoT1 \
      --noclean
    else
      echo "......Registration With 6 DOF Rigid Body Trasformation."
      clobber ${epiWarpDir}/EPItoT1.mat &&\
      flirt -in ${indir}/mcImgMean.nii.gz \
      -ref ${t1Data} \
      -out ${epiWarpDir}/EPItoT1 \
      -omat ${epiWarpDir}/EPItoT1.mat \
      -cost corratio \
      -dof 6 \
      -searchrx -90 90 -searchry -90 90 -searchrz -90 90 \
      -interp trilinear
    fi

    # Invert the affine registration (to get T1toEPI)
    clobber $epiWarpDir/T1toEPI.mat &&\
    convert_xfm -omat $epiWarpDir/T1toEPI.mat -inverse $epiWarpDir/EPItoT1.mat

    # Apply the inverted (T1toEPI) mat file to the brain mask
    clobber ${indir}/mcImgMean_mask.nii.gz &&\
    flirt -in $T1mask -ref ${indir}/mcImgMean.nii.gz -applyxfm -init $epiWarpDir/T1toEPI.mat -out ${indir}/mcImgMean_mask.nii.gz -interp nearestneighbour -datatype char

    # Create a stripped version of the EPI (mcImg) file, apply the mat file
    clobber $epiWarpDir/EPIstrippedtoT1.nii.gz &&\
    fslmaths ${indir}/mcImgMean.nii.gz -mas ${indir}/mcImgMean_mask.nii.gz ${indir}/mcImgMean_stripped.nii.gz &&\
    flirt -in ${indir}/mcImgMean_stripped.nii.gz -ref ${t1Data} -applyxfm -init $epiWarpDir/EPItoT1.mat -out $epiWarpDir/EPIstrippedtoT1.nii.gz

    # Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the affine transform (T1toEPI.mat) to get a warp from MNI to EPI
    clobber ${epiWarpDir}/MNItoEPI_warp.nii.gz &&\
    convertwarp --ref=${indir}/mcImgMean.nii.gz --warp1=${t1WarpDir}/MNItoT1_warp.nii.gz --postmat=${epiWarpDir}/T1toEPI.mat --out=${epiWarpDir}/MNItoEPI_warp.nii.gz --relout

    # Invert the warp to get EPItoMNI_warp.nii.gz
    clobber ${epiWarpDir}/EPItoMNI_warp.nii.gz &&\
    invwarp -w ${epiWarpDir}/MNItoEPI_warp.nii.gz -r $fslDir/data/standard/MNI152_T1_2mm.nii.gz -o ${epiWarpDir}/EPItoMNI_warp.nii.gz

    # Apply EPItoMNI warp to EPI file
    clobber --out=$epiWarpDir/EPItoMNI.nii.gz &&\
    applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm.nii.gz --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz

    # Echo out warp files, wmedge to log
    echo "epiMask=${indir}/mcImgMean_mask.nii.gz" >> $logDir/rsParams
    echo "t1WMedge=${epiWarpDir}/EPItoT1_fast_wmedge.nii.gz" >> $logDir/rsParams
    echo "T1toEPIWarp=${epiWarpDir}/T1toEPI.mat" >> $logDir/rsParams
    echo "EPItoT1=${epiWarpDir}/EPIstrippedtoT1.nii.gz" >> $logDir/rsParams
    echo "EPItoT1Warp=${epiWarpDir}/EPItoT1.mat" >> $logDir/rsParams
    echo "MNItoEPIWarp=${epiWarpDir}/MNItoEPI_warp.nii.gz" >> $logDir/rsParams
    echo "EPItoMNI=${epiWarpDir}/EPItoMNI.nii.gz" >> $logDir/rsParams
    echo "EPItoMNIWarp=${epiWarpDir}/EPItoMNI_warp.nii.gz" >> $logDir/rsParam

  fi

}

###############################################################################

##########
## MAIN ##
##########
#Setting variable for FSL base directory
fslDir=$FSLDIR
export fslDir

# Parse them baby

if [ $# -lt 4 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 $1);
    case "$iarg"
	in
	--epi)
	    epiData=`get_arg1 $1`;
      export epiData;
	    shift;;
	--t1)
	    t1SkullData=`get_arg1 $1`;
      export t1SkullData;
	    shift;;
  --t1brain)
	    t1Data=`get_arg1 $1`;
      export t1Data;
	    shift;;
	--fmap)
	    fieldMap=`get_arg1 $1`;
      export fieldMap;
	    fieldMapFlag=1;
      export fieldMapFlag;
	    shift;;
	--fmapmag)
	    fieldMapMagSkull=`get_arg1 $1`;
      export fieldMapMagSkull;
	    shift;;
	--fmapmagbrain)
	    fieldMapMag=`get_arg1 $1`;
      export fieldMapMag;
	    shift;;
  --dwelltime)
      dwellTime=`get_arg1 $1`;
      export dwellTime;
      shift;;
  --pedir)
      peDir=`get_arg1 $1`;
      export peDir;
      shift;;
  --regmode)
      regMode=`get_arg1 $1`;
      export regMode
      echo Registration mode = $regMode;
      shift;;
  --lesionmask)
    lesionMask=`get_imgarg1 $1`;
    export lesionMask;
    export lesionMaskFlag=1;
    shift;;
  -h)
      Usage;
      exit 0;;
  *)
      echo "Unrecognised option $1" 1>&2
      Usage
      exit 1

    esac
  done


scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $0)
scriptDir=$(dirname $scriptPath)
spikeThreshInt=300
spikeThresh=$(echo $spikeThreshInt 100 | awk '{print ($1/$2)}')


# First check for proper input files
if [ "$epiData" == "" ]; then
  echo "Error: The restingStateImage (-E) is a required option"
  exit 1
fi

if [ "$t1Data" == "" ]; then
  echo "Error: The T1 data (-A) is a required option"
  exit 1
fi

if [ "$t1SkullData" == "" ]; then
  echo "Error: The T1 (with skull) data (-a) is a required option"
  exit 1
fi


# A few default parameters (if input not specified, these parameters are assumed)
if [[ "${regMode}" == "" ]]; then
  regMode="BBR"
fi

if [[ $overwriteFlag == "" ]]; then
  overwriteFlag=0
fi

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





# If FieldMap correction is chosen, check for proper input files
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



# Echo out all input parameters into a log
logDir=$(dirname $epiData)
export logDir

echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-A $t1Data" >> $logDir/rsParams_log
echo "-a $t1SkullData" >> $logDir/rsParams_log
if [[ $lesionMaskFlag == 1 ]]; then
  echo "-l $lesionMask" >> $logDir/rsParams_log
fi
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $logDir/rsParams_log
  echo "-b $fieldMap" >> $logDir/rsParams_log
  echo "-v $fieldMapMagSkull" >> $logDir/rsParams_log
  echo "-x $fieldMapMag" >> $logDir/rsParams_log
  echo "-D $dwellTime" >> $logDir/rsParams_log
fi
echo "-d $peDir" >> $logDir/rsParams_log
if [[ $overwriteFlag == 1 ]]; then
  echo "-c" >> $logDir/rsParams_log
fi
echo "$(date)" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log

# If user defines overwrite, note in rsParams file
if [[ $overwriteFlag == 1 ]]; then
  echo "_qualityCheck_clobber" >> $logDir/rsParams
fi




indir=$logDir


echo "Running $0 ..."


clobber $indir/mcImg.nii.gz &&\
motionCorrection ${epiData}

t1Dir=$(dirname $t1Data)
export t1Dir
t1WarpDir=$t1Dir/T1forWarp
export t1WarpDir

fslmaths $t1Data -bin $t1Dir/brainMask.nii.gz -odt char

clobber ${t1WarpDir}/MNItoT1_warp.nii.gz &&\
T1toMNIreg

segDir=${t1Dir}/tissueSeg
export segDir

clobber ${t1Dir}/T1_MNI_brain_wmseg.nii.gz &&\
tissueSeg

epiWarpDir=${indir}/EPItoT1optimized_${regMode}
export epiWarpDir

clobber $epiWarpDir/EPItoMNI.nii.gz &&\
EPItoT1reg

########## Skullstrip the EPI data ######################

# skull-strip mcImgMean volume, write output to rsParams file
mcMask=$(cat $logDir/rsParams | grep "epiMask=" | awk -F"=" '{print $2}' | tail -1)
clobber $indir/mcImg_stripped.nii.gz &&\
fslmaths $indir/mcImg.nii.gz -mas $mcMask $indir/mcImg_stripped.nii.gz

# Leftover section from dataPrep (to create "RestingState.nii.gz")
clobber $indir/RestingState.nii.gz &&\
fslmaths ${epiData} -mas $mcMask $indir/RestingState.nii.gz

echo "epiStripped=$indir/RestingState.nii.gz" >> $indir/rsParams
echo "epiMC=$indir/mcImg_stripped.nii.gz" >> $indir/rsParams

################################################################





########## SNR Estimation ######################
echo "...Estimating SNR."
cd $indir || exit
########## In vs. Out of Brain SNR Calculation #
echo "...SNR mask creation."

# Calculate a few dimensions
xdim=$(fslhd $indir/mcImg.nii.gz | grep ^dim1 | awk '{print $2}')
ydim=$(fslhd $indir/mcImg.nii.gz | grep ^dim2 | awk '{print $2}')
# zdim=$(fslhd $indir/mcImg.nii.gz | grep ^dim3 | awk '{print $2}')
tdim=$(fslhd $indir/mcImg.nii.gz | grep ^dim4 | awk '{print $2}')
xydimTenth=$(echo $xdim 0.06 | awk '{print int($1*$2)}')
ydimMaskAnt=$(echo $ydim 0.93 | awk '{print int($1*$2)}')
ydimMaskPost=$(echo $ydim 0.07 | awk '{print int($1*$2)}')

################################################################

# Create a folder to dump temp data into
if [ ! -e SNR ]; then
  mkdir SNR
fi

snrDir=${indir}/SNR


# Create a GM segmentation mask (copy data from FAST processing)
clobber $snrDir/T1_GM.nii.gz &&\
fslmaths $segDir/T1_seg_1.nii.gz -bin $snrDir/T1_GM.nii.gz -odt char


echo "...Warping GM/WM/CSF mask to EPI space"
# Warp GM, WM and CSF to EPI space
# WM/CSF will be used in MELODIC s/n determination


# Check for FieldMap correction.  If used, will have to applywarp, othewise use flirt with the .mat file
if [[ $fieldMapFlag == 1 ]]; then
  # Apply the warp file
  clobber $snrDir/RestingState_GM.nii.gz &&\
  applywarp -i $snrDir/T1_GM.nii.gz -o $snrDir/RestingState_GM.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn --datatype=char

  # Transfer over GM/WM/CSF from original segmentation, without binarizing/conversion to 8bit
  clobber $snrDir/CSF_to_RS.nii.gz &&\
  applywarp -i $segDir/T1_seg_0.nii.gz -o $snrDir/CSF_to_RS.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn
  clobber $snrDir/GM_to_RS.nii.gz &&\
  applywarp -i $segDir/T1_seg_1.nii.gz -o $snrDir/GM_to_RS.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn
  clobber $snrDir/WM_to_RS.nii.gz &&\
  applywarp -i $segDir/T1_seg_2.nii.gz -o $snrDir/WM_to_RS.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn

  # Echo out location of GM/WM/CSF (EPI) to rsParams file
  echo "epiCSF=${snrDir}/CSF_to_RS.nii.gz" >> $indir/rsParams
  echo "epiGM=${snrDir}/GM_to_RS.nii.gz" >> $indir/rsParams
  echo "epiWM=${snrDir}/WM_to_RS.nii.gz" >> $indir/rsParams

  echo "...Creating tissue-based masks for CompCor regression."

  # Create tissue masks from eroded partial volume estimates (pve)
  # The WM pve mask was restricted using a 99% probability threshold and eroded at the 2-voxel level (8 mm)
  # The CSF pve mask was restricted using a 90% probability threshold.
  clobber $snrDir/WM_pve_to_RS_thresh_ero.nii.gz &&\
  applywarp --in=$segDir/T1_pve_2.nii.gz --out=$snrDir/WM_pve_to_RS.nii.gz --ref=${indir}/mcImgMean.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn &&\
  fslmaths $snrDir/WM_pve_to_RS.nii.gz -thr .99 -bin -kernel box 8 -ero $snrDir/WM_pve_to_RS_thresh_ero.nii.gz

  clobber $snrDir/GM_pve_to_RS_thresh.nii.gz &&\
  applywarp --in=$segDir/T1_pve_1.nii.gz --out=$snrDir/GM_pve_to_RS.nii.gz --ref=${indir}/mcImgMean.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn &&\
  fslmaths $snrDir/GM_pve_to_RS.nii.gz -thr .90 -bin $snrDir/GM_pve_to_RS_thresh.nii.gz -odt char

  clobber $snrDir/CSF_pve_to_RS_thresh.nii.gz &&\
  applywarp --in=$segDir/T1_pve_0.nii.gz --out=$snrDir/CSF_pve_to_RS.nii.gz --ref=${indir}/mcImgMean.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn &&\
  fslmaths $snrDir/CSF_pve_to_RS.nii.gz -thr .99 -bin $snrDir/CSF_pve_to_RS_thresh.nii.gz
else
  # Apply the affine .mat file
  clobber $snrDir/RestingState_GM.nii.gz &&\
  flirt -in $snrDir/T1_GM.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/RestingState_GM.nii.gz -interp nearestneighbour -datatype char

  # Transfer over GM/WM/CSF from original segmentation, without binarizing/conversion to 8bit
  clobber $snrDir/CSF_to_RS.nii.gz &&\
  flirt -in $segDir/T1_seg_0.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/CSF_to_RS.nii.gz -interp nearestneighbour
  clobber $snrDir/GM_to_RS.nii.gz &&\
  flirt -in $segDir/T1_seg_1.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/GM_to_RS.nii.gz -interp nearestneighbour
  clobber $snrDir/WM_to_RS.nii.gz &&\
  flirt -in $segDir/T1_seg_2.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/WM_to_RS.nii.gz -interp nearestneighbour

  # Echo out location of GM/WM/CSF (EPI) to rsParams file
  echo "epiCSF=${snrDir}/CSF_to_RS.nii.gz" >> $indir/rsParams
  echo "epiGM=${snrDir}/GM_to_RS.nii.gz" >> $indir/rsParams
  echo "epiWM=${snrDir}/WM_to_RS.nii.gz" >> $indir/rsParams

  echo "...Creating tissue-based masks for CompCor regression."

  # Create tissue masks from eroded partial volume estimates (pve)
  # The WM pve mask was restricted using a 99% probability threshold and eroded at the 2-voxel level (8 mm)
  # The CSF pve mask was restricted using a 90% probability threshold.
  clobber $snrDir/WM_pve_to_RS_thresh_ero.nii.gz &&\
	flirt -in $segDir/T1_pve_2.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/WM_pve_to_RS.nii.gz -interp nearestneighbour &&\
	fslmaths $snrDir/WM_pve_to_RS.nii.gz -thr .99 -bin -kernel box 8 -ero $snrDir/WM_pve_to_RS_thresh_ero.nii.gz

	clobber $snrDir/GM_pve_to_RS_thresh.nii.gz &&\
	flirt -in $segDir/T1_pve_1.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/GM_pve_to_RS.nii.gz -interp nearestneighbour &&\
	fslmaths $snrDir/GM_pve_to_RS.nii.gz -thr .90 -bin $snrDir/GM_pve_to_RS_thresh.nii.gz -odt char

	clobber  $snrDir/CSF_pve_to_RS_thresh.nii.gz &&\
	flirt -in $segDir/T1_pve_0.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/CSF_pve_to_RS.nii.gz -interp nearestneighbour &&\
	fslmaths $snrDir/CSF_pve_to_RS.nii.gz -thr .99 -bin $snrDir/CSF_pve_to_RS_thresh.nii.gz
fi


# smooth output to get rid of pixellation
3dmerge -doall -prefix RestingState_GMsmooth.nii.gz -session $snrDir -1blur_fwhm 5 $snrDir/RestingState_GM.nii.gz -overwrite
fslmaths $snrDir/RestingState_GMsmooth.nii.gz -add $snrDir/RestingState_GM.nii.gz -bin $snrDir/RestingState_GMfinal.nii.gz -odt char

# Strip out GM from EPI
clobber $snrDir/RestingState_GM4d.nii.gz &&\
fslmaths $indir/mcImg.nii.gz -mul $snrDir/RestingState_GMfinal.nii.gz $snrDir/RestingState_GM4d.nii.gz


echo "...Calculating SNR measurements per TR."
# Split 4D into separate files (for calculating mean of each TR)
if [ ! -e $snrDir/GMtsplit ]; then
  mkdir -p $snrDir/GMtsplit
fi
fslsplit $snrDir/RestingState_GM4d.nii.gz $snrDir/GMtsplit/RestingState_GM -t

# Calculate Mean value of signal per TR
for data in $snrDir/GMtsplit/RestingState_GM*gz
do
  fslstats $data -M  >> GM_Mean.par
done

# Create ROIs for calculating anterior and posterior noise (on Raw EPI) - based on 6% of xydimensions
$scriptDir/makeROI_Noise.sh $ydimMaskAnt $xydimTenth mcImgMean.nii.gz $snrDir/NoiseAntMask
$scriptDir/makeROI_Noise.sh $ydimMaskPost $xydimTenth mcImgMean.nii.gz $snrDir/NoisePostMask

# Strip out Anterior/Posterior Noise from EPI
fslmaths $indir/mcImg.nii.gz -mul $snrDir/NoiseAntMask.nii.gz $snrDir/RestingState_NoiseAntMask.nii.gz
fslmaths $indir/mcImg.nii.gz -mul $snrDir/NoisePostMask.nii.gz $snrDir/RestingState_NoisePostMask.nii.gz

# Split 4D (Anterior/Posterior Noise) into separate files (for calculating mean of each TR)
if [ ! -e $snrDir/Noisetsplit ]; then
  mkdir -p $snrDir/Noisetsplit
fi

tsplitDir=$snrDir/Noisetsplit

fslsplit $snrDir/RestingState_NoiseAntMask.nii.gz $tsplitDir/RestingState_AntNoise -t
fslsplit $snrDir/RestingState_NoisePostMask.nii.gz $tsplitDir/RestingState_PostNoise -t

# Calculate Mean value of Noise (Anterior and Posterior) per TR
for data in $tsplitDir/RestingState_AntNoise*gz
do
  fslstats $data -M  >> AntNoise_Mean.par
done

for data in $tsplitDir/RestingState_PostNoise*gz
do
  fslstats $data -M  >> PostNoise_Mean.par
done

# Calculate Noise (signal mean), signal to noise for each TR
i="1"
while [ $i -lt $tdim ]
do
  AntNoise=$(cat AntNoise_Mean.par | head -$i | tail -1)
  # Controlling for 0.0000 to be read as 0 (to avoid division by zero awk errors)
  AntNoisebin=$(echo $AntNoise | awk '{print int($1)}')
  PostNoise=$(cat PostNoise_Mean.par | head -$i | tail -1)
  # Controlling for 0.0000 to be read as 0 (to avoid division by zero awk errors)
  PostNoisebin=$(echo $PostNoise | awk '{print int($1)}')
  echo "antnoise${i} = $AntNoise" >> testNoise.txt
  echo "postnoise${i} = $PostNoise" >> testNoise.txt
  NoiseAvg=$(echo $AntNoise $PostNoise | awk '{print (($1+$2)/2)}')
  NoiseAvgbin=$(echo $NoiseAvg | awk '{print int($1)}')
  echo "noiseavg${i} = $NoiseAvg" >> testNoise.txt
  GMMean=$(cat GM_Mean.par | head -$i | tail -1)
  echo "gmmean${i} = $GMMean" >> testNoise.txt

  # Avoid division by zero awk errors
  if [ $AntNoisebin == 0 ]; then
AntSigNoise=0
  else
AntSigNoise=$(echo $GMMean $AntNoise | awk '{print $1/$2}')
  fi
  echo "antsignoise${i} = $AntSigNoise" >> testNoise.txt

  # Avoid division by zero awk errors
  if [ $PostNoisebin == 0 ]; then
PostSigNoise=0
  else
PostSigNoise=$(echo $GMMean $PostNoise | awk '{print $1/$2}')
  fi
  echo "postsignoise${i} = $PostSigNoise" >> testNoise.txt

  # Avoid division by zero awk errors
  if [ $NoiseAvgbin == 0 ]; then
SigNoiseAvg=0
  else
SigNoiseAvg=$(echo $GMMean $NoiseAvg | awk '{print $1/$2}')
  fi
  echo "$AntSigNoise $PostSigNoise $SigNoiseAvg" >> SigNoise.par
  echo "$NoiseAvg" >> NoiseAvg.par

i=$[$i+1]
done
################################################################



########## Plot out Ant/Post Noise, Global SNR #
clobber SigNoisePlot.png &&\
fsl_tsplot -i SigNoise.par -o SigNoisePlot.png -t 'Signal to Noise Ratio per TR' -a Anterior,Posterior,Average -u 1 --start=1 --finish=3 -w 800 -h 300
clobber NoisePlot.png &&\
fsl_tsplot -i AntNoise_Mean.par,PostNoise_Mean.par,NoiseAvg.par -o NoisePlot.png -t 'Noise (Mean Intensity) per TR' -a Anterior,Posterior,Average -u 1 -w 800 -h 300

################################################################



########## Temporal filtering (legacy option) ##
# NOT suggested to run until just before nuisance regression
# To maintain consistency with previous naming, motion-corrected image is just renamed
# Updating to call file "nonfiltered" to avoid any confusion down the road
cp $indir/mcImg.nii.gz $indir/nonfilteredImg.nii.gz

################################################################



########## Global SNR Estimation ###############
clobber $indir/nonfilteredMeanImg &&\
echo "...Calculating signal to noise measurements" &&\
fslmaths $indir/nonfilteredImg -Tmean $indir/nonfilteredMeanImg

clobber $indir/nonfilteredStdImg &&\
fslmaths $indir/nonfilteredImg -Tstd $indir/nonfilteredStdImg

clobber $indir/nonfilteredSNRImg &&\
fslmaths $indir/nonfilteredMeanImg -div $indir/nonfilteredStdImg $indir/nonfilteredSNRImg &&\
fslmaths $indir/nonfilteredSNRImg -mas $indir/mcImgMean_mask $indir/nonfilteredSNRImg
SNRout=$(fslstats $indir/nonfilteredSNRImg -M)

# Get information for timecourse
echo "$indir rest $SNRout" >> ${indir}/SNRcalc.txt

################################################################



########## Spike Detection #####################
echo "...Detecting time series spikes"

  if [ -e ${indir}/SPIKES.txt ]; then
rm ${indir}/SPIKES.txt
  fi

  if [ -e ${indir}/evspikes.txt ]; then
rm ${indir}/evspikes.txt
  fi

  if [ -e ${indir}/tmp ]; then
rm -rf ${indir}/tmp
  fi

####  CALCULATE SPIKES BASED ON NORMALIZED TIMECOURSE OF GLOBAL MEAN ####
clobber ${indir}/global_mean_ts.dat &&\
fslstats -t nonfilteredImg.nii.gz -M >> ${indir}/global_mean_ts.dat
ImgMean=$(fslstats $indir/nonfilteredImg.nii.gz -M)
echo "Image mean is $ImgMean"
meanvolsd=$($scriptDir/sd.sh ${indir}/global_mean_ts.dat)
echo "Image standard deviation is $meanvolsd"

vols=$(cat ${indir}/global_mean_ts.dat)

for vol in $vols
do
  Diffval=$(echo "scale=6; ${vol}-${ImgMean}" | bc)
  Normscore=$(echo "scale=6; ${Diffval}/${meanvolsd}" | bc)
  echo "$Normscore" >>  ${indir}/Normscore.par

  echo $Normscore | awk '{if ($1 < 0) $1 = -$1; if ($1 > 3) print 1; else print 0}' >> ${indir}/evspikes.txt
done

clobber normscore.png &&\
fsl_tsplot -i Normscore.par -t 'Normalized global mean timecourse' -u 1 --start=1 -a normedts -w 800 -h 300 -o normscore.png

################################################################




########## AFNI QC tool ########################
  # AFNI graphing tool is fugly.  Replacing with FSL

clobber 3dTqual.png &&\
3dTqual -range -automask nonfilteredImg.nii.gz >> tmpPlot &&\
fsl_tsplot -i tmpPlot -t '3dTqual Results (Difference From Norm)' -u 1 --start=1 -a quality_index -w 800 -h 300 -o 3dTqual.png &&\
rm tmpPlot

################################################################



########## Spike Report ########################

spikeCount=$(cat ${indir}/evspikes.txt | awk '/1/{n++}; END {print n+0}')

cd ${indir} || exit

################################################################



########## Report Output to HTML File ##########

echo "<h1>Resting State Analysis</h1>" > analysisResults.html
echo "<br><b>Directory: </b>$indir" >> analysisResults.html
analysisDate=$(date)
echo "<br><b>Date: </b>$analysisDate" >> analysisResults.html
user=$(whoami)
echo "<br><b>User: </b>$user<br><hr>" >> analysisResults.html
echo "<h2>Motion Results</h2>" >> analysisResults.html
echo "<br><img src=rot.png alt=rotations><br><br><img src=rot_mm.png alt=rotations_mm><br><br><img src=trans.png alt=translations><br><br><img src=rot_trans.png alt=rotations_translations><br><br><img src=disp.png alt=displacement><hr>" >> analysisResults.html
echo "<h2>SNR Results</h2>" >> analysisResults.html
echo "<br><b>Scan SNR: </b>$SNRout" >> analysisResults.html
echo "<br>$spikeCount spikes detected at ${spikeThresh} standard deviation threshold" >> analysisResults.html
echo "<br><br><img src=normscore.png" >> analysisResults.html
echo "<br>" >> analysisResults.html
echo "<br><b>AFNI 3dTqual Results</b><br><br>" >> analysisResults.html
echo "<br><img src=3dTqual.png" >> analysisResults.html
echo "<br>" >> analysisResults.html

################################################################

echo "$0 Complete"
echo ""
echo ""
