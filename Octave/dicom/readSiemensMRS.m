function [stat,fid,hdr] = readSiemensMRS(hdr)

stat = 0;
fid  = 0;

% --- Get Dicom header from a file ---
%if nargin < 1 , hdr = dicom_header('', '*');  end

% --- Read spectro data from Siemens header ---
if (~ isfield(hdr,'Private_7fe1_1010')), return; end
nums = hdr.Private_7fe1_1010;
data = typecast(nums,'single');
N    = size(data,1)/2;
even = 1:2:2*N;
fid  = complex(data(even),data(even+1));
%fid  = fid/abs(fid(1));

% --- data info - need to get from Siemens Private header ---
[status,f0,hdr] = dicom_get_header(hdr,'ImagingFrequency');
[status,bw,hdr] = dicom_get_header(hdr,'PixelBandwidth');

% --- Add params to hdr ---
hdr.MRS_f0 = f0;
hdr.MRS_N  = N;
hdr.MRS_BW = 2*bw;	%% 2x if "Remove Oversampling" is OFF

stat = 1;
return;
