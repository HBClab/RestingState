function [ resultFilename ] = createRDA( dicomFilename, rdaFilename )
%createRDA Convert a Siemens DICOM spectrscopy file to RDA format
%   This function will convert the specified Siemens DICOM file to RDA
%   format. This format is used by LCModel to analyze the metabolic 
%   concentrations.


resultFilename = rdaFilename;

%Create RDA FILE
rda = fopen(rdaFilename, 'w');
header = dicominfo(dicomFilename);
spect = dicomParserMRS(dicomFilename);


[status,sequence,header] = dicom_get_header(header,'SequenceName');
[status,transmitCoil,header] = dicom_get_header(header,'TransmittingCoil');
[status,tr,header] = dicom_get_header(header,'RepetitionTime');
[status,te,header] = dicom_get_header(header,'EchoTime');
[status,ti,header] = dicom_get_header(header,'InversionTime');
[status,numAvgs,header] = dicom_get_header(header,'NumberOfAverages');
[status,frequency,header] = dicom_get_header(header,'ImagingFrequency');
[status,nucleus,header] = dicom_get_header(header,'ImagedNucleus');
[status,echoNumber,header] = dicom_get_header(header,'EchoNumbers');
[status,fieldStrength,header] = dicom_get_header(header,'MagneticFieldStrength');
[status,numPhase,header] = dicom_get_header(header,'NumberOfPhaseEncodingSteps');
[status,phaseFOV,header] = dicom_get_header(header,'PercentPhaseFieldOfView');
[status,receiveCoil,header] = dicom_get_header(header,'ReceivingCoil');
[status,acqMatrix,header] = dicom_get_header(header,'AcquisitionMatrix');
[status,flipAngle,header] = dicom_get_header(header,'FlipAngle');
[status,sliceThickness,header] = dicom_get_header(header,'SliceThickness');
[status,imagePosition,header] = dicom_get_header(header,'ImagePositionPatient');
[status,imageOrientation,header] = dicom_get_header(header,'ImageOrientationPatient');
[status,sliceLocation,header] = dicom_get_header(header,'SliceLocation');
[status,linePosition,header] = dicom_get_header(header,'EchoLinePosition');
[status,columnPosition,header] = dicom_get_header(header,'EchoColumnPosition');
[status,partitionPosition,header] = dicom_get_header(header,'EchoPartitionPosition');
[status,dwellTime,header] = dicom_get_header(header,'RealDwellTime');
[status,pixelSpacing,header] = dicom_get_header(header,'PixelSpacing');
[status,pixelBandwith,header] = dicom_get_header(header,'PixelBandwidth');
[status,gridShiftVector,header] = dicom_get_header(header,'CsiGridshiftVector');
[status,acqPhaseColumns,header] = dicom_get_header(header,'SpectroscopyAcquisitionPhaseColumns');
[status,acqPhaseRows,header] = dicom_get_header(header,'SpectroscopyAcquisitionPhaseRows');
%[status,acqPhase3D,header] = dicom_get_header(header,'SpectroscopyAcquisitionOut-of-planePhaseSteps');
[status,acqDataColumns,header] = dicom_get_header(header,'SpectroscopyAcquisitionDataColumns');
[status,dataPointsRow,header] = dicom_get_header(header,'DataPointRows');
[status,dataPointsColumns,header] = dicom_get_header(header,'DataPointColumns');
[status,numColumns,header] = dicom_get_header(header,'Columns');
[status,numRows,header] = dicom_get_header(header,'Rows');
[status,hammingFilterWidth,header] = dicom_get_header(header,'HammingFilterWidth');
[status,referenceAmplitude,header] = dicom_get_header(header,'TransmitterReferenceAmplitude');
[status,voiThickness,header] = dicom_get_header(header,'VoiThickness');
[status,voiPhaseFov,header] = dicom_get_header(header,'VoiPhaseFoV');
[status,voiReadFov,header] = dicom_get_header(header,'VoiReadoutFoV');
[status,voiOrientation,header] = dicom_get_header(header,'VoiOrientation');
[status,voiPosition,header] = dicom_get_header(header,'VoiPosition');
[status,voiRotation,header] = dicom_get_header(header,'VoiInPlaneRotation');
[status,frequencyCorrect,header] = dicom_get_header(header,'FrequencyCorrection');
[status,sliceSpacing,header] = dicom_get_header(header,'SpacingBetweenSlices');

te = te;
tr = tr;
ti = ti;
tm = 0.0;
dwellTime = dwellTime / 1000.0;
frequency = frequency;

x = spect.lFinalMatrixSizePhase;
y = spect.lFinalMatrixSizeRead; 
z = spect.lFinalMatrixSizeSlice;
v = spect.lVectorSize;

fprintf(rda, '%s\r\n', '>>> Begin of header <<<');
fprintf(rda, '%s %s^%s\r\n', 'PatientName:', header.PatientName.FamilyName,  'TEST' ); %header.PatientName.GivenName
fprintf(rda, '%s %s\r\n', 'PatientID:',header.PatientID);
fprintf(rda, '%s %s\r\n', 'PatientSex:',header.PatientSex);
fprintf(rda, '%s %s\r\n', 'PatientBirthDate:',header.PatientBirthDate);
fprintf(rda, '%s %s\r\n', 'StudyDate:',header.StudyDate);
fprintf(rda, '%s %s\r\n', 'StudyTime:',header.StudyTime);
fprintf(rda, '%s %s\r\n', 'StudyDescription:',header.StudyDescription);
fprintf(rda, '%s %s\r\n', 'PatientAge:',header.PatientAge);
fprintf(rda, '%s %f\r\n', 'PatientWeight:',header.PatientWeight);
fprintf(rda, '%s %s\r\n', 'SeriesDate:', header.SeriesDate);
fprintf(rda, '%s %s\r\n', 'SeriesTime:', header.SeriesTime);
fprintf(rda, '%s %s\r\n', 'SeriesDescription:', header.SeriesDescription);
fprintf(rda, '%s %s\r\n', 'ProtocolName:', header.ProtocolName);
fprintf(rda, '%s %s\r\n', 'PatientPosition:', header.PatientPosition);
fprintf(rda, '%s %i\r\n', 'SeriesNumber:', header.SeriesNumber);
fprintf(rda, '%s %s\r\n', 'InstitutionName:', header.InstitutionName);
fprintf(rda, '%s %s\r\n', 'StationName:', header.StationName);
fprintf(rda, '%s %s\r\n', 'ModelName:', header.ManufacturerModelName);
fprintf(rda, '%s %s\r\n', 'DeviceSerialNumber:', header.DeviceSerialNumber);
fprintf(rda, '%s %s\r\n', 'SoftwareVersion[0]:', header.SoftwareVersion); 
fprintf(rda, '%s %s\r\n', 'InstanceDate:', header.InstanceCreationDate);
fprintf(rda, '%s %s\r\n', 'InstanceTime:', header.InstanceCreationTime);
fprintf(rda, '%s %i\r\n', 'InstanceNumber:', header.InstanceNumber);
fprintf(rda, '%s %s\r\n', 'InstanceComments:', header.ImageComments);
fprintf(rda, '%s %i\r\n', 'AcquisitionNumber:', header.AcquisitionNumber);
fprintf(rda, '%s %s\r\n', 'SequenceName:', sequence ); % 
fprintf(rda, '%s %s\r\n', 'SequenceDescription:', sequence);  
fprintf(rda, '%s %.6f\r\n', 'TR:', tr );
fprintf(rda, '%s %.6f\r\n', 'TE:', te );
fprintf(rda, '%s %.6f\r\n', 'TM:', tm );
fprintf(rda, '%s %.6f\r\n', 'TI:', ti );
fprintf(rda, '%s %d\r\n', 'DwellTime:', dwellTime);
fprintf(rda, '%s %d\r\n', 'EchoNumber:', echoNumber);
fprintf(rda, '%s %.6f\r\n', 'NumberOfAverages:', numAvgs);
fprintf(rda, '%s %.6f\r\n', 'MRFrequency:', frequency);
fprintf(rda, '%s %s\r\n', 'Nucleus:', nucleus);
fprintf(rda, '%s %.6f\r\n', 'MagneticFieldStrength:', fieldStrength);
fprintf(rda, '%s %i\r\n', 'NumOfPhaseEncodingSteps:', numPhase);
fprintf(rda, '%s %i\r\n', 'FlipAngle:', flipAngle );
fprintf(rda, '%s %i\r\n', 'VectorSize:', spect.lVectorSize );
fprintf(rda, '%s %i\r\n', 'CSIMatrixSize[0]:', spect.lFinalMatrixSizePhase);
fprintf(rda, '%s %i\r\n', 'CSIMatrixSize[1]:', spect.lFinalMatrixSizeRead);
fprintf(rda, '%s %i\r\n', 'CSIMatrixSize[2]:', spect.lFinalMatrixSizeSlice);
fprintf(rda, '%s %i\r\n', 'CSIMatrixSizeOfScan[0]:', spect.sKSpace.lBaseResolution);
fprintf(rda, '%s %i\r\n', 'CSIMatrixSizeOfScan[1]:', spect.sKSpace.lPhaseEncodingLines);
fprintf(rda, '%s %i\r\n', 'CSIMatrixSizeOfScan[2]:', spect.sKSpace.lPartitions);
if (length(gridShiftVector) == 0)
  fprintf(rda, '%s %d\r\n', 'CSIGridShift[0]:', 0.0);
  fprintf(rda, '%s %d\r\n', 'CSIGridShift[1]:', 0.0);
  fprintf(rda, '%s %d\r\n', 'CSIGridShift[2]:', 0.0);
else
  fprintf(rda, '%s %d\r\n', 'CSIGridShift[0]:', gridShiftVector(1));
  fprintf(rda, '%s %d\r\n', 'CSIGridShift[1]:', gridShiftVector(2));
  fprintf(rda, '%s %d\r\n', 'CSIGridShift[2]:', gridShiftVector(3));
end
if (hammingFilterWidth == 0.0)
    fprintf(rda, '%s %s\r\n', 'HammingFilter:', 'Off');
else
    fprintf(rda, '%s %s\r\n', 'HammingFilter:', 'On');
end

if (hammingFilterWidth > 0.0)
    fprintf(rda, '%s %d\r\n', 'HammingFilterWidth:', hammingFilterWidth);
end

fprintf(rda, '%s %s\r\n', 'FrequencyCorrection:', frequencyCorrect); 
fprintf(rda, '%s %s\r\n', 'TransmitCoil:', transmitCoil);
fprintf(rda, '%s %.6f\r\n', 'TransmitRefAmplitude[1H]:', referenceAmplitude);
fprintf(rda, '%s %.6f\r\n', 'SliceThickness:', sliceThickness);
fprintf(rda, '%s %.6f\r\n', 'PositionVector[0]:', imagePosition(1));
fprintf(rda, '%s %.6f\r\n', 'PositionVector[1]:', imagePosition(2));
fprintf(rda, '%s %.6f\r\n', 'PositionVector[2]:', imagePosition(3));
fprintf(rda, '%s %.6f\r\n', 'RowVector[0]:', imageOrientation(1));
fprintf(rda, '%s %.6f\r\n', 'RowVector[1]:', imageOrientation(2));
fprintf(rda, '%s %.6f\r\n', 'RowVector[2]:', imageOrientation(3));
fprintf(rda, '%s %.6f\r\n', 'ColumnVector[0]:', imageOrientation(4));
fprintf(rda, '%s %.6f\r\n', 'ColumnVector[1]:', imageOrientation(5));
fprintf(rda, '%s %.6f\r\n', 'ColumnVector[2]:', imageOrientation(6));
fprintf(rda, '%s %.6f\r\n', 'VOIPositionSag:', voiPosition(1));
fprintf(rda, '%s %.6f\r\n', 'VOIPositionCor:', voiPosition(2));
fprintf(rda, '%s %.6f\r\n', 'VOIPositionTra:', voiPosition(3));
fprintf(rda, '%s %.6f\r\n', 'VOIThickness:', voiThickness);
fprintf(rda, '%s %.6f\r\n', 'VOIPhaseFOV:', voiPhaseFov);
fprintf(rda, '%s %.6f\r\n', 'VOIReadoutFOV:', voiReadFov);
fprintf(rda, '%s %.6f\r\n', 'VOINormalSag:', voiOrientation(1));
fprintf(rda, '%s %.6f\r\n', 'VOINormalCor:', voiOrientation(2));
fprintf(rda, '%s %.6f\r\n', 'VOINormalTra:', voiOrientation(3));
fprintf(rda, '%s %.6f\r\n', 'VOIRotationInPlane:', voiRotation);
if ((x == 1) && (y == 1) && (z == 1))
  fprintf(rda, '%s %.6f\r\n', 'FoVHeight:', voiPhaseFov );
  fprintf(rda, '%s %.6f\r\n', 'FoVWidth:', voiReadFov);
  fprintf(rda, '%s %.6f\r\n', 'FoV3D:', voiThickness);
else
  fprintf(rda, '%s %.6f\r\n', 'FoVHeight:', spect.dPhaseFOV );
  fprintf(rda, '%s %.6f\r\n', 'FoVWidth:', spect.dReadoutFOV);
  fprintf(rda, '%s %.6f\r\n', 'FoV3D:', spect.dThickness);
end
fprintf(rda, '%s %.6f\r\n', 'PercentOfRectFoV:', phaseFOV);
fprintf(rda, '%s %i\r\n', 'NumberOfRows:', spect.lFinalMatrixSizePhase);
fprintf(rda, '%s %i\r\n', 'NumberOfColumns:', spect.lFinalMatrixSizeRead);
fprintf(rda, '%s %i\r\n', 'NumberOf3DParts:', spect.lFinalMatrixSizeSlice);
fprintf(rda, '%s %.6f\r\n', 'PixelSpacingRow:', pixelSpacing(1));
fprintf(rda, '%s %.6f\r\n', 'PixelSpacingCol:', pixelSpacing(2));
fprintf(rda, '%s %.6f\r\n', 'PixelSpacing3D:', sliceThickness);
fprintf(rda, '%s\r\n', '>>> End of header <<<');

fd = dicom_open(dicomFilename);
[y_s,r,imag] = dicom_get_spectrum_siemens(fd);
fclose(fd);

tmpVector = zeros(v*2, 1);

writeSize=0;
for index = 1:x*y*z
  for (i=1:v)
    tmpVector(2*i-1) = r((index-1)*v+i); 
    tmpVector(2*i) = imag((index-1)*v+i);
   end
   fwrite(rda, tmpVector, 'double');
end

fclose(rda);


end

