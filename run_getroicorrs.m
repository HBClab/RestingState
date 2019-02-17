% This is a wrapper script that calles the actual matlab script getroicorrs.m that does
% the actual correlation computations. Save these two scripts in your current working folder or 
% where you start matlab from or in a place that is in your matlab search
% path and run this code after making necessary changes to your path
% structure. Read on...


close all;
clear all;

%Specify a text file that has all the subjects listed one per line. (It is better
% if you can give the full path).

fid1=fopen('/data/derivatives/sublists/sublist.txt');
subList_tmp=textscan(fid1,'%s');fclose(fid1);
N=length(subList_tmp{1,1});
subList=cell(N,1);
for i=1:N
    subList{i,1}=strcat(subList_tmp{1,1}(i));
end

% Please specify a textfile that has all your regions of interest listed one per line without extensions. (It is better
% if you can give the full path).

fid2=fopen('/data/derivatives/sublists/sublist-rois.txt');   %ROI LIST HERE
roiList_tmp=textscan(fid2,'%s');fclose(fid2);
N1=length(roiList_tmp{1,1});
roiList=cell(N1,1);
for i=1:N1
    roiList{i,1}=(roiList_tmp{1,1}(i));
end

% Please specify the path where your subject data is 
% If this part is different for you, please change it according to
% your directory structure. 

mypwd='/data/derivatives/rsOut/';
outdir='/data/derivatives/rsOut/roicorrs/'

% if your data is motion scrubbed, use motion_scrub=1 else use
% motion_scrub=0. If motion scrubbed; it will look for
% roi_residvol_ms_ts.txt in the location: mypwd/sub-label/path-to-roi-resid-textfiles

ms=1; 

% want fishers z
fisherz=1;

% This specifies the number of time points in the functional data. Change
% it according to your data. If different runs have different volumes, use the least common value
numvols=180;

% Now that you have changed all the necessary fields, the following code goes and gets fc for each sub.

%prepare matrix to hold timeseries data
timeseries=repmat(struct('rest',1),1,3); %one cell per run

    %store timeseries data
timeseries(1,1,1).rest=zeros([numvols,length(roiList),length(subList)]); %volumes x numrois x subs

    %store correlation matrix
timeseries(1,1,2).rest=zeros([length(roiList),length(roiList),length(subList)]); %volumes x numrois x subs
    
    %store fishers z correlation matrix
timeseries(1,1,3).rest=zeros([length(roiList),length(roiList),length(subList)]); %volumes x numrois x subs



N=length(subList)
disp(N)

for u=1:N;
      for roi=1:length(roiList);
        % DEPENDING ON HOW YOUR DATA IS STORED, YOU MAY HAVE TO CHANGE PATH HERE
        % you want mypwd/sub-label/path-below to get you to the seed files ending in _residvol_ts.txt
        path=[mypwd,char(subList{u,1}),'/seedCorrelation/compcor_global/rois'];
        cd(path)
        if(ms==1)
            ts=load([char(roiList{roi}),'_residvol_ms_ts.txt']);
            l(u)=length(ts);
            timeseries(1,1,1).rest(1:l(u),roi,u)=ts(1:l(u));
        else
            l(u)=numvols;
            timeseries(1,1,1).rest(:,roi,u)=load([char(roiList{roi}),'_residvol_ts.txt']);
        end
      end
end


for u=1:length(subList);
            for roi=1:length(roiList);
            timeseries(1,1,2).rest(:,:,u)=corrcoef(timeseries(1,1,1).rest(1:l(u),:,u)); 
            end
end

warning('off', 'all');
%now want to do fishers z on correlation matrices 
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
% if you are familiar with matlab, then:
% -the matrix corrlist_subs gives you the correlation of each subject to each roi-pairs.
% -the matrix avgcorrmat_subs gives you the cross-correlation of roi time-series averaged over all subjects.
%    
% if do not like to work with matlab, the above matrices are written to some text files for your convenience. 
% Look for the text files 'subject_roi-pair_corr' and 'roi-roi_corr' in your current working directory.

% the following code creates a text file 'subject_roi-pair_corr' in your current directory with the correlation values for each subject
% to each roi-pairs 

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

if(exist('subject_roi-pair_corr'))
    delete('subject_roi-pair_corr');
end

fid = fopen('subject_roi-pair_corr_compcor_global.csv','w');
fprintf(fid, '%s \n', pair);
fclose(fid);

% the following code creates a text file 'roi-roi_corr' in your current directory with the cross-correlation
% of rois averaged over all subjects

for row=1:N
    fid = fopen('subject_roi-pair_corr_compcor_global.csv','a');
    clear a;
    a=char(num2str(corrlist_subs(row,:)));
    fprintf(fid,'%s %s \n',char(subList{row,1}),a);
    fclose(fid);
end


if(exist('roi-roi_corr'));
    delete('roi-roi_corr');
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