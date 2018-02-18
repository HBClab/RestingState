function nifti2analyze4D(name)
% function nifti2analyze(name)
%
% converts NIFTI images to AVW (Analyze) format images disregarding
% the affine transformation parameters
%


[dnii hnii] = read_nii_img(name);
avwh = nii2avw_hdr(hnii);

% make sure the name is in the right format
suffix = name(end-4:end);
if strcmp(suffix, '.nii')
    name = name(1:end-4);
end
if strcmp(suffix, 'i.gz')
    name = name(1:end-7);
end


write_img([name '.img'],dnii,avwh);

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function hdr=read_nii_hdr(name)
%function hdr=read_nii_hdr(name)

% maek sure filename is in the right format
suffix = name(end-2:end);
if strcmp(suffix,'.gz')
    eval(['!gunzip ' name]);
    name = name(1:end-3);
elseif strcmp(suffix,'nii')
    name = name;
else
    name = sprintf('%s.nii',name);
end

% first detect which endian file we're opening
[pFile,messg] = fopen(name, 'r','native');
if pFile == -1
    fprintf('Error opening header file: %s',name);
    return;
end

tmp = fread(pFile,1,'int32');

if strcmp(computer,'GLNX86') | ...
        strcmp(computer , 'PCWIN')| ...
        strcmp(computer,'GLNXA64') |...
        strcmp(computer,'MACI')

    if tmp==348
        endian='ieee-le';
    else
        endian='ieee-be';
    end

else
    if tmp==348
        endian='ieee-be';
    else
        endian='ieee-le';
    end

end
fclose(pFile);
% Now Read in Headerfile into the hdrstruct
[pFile,messg] = fopen(name, 'r', endian);
if pFile == -1
    msgbox(sprintf('Error opening header file: %s',name));
    return;
end


hdr = struct (...
    'sizeof_hdr'    , fread(pFile, 1,'int32')',...	% should be 348!
    'data_type'     , (fread(pFile,10,'*char')'),...
    'db_name'       , (fread(pFile,18,'*char')'),...
    'extents'       , fread(pFile, 1,'int32')', ...
    'session_error' , fread(pFile, 1,'int16')', ...
    'regular'       , fread(pFile, 1,'*char')', ...
    'dim_info'      , fread(pFile, 1,'*char')', ...
    'dim'        , fread(pFile,8,'int16')', ...
    'intent_p1'  , fread(pFile,1,'float32')', ...
    'intent_p2'  , fread(pFile,1,'float32')', ...
    'intent_p3'  , fread(pFile,1,'float32')', ...
    'intent_code' , fread(pFile,1,'int16')', ...
    'datatype'   , fread(pFile,1,'int16')', ...
    'bitpix'     , fread(pFile,1,'int16')', ...
    'slice_start' , fread(pFile,1,'int16')', ...
    'pixdim'     , fread(pFile,8,'float32')', ...
    'vox_offset' , fread(pFile,1,'float32')', ...
    'scl_slope'  , fread(pFile,1,'float32')', ...
    'scl_inter'  , fread(pFile,1,'float32')', ...
    'slice_end'  , fread(pFile,1,'int16')', ...
    'slice_code' , fread(pFile,1,'*char')', ...
    'xyzt_units' , fread(pFile,1,'*char')', ...
    'cal_max'    , fread(pFile,1,'float32')', ...
    'cal_min'    , fread(pFile,1,'float32')', ...
    'slice_duration' , fread(pFile,1,'float32')', ...
    'toffset'    , fread(pFile,1,'float32')', ...
    'glmax'      , fread(pFile,1,'int32')', ...
    'glmin'      , fread(pFile,1,'int32')', ...
    'descrip'     , (fread(pFile,80,'*char')'), ...
    'aux_file'    , (fread(pFile,24,'*char')'), ...
    'qform_code'  , fread(pFile,1,'int16')', ...
    'sform_code'  , fread(pFile,1,'int16')', ...
    'quatern_b'   , fread(pFile,1,'float32')', ...
    'quatern_c'   , fread(pFile,1,'float32')', ...
    'quatern_d'   , fread(pFile,1,'float32')', ...
    'qoffset_x'   , fread(pFile,1,'float32')', ...
    'qoffset_y'   , fread(pFile,1,'float32')', ...
    'qoffset_z'   , fread(pFile,1,'float32')', ...
    'srow_x'      , fread(pFile,4,'float32')', ...
    'srow_y'      , fread(pFile,4,'float32')', ...
    'srow_z'      , fread(pFile,4,'float32')', ...
    'intent_name' , (fread(pFile,16,'*char')'), ...
    'magic'       , (fread(pFile,4,'*char')'), ...
    'originator'  , fread(pFile, 5,'int16'),...
    'esize'       , 0, ...
    'ecode'       , 0, ...
    'edata'       , '' ...
    );
% this part is intended to read the extension data information at the end of the
% nifti header and before the image proper
%extendcode = fread(pFile,4,'char');
%if extendcode(1)~=0
%    hdr.esize = hdr.vox_offset-352;
%    hdr.edata = fread(pFile, hdr.esize, 'char');
%end

fclose(pFile);


return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [d, hdr]= read_nii_img(name)
%function [d [,hdr] ] = read_nii_img(name)
suffix = name(end-2:end);
if strcmp(suffix,'.gz')
    fprintf('\n Unzipping ...%s', name);
    eval(['!gunzip ' name]);
    name = name(1:end-3);
elseif strcmp(suffix,'nii')
    name = name;
else
    name = sprintf('%s.nii',name);
end


hdr = read_nii_hdr(name);

[pFile,messg] = fopen(name, 'r','native');
if pFile == -1
    fprintf('Error opening header file: %s',name);
    fprintf('\n%s',messg);
    return;
end

endian = img_endian(name);
fseek(pFile, hdr.sizeof_hdr, 'bof');

xdim = hdr.dim(2);
ydim = hdr.dim(3);
zdim = hdr.dim(4);
tdim = hdr.dim(5);


switch hdr.datatype
    case 0
        fmt = 'uint8';
    case 2
        fmt = 'uint8';
    case 4
        fmt = 'short';
    case 8
        fmt = 'int';
    case 16
        fmt = 'float';
    case 32
        fmt = 'float';
        xdim = hdr.xdim * 2;
        ydim = hdr.ydim * 2;
    case 64
        fmt = 'int64';
    otherwise
        errormesg(sprintf('Data Type %d Unsupported. Aborting',hdr.datatype));
        return

end



% Read in data.
d = (fread(pFile,[xdim*ydim*zdim*tdim], fmt))';
if tdim >=2
    d = reshape(d, xdim*ydim*zdim, tdim);
    d=d';
else
    d = reshape(d, [xdim ydim zdim]);
end
fclose(pFile);

if strcmp(suffix,'.gz')
    fprintf('\n Done reading file.  Re-zipping ...%s\n', name);
    eval(['!gzip ' name]);
end

if nargout == 2
    varargout(1) = {hdr};
end

return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function  write_img(name, data, hdr)

% Luis hernandez
% last edit 7-26-2006
%
% function  write_img(name, data, hdr)
%
% Writes the data to an analyze format file 'name' containing mutislice image data
% this also handles a timeseries in one file (ie -each image is a row )
%
% it also writes out the analyze header file.
%
% (c) 2005 Luis Hernandez-Garcia
% University of Michigan
% report bugs to:  hernan@umich.edu
%

[pFile,messg] = fopen(name, 'wb');
if pFile == -1
    errormesg(messg);
    return;
end


switch hdr.datatype
    case 2
        fmt = 'uint8';
    case 4
        fmt = 'short';
    case 8
        fmt = 'int';
    case 16
        fmt = 'float';
    case 32
        fmt = 'float';

    otherwise
        errormesg(sprintf('Data Type %d Unsupported. Aborting',hdr.datatype));
        return

end


if hdr.tdim>1
    fwrite(pFile, data', fmt);
else
    fwrite(pFile, data, fmt);
end

fclose(pFile);

hname = [name(1:end-4) '.hdr'];
write_hdr(hname, hdr);
return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function write_hdr(name,hdr)

% function write_hdr(name,hdr)
% Luis hernandez
% last edit 1-7-98
%
% (c) 2005 Luis Hernandez-Garcia
% University of Michigan
% report bugs to:  hernan@umich.edu
%

% Writes the analyze format header file from a file 'name'

% The function opens a file and writes the structure to it
% hdr = struct(...
%      'sizeof_hdr', fread(pFile, 1,'int32'),...
%      'pad1', setstr(fread(pFile, 28, 'uint8')),...
%      'extents', fread(pFile, 1,'int32'),...
%      'pad2', setstr(fread(pFile, 2, 'uint8')),...
%      'regular',setstr(fread(pFile, 1,'uint8')), ...
%      'pad3', setstr(fread(pFile,1, 'uint8')),...
%      'dims', fread(pFile, 1,'int16'),...
%      'xdim', fread(pFile, 1,'int16'),...
%      'ydim', fread(pFile, 1,'int16'),...
%      'zdim', fread(pFile, 1,'int16'),...
%      'tdim', fread(pFile, 1,'int16'),...
%      'pad4', setstr(fread(pFile,20, 'uint8')),...
%      'datatype', fread(pFile, 1,'int16'),...
%      'bits', fread(pFile, 1,'int16'),...
%      'pad5', setstr(fread(pFile, 6, 'uint8')),...
%      'xsize', fread(pFile, 1,'float'),...
%      'ysize', fread(pFile, 1,'float'),...
%      'zsize', fread(pFile, 1,'float'),...
%      'glmax', fread(pFile, 1,'int32'),...
%      'glmin', fread(pFile, 1,'int32'),...
%      'descrip', setstr(fread(pFile, 80,'uint8')),...
%	'aux_file'        , setstr(fread(pFile,24,'uint8'))',...
%	'orient'          , fread(pFile,1,'uint8'),...
%				0 = transverse,1 = coronal, 2=sagittal
%	'origin'          , fread(pFile,5,'int16'),...
%	'generated'       , setstr(fread(pFile,10,'uint8'))',...
%	'scannum'         , setstr(fread(pFile,10,'uint8'))',...
%	'patient_id'      , setstr(fread(pFile,10,'uint8'))',...
%	'exp_date'        , setstr(fread(pFile,10,'uint8'))',...
%	'exp_time'        , setstr(fread(pFile,10,'uint8'))',...
%	'hist_un0'        , setstr(fread(pFile,3,'uint8'))',...
%	'views'           , fread(pFile,1,'int32'),...
%	'vols_added'      , fread(pFile,1,'int32'),...
%	'start_field'     , fread(pFile,1,'int32'),...
%	'field_skip'      , fread(pFile,1,'int32'),...
%	'omax'            , fread(pFile,1,'int32'),...
%	'omin'            , fread(pFile,1,'int32'),...
%	'smax'            , fread(pFile,1,'int32'),...
%	'smin'            , fread(pFile,1,'int32') );
%      )

global SPM_scale_factor

% Read in Headerfile into the hdrstruct
[pFile,messg] = fopen(name, 'wb');
if pFile == -1
    errormesg(messg);
end


fwrite(pFile, hdr.sizeof_hdr,'int32');
fwrite(pFile,hdr.pad1, 'uint8');
fwrite(pFile,hdr.extents, 'int32');
fwrite(pFile,hdr.pad2, 'uint8');
fwrite(pFile,hdr.regular','uint8');
fwrite(pFile,hdr.pad3', 'uint8');
fwrite(pFile,hdr.dims','int16');
fwrite(pFile,hdr.xdim','int16');
fwrite(pFile,hdr.ydim', 'int16');
fwrite(pFile,hdr.zdim', 'int16');
fwrite(pFile,hdr.tdim', 'int16');
fwrite(pFile,hdr.pad4', 'uint8');
fwrite(pFile,hdr.datatype,'int16');
fwrite(pFile,hdr.bits','int16');
fwrite(pFile,hdr.pad5','uint8');
fwrite(pFile,hdr.xsize', 'float');
fwrite(pFile,hdr.ysize', 'float');
fwrite(pFile,hdr.zsize', 'float');
fwrite(pFile,hdr.pad6','uint8');
fwrite(pFile,hdr.glmax', 'int32');
fwrite(pFile,hdr.glmin', 'int32');
fwrite(pFile,hdr.descrip','uint8');
fwrite(pFile,hdr.aux_file','uint8');
fwrite(pFile,hdr.orient','uint8');
fwrite(pFile,hdr.origin','int16');
fwrite(pFile,hdr.generated','uint8');
fwrite(pFile,hdr.scannum','uint8');
fwrite(pFile,hdr.patient_id','uint8');
fwrite(pFile,hdr.exp_date','uint8');
fwrite(pFile,hdr.exp_time','uint8');
fwrite(pFile,hdr.hist_un0','uint8');
fwrite(pFile,hdr.views', 'int32');
fwrite(pFile,hdr.vols_added', 'int32');
fwrite(pFile,hdr.start_field', 'int32');
fwrite(pFile,hdr.field_skip', 'int32');
fwrite(pFile,hdr.omax', 'int32');
fwrite(pFile,hdr.omin', 'int32');
fwrite(pFile,hdr.smax', 'int32');
fwrite(pFile,hdr.smin', 'int32');


fseek(pFile, 112, 'bof');
fwrite(pFile, SPM_scale_factor , 'float');


fclose(pFile);

return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function hdr = define_avw_hdr()
% function define_avw_hdr()
% creates a structure with a blank analyze header'
hdr = struct(...
    'sizeof_hdr'      , 0, ...
    'pad1'            , char(zeros(28,1)), ...
    'extents'         , 0 , ...
    'pad2'            , char(zeros(2,1)), ...
    'regular'         , 'r', ...
    'pad3'            , ' ',...
    'dims'            , 0, ...
    'xdim'            , 0, ...
    'ydim'            , 0, ...
    'zdim'            , 0, ...
    'tdim'            , 0, ...
    'pad4'            , char(zeros(20,1)),...
    'datatype'        , 0, ...
    'bits'            , 0, ...
    'pad5'            , char(zeros(6,1)),...
    'xsize'           , 0, ...
    'ysize'           , 0, ...
    'zsize'           , 0, ...
    'pad6'            , char(zeros(48,1)) ,...
    'glmax'           , 0, ...
    'glmin'           , 0, ...
    'descrip'         , char(zeros(80,1)),...
    'aux_file'        , char(zeros(24,1)),...
    'orient'          , char(zeros(1,1)), ...
    'origin'          , zeros(5,1),...
    'generated'       , char(zeros(10,1)),...
    'scannum'         , char(zeros(10,1)),...
    'patient_id'      , char(zeros(10,1)),...
    'exp_date'        , char(zeros(10,1)),...
    'exp_time'        , char(zeros(10,1)),...
    'hist_un0'        , char(zeros(3,1)),...
    'views'           , 0, ...
    'vols_added'      , 0, ...
    'start_field'     , 0, ...
    'field_skip'      , 0, ...
    'omax'            , 0, ...
    'omin'            , 0, ...
    'smax'            , 0,...
    'smin'            , 0 ...
    );

return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function hdr = nii2avw_hdr(niih)
%funtion avwh = nii2avw_hdr(niih)

hdr = define_avw_hdr;

hdr.sizeof_hdr = niih.sizeof_hdr;
%hdr.pad1 = niih.?
hdr.extents= niih.extents;
%hdr.pad2  = niih.?
%hdr.regular= niih.?
%hdr.pad3  = niih.?
hdr.dims = niih.dim(1);
hdr.xdim = niih.dim(2);
hdr.ydim = niih.dim(3);
hdr.zdim = niih.dim(4);
hdr.tdim = niih.dim(5);
%hdr.pad4 = niih.?
hdr.datatype = niih.datatype;
hdr.bits  = niih.bitpix;
%hdr.pad5 = niih.?
hdr.xsize = niih.pixdim(2);
hdr.ysize = niih.pixdim(3);
hdr.zsize = niih.pixdim(4);
%hdr.pad6 = niih.?
hdr.glmax = niih.cal_max;
hdr.glmin = niih.cal_min;
hdr.descrip = niih.descrip;
hdr.aux_file = niih.aux_file;
%hdr.orient = niih.?
%hdr.origin = ?
%hdr.generated = niih.?
%hdr.scannum = niih.?
%hdr.patient_id = niih.?
%hdr.exp_date = niih.?
%hdr.exp_time = niih.?
%hdr.hist_un0 = niih.?
%hdr.views = niih.?
%hdr.vols_added = niih.?
%hdr.start_field = niih.?
%hdr.field_skip = niih.?
%hdr.omax = niih.?
%hdr.omin = niih.?
%hdr.smax = niih.?
%hdr.smin = niih.?

return

function endian = img_endian(name)
% function endian = img_endian(name)

[pFile,messg] = fopen(name, 'r','native');
if pFile == -1
      fprintf('Error opening header file: %s',name); 
      return;
end
tmp = fread(pFile,1,'int32');

if strcmp(computer,'GLNX86') | strcmp(computer , 'PCWIN')
       
       if tmp==348
           endian='ieee-le';
       else
           endian='ieee-be';
       end
       
else
       if tmp==348
           endian='ieee-be';
       else
           endian='ieee-le';
       end
       
end

return


