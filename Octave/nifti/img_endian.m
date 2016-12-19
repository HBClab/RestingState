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

