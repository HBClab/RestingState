function motionscrub(subjectPath,input,funcvoldim)


timedim=funcvoldim(4);

mkdir([subjectPath '/motionScrub']);

warning off all
cd(subjectPath);

%mc=load('mcImg.par');
%To be more in line with Power 2012 NeuroImage paper, using rotations converted to mm (from a 50mm Radius)
  %Use mcImg file that has ALL units converted to mm
mc=load('mcImg_mm.par');
for ts=2:funcvoldim(4)
  backdiffabs(ts-1,:)=abs(mc(ts,:)-mc(ts-1,:));
end
FD=sum(backdiffabs,2);
FD_mask=FD>0.5;



[filepath,name,ext]=fileparts(input);
cd(filepath);

funcon=load_untouch_nii(input);
func=funcon.img;
for ts=2:funcvoldim(4)
  backdiffsqr= (func(:,:,:,ts)-func(:,:,:,ts-1)).^2;
  rms_ts(ts-1)=sqrt(mean(backdiffsqr(:)));
end

dvars_mask=rms_ts>.5;
dvars_mask_new=zeros(1,timedim);
FD_mask_new=zeros(1,timedim);

for ts=1:funcvoldim(4)-1
  if (dvars_mask(ts)==1)
    if (ts~=1)
      dvars_mask_new(ts-1)=1;
    end
    dvars_mask_new(ts:ts+2)=1;
  end
  if (FD_mask(ts)==1)
    if (ts~=1)
      FD_mask_new(ts-1)=1;
    end
    FD_mask_new(ts+1:ts+2)=1;
  end
end

%Write out FD, DVARS and mask files


fid = fopen([subjectPath '/motionScrub/dvars.txt'], 'w');
fprintf(fid, '%.8f \n', rms_ts);
fclose(fid);

fid2 = fopen([subjectPath '/motionScrub/fd.txt'], 'w');
fprintf(fid2, '%.8f \n', FD);
fclose(fid2);


fid3 = fopen([subjectPath '/motionScrub/dvars_mask.txt'], 'w');
fprintf(fid3, '%.8f \n', dvars_mask);
fclose(fid3);

fid4 = fopen([subjectPath '/motionScrub/fd_mask.txt'], 'w');
fprintf(fid4, '%.8f \n', FD_mask);
fclose(fid4);


delvol=FD_mask_new(1,1:timedim).*dvars_mask_new(1,1:timedim);
delvol_mask=delvol(1:funcvoldim(4));
if (nnz(delvol)>0)
  new_func=func(:,:,:,(~delvol_mask));
else
  new_func=func;
end

cd([subjectPath '/motionScrub']);
dlmwrite('deleted_vols.txt',find(delvol),'\t');
funcon.img=new_func;
funcon.hdr.dime.dim(1,5)=size(new_func,4);
save_untouch_nii(funcon,[name,'_ms.nii']);
