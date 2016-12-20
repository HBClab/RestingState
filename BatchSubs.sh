/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -i /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsPathList.txt -o /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut2 -R /Users/mwvoss/bin/RestingState2014a/ROIs/roilist.txt -N /Users/mwvoss/bin/RestingState2014a/ROIs/roilist_nuisance.txt -t 2 -T 30 -s 6 -m 2 -P 1

/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -i /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsPathList.txt -o /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsOut -R /Users/mwvoss/bin/RestingState2014a/ROIs/roilist.txt -N /Users/mwvoss/bin/RestingState2014a/ROIs/roilist_nuisance.txt -t 2 -T 30 -s 6 -m 2 -P 1

/Users/mwvoss/bin/RestingState2014a/P1_touchup.sh -p /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut/func/rsParams
/Users/mwvoss/bin/RestingState2014a/P1_touchup.sh -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsOut/func/rsParams


/Users/mwvoss/bin/RestingState2014a/P1_touchup.sh -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub215/rsOut/func/rsParams
/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 2 -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub215/rsOut/func/rsParams

#without denoising
/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 2a -L .08 -H .008 -V -p /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut2/func/rsParams

#with denoising
/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 2 -p /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut/func/rsParams
/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 3 -L .08 -H .008 -V -p /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut/func/rsParams
/Users/mwvoss/bin/RestingState2014a/seedVoxelCorrelation.sh -E /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut2/func/RestingState.nii.gz -r Rcaud -m 2 -V
seedVoxelCorrelation.sh -E restingStateImage -r roi -m motionScrubFlag -f -V"

#sub215 act pre
/Users/mwvoss/bin/RestingState2014a/P1_touchup.sh -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub215/rsOut/func/rsParams
/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 2 -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub215/rsOut/func/rsParams
/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 3 -L .08 -H .008 -V -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub215/rsOut/func/rsParams


#with fieldmap

/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -i /Users/mwvoss/Analysis/RestingStateAnalysis/sub0005/rsPathList.txt -o /Users/mwvoss/Analysis/RestingStateAnalysis/sub0005/rsOut -R /Users/mwvoss/bin/RestingState2014a/ROIs/roilist.txt -N /Users/mwvoss/bin/RestingState2014a/ROIs/roilist_nuisance.txt -t 2 -T 25 -f -D 0.000350475 -d -y -s 6 -m 2 -P 1


/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -i /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsPathList.txt -o /Users/mwvoss/Analysis/RestingStateAnalysis/subnum/rsOut -R /Users/mwvoss/bin/RestingState2014a/ROIs/roilist.txt -N /Users/mwvoss/bin/RestingState2014a/ROIs/roilist_nuisance.txt -t 2 -T 30 -f -D 0.000350475 -d -y -s 6 -m 2 -P 1




/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -i /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsPathList.txt -o /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsOut2 -R /Users/mwvoss/bin/RestingState2014a/ROIs/roilist.txt -N /Users/mwvoss/bin/RestingState2014a/ROIs/roilist_nuisance.txt -t 2 -T 30 -s 6 -m 2 -P 1

/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -i /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsPathList.txt -o /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsOut2 -R /Users/mwvoss/bin/RestingState2014a/ROIs/roilist.txt -N /Users/mwvoss/bin/RestingState2014a/ROIs/roilist_nuisance.txt -t 2 -T 30 -s 6 -m 2 -P 1

/Users/mwvoss/bin/RestingState2014a/P1_touchup.sh -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsOut2/func/rsParams


/Users/mwvoss/bin/RestingState2014a/processRestingState.sh -P 2a -L .08 -H .008 -V -p /Users/mwvoss/Analysis/RestingStateAnalysis/sub111/rsOut2/func/rsParams