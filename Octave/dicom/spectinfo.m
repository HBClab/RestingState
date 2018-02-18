function header_str = spectinfo(fname)

% This function takes a dicom file and reports Siemens specific
% spectroscopy information in the header.  This just writes out the
% data to the screen and returns nothing.  Modify as needed.

% Usage: spectinfo('test.dcm')
% [filename , pathname] = uigetfile('*.dcm', 'Select an DCM file');
% fname = fullfile(pathname , filename);

% Extracting image info from 
info = dicominfo( fname );

% temp = strtok(filename, '.');

% rda_filename = [temp, '.rda'];
% rda_filename = [pathname, rda_filename];
% fid = fopen(rda_filename, 'w');

% Grab the Siemens specific header (mostly the Phoenix stuff, I
% think).

s = char(getfield(info,'Private_0029_1120'))';

% Here's an example of the set of spectroscopy-specific information in proprietary headers.

% sSpecPara.lVectorSize                    = 1024
% sSpecPara.lPreparingScans                = 4
% sSpecPara.lPhaseCyclingType              = 1
% sSpecPara.lPhaseEncodingType             = 2
% sSpecPara.lRFExcitationBandwidth         = 50
% sSpecPara.sVoI.sPosition.dSag            = -0.3318950655
% sSpecPara.sVoI.sPosition.dCor            = -10.97657668
% sSpecPara.sVoI.sPosition.dTra            = -1.444198394
% sSpecPara.sVoI.sNormal.dTra              = 1
% sSpecPara.sVoI.dThickness                = 20
% sSpecPara.sVoI.dPhaseFOV                 = 100
% sSpecPara.sVoI.dReadoutFOV               = 100
% sSpecPara.ucVoIValid                     = 0x1
% sSpecPara.ucRemoveOversampling           = 0x1
% sSpecPara.lAutoRefScanNo                 = 1
% sSpecPara.ucOuterVolumeSuppression       = 0x1
% sSpecPara.lDecouplingType                = 1
% sSpecPara.lNOEType                       = 1
% sSpecPara.lExcitationType                = 1
% sSpecPara.lFinalMatrixSizePhase          = 32
% sSpecPara.lFinalMatrixSizeRead           = 32
% sSpecPara.lFinalMatrixSizeSlice          = 1
% sSpecPara.dDeltaFrequency                = -2.7
% sSpecPara.lSpecAppl                      = 1
% sSpecPara.lSpectralSuppression           = 1
% sSpecPara.dSpecLipidSupprBandwidth       = 1.55
% sSpecPara.dSpecLipidSupprDeltaPos        = -3.4
% sSpecPara.dSpecWaterSupprBandwidth       = 1.55

lPreparingScans			 = extractSiemensInfo(s,'sSpecPara.lPreparingScans' );
lPhaseCyclingType		 = extractSiemensInfo(s,'sSpecPara.lPhaseCyclingType' );
lPhaseEncodingType		 = extractSiemensInfo(s,'sSpecPara.lPhaseEncodingType' );
lRFExcitationBandwidth		 = extractSiemensInfo(s,'sSpecPara.lRFExcitationBandwidth' );
sVoI_sPosition_dSag		 = extractSiemensInfo(s,'sSpecPara.sVoI.sPosition.dSag' );
sVoI_sPosition_dCor		 = extractSiemensInfo(s,'sSpecPara.sVoI.sPosition.dCor' );
sVoI_sPosition_dTra		 = extractSiemensInfo(s,'sSpecPara.sVoI.sPosition.dTra' );
sVoI_sNormal_dTra		 = extractSiemensInfo(s,'sSpecPara.sVoI.sNormal.dTra' );
sVoI_dThickness			 = extractSiemensInfo(s,'sSpecPara.sVoI.dThickness' );
sVoI_dPhaseFOV			 = extractSiemensInfo(s,'sSpecPara.sVoI.dPhaseFOV' );
sVoI_dReadoutFOV		 = extractSiemensInfo(s,'sSpecPara.sVoI.dReadoutFOV' );
ucVoIValid			 = extractSiemensInfo(s,'sSpecPara.ucVoIValid' );
ucRemoveOversampling		 = extractSiemensInfo(s,'sSpecPara.ucRemoveOversampling' );
lAutoRefScanNo			 = extractSiemensInfo(s,'sSpecPara.lAutoRefScanNo' );
ucOuterVolumeSuppression	 = extractSiemensInfo(s,'sSpecPara.ucOuterVolumeSuppression' );
lDecouplingType			 = extractSiemensInfo(s,'sSpecPara.lDecouplingType' );
lNOEType			 = extractSiemensInfo(s,'sSpecPara.lNOEType' );
lExcitationType			 = extractSiemensInfo(s,'sSpecPara.lExcitationType' );

dDeltaFrequency			 = extractSiemensInfo(s,'sSpecPara.dDeltaFrequency' );
lSpecAppl			 = extractSiemensInfo(s,'sSpecPara.lSpecAppl' );
lSpectralSuppression		 = extractSiemensInfo(s,'sSpecPara.lSpectralSuppression' );
dSpecLipidSupprBandwidth	 = extractSiemensInfo(s,'sSpecPara.dSpecLipidSupprBandwidth' );
dSpecLipidSupprDeltaPos		 = extractSiemensInfo(s,'sSpecPara.dSpecLipidSupprDeltaPos' );
dSpecWaterSupprBandwidth	 = extractSiemensInfo(s,'sSpecPara.dSpecWaterSupprBandwidth' );

tSequenceFileName = extractSiemensInfo(s, 'tSequenceFileName');

Nucleus         = extractSiemensInfo(s, 'sTXSPEC.asNucleusInfo\[0\].tNucleus'); %   = ""1H""
MRFrequency     = extractSiemensInfo(s, 'sTXSPEC.asNucleusInfo\[0\].lFrequency'); %  = 123256300

alTR = extractSiemensInfo(s,'alTR\[0\]')

% rda = fopen(rda_filename);

% These lines indicate the header file.
head_start_text = '>>> Begin of header <<<';
head_end_text   = '>>> End of header <<<';

header_str = head_start_text;



%line = ['PatientName:',' ', info.PatientName.FamilyName, '^',info.PatientName.GivenName,'\n']; %PHANTOM^SPECTROSCOPY
line = ['PatientName:',' ', info.PatientName.FamilyName, '\n']; %PHANTOM^SPECTROSCOPY
header_str = [header_str 10 line];
line = ['PatientID:',' ', info.PatientID,'\n'];
%PatientID: GE MRS
header_str = [header_str 10 line];
line = ['PatientSex:',' ', info.PatientSex,'\n'];
header_str = [header_str 10 line];
line = ['PatientBirthDate:',' ', info.PatientBirthDate,'\n']; %19861103
header_str = [header_str 10 line];
line = ['StudyDate:',' ', info.StudyDate,'\n']; %20111103
header_str = [header_str 10 line];
line = ['StudyTime:',' ', info.StudyTime,'\n']; %160315.875000
header_str = [header_str 10 line];
line = ['StudyDescription:',' ', info.StudyDescription,'\n']; %RESEARCH^YAGER
header_str = [header_str 10 line];
line = ['PatientAge:',' ', info.PatientAge,'\n']; %025Y
header_str = [header_str 10 line];
line = ['PatientWeight:',' ', info.PatientWeight,'\n']; %68.038864
header_str = [header_str 10 line];
line = ['SeriesDate:',' ', info.SeriesDate,'\n']; % 20111103
header_str = [header_str 10 line];
line = ['SeriesTime:',' ', info.SeriesTime,'\n']; % 162249.687000
header_str = [header_str 10 line];
line = ['SeriesDescription:',' ', info.SeriesDescription,'\n']; %2DCSI-1500-30
header_str = [header_str 10 line];
line = ['ProtocolName:',' ', info.ProtocolName,'\n']; %2DCSI-1500-30
header_str = [header_str 10 line];
line = ['PatientPosition:',' ', info.PatientPosition,'\n']; %HFS
header_str = [header_str 10 line];
line = ['SeriesNumber:',' ', num2str(info.SeriesNumber),'\n']; %3
header_str = [header_str 10 line];
line = ['InstitutionName:',' ', info.InstitutionName,'\n']; %University of Iowa
header_str = [header_str 10 line];
line = ['StationName:',' ', info.StationName,'\n']; %MRC35267
header_str = [header_str 10 line];
line = ['ModelName:',' ', info.ManufacturerModelName,'\n']; %TrioTim
header_str = [header_str 10 line];
line = ['DeviceSerialNumber:',' ', info.DeviceSerialNumber,'\n']; % 35267
header_str = [header_str 10 line];
line = ['SoftwareVersion[0]:',' ', info.SoftwareVersion,'\n']; %syngo MR B17
header_str = [header_str 10 line];
line = ['InstanceDate:',' ', info.InstanceCreationDate,'\n']; % 20111103
header_str = [header_str 10 line];
line = ['InstanceTime:',' ', info.InstanceCreationTime,'\n']; %162249.703000
header_str = [header_str 10 line];
line = ['InstanceNumber:',' ', num2str(info.InstanceNumber),'\n']; %1
header_str = [header_str 10 line];
line = ['InstanceComments:',' ', info.ImageComments,'\n']; % _nc_4
header_str = [header_str 10 line];
line = ['AcquisitionNumber:',' ', num2str(info.AcquisitionNumber),'\n']; %1
header_str = [header_str 10 line];
line = ['SequenceName:',' ', tSequenceFileName,'\n']; %*csi_se
header_str = [header_str 10 line];
line = ['SequenceDescription:',' ', tSequenceFileName,'\n']; %*csi_se
header_str = [header_str 10 line];
alTR = extractSiemensInfo(s,'alTR\[0\]');
%line = ['TR:',' ', num2str(str2num(alTR)/1000),'\n' ]; %1500.000000
line = ['TR:',' ', num2str(alTR/1000),'\n' ]; %1500.000000
header_str = [header_str 10 line];
alTE = extractSiemensInfo(s,'alTE\[0\]');
%line = ['TE:',' ', num2str(str2num(alTE)/1000),'\n' ]; %30.000000
line = ['TE:',' ', num2str(alTE/1000),'\n' ]; %30.000000
header_str = [header_str 10 line];
line = ['TM:',' 0','\n'];
% TM:',' 0.000000
header_str = [header_str 10 line];
line = ['TI:',' 0','\n'];
% TI: 0.000000
header_str = [header_str 10 line];
DwellTime = extractSiemensInfo(s, 'sRXSPEC.alDwellTime\[0\]'); 
line = ['DwellTime:',' ', DwellTime,'\n']; % DwellTime: 625
header_str = [header_str 10 line];
line = ['EchoNumber:',' 0','\n']; % EchoNumber: 0
header_str = [header_str 10 line];
NEX = extractSiemensInfo(s, 'lAverages');
line = ['NumberOfAverages:',' ', NEX,'\n']; % NumberOfAverages: 1.000000
header_str = [header_str 10 line];
%line = ['MRFrequency:',' ', num2str(str2num(MRFrequency)/1000000),'\n']; % MRFrequency: 123.256610
line = ['MRFrequency:',' ', num2str(MRFrequency/1000000),'\n']; % MRFrequency: 123.256610
header_str = [header_str 10 line];
line = ['Nucleus:',' ', Nucleus,'\n']; % Nucleus: 1H
header_str = [header_str 10 line];
B0FieldStrength = extractSiemensInfo(s, 'sProtConsistencyInfo.flNominalB0'); % = 2.89362
line = ['MagneticFieldStrength:',' ', B0FieldStrength,'\n']; % 3.000000
header_str = [header_str 10 line];
PhaseEncodingSteps = extractSiemensInfo(s, 'sKSpace.lPhaseEncodingLines'); % = 24
line = ['NumOfPhaseEncodingSteps:',' ', PhaseEncodingSteps,'\n']; %24
header_str = [header_str 10 line];
FlipAngle  = extractSiemensInfo(s, 'adFlipAngleDegree\[0\]'); % = 90
line = ['FlipAngle:',' ', FlipAngle,'\n']; %90.000000
header_str = [header_str 10 line];
lVectorSize			 = extractSiemensInfo(s,'sSpecPara.lVectorSize' );
line = ['VectorSize:',' ', lVectorSize,'\n']; %1024
header_str = [header_str 10 line];
lFinalMatrixSizePhase		 = extractSiemensInfo(s,'sSpecPara.lFinalMatrixSizePhase' );
line = ['CSIMatrixSize[0]:',' ', lFinalMatrixSizePhase,'\n']; %32
header_str = [header_str 10 line];
lFinalMatrixSizeRead		 = extractSiemensInfo(s,'sSpecPara.lFinalMatrixSizeRead' );
line = ['CSIMatrixSize[1]:',' ', lFinalMatrixSizeRead,'\n']; %32
header_str = [header_str 10 line];
lFinalMatrixSizeSlice		 = extractSiemensInfo(s,'sSpecPara.lFinalMatrixSizeSlice' );
line = ['CSIMatrixSize[2]:',' ', lFinalMatrixSizeSlice,'\n']; %1
header_str = [header_str 10 line];
PhaseEncode0 = extractSiemensInfo(s, 'sKSpace.lBaseResolution'); %  = 24
line = ['CSIMatrixSizeOfScan[0]:',' ', PhaseEncode0,'\n']; 
header_str = [header_str 10 line];
PhaseEncode1 = extractSiemensInfo(s, 'sKSpace.lPhaseEncodingLines'); %  = 24
line = ['CSIMatrixSizeOfScan[1]:',' ', PhaseEncode1,'\n']; 
header_str = [header_str 10 line];
PhaseEncode2 = extractSiemensInfo(s, 'sKSpace.lPartitions '); %  = 1
line = ['CSIMatrixSizeOfScan[2]:',' ', PhaseEncode2,'\n']; 
header_str = [header_str 10 line];
line = ['CSIGridShift[0]:',' 0','\n'];
header_str = [header_str 10 line];
line = ['CSIGridShift[1]:',' 0','\n'];
header_str = [header_str 10 line];
line = ['CSIGridShift[2]:',' 0','\n'];
header_str = [header_str 10 line];
% CSIGridShift[1]: 0
% CSIGridShift[2]: 0
HammingFilter = extractSiemensInfo(s, 'sHammingFilter.ucOn'); % HammingFilter: On
line = ['HammingFilter:',' ',HammingFilter,'\n']; %    = 0x1
header_str = [header_str 10 line];

HammingWidth = extractSiemensInfo(s, 'sHammingFilter.lWidthPercent');% HammingFilterWidth: 50
line = ['HammingFilterWidth:',' ',HammingWidth,'\n']; % = 50
header_str = [header_str 10 line];

FreqCorr = extractSiemensInfo(s, 'sAdjData.uiAdjFreMode'); %   = 0x1
line = ['FrequencyCorrection:',' ',FreqCorr,'\n']; % NO
header_str = [header_str 10 line];

TransmitCoil = extractSiemensInfo(s, 'sTXSPEC.ucExcitMode'); %  = 0x1
line = ['TransmitCoil:',' ', TransmitCoil,'\n']; %Body
header_str = [header_str 10 line];

TransRefAmp = extractSiemensInfo(s, 'sTXSPEC.asNucleusInfo\[0\].flReferenceAmplitude'); % = 274.521
line = ['TransmitRefAmplitude[1H]:',' ',TransRefAmp,'\n']; 
header_str = [header_str 10 line];

SliceThickness = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dThickness'); %  = 15
line = ['SliceThickness:',' ', SliceThickness,'\n']; %15.000000
header_str = [header_str 10 line];

PositionVector0 = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].sPosition.dSag'); % = -4.058139801
line = ['PositionVector[0]:',' ', PositionVector0,'\n']; % -105.762712
header_str = [header_str 10 line];

PositionVector1 = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].sPosition.dCor'); % = -25.89830017
line = ['PositionVector[1]:',' ', PositionVector1,'\n']; %-120.290557
header_str = [header_str 10 line];

PositionVector2 = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].sPosition.dTra'); % = 58.57189941
line = ['PositionVector[2]:',' ', PositionVector2,'\n']; % -3.026634
header_str = [header_str 10 line];

line = ['RowVector[0]:',' 1.000000','\n'];
header_str = [header_str 10 line];
line = ['RowVector[1]:',' 0.000000','\n'];
header_str = [header_str 10 line];
line = ['RowVector[2]:',' 0.000000','\n'];
header_str = [header_str 10 line];

ColVector0  = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dSag');
line = ['ColumnVector[0]:',' ', ColVector0,'\n']; %0.000000
header_str = [header_str 10 line];

ColVector1 = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dTra');
line = ['ColumnVector[1]:',' ', ColVector1,'\n']; %0.000000
header_str = [header_str 10 line];

ColVector2 = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dCor');
%line = ['ColumnVector[2]:',' ', num2str(-1*str2num(ColVector2)),'\n']; %0.000000
line = ['ColumnVector[2]:',' ', num2str(-1*ColVector2),'\n']; %0.000000
header_str = [header_str 10 line];

% ColumnVector[1]: 1.000000
% ColumnVector[2]: 0.000000
VOIPosSag = extractSiemensInfo(s, 'SpecPara.sVoI.sPosition.dSag'); % = -4.058139801
line = ['VOIPositionSag:',' ', VOIPosSag,'\n']; %4.237288
header_str = [header_str 10 line];

VOIPosCor = extractSiemensInfo(s, 'SpecPara.sVoI.sPosition.dCor'); %  = -25.89830017
line = ['VOIPositionCor:',' ', VOIPosCor,'\n']; %-10.290557
header_str = [header_str 10 line];

VOIPosTra = extractSiemensInfo(s, 'sSpecPara.sVoI.sPosition.dTra'); % = 58.57189941
line = ['VOIPositionTra:',' ',VOIPosTra,'\n']; %-3.026634
header_str = [header_str 10 line];

VOIThickness = extractSiemensInfo(s, 'SpecPara.sVoI.dThickness'); %     = 15
line = ['VOIThickness:',' ', VOIThickness,'\n']; %15.000000
header_str = [header_str 10 line];

VOIPhaseFOV = extractSiemensInfo(s, 'sSpecPara.sVoI.dPhaseFOV'); %  = 90
line = ['VOIPhaseFOV:',' ', VOIPhaseFOV,'\n']; %100.000000
header_str = [header_str 10 line];

VOIReadFOV = extractSiemensInfo(s, 'pecPara.sVoI.dReadoutFOV'); %     = 90
line = ['VOIReadoutFOV:',' ', VOIReadFOV,'\n']; %100.000000
header_str = [header_str 10 line];

VOINormSag = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dSag'); %    = -3.683339976e-017
line = ['VOINormalSag:',' ', VOINormSag,'\n']; %0.000000
header_str = [header_str 10 line];

VOINormCor = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dCor'); %  = -0.1460829973
line = ['VOINormalCor:',' ', VOINormCor,'\n']; % 0.000000
header_str = [header_str 10 line];

VOINormTra = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dTra');  %  = 0.9892719984
line = ['VOINormalTra:',' ', VOINormTra,'\n']; %1.000000
header_str = [header_str 10 line];


% VOIRotationInPlane: 0.000000
line = ['VOIRotationInPlane:',' 0.000000','\n'];
header_str = [header_str 10 line];


FOVRead = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dReadoutFOV'); %    = 220
line = ['FoVHeight:',' ', FOVRead,'\n']; % 220.000000
header_str = [header_str 10 line];

FOVPhase = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dPhaseFOV');  %   = 220
line = ['FoVWidth:',' ', FOVPhase,'\n']; %220.000000
header_str = [header_str 10 line];

FOVThickness = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dThickness'); % = 15
line = ['FoV3D:',' ', FOVThickness,'\n']; %15.000000
header_str = [header_str 10 line];

FullyExcited = extractSiemensInfo(s, 'sSpecPara.lExcitationType'); %   = 1  %???
line = ['PercentOfRectFoV:',' ', FullyExcited,'\n']; %1.000000
header_str = [header_str 10 line];

Rows = extractSiemensInfo(s, 'sSpecPara.lFinalMatrixSizePhase'); % = 32
line = ['NumberOfRows:',' ',Rows,'\n']; %32
header_str = [header_str 10 line];

Cols = extractSiemensInfo(s, 'sSpecPara.lFinalMatrixSizeRead'); %   = 32
line = ['NumberOfColumns:',' ', Cols,'\n']; %32
header_str = [header_str 10 line];

Slices = extractSiemensInfo(s, 'sSpecPara.lFinalMatrixSizeSlice'); %  = 1
line = ['NumberOf3DParts:',' ', Slices,'\n']; %1
header_str = [header_str 10 line];


% %do the math 220/32 = 6.875
% RowSpacing = num2str(str2num(FOVRead)/str2num(Rows));
% line = ['PixelSpacingRow:',' ', RowSpacing]; %6.875000
% header_str = [header_str 10 line];
% 
% ColSpacing = num2str(str2num(FOVPhase)/str2num(Cols));
% line = ['PixelSpacingCol:',' ', ColSpacing]; %6.875000
% header_str = [header_str 10 line];
% % PixelSpacingCol: 6.875000
% 
% Spacing3D = num2str(str2num(FOVThickness)/str2num(Slices));
% line = ['PixelSpacing3D:',' ', Spacing3D]; %6.875000
% header_str = [header_str 10 line];
% % PixelSpacing3D: 15.000000
line = '>>> End of header <<<'
header_str = [header_str 10 line];


% fprintf(fid, '%s', header_str);

% fclose(fid);