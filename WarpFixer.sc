#!/bin/bash

########################################################################
# Script to fix upper-level processing when flirt/fnirt or fieldMap/BBR
#  are changed from preproc
########################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`


function printCommandLine {
  echo "Usage: WarpFixer.sh -E restingStateImage -N nuisanceROI -A T1image -t tr -T te -H highpass -L lowpass"
  echo " where"
  echo "  -E Resting State file (motion-corrected, skull-stripped)"
  echo "  -N Data file with nuisance ROI list, one seed per line"
  echo "  -A T1 file (skull-stripped)"
  echo "  -t TR time (seconds)"
  echo "  -T TE (milliseconds) (default to 30 ms)"
  echo "  -L lowpass filter frequency (Hz) (e.g. 0.08 Hz (2.5 sigma))"
  echo "  -H highpass filter frequency (Hz) (e.g. 0.008 Hz (25.5 sigma / 120 s))"
  exit 1
}


# Parse Command line arguments
while getopts “hE:N:A:t:T:L:H:” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    N)
      nuisanceList=`cat $OPTARG`
      nuisanceInFile=$OPTARG
      ;;
    A)
      t1Data=$OPTARG
      ;;
    t)
      tr=$OPTARG
      ;;
    T)
      te=$OPTARG
      ;;
    L)
      lowpassArg=$OPTARG
      ;;
    H)
      highpassArg=$OPTARG
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done



echo "Running $0 ..."


indir=`dirname $epiData`





##########restingStatePreprocess############################################################

###### FEAT registration correction ########################################
echo "...Fixing FEAT registration QC images."

cd $indir
analysis=preproc
preprocfeat=${analysis}.feat
preprocDir=$indir/${preprocfeat}

regDir=$preprocDir/reg

##Copy over appropriate files from previous processing
  #T1 (highres)
t1toMNI=`cat $indir/rsParams | grep "T1toMNI=" | tail -1 | awk -F"=" '{print $2}'`
fslmaths $t1toMNI $regDir/highres2standard.nii.gz
  #EPI (example_func)
epitoMNI=`cat $indir/rsParams | grep "EPItoMNI=" | tail -1 | awk -F"=" '{print $2}'`
fslmaths $epitoMNI $regDir/example_func2standard.nii.gz
  #MNI (standard)
    #Transforms
epiWarpDirtmp=`cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}'`
  epiWarpDir=`dirname $epiWarpDirtmp`
    #T1toMNI
T1WarpDirtmp=`cat $indir/rsParams | grep "MNItoT1IWarp=" | tail -1 | awk -F"=" '{print $2}'`
  T1WarpDir=`dirname $T1WarpDirtmp`
cp $T1WarpDir/coef_T1_to_MNI152.nii.gz $regDir/highres2standard_warp.nii.gz


#Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
cd $regDir

#highres2standard
echo "......highres2standard"
slicer highres2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png

slicer standard.nii.gz highres2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png

pngappend highres2standard1.png - highres2standard2.png highres2standard.png

rm sl*.png

#example_func2standard
echo "......func2standard"
slicer example_func2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png

slicer standard.nii.gz example_func2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png

pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png

rm sl*.png

################################################################










##########removeNuisanceRegressor############################################################

analysis=nuisancereg
analysis2=nuisanceregFix
nuisancefeat=nuisancereg.feat
preprocfeat=preproc.feat
melodicfeat=melodic.ica
fsf=${analysis}.fsf
fsf2=${analysis2}.fsf
logDir=$indir
epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

#Echo out nuisance ROIs to a text file in input directory.

if [ -e $indir/nuisance_rois.txt ]; then
  rm $indir/nuisance_rois.txt
fi

for i in $nuisanceList
do
  echo $i >> $indir/nuisance_rois.txt
done

nuisanceroiList=$indir/nuisance_rois.txt

roiList=`echo $nuisanceList`

#### Nuisance ROI mapping ############
echo "...Warping Nuisance ROIs to EPI space"

cd $indir/${preprocfeat}

for roi in $roiList
do
  echo "......Mapping nuisance regressor $roi"

  ###Need to use warp from MNI to EPI from qualityCheck
  MNItoEPIwarp=`cat $indir/rsParams | grep "MNItoEPIWarp=" | tail -1 | awk -F"=" '{print $2}'`
  applywarp --ref=$indir/mcImgMean_stripped.nii.gz --in=${scriptDir}/ROIs/${roi}.nii.gz --out=rois/${roi}_native.nii.gz --warp=$MNItoEPIwarp --datatype=float
  fslmaths rois/${roi}_native.nii.gz -thr 0.5 rois/${roi}_native.nii.gz
  fslmaths rois/${roi}_native.nii.gz -bin rois/${roi}_native.nii.gz
  #Remove old time series
    rm rois/mean_${roi}_ts.txt
  fslmeants -i $epiDataFilt -o rois/mean_${roi}_ts.txt -m rois/${roi}_native.nii.gz
done

#################################


##Move all old nuisancereg processing to another directory, just rerun from scratch

mkdir $indir/OLD_nuisance_old_transforms

oldDir=$indir/OLD_nuisance_old_transforms

cd $indir

mv nuisancereg.fsf $oldDir
mv run_normseedregressors.m $oldDir
mv tsregressorslp $oldDir
mv global_norm.png $oldDir
mv latvent_norm.png $oldDir
mv wmroi_norm.png $oldDir
mv nuisanceregFix.fsf $oldDir
mv nuisancereg.feat $oldDir
mv run_motionscrub.m $oldDir
mv motion_scrubbing_info.txt $oldDir
mv seeds.txt $oldDir
mv run_seedregistrationcheck.m $oldDir
mv seedQC $oldDir
mv run_firstlevelseeding_parallel.m $oldDir
mv run_firstlevelseeding_parallel_ms.m $oldDir
mv pccrsp.png $oldDir
mv rmot.png $oldDir
mv ampfc.png $oldDir
mv dmpfc.png $oldDir
mv lamyg.png $oldDir
mv Linsu.png $oldDir
mv tpol.png $oldDir
mv seedCorrelation $oldDir
mv rtpol.png $oldDir


#### FEAT setup ############
echo "... FEAT setup"

cd $indir

#Set a few variables from data
  #epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
peDirBase=`cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}'`
if [[ $peDirBase == "" ]]; then
    peDirNEW="y-"
else
  peDirTmp1=`echo $peDirBase | cut -c1`
  peDirTmp2=`echo $peDirBase | cut -c2`
  if [[ "$peDirTmp1" == "-" ]]; then
    peDirNEW="${peDirTmp2}${peDirTmp1}"
  else
    peDirNEW="${peDirBase}"
  fi
fi

numtimepoint=`fslinfo $epiDataFilt | grep ^dim4 | awk '{print $2}'`

dwellTimeBase=`cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}'`
if [[ $dwellTimeBase == "" ]]; then
  dwellTime=0.00056
else
  dwellTime=$dwellTimeBase
fi


cat $scriptDir/dummy_nuisance.fsf | sed 's|SUBJECTPATH|'${indir}'|g' | \
                                    sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
                                    sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                    sed 's|SCANTE|'${te}'|g' | \
                                    sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                    sed 's|SUBJECTTR|'${tr}'|g' | \
                                    sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                    sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                    sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf}

#################################



#### Calculate Nuisance Regressor time-series ############

# Create Regressors using Octave
echo "...Creating Regressors"
filename=run_normseedregressors.m;
cat > $filename << EOF

% It is matlab script
close all;
clear all;
addpath('${scriptDir}');
statsScripts=['${scriptDir}','/Octave/statistics'];
addpath(statsScripts);
nuisanceRoiFile=['${nuisanceroiList}'];
fid=fopen(nuisanceRoiFile);
roiList_tmp=textscan(fid,'%s');
fclose(fid);
roiList=cell(3,1);

for i=1:3
  roiList{i,1}=(roiList_tmp{1,1}(i));
end


featdir='${preprocfeat}';
includemotion=1;
normseedregressors('${indir}',roiList,featdir,includemotion)
quit;
EOF

# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system $indir/$filename 
else
  matlab -nodisplay -r "run $indir/$filename"
fi


echo "<hr><h2>Nuisance Regressors</h2>" >> $indir/analysisResults.html

#################################



#### Bandpass Motion Regressors ######

echo "...Bandpass filtering Motion Regressors"

#Filtering ONLY if low/highpass don't both = 0
mclist='1 2 3 4 5 6'
for mc in ${mclist}
do
    cp ${indir}/tsregressorslp/mc${mc}_normalized.txt ${indir}/tsregressorslp/mc${mc}_normalized.1D
    1dBandpass $highpassArg $lowpassArg ${indir}/tsregressorslp/mc${mc}_normalized.1D > ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D   
    cat ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D > ${indir}/tsregressorslp/mc${mc}_normalized.txt
done

#################################



#### Plotting Regressor time courses ######

echo "...Plotting Regressor time series"

for roi in $roiList
do
  fsl_tsplot -i $indir/tsregressorslp/${roi}_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o $indir/${roi}_norm.png
done

#################################



#### FEAT Regression ######
    
#Run feat
echo "...Running FEAT (nuisancereg)"
feat ${indir}/${fsf}

#################################



###### FEAT registration correction ########################################

echo "...Fixing FEAT registration QC images."

  #http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
    #ss: "How can I insert a custom registration into a FEAT analysis?"

regDir=$indir/${nuisancefeat}/reg





#Remove all FEAT files (after backup), repopulate with proper files
cp -r $regDir $indir/${nuisancefeat}/regORIG
rm -rf $regDir
    
##Copy over appropriate reg directory from preproc.feat processing
  #Copy over "preproc" registration directory
cp -r $indir/${preprocfeat}/reg $indir/${nuisancefeat}     

#Backup original design file
cp $indir/${nuisancefeat}/design.fsf $indir/${nuisancefeat}/designORIG.fsf


#Rerun FEAT to fix only post-stats portions (with no registrations)
  #VOXTOT
epiVoxTot=`fslstats ${epiDataFilt} -v | awk '{print $1}'`

  #NUISANCEDIR
nuisanceDir=$indir/${nuisancefeat}

cat $scriptDir/dummy_nuisance_regFix.fsf | sed 's|SUBJECTPATH|'${indir}'|g' | \
                                           sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                           sed 's|NUISANCEDIR|'${nuisanceDir}'|g' | \
                                           sed 's|SCANTE|'${te}'|g' | \
                                           sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                           sed 's|SUBJECTTR|'${tr}'|g' | \
                                           sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                           sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                           sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf2}

#Re-run feat
echo "...Rerunning FEAT (nuisancereg(post-stats only)0"
feat ${indir}/${fsf2}

#################################



###### Post-FEAT data-scaling ########################################

cd $indir/${nuisancefeat}/stats

#Backup file
echo "...Scaling data by 1000"
cp res4d.nii.gz res4d_orig.nii.gz
	
#For some reason, this mask isn't very good.  Use the good mask top-level
echo "...Copy Brain mask"
cp $indir/mcImgMean_mask.nii.gz mask.nii.gz
fslmaths mask -mul 1000 mask1000 -odt float

#normalize res4d here
echo "...Normalize Data"
fslmaths res4d -Tmean res4d_tmean 
fslmaths res4d -Tstd res4d_std 
fslmaths res4d -sub res4d_tmean res4d_dmean
fslmaths res4d_dmean -div res4d_std res4d_normed
fslmaths res4d_normed -add mask1000 res4d_normandscaled -odt float

#################################









