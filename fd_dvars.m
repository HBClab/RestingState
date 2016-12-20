function fd_dvars(subjectPath,featdir,funcvoldim)


timedim=funcvoldim(4);


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
   

mypath=[subjectPath,'/',featdir,'/stats'];
cd(mypath);

if exist('res4d_normandscaled.nii.gz', 'file')
  system('gunzip res4d_normandscaled.nii.gz');
end

funcon=load_untouch_nii('res4d_normandscaled.nii');
func=funcon.img;
for ts=2:funcvoldim(4)
  backdiffsqr= (func(:,:,:,ts)-func(:,:,:,ts-1)).^2;
  rms_ts(ts-1)=sqrt(mean(backdiffsqr(:)));
end
dvars_mask=rms_ts>.5;



%Write out FD, DVARS and mask files


fid = fopen([mypath '/dvars.txt'], 'w');
fprintf(fid, '%.8f \n', rms_ts);
fclose(fid);

fid2 = fopen([mypath '/fd.txt'], 'w');
fprintf(fid2, '%.8f \n', FD);
fclose(fid2);


fid3 = fopen([mypath '/dvars_mask.txt'], 'w');
fprintf(fid3, '%.8f \n', dvars_mask);
fclose(fid3);

fid4 = fopen([mypath '/fd_mask.txt'], 'w');
fprintf(fid4, '%.8f \n', FD_mask);
fclose(fid4);


