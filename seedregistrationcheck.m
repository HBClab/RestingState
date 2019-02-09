function seedregistrationcheck(seedDir,roiList,imageDir)

%Joel Bruss
%joel-bruss@uiowa.edu
%last edited 11/14/12

%script will take input ROI seeds (e.g. pccrsp, icalc) and produce an image overlaying the seed registered to subject's EPI space.
%COG of registered seed is calculated, axial slice is determined, then input RestingState and registered seed volumes are split into individual slices/volumes.  Volumes are fed to this script, seed is colored then overlaid onto RestingState data, then output as a png file.


%
%
%INPUTS:
%
%   seedDir=location of input underlay/overlay files for coronal/sagittal/axial views for each seed
%      e.g., seedDir='/"inputdirectory/"ID"/func/nuisancereg.feat/stats/seedQC';
%   roiList=input list of ROIs (e.g. pccrsp icalc etc.)
%      e.g., roiList={'pccrsp' 'icalc' 'rmot'};
%   imageDir=output directory to place composite underlay/overlay seed/EPI images
%      e.g., imageDir='/"inputdirectory/"ID"/func/seedQC';
%
%EXAMPLE usage:
%
%seedregistrationcheck(seedDir,roiList,imageDir)
%
%%







%Determine Number of ROIs to set recursuve loop to
roiN=length(roiList{1,1});

%Move into template directory
warning off all
cd(seedDir);

%Start loop through seed ROIs
for r=1:roiN

  %Set variable for input seed
  seed=[(roiList{1,1}(r))];
  seed=char(seed);

  %Loop through 3 cardinal orientations
  for orientation={'coronal','sagittal','axial'}  
    orientation=char(orientation);

    %Variable for underlay/overlay inputs
    ulay=[seed,'_underlay_',orientation];
    olay=[seed,'_overlay_',orientation];

    %Check to see if input files are compressed (and uncompress if they are)
    if exist([ulay,'.nii.gz'],'file');
      system(['gunzip -f' ulay,'.nii.gz'])
    end

    %if exist([olay,'.nii.gz'],'file');
    if exist([olay,'.nii.gz']);
      system(['gunzip -f' olay,'.nii.gz'])
    end

    %%Underlay
    uinput=[ulay,'.nii'];
    %useedhdr=load_nii(uinput);
    useedhdr=load_untouch_nii(uinput);
    useedimg=useedhdr.img;
    useedimg=useedimg-min(useedimg(:)); % shift data such that the smallest element of seedimg is 0
    useedimg=useedimg/max(useedimg(:)); % normalize the shifted data to 1
    uR=1;
    uG=1;
    uB=1;
    uRGB=cat(3,useedimg*uR,useedimg*uB,useedimg*uG);
    uFlip=flipdim(uRGB,1);
    uRotate=imrotate(uFlip,90);
    uResize=imresize(uRotate,4,'bicubic');

    %%Overlay
    oinput=[olay,'.nii'];
    %oseedhdr=load_nii(oinput);
    oseedhdr=load_untouch_nii(oinput);
    oseedimg=oseedhdr.img;
    oseedimg=oseedimg-min(oseedimg(:)); % shift data such that the smallest element of seedimg is 0
    oseedimg=oseedimg/max(oseedimg(:)); % normalize the shifted data to 1
    oR=1;
    oG=0;
    oB=0;
    oRGB=cat(3,oseedimg*oR,oseedimg*oB,oseedimg*oG);
    oFlip=flipdim(oRGB,1);
    oRotate=imrotate(oFlip,90);
    oResize=imresize(oRotate,4,'bicubic');

    %%Combine two images (red voxels on grayscale brain image)
    %Copied code from Steve Eddins "Image Overlay" from matlab central (http://www.mathworks.com/matlabcentral/fileexchange/10502-image-overlay/content/imoverlay.m)
    U=uResize;
    O=oResize>0.2;
    color=[1 0 0];

    % Force the 2nd input to be logical.
    mask = (O ~= 0);

    % Make the uint8 the working data class.  The output is also uint8.
    in_uint8 = im2uint8(U);
    color_uint8 = im2uint8(color);

    % Initialize the red, green, and blue output channels.
    if ndims(in_uint8) == 2
      % Input is grayscale.  Initialize all output channels the same.
      out_red   = in_uint8;
      out_green = in_uint8;
      out_blue  = in_uint8;
    else
      % Input is RGB truecolor.
      out_red   = in_uint8(:,:,1);
      out_green = in_uint8(:,:,2);
      out_blue  = in_uint8(:,:,3);
    end

    % Replace output channel values in the mask locations with the appropriate
    % color value.
    out_red(O)   = color_uint8(1);
    out_green(O) = color_uint8(2);
    out_blue(O)  = color_uint8(3);

    % Form an RGB truecolor image by concatenating the channel matrices along
    % the third dimension.
    MergedOut = cat(3, out_red, out_green, out_blue);
    imwrite(MergedOut,[imageDir,'/',seed,'_',orientation,'.png'])

  end
end
