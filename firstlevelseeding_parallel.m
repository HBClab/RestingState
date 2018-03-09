function firstlevelseeding_parallel(roiList,roiOutDir,funcvoldim,input,motion_scrub,doFisherZ)

%script to calculate correlation coefficient between a set of seed
%timecourses and a functional volume that has had nuisance signals
%regressed out with FSL
%%michelle voss, uses tools by Luis Hernandez (LuisTools) at UM (available online).
%mvoss@illinois.edu
%last edited 6/29/11
%
%Edits by M. Sutterer on 3/3/14 to utilize matlab parallel processing
%toolbox for seeding steps.
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
%   funcvoldim=dimensions of one functional volume, input as matrix
%   e.g., [64 64 28]
%
%   doFisherZ=1 to do Fisher's Z correction, 0 to not
%
%EXAMPLE usage, if list variables defined as variables in matlab command
%window, and you want to include Fisher's Z correction of pearson
%correlation maps
%
%firstlevelseeding(subPath,roiList,'nuisancereg',[64 64 28],'tmp.nii', 1,1)
%%


roiN=length(roiList{1,1});
imagedimsx=funcvoldim(1);
imagedimsy=funcvoldim(2);
imagedimsz=funcvoldim(3);

numclusters = parcluster('local'); %find the number of workers available on your machine/server

if roiN <= 4
    dcpoolsize = roiN; %for cases when there's only 1 or 2 ROIs
elseif numclusters.NumWorkers > 4
    dcpoolsize = numclusters.NumWorkers-2; %if you have more than 4 workers available, set pool size to N-2, limits tying up server
else
    dcpoolsize = numclusters.NumWorkers; %if you have 4 or less workers available, set pool size to all available workers (may bog down local machines).
end

try
matlabpool(num2str(dcpoolsize))
%http://www.mathworks.com/help/distcomp/parpool.html#btyaboo-7
%parpool(local,num2str(dcpoolsize))
%Warning: matlabpool will be removed in a future release.
%Use parpool instead.
%PARPOOL was introduced in R2013b to replace MATLABPOOL. In R2013a and earlier, use MATLABPOOL.
catch err
    warning(err.message)
end

warning off all
mypath=[roiOutDir];
cd(mypath);

%if exist('cope1.nii.gz','file')
%  system('gunzip cope1.nii.gz')
%end

funcon=load_untouch_nii(input);
func=funcon.img;











totalslices=imagedimsx*roiN;
%index=1;


parfor r=1:roiN

  fcmap=zeros(imagedimsx,imagedimsy,imagedimsz);

  if (motion_scrub==1)
    seedts=load([char(roiList{1,1}(r)),'_','residvol_ms_ts.txt']);
  else
    seedts=load([char(roiList{1,1}(r)),'_','residvol_ts.txt']);
  end
  % Loop over three dims - x y z
  for a=1:imagedimsx;

    %fprintf(1, '%3d%% \n',int8(index/totalslices*100.0));
    %index = index +1

    for b=1:imagedimsy;
      for c=1:imagedimsz;
        %calc correlation bewteen seed timeseries and timeseries of that voxel; tmp=2x2 symmetric corr table
        tmp=corrcoef(seedts,squeeze(func(a,b,c,:)));
        if exist('OCTAVE_VERSION','builtin')
          pixr=tmp;
        else
          pixr=tmp(1,2);
        end

        if isnan(pixr)
          pixr=0.0;
        end

        if doFisherZ
          pixr=(.5*log((1+pixr)/(1-pixr)));
        end

        %fill voxel with correlation coefficient
        fcmap(a,b,c)=pixr;
      end
    end
  end

  spacing=funcon.hdr.dime.pixdim(2:4);
  origin=[funcon.hdr.hist.qoffset_x, funcon.hdr.hist.qoffset_y, funcon.hdr.hist.qoffset_z];
  datatype=16;
  description='Seed Voxel';

  threeD = make_nii(fcmap, spacing, origin, datatype, description);
%changed output section to operate in parallel, files are initially written
%as seed_threeD_ms.ii, changed to seed_cope1_ms.nii, and then copied to
%seed folder as cope1.nii. this is to prevent simultanous overwriting of
%cope1.nii from multiple workers.
  if (motion_scrub==1)
    save_nii(threeD,[char(roiList{1,1}(r)) '_threeD_ms.nii']);
    %Need to fix issue of "make_nii" creating LPI oriented files and NOT RPI oriented files
    flip_lr([char(roiList{1,1}(r)) '_threeD_ms.nii'],[char(roiList{1,1}(r)) '_threeD_ms.nii']);
    system(['mv',' ', [char(roiList{1,1}(r)) '_threeD_ms.nii'],' ',[char(roiList{1,1}(r)) '_cope1_ms.nii']]);
    mkdir([char(roiList{1,1}(r)) '_ms']);
    system(['cp',' ', [char(roiList{1,1}(r)) '_cope1_ms.nii'], ' ', [char(roiList{1,1}(r)) '_ms'],'/','cope1.nii']);
    system(['rm',' ', [char(roiList{1,1}(r)) '_cope1_ms.nii']]);
    fprintf(1,'%s_ms Done \n',[char(roiList{1,1}(r))]);
  else
    save_nii(threeD,[char(roiList{1,1}(r)) '_threeD.nii']);
    %Need to fix issue of "make_nii" creating LPI oriented files and NOT RPI oriented files
    flip_lr([char(roiList{1,1}(r)) '_threeD.nii'],[char(roiList{1,1}(r)) '_threeD.nii']);
    system(['mv',' ', [char(roiList{1,1}(r)) '_threeD.nii'],' ', [char(roiList{1,1}(r)) '_cope1.nii']]);
    mkdir(char(roiList{1,1}(r)));
    system(['cp',' ', [char(roiList{1,1}(r)) '_cope1.nii'], ' ', char(roiList{1,1}(r)),'/','cope1.nii']);
    system(['rm',' ', [char(roiList{1,1}(r)) '_cope1.nii']]);
    fprintf(1,'%s Done \n',[char(roiList{1,1}(r))]);
  end

end
