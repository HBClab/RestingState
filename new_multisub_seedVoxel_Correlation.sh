
#!/bin/bash
#script to give input list of subjects and ROI list, and run seedVoxelCorrelation. assumes you have run all previous processing steps.
#Matt Sutterer

scriptDir='/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014'

subList=`cat /ppg/resting_state/sublist_bdc.txt`
roiList='/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014/ROIs/roilist_sutterer_4_26_2014.txt'

START=$(date +"%s")
for sub in $subList
  do
    echo ${sub}
    rsParamFile=`echo /ppg/resting_state/${sub}/rsOut/func/rsParams`
    epiData=`cat $rsParamFile | grep "epiRaw" | tail -1 | awk -F"=" '{print $2}'`
    motionScrubCheck=`cat $rsParamFile | grep "motionScrub=" | tail -1 | awk -F"=" '{print $2}'`
       if [[ $motionScrubCheck != "" ]]; then                  
	    motionScrubOption="-m $motionScrubCheck"
       else
            motionScrubOption=""
       fi

     #FieldMap flag
     fieldMapCheck=`cat $rsParamFile | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`
       if [[ $fieldMapCheck == 1 ]]; then
                fieldMapOption="-f"
       else
                fieldMapOption=""
       fi
     
    $scriptDir/seedVoxelCorrelation.sh -E $epiData -R $roiList $motionScrubOption $fieldMapOption -V 
    #$scriptDir/seedVoxelCorrelation_old.sh -f $epiData -R $roiList -m 2 -V    
done
END=$(date +"%s")
diff=$(($END-$START))
echo "Duration: $(($diff/3600 )) hours $((($diff%3600)/60)) minutes $(($diff%60)) seconds"