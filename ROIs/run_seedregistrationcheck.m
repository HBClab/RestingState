
% It is matlab script
close all;
clear all;
addpath('/Volumes/VossLab/Universal_Software/RestingState2014a');
niftiScripts=['/Volumes/VossLab/Universal_Software/RestingState2014a','/Octave/nifti'];
addpath(niftiScripts);statsScripts=['/Volumes/VossLab/Universal_Software/RestingState2014a','/Octave/statistics'];
statsScripts=['/Volumes/VossLab/Universal_Software/RestingState2014a','/Octave/statistics'];
addpath(statsScripts);
fid=fopen('/Users/VossLabMount/Projects/Bilingualism_DisEGV/sub6107_1/rsOut/func/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);
seedDir='/Users/VossLabMount/Projects/Bilingualism_DisEGV/sub6107_1/rsOut/func/nuisancereg.feat/stats/seedQC';
imageDir='/Users/VossLabMount/Projects/Bilingualism_DisEGV/sub6107_1/rsOut/func/seedQC';
seedregistrationcheck(seedDir,roiList,imageDir)
quit;
