
% It is matlab script
close all;
clear all;
addpath('/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014');
statsScripts=['/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014','/Octave/statistics'];
addpath(statsScripts);
fid=fopen('/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014/partITest_nonSusan/P1OutputTest/func/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);
seedDir='/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014/partITest_nonSusan/P1OutputTest/func/nuisancereg.feat/stats/seedQC';
imageDir='/ppg/resting_state/Magnotta_scripts/RestingState_Joel_2014/partITest_nonSusan/P1OutputTest/func/seedQC';
seedregistrationcheck(seedDir,roiList,imageDir)
quit;
