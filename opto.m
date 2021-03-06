function [] = opto()
%% opto.m USAGE NOTES AND CREDITS
% 
% Syntax
% -----------------------------------------------------
%     opto()
%     opto(varargin,'filename.xml')
%     opto(____,'doctype','xmlns')
% 
% Description
% -----------------------------------------------------
%     opto() takes a set of 2D or 3D vertices (vrts) and a tetrahedral (tets)
%     connectivity list, and creates an XML file of the mesh. This function was 
%     originally created to export xml mesh files for using in Fenics:Dolfin 
%     but can be adapted for universal xml export of triangulated meshes.
%
%
% EXPAND FOR MORE...
%{
% Useage Definitions
% -----------------------------------------------------
% 
% 
%     opto(vrts,tets)
%         creates an XML file 'xmlmesh.xml' from a set of vertices "vrts"
%         and a connectivity list; here the connectivity list is referred 
%         to as "tets". These parameters can be generated manually, or by
%         using matlab's builtin triangulation functions. The point list
%         "vrts" is a matrix with dimensions Mx2 (for 2D) or Mx3 (for 3D).
%         The matrix "tets" represents the triangulated connectivity list 
%         of size Mx3 (for 2D) or Mx4 (for 3D), where M is the number of 
%         triangles. Each row of tets specifies a triangle defined by indices 
%         with respect to the points. The delaunayTriangulation function
%         can be used to quickly generate these input variables:
%             TR = delaunayTriangulation(XYZ);
%             vrts = TR.Points;
%             tets = TR.ConnectivityList;
% 
% 
%     opto(vrts,tets,'filename.xml')
%         same as above, but allows you to specify the xml filename.
% 
% 
%     opto(____,'doctype','xmlns')
%         same as above, but allows you to additionally specify the
%         xml namespace xmlns attribute. For details see:
%         http://www.w3schools.com/xml/xml_namespaces.asp
% 
% 
% 
% 
% Example
% -----------------------------------------------------
%
% Create 2D triangulated mesh
%     XY = randn(10,2);
%     TR2D = delaunayTriangulation(XY);
%     vrts = TR2D.Points;
%     tets = TR2D.ConnectivityList;
% 
%     xmlmesh(vrts,tets,'xmlmesh_2D.xml')
% 
% 
% Create 3D triangulated mesh
%     d = [-5 8];
%     [x,y,z] = meshgrid(d,d,d); % a cube
%     XYZ = [x(:) y(:) z(:)];
%     TR3D = delaunayTriangulation(XYZ);
%     vrts = TR3D.Points;
%     tets = TR3D.ConnectivityList;
% 
%     xmlmesh(vrts,tets,'xmlmesh_3D.xml')
% 
% 
% Attribution
% -----------------------------------------------------
% Created by: Bradley Monk
% email: brad.monk@gmail.com
% website: bradleymonk.com
% 2016.06.19
%
% 
% Potentially Helpful Resources and Documentation
% -----------------------------------------------------
% General brad code resources:
%     > http://bradleymonk.com/MATLAB
%     > https://github.com/subroutines
%
% Info related to this function/script:
%     > <a href="matlab: 
% web('http://www.mathworks.com/help/daq/ref/daq.getdevices.html')">daq.getdevices</a>
%     > <a href="matlab: 
% web(fullfile(docroot, 'instrument/examples.html'))">instrument control toolbox</a>
%     > <a href="matlab: 
% web(fullfile(docroot, 'imaq/examples/working-with-triggers.html'))">image triggers</a>
%
%   See also daqread, instrhwinfo

%}


clc; close all; clear

%% CREATE PULSE WAVE FOR DAQ OUTPUT
pulse.number = 30;                  % (n) total number of pulses per session
pulse.duration = 100;                % (ms) duration of each pulse
pulse.ipi = 1000 - pulse.duration;  % (ms) inter pulse interval
pulses = [ones(1,pulse.duration) , zeros(1,pulse.ipi)];
pulses = repmat(pulses,1,pulse.number);


fh1=figure('Units','normalized','OuterPosition',[.40 .22 .59 .75],'Color','w');
hax1 = axes('Position',[.05 .05 .9 .9],'Color','none');
% axis(axLim); view(vlim); hold on

plot(pulses);
ylim([0 1.2])


%% CREATE CS+ OR CS- TONE OBJECTS

SampleRate  = 10000;
TimeValue   = 1;
Samples     = 0:(1/SampleRate):TimeValue;
freqCSplus 	= 600;
freqCSminus = 350;
toneCSplus  = sin(2*pi*freqCSplus*Samples);
toneCSminus = sin(2*pi*freqCSminus*Samples);

plot(toneCSplus(1:100));
% ylim([-1 1])


%% ACQUIRE DAQ DEVICE

nidaq.vendor        = 'ni';
nidaq.device        = 'Dev2';
nidaq.channelOut    = 'ao0';
nidaq.channelIn     = 'ao1';
nidaq.outtype       = 'Voltage';
nidaq.rate          = 8000;
nidaq.volt          = 1000;

[s] = getnidaq(nidaq);


%% QUEUE DAQ OUTPUT

queueOutputData(s,pulses);
% s.startForeground;







%% ACQUIRE IMAGE ACQUISITION DEVICE
% imaqtool

vidobj = videoinput('macvideo', 1, 'YCbCr422_1280x720');
src = getselectedsource(vidobj);

% vidobj.ReturnedColorspace = 'rgb';
% vidobj.ReturnedColorspace = 'YCbCr';
vidobj.ReturnedColorspace = 'grayscale';


% Configure the trigger type.
triggerconfig(vidobj, 'manual')


% TriggerRepeat is zero based and is always one
% less than the number of triggers. If you want to capture
% frames once per second for one minute set this value to 59.
% If you specify a particular amount of TriggerRepeats, you must
% carry out that exact number or MATLAB will complain. You can
% also do: % vidObj.TriggerRepeat = Inf;

vidobj.TriggerRepeat = 1;


% This determines the number of frames to capture per trigger
% and the upper bound is the number of frames per second
% your camera delivers to your machine.

vidobj.FramesPerTrigger = 3;


% Initiate the acquisition.
start(vidobj)


% Trigger the acquisition.
trigger(vidobj)

data = getdata(vidobj);

pause(1)

% Trigger the acquisition.
trigger(vidobj)


% Wait for the acquisition to end.
wait(vidobj, 10);

% Determine the number frames acquired.
frameslogged = vidobj.FramesAcquired


data = getdata(vidobj);
size(data)
imagesc(data(:,:,1,3))

% Once the video input object is no longer needed, delete
% it and clear it from the workspace.
delete(vidobj)
clear vidobj




img = double(data(:,:,1,3));
img = max(img(:)) - img;




%======================================%
%% -- MANUALLY SET MASK POSITIONS
%--------------------------------------

% promptTXT = {'How many ROIs are there?:'};
% dlg_title = 'Input'; num_lines = 1; presetval = {'4'};
% dlgOut = inputdlg(promptTXT,dlg_title,num_lines,presetval);
% NumMasks = str2num(dlgOut{:});
NumMasks = 4;


disp('press OK button, then use cursor to draw a rectangle around TOP LEFT zone')
disp('then press OK button and use cursor to draw a rectangle around TOP RIGHT zone')
disp('then press OK button and use cursor to draw a rectangle around BOTTOM LEFT zone')
disp('then press OK button and use cursor to draw a rectangle around BOTTOM RIGHT zone')
disp('when done tracing all 4 zones EXIT the window to proceed')
getROI = @(hImg) round(getPosition(imrect));

pause(1)
roi = [];

% %---------
% set(figure(99),'OuterPosition',[300 200 800 700],'Color',[1,1,1])
% Hax = axes('Position',[.08 .08 .85 .85]);
% %---------

hImg = imagesc(img);
pause(1)
[hui] = uicontrol('Style', 'pushbutton', 'String', 'OK',...
				'Position', [200 7 50 20],...
				'Callback', 'roi(end+1,:) = getROI(hImg)');

NMui = 0;            
while NMui < NumMasks; uiwait; NMui = NMui+1; end;
%======================================%
disp('when done tracing all 4 zones EXIT the window to proceed')

roi1 = roi(1,:); roi2 = roi(2,:); roi3 = roi(3,:); roi4 = roi(4,:);
M1_yTyBxLxR = [roi1(2) (roi1(2)+roi1(4)) roi1(1) (roi1(1)+roi1(3))];
M2_yTyBxLxR = [roi2(2) (roi2(2)+roi2(4)) roi2(1) (roi2(1)+roi2(3))];
M3_yTyBxLxR = [roi3(2) (roi3(2)+roi3(4)) roi3(1) (roi3(1)+roi3(3))];
M4_yTyBxLxR = [roi4(2) (roi4(2)+roi4(4)) roi4(1) (roi4(1)+roi4(3))];



%======================================%
% make masks, so we don't need to worry about detecting multiple mice in one 'region'
% mask{1} = zeros(size(f1)); mask{1}([Ytop:Ybottom], [Xleft:Xright]) = 1;

% zone 1
mask{1} = zeros(size(img));
mask{1}(M1_yTyBxLxR(1):M1_yTyBxLxR(2), M1_yTyBxLxR(3):M1_yTyBxLxR(4)) = 1;

% zone 2
mask{2} = zeros(size(img));
mask{2}(M2_yTyBxLxR(1):M2_yTyBxLxR(2), M2_yTyBxLxR(3):M2_yTyBxLxR(4)) = 1;

% zone 3
mask{3} = zeros(size(img));
mask{3}(M3_yTyBxLxR(1):M3_yTyBxLxR(2), M3_yTyBxLxR(3):M3_yTyBxLxR(4)) = 1;

% zone 4
mask{4} = zeros(size(img));
mask{4}(M4_yTyBxLxR(1):M4_yTyBxLxR(2), M4_yTyBxLxR(3):M4_yTyBxLxR(4)) = 1;


%% CHECK MASK PLACEMENTS

fh1=figure('Units','normalized','OuterPosition',[.40 .22 .59 .75],'Color','w');
hax1 = axes('Position',[.05 .05 .9 .9],'Color','none');

for i = 1:4
    subplot(2,2,i);
    imagesc(img.*mask{i});
	%axis square
end


%% CHECK VAGUE SNR DISTRIBUTIONS
fh2=figure('Units','normalized','OuterPosition',[.40 .22 .59 .75],'Color','w');

for i = [1:4]
    subplot(2,2,i);
    hist(img(mask{i}==1),200);
    % xlim([min(img(:)) max(img(:))])
    xlim([50 240])
end

% set mask threshold to cutoff background pixels
threshmask = [75 75 75 75];


%% get pixels that passed threshold

% f1M1thresh = f1 > threshmask(1);
% f1M1 = f1 .* f1M1thresh .* mask{1};

f1M1thresh = img > threshmask(1);
f1M1 = img .* f1M1thresh .* mask{1};

f1M2thresh = img > threshmask(2);
f1M2 = img .* f1M2thresh .* mask{2};

f1M3thresh = img > threshmask(3);
f1M3 = img .* f1M3thresh .* mask{3};

f1M4thresh = img > threshmask(4);
f1M4 = img .* f1M4thresh .* mask{4};

f1M = f1M1 + f1M2 + f1M3 + f1M4;


close all
fh1=figure('Units','normalized','OuterPosition',[.40 .22 .59 .75],'Color','w');
hax1 = axes('Position',[.05 .05 .9 .9],'Color','none');

hImg = imagesc(f1M);
colormap(hot)


%% DETERMINE QUADRANT TO DELIVER PULSE

muQ1 = mean(f1M1(f1M1>0))
muQ2 = mean(f1M2(f1M2>0))
muQ3 = mean(f1M3(f1M3>0))
muQ4 = mean(f1M4(f1M4>0))

muMax = max([muQ1 muQ2 muQ3 muQ4])



if muQ1 == muMax
    
    subplot(2,2,1);
    plot(pulses);
    ylim([0 1.2])
    % Create textbox
    annotation(fh1,'textbox',...
    [0.167 0.629 0.261 0.192],...
    'Color',[0.0666 0.250 0.537],...
    'String','Pulses being delivered to Zone-1',...
    'LineWidth',5,...
    'FontSize',36,...
    'FontName','Helvetica',...
    'FitBoxToText','off',...
    'EdgeColor',[0 0.447 0.741],...
    'BackgroundColor',[0.301 0.745 0.933]);
    

elseif muQ2 == muMax
    
    subplot(2,2,2);
    plot(pulses);
    ylim([0 1.2])
        % Create textbox
    annotation(fh1,'textbox',...
    [0.6 0.629 0.261 0.192],...
    'Color',[0.0666 0.250 0.537],...
    'String','Pulses being delivered to Zone-2',...
    'LineWidth',5,...
    'FontSize',36,...
    'FontName','Helvetica',...
    'FitBoxToText','off',...
    'EdgeColor',[0 0.447 0.741],...
    'BackgroundColor',[0.301 0.745 0.933]);
    
elseif muQ3 == muMax
        
    subplot(2,2,3);
    plot(pulses);
    ylim([0 1.2])
        % Create textbox
    annotation(fh1,'textbox',...
    [0.167 0.18 0.261 0.192],...
    'Color',[0.0666 0.250 0.537],...
    'String','Pulses being delivered to Zone-3',...
    'LineWidth',5,...
    'FontSize',36,...
    'FontName','Helvetica',...
    'FitBoxToText','off',...
    'EdgeColor',[0 0.447 0.741],...
    'BackgroundColor',[0.301 0.745 0.933]);
                
elseif muQ4 == muMax
    
    subplot(2,2,4);
    plot(pulses);
    ylim([0 1.2])
        % Create textbox
    annotation(fh1,'textbox',...
    [0.6 0.18 0.261 0.192],...
    'Color',[0.0666 0.250 0.537],...
    'String','Pulses being delivered to Zone-4',...
    'LineWidth',5,...
    'FontSize',36,...
    'FontName','Helvetica',...
    'FitBoxToText','off',...
    'EdgeColor',[0 0.447 0.741],...
    'BackgroundColor',[0.301 0.745 0.933]);
        
else
    
    disp('something went wrong determining zone')

end





%%


%{

%%


% TriggerRepeat is zero based and is always one
% less than the number of triggers. If you want to capture
% frames once per second for one minute set this value to 59.
% If you specify a particular amount of TriggerRepeats, you must
% carry out that exact number or MATLAB will complain. You can
% also do: % vidObj.TriggerRepeat = Inf;

vidobj.TriggerRepeat = 1;


% This determines the number of frames to capture per trigger
% and the upper bound is the number of frames per second
% your camera delivers to your machine.

vidobj.FramesPerTrigger = 2;



% Setting triggerconfig to manual allows us to place triggers
% within a loop to trigger at preset/key timepoints

triggerconfig(vidobj, 'manual');

% triggerconfig(vidobj, 'hardware', 'fallingEdge', 'optoTrigger')


% COLLECT SOME SAMPLE VIDEO FRAMES


preview(vidobj);

start(vidobj);

trigger(vidobj);

wait(vidobj, 5)

trigger(vidobj);



%%
pause(2)

trigger(vidobj);

wait(vidobj, 2)
pause(2)

stoppreview(vidobj);
% Once the video input object is no longer needed, delete
% it and clear it from the workspace.
delete(vidobj)
clear vidobj
clear src

% frameslogged = vidobj.FramesAcquired;

data = getdata(vidobj);




%%
clear data;







%% ACQUIRE IMAGE ACQUISITION DEVICE
% imaqtool

vidobj = videoinput('macvideo', 1, 'YCbCr422_1280x720');
src = getselectedsource(vidobj);

% vidobj.ReturnedColorspace = 'rgb';
% vidobj.ReturnedColorspace = 'YCbCr';
vidobj.ReturnedColorspace = 'grayscale';

% preview(vidobj);
% pause(3)
% stoppreview(vidobj);


% Configure the trigger type.
triggerconfig(vidobj, 'immediate')

% Initiate the acquisition.
start(vidobj)

% Wait for acquisition to end.
wait(vidobj, 2)

% Determine the number frames acquired.
frameslogged = vidobj.FramesAcquired;


%%







% PREALLOCATE MEMORY FOR IMAGE DATA CONTAINERS
FramesPerTrial = 3;
nFrames = FramesPerTrial * TotTrials;
Frames = repmat({uint8(zeros(720,1280,3))},1,nFrames);  % Frames{1xN}(720x1280x3)uint8
FramesTS = repmat({clock},1,nFrames);

% ACQUIRE IMAGING DEVICE AS vidObj
% vidObj = videoinput('winvideo', 1, 'UYVY_720x576');  % Thermal Cam (UYVY_720x576 or UYVY_720x480)
vidObj = videoinput('macvideo', 1, 'YCbCr422_1280x720'); % iSight Cam
vidsrc = getselectedsource(vidObj);

vidObj.LoggingMode = 'memory';
vidObj.ReturnedColorspace = 'rgb';

vidObj.TriggerRepeat = Inf;
vidObj.FramesPerTrigger = 1;
triggerconfig(vidObj, 'manual');
% src.AnalogVideoFormat = 'ntsc_m_j'; % UNCOMMENT WHEN USING winvideo
% vidObj.ROIPosition = [488 95 397 507];
% preview(vidObj); pause(3); stoppreview(vidObj);

start(vidObj);





----------

vidobj = videoinput('macvideo', 1, 'YCbCr422_1280x720');
src = getselectedsource(vidobj);

vidobj.FramesPerTrigger = 1;

preview(vidobj);

stoppreview(vidobj);

preview(vidobj);

stoppreview(vidobj);

preview(vidobj);

start(vidobj);

stoppreview(vidobj);

vidobj.FramesPerTrigger = 2;

vidobj.FramesPerTrigger = 3;

vidobj.ReturnedColorspace = 'rgb';

triggerconfig(vidobj, 'manual');

vidobj.ROIPosition = [1 0 1279 720];

vidobj.ROIPosition = [1 1 1279 719];

vidobj.ROIPosition = [1 1 1278 719];

vidobj.ROIPosition = [1 1 1278 718];

vidobj.ROIPosition = [1 1 1278 719];

vidobj.ROIPosition = [1 1 1279 719];

vidobj.ROIPosition = [1 0 1279 719];

vidobj.ROIPosition = [0 0 1279 719];

vidobj.ROIPosition = [0 0 1280 720];

preview(vidobj);

start(vidobj);

trigger(vidobj);

stoppreview(vidobj);

data = getdata(vidobj);
save('previewisight.mat', 'data');
clear data;

vidobj.ReturnedColorspace = 'grayscale';

vidobj.ReturnedColorspace = 'rgb';

% TriggerRepeat is zero based and is always one
% less than the number of triggers.
vidobj.TriggerRepeat = 1;

% TriggerRepeat is zero based and is always one
% less than the number of triggers.
vidobj.TriggerRepeat = 2;

% TriggerRepeat is zero based and is always one
% less than the number of triggers.
vidobj.TriggerRepeat = 3;

preview(vidobj);

start(vidobj);

trigger(vidobj);

trigger(vidobj);

trigger(vidobj);

trigger(vidobj);

stoppreview(vidobj);



%}

%{
% This will get info about all daq devices
devices = daq.getDevices;
devices(2)

% Open a session using national instruments drivers
s = daq.createSession('ni');

% Make ready the two output channels
addAnalogOutputChannel(s,'Dev2','ao0','Voltage')
addAnalogOutputChannel(s,'Dev2','ao1','Voltage')

% You can change the output rate like so...
s.Rate = 8000;

% Create a constant output value of 5 volts
outputSingleValue = 5;
outputSingleScan(s,[outputSingleValue outputSingleValue]);


% Bring output value back to 0 volts
outputSingleValue = 0;
outputSingleScan(s,[outputSingleValue outputSingleValue]);


%% Queue an output then run output later
clc; close all; clear;

% This will get info about all daq devices
devices = daq.getDevices;
devices(2)

% Open a session using national instruments drivers
s = daq.createSession('ni');

% Make ready the two output channels
addAnalogOutputChannel(s,'Dev2','ao0','Voltage')
addAnalogOutputChannel(s,'Dev2','ao1','Voltage')


stop(s)

% You can change the output rate like so...
s.Rate = 8000;

% Create and plot a single sine wave and step function
outputSignal1 = sin(linspace(0,pi*2,s.Rate)');
outputSignal2 = linspace(-1,1,s.Rate)';
outputSignal3 = sin(linspace(0, 2*pi*1000, 10001))';

plot(outputSignal3)
% plot(outputSignal1);
% hold on;
% plot(outputSignal2,'-g');
xlabel('Time');
ylabel('Voltage');
legend('Analog Output 0', 'Analog Output 1');

% Queue that signal for output
queueOutputData(s,[outputSignal3 outputSignal3]);

%% OUTPUT THE QUEUED SIGNAL TO THE DAQ

s.startForeground;

















%% CREATE SQUARE WAVE
clc; close all; clear;

pulse.number = 30;                  % (n) total number of pulses per session

pulse.duration = 100;                % (ms) duration of each pulse

pulse.ipi = 1000 - pulse.duration;  % (ms) inter pulse interval

pulses = [ones(1,pulse.duration) , zeros(1,pulse.ipi)];

pulses = repmat(pulses,1,pulse.number);



plot(pulses);
ylim([0 1.2])


%% ACQUIRE DAQ DEVICE

d = daq.getDevices;

s = daq.createSession('ni');

addAnalogInputChannel(s,'cDAQ1Mod1',0,'Voltage');
disp(s)

data = s.startForeground();

plot(data)

s.Rate = 5000;
s.DurationInSeconds = 2;
disp(s)


%%

% creates the VISA object obj with a resource name given by rsrcname 
% for the vendor specified by vendor...

obj = visa('vendor','rsrcname') 

% You must first configure your VISA resources in the vendor's tool first, 
% and then you create these VISA objects. Use instrhwinfo to find the 
% commands to configure the objects:

vinfo = instrhwinfo('visa','agilent');
vinfo.ObjectConstructorName

% EXAMPLES Create a VISA-serial object connected to serial port COM1 using
% National Instruments® VISA interface.

vs = visa('ni','ASRL1::INSTR');

% Create a VISA-GPIB object connected to board 0 with primary address 1 and
% secondary address 30 using Agilent Technologies® VISA interface.

vg = visa('agilent','GPIB0::1::30::INSTR');

%Create a VISA-VXI object connected to a VXI instrument located at logical
% address 8 in the first VXI chassis.

vv = visa('agilent','VXI0::8::INSTR');

% Create a VISA-GPIB-VXI object connected to a GPIB-VXI instrument located
% at logical address 72 in the second VXI chassis.

vgv = visa('agilent','GPIB-VXI1::72::INSTR');

% Create a VISA-RSIB object connected to an instrument configured with IP
% address 192.168.1.33.

vr = visa('ni', 'RSIB::192.168.1.33::INSTR')

% Create a VISA-TCPIP object connected to an instrument configured with IP
% address 216.148.60.170.

vt = visa('tek', 'TCPIP::216.148.60.170::INSTR')

% Create a VISA-USB object connected to a USB instrument with manufacturer
% ID 0x1234, model code 125, and serial number A22-5.

vu = visa('agilent', 'USB::0x1234::125::A22-5::INSTR')



%}

end


























