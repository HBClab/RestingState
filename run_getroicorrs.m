% This is a wrapper script that calles the actual matlab script get_fc_matrix_subset.m that does
% the actual correlation computations. Save these two scripts in your current working folder or 
% where you start matlab from or in a place that is in your matlab's search
% path and run this code after making necessary changes to your path
% structure. Read on...


close all;
clear all;

%Specify a text file that has all the subjects listed one per line. (It is better
% if you can give the full path).

fid1=fopen('/Users/suttererm/VossLabMount/Projects/FAST/PreprocData/n189_time_2_raw_exists.txt');
subList_tmp=textscan(fid1,'%s');fclose(fid1);
N=length(subList_tmp{1,1});
subList=cell(N,1);
for i=1:N
    subList{i,1}=strcat(subList_tmp{1,1}(i));
end

% Please specify a textfile that has all your regions of interest listed one per line. (It is better
% if you can give the full path).

fid2=fopen('/Users/suttererm/VossLabMount/Projects/FAST/PreprocData/scripts/fast_UIUC_DMN_phgf.txt');   %ROI LIST HERE
roiList_tmp=textscan(fid2,'%s');fclose(fid2);
N1=length(roiList_tmp{1,1});
roiList=cell(N1,1);
for i=1:N1
    roiList{i,1}=(roiList_tmp{1,1}(i));
end

% Please specify the path where your subject data is (ie, the .feat/stats).
% The scripts assumes the following path:
% /mypwd/sub/func/nuisancereg.feat/stats
% This is where the code will look for the 'roi_residvol_ts.txt' to compute
% the correlations. The part "/func/nuisancereg.feat/stats/" of the above path is hard-coded in the
% get_fc_matrix_subset.m script at line 66. If this part is different for you, please change it according to
% your directory structure. Ultimately, it should point to the _residvol_ts.txt

mypwd='/Users/suttererm/VossLabMount/Projects/FAST/PreprocData/';

% if your data is motion scrubbed, use motion_scrub=1 else use
% motion_scrub=0. If motion scrubbed; it will look for
% roi_residvol_ms_ts.txt in the location: mypwd/subname/image/rest/nuisancereg.feat/stats/

motion_scrub=1; 

% This specifies the number of time points in the functional data. Change
% it according to your data.
numvols=180;

% Now that you have changed all the necessary feilds, you can run this script. The next line calls the correlation
% computation function.

[corrlist_subs_ms avgcorrmat_subs_ms]=getroicorrs(subList,roiList,mypwd,motion_scrub,numvols);

%%
% if you are familiar with matlab, then:
% -the matrix corrlist_subs_ms gives you the correlation of each subject to each roi-pairs.
% -the matrix avgcorrmat_subs_ms gives you the cross-correlation of roi time-series averaged over all subjects.
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
        %     pair=cat(2, pair, char(strcat(r2,'-',r4,\t')));
        pair=cat(2, pair, [char(r2),'-',char(r4),' ']);
    end
    roi_row=cat(2,roi_row, [char(r2),' ']);
end
if(exist('subject_roi-pair_corr'))
    delete('subject_roi-pair_corr');
end
fid = fopen('subject_roi-pair_corr_compcor_n189_ms_UIUC_DMN_phgf_time_2.txt','w');
fprintf(fid, '%s \n', pair);
fclose(fid);
% the following code creates a text file 'roi-roi_corr' in your current directory with the cross-correlation
% of rois averaged over all subjects

for row=1:N
    fid = fopen('subject_roi-pair_corr_compcor_n189_ms_UIUC_DMN_phgf_time_2.txt','a');
    clear a;
    a=char(num2str(corrlist_subs_ms(row,:)));
    fprintf(fid,'%s %s \n',['sub',char(subList{row,1}),'_2'],a);
    fclose(fid);
end

if(exist('roi-roi_corr'));
    delete('roi-roi_corr');
end

fid = fopen('roi-roi_corr_compcor_n189_ms_UIUC_DMN_phgf_time_2.txt','a');
fprintf(fid, '%s \n', roi_row);
fclose(fid);

for roi1=1:length(roiList)
    r1=roiList{roi1};
    r2=strrep(r1,'.nii.gz',' ');
    clear a;
    a=char(num2str(avgcorrmat_subs_ms(roi1,:)));
    fid = fopen('roi-roi_corr_compcor_n189_ms_UIUC_DMN_phgf_time_2.txt', 'a');
    fprintf(fid, '%s %s \n', char(r2),a);
    fclose(fid);
end

