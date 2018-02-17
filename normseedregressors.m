function normseedregressors(subjectPath,roiList,featdir,includemotion)

%michelle voss
%mvoss@illinois.edu
%last edited 6/29/11

%script will normalize motion correction parameters and mean_mask_ts for 
%rois that featquery has been run on, and put normed ts into a folder 
%for normed regressors


%
%
%INPUTS:
%   subList=cell array with list of subject labels for their data directories
%   e.g., suggest creating in matlab before running the script or creating at
%    the top of this script such as:
%    subList={'sub1' 'sub2'};
%
%
%   roiList=cell array with list of image names (without extension) from which
%   timeseries data was extracted with featquery
%   e.g., suggest creating in matlab before running the script
%   roiList={'wmroi' 'latvent' 'global'};
%
%   mypwd=root directory where subject directories are kept
%   e.g., mypwd = '/Volumes/Data3/restingstate/';
%
%   taskdir=sub-directory where motion regressors and preproc.feat directory is
%   e.g., taskdir = 'rest';
%
%   featdir=sub-directory name for .feat directory where ROIs have been run with
%   featquery
%   e.g., featdir='preproc'
%
%
%   includemotion=1 if so, 0 if not
%
%
%
%EXAMPLE usage, if list variables defined as variables in matlab command
%window, and you want to include norming the motion correction regressors

%normseedregressors(subList,roiList,'/Volumes/Data3/restingstate/','rest','preproc',1)



%Normalization of Motion Correction Vectors%%
%
%
CFV=[];
if includemotion
  cd(subjectPath);
  %mkdir('tsregressorslp');
  tsexist=exist('tsregressorslp','dir');
    if tsexist == 0
      mkdir('tsregressorslp');
    end
  mc=load('mcImg.par');
  normedmc=zscore(mc);
  CFV=normedmc;
  for i=1:6
    dlmwrite(['tsregressorslp/mc',num2str(i),'_normalized.txt'],CFV(:,i));
  end
end
    
    
    
%Normalization of ROI timeseries data
    
mypath=[subjectPath,'/',featdir,'/rois'];
cd(mypath);
if(exist('normalized_confound_ts.txt'))
  delete('normalized_confound_ts.txt');
end

roiN=length(roiList);
for r=1:roiN
  ts=load(['mean_',char(roiList{r}),'_ts.txt']);
  normedts=zscore(ts);
  CFV=cat(2,CFV,normedts);
  dlmwrite(['../../tsregressorslp/',char(roiList{r}),'_normalized_ts.txt'],normedts);
end


