function value = extractSiemensInfo( siemensDicomField, fieldName)

% This function extracts fields from the proprietary section of the Siemens DICOM header.

% siemensDicomField: A character string extracted from the appropriate
% DICOM tag in a Siemens MRI file.  This can be set up, for example,
% by
%
% info=dicominfo(fname);
% siemensDicomField = char( getfield( info,'Private_0029_1120' ) )';
%
% fieldName: A character string matching the variable value in the
% private header.  These usually take the form of something like
% 'sSpecPara.lVectorSize'.  Presently, the way this matches is directly
% with a regular expression incorporating 'fieldName' and it needs to
% match to the end of the field name.  This means that you may need to
% escape some characters such as square brackets (e.g. to get 
% sGRADSPEC.sEddyCompensationX.aflAmplitude[0], you'll need to pass 
% 'sGRADSPEC.sEddyCompensationX.aflAmplitude\[0\]'.
%
% Returns: If a match is found, returns the value.  Otherwise it
% returns an empty vector.
%

% Limitations: This now works for string, numerical, and hexadecimal
% data.  As mentioned above, it also uses the passed field name
% directly as a regular expression, so some characters will have
% special meaning.  For '.' this will almost never matter, but
% brackets/braces/parens may need special attention.  The strings are
% assumed to be contained in double-double quotes (e.g. ""STRING"").
% The regular expressions are not exhaustive and can likely be fooled
% in some cases.

% Regular expression for matching a hexadecimal integer
hexRegex	 = '0x(-*[0-9A-Fa-f][0-9A-Fa-f]*)';

% Regular expression for matching an integer or real number.  This
% one is not bulletproof, but seems to get everything I've tried so
% far correct.
numericRegex	 = '(-*[0-9][0-9]*\.*[0-9e-]*)';

% Regular expression for matching a string value.  Again, probably
% doesn't account for everything, but as long as it gets the
% basics, it should be useful.
stringRegex      = '""([^"]*)""*';

% See if the hex form matches.  If so, it gets converted to a number
% differently than real numbers.
[numericField] = regexp(siemensDicomField,[fieldName, ' *= *' hexRegex], 'tokens');
if length(numericField) ~= 0,
  value = [ num2str(hex2dec( char( numericField{1,1} ) ) )];

% Not Hex, try regular number.
else
  [numericField] = regexp(siemensDicomField,[fieldName, ' *= *' numericRegex], 'tokens');
  if length(numericField) ~= 0,
    value = [  char( numericField{1,1} )  ]; %str2num()

% Wasn't a number either, so report it as 'unknown'' with an empty vector.
  else
    stringField = regexp(siemensDicomField,[fieldName, ' *= *', stringRegex], 'tokens');
    if length(stringField) ~= 0,
      value = char( stringField{1,1} );
    else
      value = [];
    end
  end
end

