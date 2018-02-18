function spec = dicomParserMRS(fname)

% Casey Johnson
%
% Modified from spectinfo.m provided by Jeff Yager
%
% This function takes a dicom file and reports Siemens specific
% spectroscopy information.
%
% Usage: spectinfo('test.dcm')
% [filename , pathname] = uigetfile('*.dcm', 'Select an DCM file');
% fname = fullfile(pathname , filename);

% Extracting image info from 
info = dicominfo( fname );

% Grab the Siemens specific header (mostly the Phoenix stuff, I think).
s = char(getfield(info,'Private_0029_1120'))';



spec.lPreparingScans			 = extractSiemensInfo(s,'sSpecPara.lPreparingScans' );
spec.lPhaseCyclingType		 = extractSiemensInfo(s,'sSpecPara.lPhaseCyclingType' );
spec.lPhaseEncodingType		 = extractSiemensInfo(s,'sSpecPara.lPhaseEncodingType' );
spec.lRFExcitationBandwidth		 = extractSiemensInfo(s,'sSpecPara.lRFExcitationBandwidth' );
spec.sVoI_sPosition_dSag		 = extractSiemensInfo(s,'sSpecPara.sVoI.sPosition.dSag' );
spec.sVoI_sPosition_dCor		 = extractSiemensInfo(s,'sSpecPara.sVoI.sPosition.dCor' );
spec.sVoI_sPosition_dTra		 = extractSiemensInfo(s,'sSpecPara.sVoI.sPosition.dTra' );
spec.sVoI_sNormal_dTra		 = extractSiemensInfo(s,'sSpecPara.sVoI.sNormal.dTra' );
spec.sVoI_dThickness			 = extractSiemensInfo(s,'sSpecPara.sVoI.dThickness' );
spec.sVoI_dPhaseFOV			 = extractSiemensInfo(s,'sSpecPara.sVoI.dPhaseFOV' );
spec.sVoI_dReadoutFOV		 = extractSiemensInfo(s,'sSpecPara.sVoI.dReadoutFOV' );
spec.ucVoIValid			 = extractSiemensInfo(s,'sSpecPara.ucVoIValid' );
spec.ucRemoveOversampling		 = extractSiemensInfo(s,'sSpecPara.ucRemoveOversampling' );
spec.lAutoRefScanNo			 = extractSiemensInfo(s,'sSpecPara.lAutoRefScanNo' );
spec.ucOuterVolumeSuppression	 = extractSiemensInfo(s,'sSpecPara.ucOuterVolumeSuppression' );
spec.lDecouplingType			 = extractSiemensInfo(s,'sSpecPara.lDecouplingType' );
spec.lNOEType			 = extractSiemensInfo(s,'sSpecPara.lNOEType' );
spec.lExcitationType			 = extractSiemensInfo(s,'sSpecPara.lExcitationType' );
spec.dDeltaFrequency			 = extractSiemensInfo(s,'sSpecPara.dDeltaFrequency' );
spec.lSpecAppl			 = extractSiemensInfo(s,'sSpecPara.lSpecAppl' );
spec.lSpectralSuppression		 = extractSiemensInfo(s,'sSpecPara.lSpectralSuppression' );
spec.dSpecLipidSupprBandwidth	 = extractSiemensInfo(s,'sSpecPara.dSpecLipidSupprBandwidth' );
spec.dSpecLipidSupprDeltaPos		 = extractSiemensInfo(s,'sSpecPara.dSpecLipidSupprDeltaPos' );
spec.dSpecWaterSupprBandwidth	 = extractSiemensInfo(s,'sSpecPara.dSpecWaterSupprBandwidth' );
spec.tSequenceFileName = extractSiemensInfo(s, 'tSequenceFileName');
spec.sTXSPEC.asNucleusInfo.tNucleus         = extractSiemensInfo(s, 'sTXSPEC.asNucleusInfo\[0\].tNucleus'); %   = ""1H""
spec.sTXSPEC.asNucleusInfo.lFrequency     = extractSiemensInfo(s, 'sTXSPEC.asNucleusInfo\[0\].lFrequency'); %  = 123256300
spec.dPhaseFOV = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dPhaseFOV');
spec.dReadoutFOV = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dReadoutFOV');
spec.dThickness = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dThickness');
spec.alTR = extractSiemensInfo(s,'alTR\[0\]');
spec.alTE = extractSiemensInfo(s,'alTE\[0\]');
spec.alTM = extractSiemensInfo(s,'alTM\[0\]');
spec.alTI = extractSiemensInfo(s,'alTI\[0\]');
spec.sRXSPEC.alDwellTime = extractSiemensInfo(s, 'sRXSPEC.alDwellTime\[0\]'); 
spec.lAverages = extractSiemensInfo(s, 'lAverages');
spec.sProtConsistencyInfo.flNominalB0 = extractSiemensInfo(s, 'sProtConsistencyInfo.flNominalB0'); % = 2.89362
spec.sKSpace.lPhaseEncodingLines = extractSiemensInfo(s, 'sKSpace.lPhaseEncodingLines'); % = 24
spec.adFlipAngleDegree  = extractSiemensInfo(s, 'adFlipAngleDegree\[0\]'); % = 90
spec.lVectorSize			 = extractSiemensInfo(s,'sSpecPara.lVectorSize' );
spec.lFinalMatrixSizePhase		 = extractSiemensInfo(s,'sSpecPara.lFinalMatrixSizePhase' );
spec.lFinalMatrixSizeRead		 = extractSiemensInfo(s,'sSpecPara.lFinalMatrixSizeRead' );
spec.lFinalMatrixSizeSlice		 = extractSiemensInfo(s,'sSpecPara.lFinalMatrixSizeSlice' );
spec.sKSpace.lBaseResolution = extractSiemensInfo(s, 'sKSpace.lBaseResolution'); %  = 24
spec.sKSpace.lPhaseEncodingLines = extractSiemensInfo(s, 'sKSpace.lPhaseEncodingLines'); %  = 24
spec.sKSpace.lPartitions = extractSiemensInfo(s, 'sKSpace.lPartitions '); %  = 1
spec.sHammingFilter.ucOn = extractSiemensInfo(s, 'sHammingFilter.ucOn'); % HammingFilter: On
spec.sHammingFilter.lWidthPercent = extractSiemensInfo(s, 'sHammingFilter.lWidthPercent');% HammingFilterWidth: 50
spec.sAdjData.uiAdjFreMode = extractSiemensInfo(s, 'sAdjData.uiAdjFreMode'); %   = 0x1
spec.sTXSPEC.ucExcitMode = extractSiemensInfo(s, 'sTXSPEC.ucExcitMode'); %  = 0x1
spec.sTXSPEC.asNucleusInfo0.flReferenceAmplitude = extractSiemensInfo(s, 'sTXSPEC.asNucleusInfo\[0\].flReferenceAmplitude'); % = 274.521
spec.sSliceArray.asSlice0.dThickness = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dThickness'); %  = 15
spec.sSliceArray.asSlice0.sPosition.dSag = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].sPosition.dSag'); % = -4.058139801
spec.sSliceArray.asSlice0.sPosition.dCor = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].sPosition.dCor'); % = -25.89830017
spec.sSliceArray.asSlice0.sPosition.dTra = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].sPosition.dTra'); % = 58.57189941
spec.sVoI.sNormal.dSag  = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dSag');
spec.sVoI.sNormal.dTra = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dTra');
spec.sVoI.sNormal.dCor = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dCor');
spec.sVoI.sPosition.dSag = extractSiemensInfo(s, 'SpecPara.sVoI.sPosition.dSag'); % = -4.058139801
spec.sVoI.sPosition.dCor = extractSiemensInfo(s, 'SpecPara.sVoI.sPosition.dCor'); %  = -25.89830017
spec.sVoI.sPosition.dTra = extractSiemensInfo(s, 'sSpecPara.sVoI.sPosition.dTra'); % = 58.57189941
spec.sVoI.dThickness = extractSiemensInfo(s, 'SpecPara.sVoI.dThickness'); %     = 15
spec.sVoI.dPhaseFOV = extractSiemensInfo(s, 'sSpecPara.sVoI.dPhaseFOV'); %  = 90
spec.sVoI.dReadoutFOV = extractSiemensInfo(s, 'pecPara.sVoI.dReadoutFOV'); %     = 90
spec.sVoI.sNormal.dSag = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dSag'); %    = -3.683339976e-017
spec.sVoI.sNormal.dCor = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dCor'); %  = -0.1460829973
spec.sVoI.sNormal.dTra = extractSiemensInfo(s, 'sSpecPara.sVoI.sNormal.dTra');  %  = 0.9892719984
spec.sSliceArray.asSlice0.dReadoutFOV = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dReadoutFOV'); %    = 220
spec.sSliceArray.asSlice0.dPhaseFOV = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dPhaseFOV');  %   = 220
spec.sSliceArray.asSlice0.dThickness = extractSiemensInfo(s, 'sSliceArray.asSlice\[0\].dThickness'); % = 15
spec.lExcitationType = extractSiemensInfo(s, 'sSpecPara.lExcitationType'); %   = 1  %???
spec.lFinalMatrixSizePhase = extractSiemensInfo(s, 'sSpecPara.lFinalMatrixSizePhase'); % = 32
if (length(spec.lFinalMatrixSizePhase) == 0)
    spec.lFinalMatrixSizePhase = 1;
end
spec.lFinalMatrixSizeRead = extractSiemensInfo(s, 'sSpecPara.lFinalMatrixSizeRead'); %   = 32
if (length(spec.lFinalMatrixSizeRead) == 0)
    spec.lFinalMatrixSizeRead = 1;
end
spec.lFinalMatrixSizeSlice = extractSiemensInfo(s, 'sSpecPara.lFinalMatrixSizeSlice'); %  = 1


end
