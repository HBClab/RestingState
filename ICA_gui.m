function varargout = ICA_gui(varargin)
%  - module for automatic and manual detection and removal of noise
%           components in single session ICA generated in FSL's MELODIC
%
% ICA_gui
% Launches the ICA_gui. This will prompt the user to enter the .ica directory
% of a completed single session MELODIC. Optionally the user can also
% specify a motion parameter .par file of the same scan.
%
% The top image displays the spatial pattern of the selected component.
%
% The middle image shows the timecourse of the component. If the user loads
% in the motion parameter .par file, the motion graphs can be overlaid on
% this image.
%
% The bottom image shows the frequency specturm of the particular
% component.
%
% On the right side of the gui, there are navigational controls for
% selecting the previous and next copmomnnents in the series, as well as
% buttons to manually classify each component, and a text box to enter
% notes about the component
%
% In the bottom right corner, there is a button to save the current
% classification.
%--------------------------------------------------------------------------
% CHANGE LOG:
% 7/16: Cleaned up code
%
%
% Kevin Terashima 2011
% Last Modified by GUIDE v2.5 24-May-2013 11:23:38

%% ---------------   GUI initialization  -----------------------------
% GUIDE GUI default creation and callback support
% --------------------------------------------------------------------
% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ICA_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @ICA_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


%% ---------------   Main process -----------------------------
% Main functionality of ICA_gui (this process runs once for each dataset)
% --------------------------------------------------------------------

% -----------------------------------------------------------------------
% ICA_gui_OPENINGFCN
% This function is called before opening the gui.
% -----------------------------------------------------------------------
% --- Executes just before ICA_gui is made visible.
function ICA_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ICA_gui_v1_1 (see VARARGIN)

handles.ica_folder = blanks(1);
handles.Index = 1;
handles.threshmap2 = '_thresh.png';
handles.png = '.png';
handles.txt = '.txt';
handles.motion_par=0;
handles.ica_home_path = pwd;
handles.motion_home_path = pwd;

%default view: all
handles.view = 4;

% Choose default command line output for ICA_gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ICA_gui_v1_1 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = ICA_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Outputs from pushbutton5 and pushbutton7 (Navigation)
function Prev_Next_Callback(hObject, eventdata,handles,str)
% Get the index pointer
viewArray=handles.viewArray;
index = find(viewArray==handles.Index);
% Depending on whether Prev or Next was clicked,
% change the display
switch str
case 'Prev'
	% Decrease the index by one
	i = index - 1;	
	% If the index is less than one then set it equal to the index
   %  of the last element in the Addresses array
	if i < 1
		i = length(handles.viewArray);
	end
case 'Next'
	% Increase the index by one
	i = index + 1;	
	% If the index is greater than the size of the array then 
	% point to the first item in the Addresses array
	if i > length(handles.viewArray)
		i = 1;
	end	
end

handles.Index = viewArray(i);
guidata(hObject, handles);
set_viewArray(hObject,handles);
%RefreshScreen(hObject,handles);


% --- Update the screen with the relavent info
function RefreshScreen(hObject,handles)
% Get the appropriate data for the index in selected
classified = handles.Classified;
i = handles.Index;

set(handles.numCom,'String',int2str(i)); %Current component number
%if the component images exist
% Display the png files for the component
% thresholded map
  if exist([handles.threshmap1,int2str(i),handles.threshmap2],'file')==0  
warndlg('Warning: Component images do not exist! Consider re-running MELODIC','Bad input');
return;
  end

axes(handles.axes1);
imshow([handles.threshmap1,int2str(i),handles.threshmap2]);
% temporal
%temporal_data=load([handles.temporal,int2str(i),handles.txt]);
temporal_data=handles.temporal;
axes(handles.axes2);
plot(temporal_data(:,i),'color','k');
%plot(temporal_data(:,2),'color','r');
set(handles.axes2,'Xlim',[0 length(temporal_data)],'Color','none');
title('temporal timecourse');
xlabel('TR');
ylabel('Normalized Response');


%CW added to overlay predicted task model 
%***COMMENT OUT IF YOU DON'T HAVE A PREDICTED TASK MODEL***
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%axes(handles.axes6);
%task_ts=load([handles.model,int2str(i),'.txt']);
%plot(task_ts(:,2),'color','m');
%Ytask=ylim(handles.axes2);
%set(handles.axes6,'Xlim',[0 length(temporal_data)],'Color','none');
%set(handles.axes6,'Ylim',Ytask,'Color','none');
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

% power spectrum
%Below is code to displat the png file 
%axes(handles.axes3);
%imshow([handles.power,int2str(i),handles.png]);

%Below is code if you want to plot out power spectrum
power_ax=handles.powerax;
power_data=load([handles.power,int2str(i),handles.txt]);
axes(handles.axes3);
plot((power_ax*100), power_data);
%set(handles.axes3,'Xlim',[0 (max(power_ax)*100)]);
title('Powerspectrum of timecourse');
xlabel('Frequency (in Hz / 100)');
ylabel('Power');

%BG color
switch classified(i)
    case 0
        set(handles.class_pannel,'BackgroundColor',[0.7,0.7,0.7]);
    case 1
        set(handles.class_pannel,'BackgroundColor',[0,0.5,0]);
    case 2
        set(handles.class_pannel,'BackgroundColor','yellow');
    case 3
        set(handles.class_pannel,'BackgroundColor','red');
end

%Name of subject
[pathstr, ~, ~] = fileparts(handles.ica_folder);
set(handles.subject_name,'String', pathstr);
% Explained and total Variance
set(handles.exp_var_txt,'String',[num2str(handles.explained_var(handles.Index),3),'% of explained variance']);
set(handles.tot_var_txt,'String',[num2str(handles.total_var(handles.Index),3),'% of total variance']);

%CW ADDED
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% percent activation in CSF, GM, WM 
set(handles.text4,'String',[num2str(handles.percent(handles.Index,3),4),'% GM']);
set(handles.text5,'String',[num2str(handles.percent(handles.Index,4),4),'% WM']);
set(handles.text6,'String',[num2str(handles.percent(handles.Index,2),4),'% CSF']);
set(handles.text18,'String',[num2str(handles.percent(handles.Index,5),4),'% OUT']);

%percent freq above .1hz
set(handles.text19,'String',[num2str(handles.freqthresh(handles.Index,2),4),'% Freq>.1']);
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%Progress/Stats box
%number of signal
numSig=sum(classified==1);
%number of borderline
numBorder=sum(classified==2);
%number of noise
numNoise=sum(classified==3);
%total classified
totalClassified=numSig+numBorder+numNoise;

% Set notes box
set(handles.note_box,'String',handles.notes{handles.Index});

% Set progress box
set(handles.totalProgress,'String',[int2str(totalClassified),'/',int2str(handles.numComponents),' Components Classified']);
set(handles.signalCom,'String',[int2str(numSig),' Signal Componets']);
set(handles.borderCom,'String',[int2str(numBorder),' Borderline Componets']);
set(handles.noiseCom,'String',[int2str(numNoise),' Noise Components']);

%Enable correct menu items
if sum(classified==1)>0
set(handles.menu_view_sig,'Enable','on');
else
set(handles.menu_view_sig,'Enable','off');
end
if sum(classified==2)>0
set(handles.menu_view_bor,'Enable','on');
else
set(handles.menu_view_bor,'Enable','off');
end
if sum(classified==3)>0
set(handles.menu_view_noi,'Enable','on');
else
set(handles.menu_view_noi,'Enable','off');
end
if sum(classified==0)>0
set(handles.menu_view_un,'Enable','on');
else
set(handles.menu_view_un,'Enable','off');
end

handles.totalClassified = totalClassified;
guidata(hObject, handles);
% Components listbox
load_listbox(handles);

% --- Executes on button press of classification buttons
function classify_Callback(hObject, eventdata,handles,str)

classified = handles.Classified;
index = handles.Index;

switch str
    case 'Signal'
        classified(index) = 1;
    case 'Borderline'
        classified(index) = 2;
    case 'Noise'
        classified(index) = 3;
end

handles.Classified = classified;
guidata(hObject, handles);
Prev_Next_Callback(hObject, eventdata,handles,'Next');



% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox1
get(handles.figure1,'SelectionType');
if strcmp(get(handles.figure1,'SelectionType'),'open')
    index_selected = get(handles.listbox1,'Value');
    handles.Index = handles.viewArray(index_selected);
    guidata(hObject, handles);
    RefreshScreen(hObject,handles);
end


% --- Executes during object creation, after setting all properties.
function listbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function load_listbox(handles)
classified = handles.Classified; 
viewArray = handles.viewArray; 
numArray = {1:length(handles.viewArray)}';
notes=handles.notes;
set(handles.listbox1, 'Value',1);

for i=1:length(viewArray);
    switch classified(viewArray(i))
        case 0 %Unclassified
            numArray{i}=['<HTML><FONT COLOR="black">', int2str(viewArray(i)), '</FONT></HTML>'];
        case 1 %Signal
            numArray{i}=['<HTML><FONT COLOR="green">', int2str(viewArray(i)), '</FONT><FONT COLOR="black"> Signal ', notes{i}, '</FONT></HTML>'];
        case 2 %Borderline
            numArray{i} =['<HTML><FONT COLOR="yellow">',int2str(viewArray(i)),'</FONT><FONT COLOR="black"> Borderline ', notes{i}, '</FONT></HTML>'];
        case 3 %Noise
            numArray{i} = ['<HTML><FONT COLOR="red">',int2str(viewArray(i)),'</FONT><FONT COLOR="black"> Noise ', notes{i}, '</FONT></HTML>'];
    end
end

set(handles.listbox1,'String',numArray, ...
    'Value',1);
set(handles.listbox1,'Value',find(handles.viewArray==handles.Index));

% --- Executes on button press in finishButton (Finished)
function finishButton_Callback(hObject, eventdata, handles)
% hObject    handle to finishButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Saves the classified array and 3 text files with the info
RefreshScreen(hObject,handles);
finished_array = handles.Classified;
numComponents = handles.numComponents;
totalClassified = handles.totalClassified;
notes = handles.notes;

% send warning if classification is not complete
if numComponents ~= totalClassified
    Answer=questdlg('Classification not complete! Save anyway?', ... 
        'Save Unfinished Classification', ... 
        'Yes','Cancel','Yes');
    switch Answer
        case 'Yes'
            save([handles.ica_folder,'/manual_labeling/manualclassify.mat'],'finished_array','notes');
            msgbox('Classification saved','ICA_gui');
        case 'Cancel'
            return
    end
% else if classification is complete, also save text files that can be read by
% fsl_regfilt
else
    save([handles.ica_folder,'/manual_labeling/manualclassify.mat'],'finished_array','notes');
    sig_list=find(finished_array'==1);
    border_list=find(finished_array'==2);
    noise_list=find(finished_array'==3);
    csvwrite([handles.ica_folder,'/manual_labeling/signal_com.txt'],sig_list);
    csvwrite([handles.ica_folder,'/manual_labeling/border_com.txt'],border_list);
    csvwrite([handles.ica_folder,'/manual_labeling/noise_com.txt'],noise_list);
    
    %create notes file
    number=1:1:numComponents;
    label={'signal','border','noise'};
    notes_file=[handles.ica_folder,'/manual_labeling/notes.txt'];
    fid = fopen(notes_file, 'w');
    for i=1:numComponents
        fprintf(fid, '%d\t%s\t%s\n', number(i), label{finished_array(i)}, notes{i});
    end
    fclose(fid);
    
    msgbox('Classification and text files saved','ICA_gui');
end

% --------------------------------------------------------------------
function menu_help_tutorial_Callback(hObject, eventdata, handles)
% hObject    handle to menu_help_tutorial (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
about_string=sprintf('First load in a .ica folder\n');
msgbox(about_string,'ICA_gui','help');

% --------------------------------------------------------------------
function menu_help_about_Callback(hObject, eventdata, handles)
% hObject    handle to menu_help_about (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
about_string=sprintf('ICA_gui\nBy Kevin Terashima\nVersion 1.0');
msgbox(about_string,'ICA_gui','help');

% --------------------------------------------------------------------
function menu_file_open_Callback(hObject, eventdata, handles)
% hObject    handle to menu_file_open (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Check if previous classfication is unsaved
if isequal(handles.ica_folder,blanks(1))==0
    if exist([handles.ica_folder,'/manual_labeling/manualclassify.mat'],'file')==0    
Answer=questdlg('Warning: Unsaved classification! Continue without saving?', ... 
        'Unsaved Classification', ... 
        'Yes','Cancel','Cancel');
    switch Answer
        case 'Yes'
            %continue to next part
        case 'Cancel'
            return
    end
    end
end
    
ica_folder = uigetdir(handles.ica_home_path,'Select .ica folder'); %load in ICA folder
if isequal(ica_folder,0)
    return
else
    [~,~,ext]=fileparts(ica_folder);
    if isequal(ext,'.ica')
    handles.ica_folder = ica_folder;
    else
        warndlg('Not a valid .ica folder!','Bad input');
        return
    end
end

handles.ica_folder = ica_folder;
handles.motion_par = 0; % clear previous motion parameters

% Get number of components
stats_file=[ica_folder,'/melodic_ICstats'];
[~,result]=unix(['cat ', stats_file, ' | wc -l']);
numComponents = str2num(result);
handles.numComponents = numComponents;

fid = fopen(stats_file);
variance = textscan(fid, '%f %f %f %f');
fclose(fid);

handles.explained_var=variance{1,1};
handles.total_var=variance{1,2};

% check for .mat array with previously classified components
load_old = exist([ica_folder,'/manual_labeling/'],'dir');
if load_old == 0 % if not, then create directory "manual_labeling"
    unix(['mkdir ',ica_folder,'/manual_labeling/']);
    handles.Classified = zeros(handles.numComponents,1);
    handles.notes=cell(handles.numComponents,1);
else % initialize array for previously classified components
    old_save_file = exist([ica_folder,'/manual_labeling/manualclassify.mat'], 'file');
    if old_save_file == 2
        load ([ica_folder,'/manual_labeling/manualclassify.mat']);
        handles.Classified = finished_array;
        if exist('notes','var') == 1
            handles.notes=notes;
        else
            handles.notes=cell(handles.numComponents,1);
        end
    else
        handles.Classified = zeros(handles.numComponents,1);
        handles.notes=cell(handles.numComponents);
    end
end

% Initialize names
handles.Index = 1;
handles.threshmap1 = [ica_folder,'/report/IC_'];
handles.model = [ica_folder,'/report/t'];
handles.power = [ica_folder,'/report/f'];

%Load arrays

%CWadded
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Segmented percent
handles.percent = load(fullfile(ica_folder,'/statsreg/segmented_percentact.txt'));
%Temporal timecourses
handles.temporal = load(fullfile(ica_folder,'melodic_mix'));
%Power x-axis uncomment if you want to plot power spectrum 
handles.powerax = load(fullfile(ica_folder,'/freq_thresh/Hzconv.txt')); 
%Freq threshold
handles.freqthresh = load(fullfile(ica_folder,'/freq_thresh/f_thresh.txt'));
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


% Initialize Current view
handles.viewArray = (1:length(handles.Classified))';

% Enable buttons
set(handles.signal_button,'Enable','on');
set(handles.noise_button,'Enable','on');
set(handles.borderline_button,'Enable','on');
set(handles.pushbutton5,'Enable','on');
set(handles.pushbutton7,'Enable','on');
set(handles.finishButton,'Enable','on');
set(handles.menu_file_save,'Enable','on');
set(handles.menu_view_all,'Enable','on');
set(handles.listbox1,'Enable','on');
set(handles.menu_view_all,'Checked','on');
set(handles.load_motion,'Enable','on');
set(handles.note_box,'Enable','on');

% Motion Graph Reset
% Clear existing motion graph
cla(handles.motion_axes);
legend(handles.motion_axes,'hide')
set(handles.motion_rot,'Enable','off');
set(handles.motion_trans,'Enable','off');
set(handles.motion_disp,'Enable','off');
set(handles.motion_rot,'Checked','off');
set(handles.motion_trans,'Checked','off');
set(handles.motion_disp,'Checked','off');

set(handles.note_box, 'String', handles.notes{handles.Index});
guidata(hObject, handles);
RefreshScreen(hObject,handles);

% --------------------------------------------------------------------
function menu_file_save_Callback(hObject, eventdata, handles)
% hObject    handle to menu_file_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%check to see if array is fully complete, gives warning if not
finishButton_Callback(hObject, eventdata, handles);

function file_menu_Callback(hObject, eventdata, handles)
% hObject    handle to menu_file_exit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function help_menu_Callback(hObject, eventdata, handles)
% hObject    handle to menu_file_exit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in load_button.
function load_button_Callback(hObject, eventdata, handles)
% hObject    handle to load_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
menu_file_open_Callback(hObject, eventdata, handles);


% --------------------------------------------------------------------
function view_menu_Callback(hObject, eventdata, handles)
% hObject    handle to view_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Change view: view a subset of components or all
function View_Callback(hObject, eventdata,handles,str)

% Uncheck all menu items
set(handles.menu_view_sig,'Checked','off');
set(handles.menu_view_bor,'Checked','off');
set(handles.menu_view_noi,'Checked','off');
set(handles.menu_view_un,'Checked','off');
set(handles.menu_view_all,'Checked','off');

switch str
    case 'Signal'
        view = 1;
        set(handles.menu_view_sig,'Checked','on');
    case 'Borderline'
        view = 2;
        set(handles.menu_view_bor,'Checked','on');
    case 'Noise'
        view = 3;
        set(handles.menu_view_noi,'Checked','on');
    case 'Unclass'
        view = 0;
        set(handles.menu_view_un,'Checked','on');
    case 'All'
        view = 4;
        set(handles.menu_view_all,'Checked','on');
end

classified = handles.Classified;
handles.Index = 0;
handles.view = view;
guidata(hObject, handles);
set_viewArray(hObject,handles);

function set_viewArray(hObject, handles)
% set the viewArray
classified = handles.Classified;
view = handles.view;

if view < 4
    viewArray=find(classified==view);
else
    viewArray=(1:length(classified))';
end

%change index
if handles.Index ==0
handles.Index = viewArray(1);
end
handles.viewArray = viewArray;
guidata(hObject, handles);
RefreshScreen(hObject,handles);



function note_box_Callback(hObject, eventdata, handles)
% hObject    handle to note_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of note_box as text
%        str2double(get(hObject,'String')) returns contents of note_box as a double
notes = handles.notes;
note_string=get(hObject,'String');
notes{handles.Index} = note_string;
handles.notes = notes;
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function note_box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to note_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in load_motion.
function load_motion_Callback(hObject, eventdata, handles)
% Loads in the motion directory generated by MCFLIRT
% Following files must be in directory to load properly:
% A .par file
% abs.rms
% rel.rms
mc_folder = uigetdir(handles.motion_home_path, 'Select Motion Directory')
if isequal(mc_folder,0)
    return
else
    
    par_file=dir(fullfile(mc_folder,'*.par'));
    abs_rms_file=dir(fullfile(mc_folder,'*abs.rms'));
    rel_rms_file=dir(fullfile(mc_folder,'*rel.rms'));
    
    if length(par_file)~=0 && length(abs_rms_file)~=0 && length(rel_rms_file)~=0
        handles.mc_folder = mc_folder;
        handles.motion_par = load(fullfile(mc_folder,par_file.name));
        handles.abs_rms = load(fullfile(mc_folder,abs_rms_file.name));
        handles.rel_rms = load(fullfile(mc_folder,rel_rms_file.name));
        %set(handles.load_motion,'Enable','off');
        guidata(hObject, handles);
        handles.motionView=3; %default view is displacement
        set(handles.motion_disp,'Checked','on');
        
        % Enable menu items:
        set(handles.motion_rot,'Enable','on');
        set(handles.motion_trans,'Enable','on');
        set(handles.motion_disp,'Enable','on');
        
        % Find p-values of correlation with motion
        %[~,handles.motion_corr]=corr(handles.temporal,[handles.motion_par handles.abs_rms handles.rel_rms]);
        %[~,handles.motion_corr]=corr(handles.temporal,[handles.motion_par handles.abs_rms handles.rel_rms]);
        
        size(handles.temporal)
        size(handles.motion_par)
        size(handles.abs_rms)
        size(handles.rel_rms)
        RefreshMotionGraphs(handles);
    else
        warndlg('Not a valid motion folder!', 'Bad input');
        return
    end
end


% --- Executes on button press in auto_classify.
function auto_classify_Callback(hObject, eventdata, handles)
% hObject    handle to auto_classify (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in remove_noise.
function remove_noise_Callback(hObject, eventdata, handles)
% hObject    handle to remove_noise (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%this button will be enabled once all components are classified. IT will
%run fsl_regfilt to remove noise components.

% --- Refreshes the motion graph. Executes each time motion parameters are
% added or alternative motion graph is clicked
function RefreshMotionGraphs(handles)
% If motion parameters were loaded
motion_par=handles.motion_par;
abs_motion=handles.abs_rms;
rel_motion=handles.rel_rms;
axes(handles.motion_axes);

hold on;

switch handles.motionView
    case 1
        %view = 1;
        %set(handles.menu_view_sig,'Checked','on');
        x_motion=plot(motion_par(:,1),'color',[0.8 0.8 1],'hittest','off'); %light blue
        y_motion=plot(motion_par(:,2),'color',[0.8 1 0.8],'hittest','off'); %light green
        z_motion=plot(motion_par(:,3),'color',[1 0.8 0.8],'hittest','off'); %light red
        set(handles.motion_axes,'YAxisLocation','right','Color','none','XColor','k','YColor','r','Xlim',[0 size(motion_par,1)]);
        handles.motion_legend=legend('x','y','z');
        ylabel('rot (radians)');
    case 2
        %view = 2;
        %set(handles.menu_view_bor,'Checked','on');
        x_motion=plot(motion_par(:,4),'color',[0.8 0.8 1],'hittest','off'); %light blue
        y_motion=plot(motion_par(:,5),'color',[0.8 1 0.8],'hittest','off'); %light green
        z_motion=plot(motion_par(:,6),'color',[1 0.8 0.8],'hittest','off'); %light red
        set(handles.motion_axes,'YAxisLocation','right','Color','none','XColor','k','YColor','r','Xlim',[0 size(motion_par,1)]);
        handles.motion_legend=legend('x','y','z');
        ylabel('trans (mm)');
    case 3
        abs_motion=plot(abs_motion(:,1),'color',[0.8 0.8 1],'hittest','off'); %light blue
        rel_motion=plot(rel_motion(:,1),'color',[0.8 1 0.8],'hittest','off'); %light green
        set(handles.motion_axes,'YAxisLocation','right','Color','none','XColor','k','YColor','r','Xlim',[0 size(motion_par,1)]);
        handles.motion_legend=legend('abs','rel');
        ylabel('disp (mm)');
end
hold off;

%guidata(handles);

% This function loads in all the timecourses into the program into one
% array

% This function finds the correlation coefficient p-values for all
% components and the motion parameters


% --- Change view: view motion graph
function Motion_Callback(hObject, eventdata,handles,str)

% Uncheck all menu items
set(handles.motion_rot,'Checked','off');
set(handles.motion_trans,'Checked','off');
set(handles.motion_disp,'Checked','off');

% Clear existing motion graph
cla(handles.motion_axes');

switch str
    case 'rot'
        handles.motionView = 1;
        set(handles.motion_rot,'Checked','on');
    case 'trans'
        handles.motionView = 2;
        set(handles.motion_trans,'Checked','on');
    case 'disp'
        handles.motionView = 3;
        set(handles.motion_disp,'Checked','on');
end

guidata(hObject, handles);
RefreshMotionGraphs(handles);


% --- Executes when graphs_panel is resized.
function graphs_panel_ResizeFcn(hObject, eventdata, handles)
% hObject    handle to graphs_panel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
