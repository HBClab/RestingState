function [corrlist_subs avgcorrmat_subs]=getroicorrs(subList,roiList,sess,mypwd,outdir,ms,numvols,fisherz)

%script to pull out group correlation matrix in fisher transformed units of
%ROI-pairs in functional connectivity analysis with 1 run per subject.  The
%script will also output a list of correlation values for each ROI-pair for
%each subject (which can be used in SPSS for follow-up analyses)
%
%%Michelle Voss and Merry Mani 
%INPUTS set up by the run_getroicorrs.m script   
%%




%%%%%%%%%%%%%

cd(mypwd)

%prepare matrix to hold timeseries data
timeseries=repmat(struct('rest',1),1,3); %one cell per run

    %store timeseries data
timeseries(1,1,1).rest=zeros([numvols,length(roiList),length(subList)]); %volumes x numrois x subs

    %store correlation matrix
timeseries(1,1,2).rest=zeros([length(roiList),length(roiList),length(subList)]); %volumes x numrois x subs
    
    %store fisher's z correlation matrix
timeseries(1,1,3).rest=zeros([length(roiList),length(roiList),length(subList)]); %volumes x numrois x subs




N=length(subList)

for u=1:N;
      for roi=1:length(roiList);
        %DEPENDING ON HOW YOUR DATA IS STORED, YOU MAY HAVE TO CHANGE ...
         %   THIS LINE!!
        path=[mypwd,char(subList{u,1}),'/ses-',sess,'/seedCorrelation/compcor/rois'];
        cd(path)
        if(ms==1)
            ts=load([char(roiList{roi}),'_residvol_ms_ts.txt']);
            l(u)=length(ts);
            timeseries(1,1,1).rest(1:l(u),roi,u)=ts(1:l(u));
        else
            l(u)=numvols;
            timeseries(1,1,1).rest(:,roi,u)=load([char(roiList{roi}),'_residvol_ts.txt']);
        end
        %timeseries(1,1,1).rest(:,:,1)=timeseries data for six rois for first subject
      end

end


%now have structure with timeseries data per sub
%make correlation matrix for each now


for u=1:length(subList);
            for roi=1:length(roiList);
            timeseries(1,1,2).rest(:,:,u)=corrcoef(timeseries(1,1,1).rest(1:l(u),:,u)); 
            %timeseries(1,1,2).rest(:,:,1)=correlation matrix between rois for first subject
            end
end


%now want to do fisher's z on correlation matrices 
if (fisherz==1)
    for u=1:length(subList);
                for roi=1:length(roiList);
                    for p=1:(length(roiList)*length(roiList)*length(subList))
                        x=timeseries(1,1,2).rest(p);
                        timeseries(1,1,3).rest(p)=(.5*log((1+(x))/(1-(x)))); 
                        %timeseries(1,1,3).rest(:,:,1)=correlation matrix between rois, in fzt units, for first subject
                        %sub_mat=timeseries(1,1,3).rest(p)
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


%output a text file subjects x roi-pairs that has fisher's z estimates per roi-pair

%make all diagonals zero for first sub as test matrix to get index for lower-triangular matrix
x=tril(avgcorrmat_subs); %x is roi x roi
for roi=1:length(roiList)
    x(roi,roi)=0;
end

%index x's row,col addresses that have non-zero entries
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


