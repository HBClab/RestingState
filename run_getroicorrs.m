% This script will set up variables for computing roi-roi correlations per subject, and ouputs
% the result per subject (subject_roi-pair_corr_compcor_global.csv) 
% and as an average correlation matrix (roi-roi_corr.csv)

close all;
clear all;

% Arguments
arg_list = argv ();
subList=arg_list{1};
roiList=arg_list{2};

for i = 1:nargin
  printf (" %s", arg_list{i});
endfor

% Specify a text file that has all the subjects listed one per line. 

fid1=fopen(subList);
subList_tmp=textscan(fid1,'%s');fclose(fid1);
N=length(subList_tmp{1,1});
subList=cell(N,1);
for i=1:N
    subList{i,1}=strcat(subList_tmp{1,1}(i));
end

% Specify a textfile that has all your regions of interest listed one per line without extensions. 

fid2=fopen(roiList);   
roiList_tmp=textscan(fid2,'%s');fclose(fid2);
N1=length(roiList_tmp{1,1});
roiList=cell(N1,1);
for i=1:N1
    roiList{i,1}=(roiList_tmp{1,1}(i));
end

% Specify the path where your subject data is and where you want outputs

mypwd='/data/derivatives/rsOut/';
outdir='/data/derivatives/rsOut/roicorrs/'

% Specify if your data is motion scrubbed, use ms=1 else use ms=0

ms=1; 

% Specify if you want fishers z (usually yes)
fisherz=1;

% This is a filler number for setting up matrices, and it is dynamically adjusted based on timeseries length below
numvols=10; 

% The following code now goes and gets fc for each sub.

%prepare matrix to hold timeseries data
timeseries=repmat(struct('rest',1),1,3); %one cell per run

    %store timeseries data
timeseries(1,1,1).rest=zeros([numvols,length(roiList),length(subList)]); %volumes x numrois x subs

    %store correlation matrix
timeseries(1,1,2).rest=zeros([length(roiList),length(roiList),length(subList)]); %volumes x numrois x subs
    
    %store fishers z correlation matrix
timeseries(1,1,3).rest=zeros([length(roiList),length(roiList),length(subList)]); %volumes x numrois x subs

% uncomment to show size of filler structure
% size(timeseries(1,1,1).rest)


N=length(subList)
disp(N)

for u=1:N;
      for roi=1:length(roiList);
        % Specify where the _residvol_*_ts.txt files are
        % you want mypwd/sub-label/path-below to get you to the seed files ending in _residvol_*_ts.txt
        % this will change based on nuisance regression approach
        path=[mypwd,char(subList{u,1}),'/seedCorrelation/compcor_global/rois'];
        cd(path)
        if(ms==1)
            ts=load([char(roiList{roi}),'_residvol_ms_ts.txt']);
            l(u)=length(ts);
            timeseries(1,1,1).rest(1:l(u),roi,u)=ts(1:l(u));
        else
            ts=load([char(roiList{roi}),'_residvol_ts.txt']);
            l(u)=length(ts);
            timeseries(1,1,1).rest(:,roi,u)=load([char(roiList{roi}),'_residvol_ts.txt']);
        end
      end
end

% uncomment to show size of filled structure
% size(timeseries(1,1,1).rest)


for u=1:length(subList);
            for roi=1:length(roiList);
            timeseries(1,1,2).rest(:,:,u)=corrcoef(timeseries(1,1,1).rest(1:l(u),:,u)); 
            end
end


%now want to do fishers z on correlation matrices, turn warnings of divide by zero off
warning('off', 'all');
if (fisherz==1)
    for u=1:length(subList);
                for roi=1:length(roiList);
                    for p=1:(length(roiList)*length(roiList)*length(subList))
                        x=timeseries(1,1,2).rest(p);
                        timeseries(1,1,3).rest(p)=(.5*log((1+(x))/(1-(x)))); 
                        % sub_mat=timeseries(1,1,3).rest(p)
                        %  save([char(subList{u,1}),'.mat'],'sub_mat')
                    end
                end
    end
end




%output a text file with the avereage correlation matrix for the group of subjects for each condition

%prepare to hold average matrix of subjects (average across runs per condition)
avgcorrmat_subs=mean(timeseries(1,1,3).rest(:,:,:),3);
% below would do the same for pearson instead of fishers
% avgcorrmat_subs=mean(timeseries(1,1,2).rest(:,:,:),3);

%write to text file
cd(outdir)
for u=1:length(subList);
    if (fisherz==1)
        fname=[sprintf('%05d',sscanf(char(subList{u,1}),'sub%d')),'.mat']; % zeropad subID
    else 
        fname=[sprintf('%05d',sscanf(char(subList{u,1}),'sub%d')),'_rawcorr.mat']
    end
    
    sub_mat=timeseries(1,1,3).rest(:,:,u);
    sub_mat(isinf(sub_mat))=1;
    save(fname,'sub_mat'); 
end



%dlmwrite('fztmat_allsubs_rest.txt',avgcorrmat_subs,'delimiter',' ','precision',3)


%output a text file subjects x roi-pairs that has fishers z estimates per roi-pair

% make all diagonals zero for first sub as test matrix to get index for lower-triangular matrix
x=tril(avgcorrmat_subs); %x is roi x roi
for roi=1:length(roiList)
    x(roi,roi)=0;
end

%index x row,col addresses that have non-zero entries
[r,c]=find(x);

%make a matrix that is sub x roi-pairs
corrlist_subs=zeros(length(subList),length(r));

%fill these in
for rel=1:length(r)
    for u=1:length(subList)
    corrlist_subs(u,rel)=timeseries(1,1,3).rest(r(rel),c(rel),u);
%         corrlist_subs(u,rel)=timeseries(1,1,2).rest(r(rel),c(rel),u);

    end
end



%%
% the matrix corrlist_subs gives you the correlation of each subject to each roi-pairs.
% the matrix avgcorrmat_subs gives you the cross-correlation of roi time-series averaged over all subjects.
%    
% the above matrices are written to .csv files
% Look for the text files 'subject_roi-pair_corr' and 'roi-roi_corr' in your specified outdir

% the following code creates a text file 'subject_roi-pair_corr' 

pair=[char(9)];roi_row=[char(9)];
for roi1=1:length(roiList)
    for roi2=roi1+1:length(roiList)
        r1=roiList{roi1};
        r2=strrep(r1,'.nii.gz',' ');
        r3=roiList{roi2};
        r4=strrep(r3,'.nii.gz',' ');
        pair=cat(2, pair, [char(r2),'-',char(r4),' ']);
    end
    roi_row=cat(2,roi_row, [char(r2),' ']);
end

if(exist('subject_roi-pair_corr.csv'))
    delete('subject_roi-pair_corr.csv');
end

fid = fopen('subject_roi-pair_corr.csv','w');
fprintf(fid, '%s \n', pair);
fclose(fid);

% the following code creates a text file 'roi-roi_corr' 

for row=1:N
    fid = fopen('subject_roi-pair_corr.csv','a');
    clear a;
    a=char(num2str(corrlist_subs(row,:)));
    fprintf(fid,'%s %s \n',char(subList{row,1}),a);
    fclose(fid);
end


if(exist('roi-roi_corr.csv'));
    delete('roi-roi_corr.csv');
end

fid = fopen('roi-roi_corr.csv','a');
fprintf(fid, '%s \n', roi_row);
fclose(fid);

for roi1=1:length(roiList)
    r1=roiList{roi1};
    r2=strrep(r1,'.nii.gz',' ');
    clear a;
    a=char(num2str(avgcorrmat_subs(roi1,:)));
    fid = fopen('roi-roi_corr.csv', 'a');
    fprintf(fid, '%s %s \n', char(r2),a);
    fclose(fid);
end