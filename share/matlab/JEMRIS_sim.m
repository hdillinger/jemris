function varargout = JEMRIS_sim(varargin)
%GUI for jemris simulation visualisation

%
%  JEMRIS Copyright (C) 2007-2009  Tony Stcker, Kaveh Vahedipour
%                                  Forschungszentrum Jlich, Germany
%
%  This program is free software; you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation; either version 2 of the License, or
%  (at your option) any later version.
%
%  This program is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%
%  You should have received a copy of the GNU General Public License
%  along with this program; if not, write to the Free Software
%  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
%

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @JEMRIS_sim_OpeningFcn, ...
                   'gui_OutputFcn',  @JEMRIS_sim_OutputFcn, ...
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


% --- Executes just before JEMRIS_sim is made visible.
function JEMRIS_sim_OpeningFcn(hObject, eventdata, handles, varargin)

colordef white

% Choose default command line output for JEMRIS_sim
handles.output = hObject;

handles.seqname = ''; handles.seqfile = ''; handles.seqdir='';
handles.txaname = ''; handles.txafile = ''; handles.txadir='';
handles.rxaname = ''; handles.rxafile = ''; handles.rxadir='';
hax{1}=handles.axes1; hax{2}=handles.axes2;
hax{3}=handles.axes3; hax{4}=handles.axes4;
hax{5}=handles.axes5; hax{6}=handles.axes6;
for i=1:6; set(hax{i},'color',[1 1 1],'visible','off'); end
handles.hax=hax;
handles.epil=0;
handles.epir=0;
handles.CWD=pwd;
handles.JemrisPath='/usr/local/bin';
handles.JemrisShare='/usr/local/share/jemris/matlab';

%define how to call jemris / pjemris
[s,w]=system('setenv');
if s==0 % a TCSH
    handles.JemrisCall  = ['setenv LD_LIBRARY_PATH ""; ',handles.JemrisPath,'/jemris simu.xml > .sim.out &'];
    handles.PJemrisCall = ['setenv LD_LIBRARY_PATH ""; mpirun -np 5 ',handles.JemrisPath,'/pjemris simu.xml > .sim.out &'];
else    % a BASH 
    handles.JemrisCall  = ['LD_LIBRARY_PATH=""; ',handles.JemrisPath,'/jemris simu.xml > .sim.out &'];
    handles.PJemrisCall = ['LD_LIBRARY_PATH=""; mpirun -np 5 ',handles.JemrisPath,'/pjemris simu.xml > .sim.out &'];
end
%CLUSTER call works only, if the CWD belongs to cluster
cwd=pwd;[w,s]=system('whoami');n=strfind(cwd,s(1:end-1));cwd=['/data/home/',cwd(n:end)]
handles.ClusterCall=sprintf('ssh mrcluster "cd %s; qsub /apps/prod/misc/share/jemris/pbs_script.sh"',cwd);

%default is sequential computing
set(handles.LocCompTag,'Checked','on');
set(handles.LocCompTagPar,'Checked','off');
set(handles.ParCompTag,'Checked','off');

%check if parallel jemris exists
if exist([handles.JemrisPath,'/pjemris'])==0
    set(handles.LocCompTagPar,'Enable','off');
end
%check if our cluster is reachable
[s,w]=system('ping -c 1 mrcluster');
if s~=0
    set(handles.ParCompTag,'Enable','off');
end


%
sample.file='sample.bin';
sample.name='2D sphere';
sample.T1=1000; sample.T2=100; sample.M0=1; sample.CS=0; sample.Suscept=0;
sample.R=50;sample.DxDy=1; sample.gamBo=63.87;
handles.sample=sample;
handles.UserSample=[];
handles.maxM0=1;
sim.R2P=0; sim.CSF=0; sim.CF=0; sim.RN=0; sim.INC=0; 
handles.sim=sim;
handles.img_num=1;
%set(gcf,'color',[.88 .88 .88])

%default coilarray for transmit and reveice
ca.c=1; ca.r=1; ca.loopr=1; ca.s='UNIFORM'; ca.name='ideal coil';
handles.rxca=ca;
handles.txca=ca;

C={'Sample','Signal','k-Space','k-Space (Phase)','Image','Image (phase)'};
set(handles.showLeft,'String',C);
C={'Signal','k-Space','k-Space (Phase)','Image','Image (phase)','Evolution'};
set(handles.showRight,'String',C);
C={'2D sphere','2D 2-spheres','brain','user defined'};
set(handles.Sample,'String',C);
set(handles.EPI_L,'Visible','off');
set(handles.EPI_R,'Visible','off');
set(handles.ImageL,'Visible','off');
set(handles.ImageR,'Visible','off');
set(handles.SusceptTag,'Value',0,'Visible','off');
set(handles.gamBoTag,'Visible','off');    
set(handles.gamBoText,'Visible','off');    
set(handles.TxText,'Visible','off');
set(handles.RxText,'Visible','off');
write_simu_xml(handles,1);
guidata(hObject, handles);


% UIWAIT makes JEMRIS_sim wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- writes the simulation xml file. This is *not* an object of the GUI!
function handles=write_simu_xml(handles,redraw)
 %path defintions differ on cluster
 if strcmp(get(handles.ParCompTag,'Checked')   ,'on')
     jp='/apps/prod/misc/share/jemris/';
     [w,s]=system('whoami');
     cwd=pwd            ; n=strfind(cwd,s(1:end-1)); cwd=['/data/home/',cwd(n:end)];
     sd =handles.seqdir ; n=strfind(sd,s(1:end-1)) ; sd =['/data/home/',sd(n:end)] ;
     td =handles.txadir ; n=strfind(td,s(1:end-1)) ; td =['/data/home/',td(n:end)] ;
     rd =handles.rxadir ; n=strfind(rd,s(1:end-1)) ; rd =['/data/home/',rd(n:end)] ;    
 else
     jp=handles.JemrisShare;
     cwd=pwd; sd=handles.seqdir; td=handles.txadir; rd=handles.rxadir;
 end
 %
 sample=handles.sample; sim=handles.sim; rxca=handles.rxca; txca=handles.txca;
 %sample item
 SAMP.Name='sample'     ; SAMP.Data=''; SAMP.Children=[]; 
 SAMP.Attributes(1).Name='name'; SAMP.Attributes(1).Value=sample.name;
 SAMP.Attributes(2).Name='uri';  SAMP.Attributes(2).Value=fullfile(cwd,sample.file);
 %write binary sample file
 if isempty(handles.UserSample)
    T1=handles.sample.T1; T2=handles.sample.T2;
    M0=handles.sample.M0; CS=handles.sample.CS;
    R=handles.sample.R;  res=handles.sample.DxDy;
    handles.maxM0=writeSample(sample.name,round(2*R/res),res,0,M0,T1,T2,CS,0,sample.file);
 else
    handles.maxM0=writeSample(handles.UserSample);
 end       
 %RX coilarray
 RXCA.Name='RXcoilarray'; RXCA.Data=''; RXCA.Children=[]; RXCA.Attributes.Name='uri';
 if isempty(handles.rxafile)
    RXCA.Attributes.Value=fullfile(jp,'uniform.xml');
 else
    RXCA.Attributes.Value=fullfile(rd,handles.rxafile); 
 end
 %TX coilarray
 TXCA.Name='TXcoilarray'; TXCA.Data=''; TXCA.Children=[]; TXCA.Attributes.Name='uri'; 
 if isempty(handles.txafile)
    TXCA.Attributes.Value=fullfile(jp,'uniform.xml');
 else
    TXCA.Attributes.Value=fullfile(td,handles.txafile); 
 end
 %sequence section
 SEQU.Name='sequence'   ; SEQU.Data=''; SEQU.Children=[]; 
 SEQU.Attributes(1).Name='name'; SEQU.Attributes(1).Value=handles.seqname;
 SEQU.Attributes(2).Name='uri';  SEQU.Attributes(2).Value=fullfile(sd,handles.seqfile);
 %model section
 MODE.Name='model'  ; MODE.Data=''; MODE.Children=[]; 
 MODE.Attributes(1).Name='name'; MODE.Attributes(1).Value='Bloch';
 MODE.Attributes(2).Name='type'; MODE.Attributes(2).Value='CVODE';
 %parameter section
 PARA.Name='parameter'  ; PARA.Data=''; PARA.Children=[]; 
 NAMES = {'R2Prime','EvolutionSteps','EvolutionPrefix','ConcomitantFields','RandomNoise'};
 VALUES= {num2str(sim.R2P),num2str(sim.INC),'evol',num2str(sim.CF),num2str(sim.RN)};
 for i=1:length(NAMES); PARA.Attributes(i).Name=NAMES{i}; PARA.Attributes(i).Value=VALUES{i}; end
 %build simu-structure and write simu xml file 
 SIMU.Name='simulate';  SIMU.Attributes(1).Name='name'; SIMU.Attributes(1).Value='JEMRIS'; SIMU.Data='';
 SIMU.Children(1)=SAMP; SIMU.Children(2)=RXCA; SIMU.Children(3)=TXCA;
 SIMU.Children(4)=PARA; SIMU.Children(5)=SEQU; SIMU.Children(6)=MODE;
 %write simu file, only if sequence exists!
 if (exist(fullfile(handles.seqdir,handles.seqfile)) == 2)
    writeXMLseq(handles,SIMU,'simu.xml');
 else
     disp('select a sequence!')
 end
 %redraw sample
 if nargin==2
  for i=[1 3 4 5 6]
    cla(handles.hax{i},'reset');
    set(handles.hax{i},'color',[1 1 1],'visible','off');
  end
  plotsim(handles,1);
  set(handles.showLeft,'Value',1);
 end


% --- Outputs from this function are returned to the command line.
function varargout = JEMRIS_sim_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles;

% --- Executes on selection change in Sample.
function Sample_Callback(hObject, eventdata, handles)
 C=get(hObject,'String');
 Nsample=get(hObject,'Value');
 handles.sample.name=C{Nsample};
 handles.UserSample=[];
 handles.sample.Suscept=0;
 set(handles.gamBoTag,'Visible','off');    
 set(handles.gamBoText,'Visible','off');    
 set(handles.SusceptTag,'Value',0,'Visible','off');
 switch Nsample
    case 1 %sphere
        bv1='on';bv2='on';
        handles.sample.T1=1000;handles.sample.T2=100;handles.sample.CS=0;
        handles.sample.M0=1;handles.sample.R=50;handles.sample.DxDy=1;
        handles.sim.R2P=0;handles.sim.CSF=1;
        M0str='M0'; CSstr='CS [Hz]'; SSstr='Radius'; T1str='T1 [ms]';  T2str='T2 [ms]';
    case 2 %2spheres
        bv1='on';bv2='on';
        handles.sample.T1=[100 50];handles.sample.T2=[100 50];handles.sample.CS=[0 0];
        handles.sample.M0=[1 1];handles.sample.R=[50 25];handles.sample.DxDy=1;
        handles.sim.R2P=0;handles.sim.CSF=1;
        M0str='M0'; CSstr='CS [Hz]'; SSstr='Radius'; T1str='T1 [ms]';  T2str='T2 [ms]';
   case 3 %brain
        bv1='off';bv2='on';
        set(handles.SusceptTag,'Value',0,'Visible','on');
        handles.sample.T1=1;handles.sample.T2=1;handles.sample.CS=1;
        handles.sample.M0=1;handles.sample.R=90;handles.sample.DxDy=1;
        M0str='M0 x'; CSstr='CS x'; SSstr='slice(s) [1st,last]'; T1str='T1 x';  T2str='T2 x';
   case 4 %user defined
       bv1='off';bv2='off';
       M0str=''; CSstr=''; SSstr=''; T1str='';  T2str='';
 end

 set(handles.text10,'String',T1str,'Visible',bv2);
 set(handles.text11,'String',T2str,'Visible',bv2); 
 set(handles.text12,'String',M0str,'Visible',bv2); 
 set(handles.text13,'String',SSstr,'Visible',bv2); 
 set(handles.text16,'Visible',bv2);
 set(handles.text17,'String',CSstr,'Visible',bv2); 
 set(handles.setT1,'String',num2str(handles.sample.T1),'Visible',bv2);
 set(handles.setT2,'String',num2str(handles.sample.T2),'Visible',bv2);
 set(handles.setM0,'String',num2str(handles.sample.M0),'Visible',bv2);
 set(handles.setChemShift,'String',num2str(handles.sample.CS),'visible',bv2);
 set(handles.setRadius,'String',num2str(handles.sample.R),'Visible',bv2);
 set(handles.setGrid,'String',num2str(handles.sample.DxDy),'Visible',bv2);
 set(handles.setT2Prime,'String','inf');
 
 %user defined sample
 if Nsample==4;
     [FileName,PathName] = uigetfile('*.mat','Select the Sample Mat file');
     if FileName==0,return;end
     handles.UserSample=load(FileName);
 end
 
 %brain slice(s)
 if Nsample==3; handles.UserSample=brainSample(handles); end
 
 %redraw sample
 handles=write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function Sample_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in start_simu.
function start_simu_Callback(hObject, eventdata, handles)
 if (exist(fullfile(handles.seqdir,handles.seqfile)) ~= 2); errordlg('select sequence first!'); return; end
 write_simu_xml(handles);
 %clean up
  if (~isempty(dir('signal*.bin')) ); delete('signal*.bin'); end
  if (~isempty(dir('evol*.bin')) && handles.sim.INC>0); delete('evol*.bin'); end
 %external calling method
  % a) sequential JEMRIS on localhost
  COMMAND = handles.JemrisCall;
  % b) mpirun on cluster with PBS script
  if strcmp(get(handles.ParCompTag,'Checked')   ,'on'); COMMAND = handles.ClusterCall; end
  % c) mpirun on localhost
  if strcmp(get(handles.LocCompTagPar,'Checked'),'on'); COMMAND = handles.PJemrisCall; end

 %call external JEMRIS
 C={['executing ',COMMAND,' ... waiting for results']};
 set(handles.sim_dump,'String',C,'FontName','monospaced','FontSize',8);
 guidata(hObject, handles);
 pause(1);
 system(COMMAND);
 %progress counter
 warning off;delete('.jemris_progress.out');warning on
 h = waitbar(0,'Please wait...');
 j = 0;
 while 1
    try 
        p=load('.jemris_progress.out','-ascii');
        waitbar(p/100)
        if p==100, break; end
        pause(1)
    catch
pause(1)
        j=j+1;
        if j==60, error('waiting for 60 sec ... jemris seems not to start??'), end
    end
 end
 close(h);

 %read output text file
 pause(1)
 while 1
  C={};
  fid=fopen('.sim.out');
  while 1
    tline = fgetl(fid);
    if ~ischar(tline), break, end
    C{end+1}=tline;
  end
  fclose(fid);
  FIN=0;
  for i=1:length(C); if strfind(C{i},'Finished'),FIN=1;end,end
  if FIN;break;end
 end
 set(handles.sim_dump,'String',C,'FontName','monospaced','FontSize',8);
 pause(1)

 %plot signal
 set(handles.showLeft,'Value',1);
 set(handles.showRight,'Value',1);
 guidata(hObject, handles);
 showLeft_Callback(hObject, eventdata, handles);
 showRight_Callback(hObject, eventdata, handles);

% --------------------------------------------------------------------
function FileTag_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function loadSeqTag_Callback(hObject, eventdata, handles)
[FileName,PathName] = uigetfile('*.xml','Select the Sequence XML file');
if FileName==0,return;end
handles.seqfile=FileName;
handles.seqdir=PathName;
[dummy,handles.seqname]=fileparts(FileName);
set(handles.SeqNameTag,'String',['Sequence: ',FileName]);
guidata(hObject, handles);

% --------------------------------------------------------------------
function loadTxTag_Callback(hObject, eventdata, handles)
[FileName,PathName] = uigetfile('*.xml','Select the Tx-Array XML file');
if FileName==0,return;end
handles.txafile=FileName;
handles.txadir=PathName;
[dummy,handles.txaname]=fileparts(FileName);
set(handles.TxText,'String',['Tx-Array: ',FileName],'Visible','on');
guidata(hObject, handles);

% --------------------------------------------------------------------
function loadRxTag_Callback(hObject, eventdata, handles)
[FileName,PathName] = uigetfile('*.xml','Select the Rx-Array XML file');
if FileName==0,return;end
handles.rxafile=FileName;
handles.rxadir=PathName;
[dummy,handles.txaname]=fileparts(FileName);
set(handles.RxText,'String',['Rx-Array: ',FileName],'Visible','on');
guidata(hObject, handles);

% --------------------------------------------------------------------
function loadSampleTag_Callback(hObject, eventdata, handles)
[FileName,PathName] = uigetfile('*.mat;*.bin','Select sample from mat file, or binary file');
if FileName==0,return;end
handles.samplefile=FileName;
guidata(hObject, handles);

% --- Executes on selection change in sim_dump.
function sim_dump_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function sim_dump_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setT1_Callback(hObject, eventdata, handles)
handles.sample.T1=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
elseelement
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setT1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setT2_Callback(hObject, eventdata, handles)
handles.sample.T2=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setT2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setM0_Callback(hObject, eventdata, handles)
handles.sample.M0=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setM0_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setChemShift_Callback(hObject, eventdata, handles)
handles.sample.CS=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setChemShift_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setRadius_Callback(hObject, eventdata, handles)
handles.sample.R=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setRadius_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in SusceptTag.
function SusceptTag_Callback(hObject, eventdata, handles)
handles.sample.Suscept=get(hObject,'Value');
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
if (handles.sample.Suscept==1),bvis='on';else, bvis='off';end
set(handles.gamBoTag,'Visible',bvis);    
set(handles.gamBoText,'Visible',bvis);    
write_simu_xml(handles,1);
guidata(hObject, handles);

function gamBoTag_Callback(hObject, eventdata, handles)
handles.sample.gamBo=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function gamBoTag_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function setGrid_Callback(hObject, eventdata, handles)
handles.sample.DxDy=str2num(get(hObject,'String'));
if strcmp(handles.sample.name,'brain')
 handles.UserSample=brainSample(handles);
else
 handles.UserSample=[];
end
write_simu_xml(handles,1);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setGrid_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setIncTag_Callback(hObject, eventdata, handles)
handles.sim.INC=str2num(get(hObject,'String'));
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setIncTag_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setT2Prime_Callback(hObject, eventdata, handles)
p=str2num(get(hObject,'String'));
if p==0
    p=inf;
    set(hObject,'String','inf');
end
handles.sim.R2P=1/p;
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setT2Prime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setConcField_Callback(hObject, eventdata, handles)
handles.sim.CF=str2num(get(hObject,'String'));
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setConcField_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setNoise_Callback(hObject, eventdata, handles)
handles.sim.RN=str2num(get(hObject,'String'));
handles=write_simu_xml(handles,1);
handles.sim.RN=handles.sim.RN*handles.maxM0/100;
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function setNoise_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in showLeft.
function showLeft_Callback(hObject, eventdata, handles)
axes(handles.hax{1});
for i=[1 3 4 5 6]
    cla(handles.hax{i},'reset');
    set(handles.hax{i},'color',[1 1 1],'visible','off');
end
Nimg=plotsim(handles,get(hObject,'Value'));
if get(hObject,'Value')<3,bvis='off';else;bvis='on';end
set(handles.EPI_L,'Visible',bvis);
if (Nimg==1),bvis='off';
else;bvis='on';for i=1:Nimg;C{i}=['# ',num2str(i)];end;set(handles.ImageL,'String',C);end
set(handles.ImageL,'Visible',bvis);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function showLeft_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in showRight.
function showRight_Callback(hObject, eventdata, handles)
axes(handles.hax{2});
cla(handles.hax{2},'reset');
set(handles.hax{2},'color',[1 1 1],'visible','off');
tmp=handles.epil;handles.epil=handles.epir;
Nimg=plotsim(handles,1+get(hObject,'Value'));
handles.epil=tmp;
if get(hObject,'Value')==1,bvis='off';else;bvis='on';end
set(handles.EPI_R,'Visible',bvis);
if (Nimg==1),bvis='off';handles.img_num=1;
else;bvis='on';for i=1:Nimg;C{i}=['# ',num2str(i)];end;set(handles.ImageR,'Value',1),set(handles.ImageR,'String',C);end
set(handles.ImageR,'Visible',bvis);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function showRight_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in EPI_R.
function EPI_R_Callback(hObject, eventdata, handles)
handles.epir=get(hObject,'Value');
set(hObject,'Value',get(handles.showRight,'Value'));
showRight_Callback(hObject, eventdata, handles);
set(hObject,'Value',handles.epir);
guidata(hObject, handles);

% --- Executes on button press in EPI_L.
function EPI_L_Callback(hObject, eventdata, handles)
handles.epil=get(hObject,'Value');
set(hObject,'Value',get(handles.showLeft,'Value'));
showLeft_Callback(hObject, eventdata, handles);
set(hObject,'Value',handles.epil);
guidata(hObject, handles);


% --- Executes on button press in zoomflag.
function zoomflag_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    zoom(gcf,'on')
else
 set(hObject,'Value',get(handles.showRight,'Value'));
 showRight_Callback(hObject, eventdata, handles);
 set(hObject,'Value',get(handles.showLeft,'Value'));
 showLeft_Callback(hObject, eventdata, handles);
 set(hObject,'Value',0);
 guidata(hObject, handles);
 zoom(gcf,'off')
end


% --- Executes on selection change in ImageL.
function ImageL_Callback(hObject, eventdata, handles)
handles.img_num=get(hObject,'Value');
set(hObject,'Value',get(handles.showLeft,'Value'));
showLeft_Callback(hObject, eventdata, handles);
set(hObject,'Value',handles.img_num);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function ImageL_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ImageR.
function ImageR_Callback(hObject, eventdata, handles)
handles.img_num=get(hObject,'Value');
set(hObject,'Value',get(handles.showRight,'Value'));
showRight_Callback(hObject, eventdata, handles);
set(hObject,'Value',handles.img_num);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function ImageR_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function setROI_Callback(hObject, eventdata, handles)
r=str2num(get(hObject,'String'));
[x,y]=ginput(1);
try
 c=get(gca,'Children'); A=get(c(end),'Cdata');
 [X,Y]=size(A);[X,Y]=meshgrid(1:X,1:Y);
 [I,J]=find( (X-x).^2+(Y-y).^2 <= r^2 );
 if ~isempty(I); A=A(I,J); else A=A(round(x),round(y));end
 set(handles.MROI,'String',['M=',num2str(mean(A(:)),3)]);
 set(handles.SROI,'String',['S=',num2str(std(A(:)),3)]);
 hold on
  if r>0
   plot(x+r*cos(0:.01:2*pi),y+r*sin(0:.01:2*pi),'r','linewidth',2)
  else
   plot(x,y,'xr')
  end
 hold off
catch
 set(handles.MROI,'String','');
 set(handles.SROI,'String','');
end
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function setROI_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function plotTag_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function plotGUITag_Callback(hObject, eventdata, handles)
 [FileName,PathName] = uiputfile('*.jpg');
 if FileName==0,return;end
 set(gcf,'PaperPositionMode','auto','InvertHardcopy','off')
 print('-djpeg90',FileName)


% --------------------------------------------------------------------
function plotLeftTag_Callback(hObject, eventdata, handles)
h=figure;
colormap(gray);
if get(handles.showLeft,'Value')>1
 h=copyobj(handles.hax{1},h);
 set(h,'units','normalized','position',[.1 .1 .8 .8])
else
    p=[ 0.1300    0.5838    0.3347    0.3412; ...
        0.5703    0.5838    0.3347    0.3412; ...
        0.1300    0.1100    0.3347    0.3412; ...
        0.5703    0.1100    0.3347    0.3412];
    for j=1:4
         g(j)=copyobj(handles.hax{2+j},h);
         set(g(j),'units','normalized','position',p(j,:))
         colorbar('peer',g(j));
    end
end

% --------------------------------------------------------------------
function plotRightTag_Callback(hObject, eventdata, handles)
h=figure;
colormap(gray);
h=copyobj(handles.hax{2},h);
set(h,'units','normalized','position',[.1 .1 .8 .8])
if get(handles.showRight,'Value')==4;colorbar('peer',h,'southoutside');end

% --------------------------------------------------------------------
function SettingsTag_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function ParCompTag_Callback(hObject, eventdata, handles)
 set(hObject,'Checked','on')
 set(handles.LocCompTag,'Checked','off');
 set(handles.LocCompTagPar,'Checked','off');
 guidata(hObject, handles);

% --------------------------------------------------------------------
function LocCompTagPar_Callback(hObject, eventdata, handles)
 set(hObject,'Checked','on')
 set(handles.ParCompTag,'Checked','off');
 set(handles.LocCompTag,'Checked','off');
 guidata(hObject, handles);

% --------------------------------------------------------------------
function LocCompTag_Callback(hObject, eventdata, handles)
 set(hObject,'Checked','on')
 set(handles.ParCompTag,'Checked','off');
 set(handles.LocCompTagPar,'Checked','off');
 guidata(hObject, handles);

% --------------------------------------------------------------------
function ComputationTag_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function loadSigTag_Callback(hObject, eventdata, handles)
 [FileName,PathName] = uigetfile('*.mat','Select a Signal mat-file');
 if FileName==0,return;end
 SIGNAL=load(FileName);
 f=fopen('signal.bin','wb'); fwrite(f,SIGNAL.All,'double','l'); fclose(f);
 cla(handles.hax{2},'reset');
 set(handles.hax{2},'color',[1 1 1],'visible','off');
 set(handles.EPI_R,'Visible','off');
 set(handles.ImageR,'Visible','off');
 tmp=handles.epil; handles.epil=handles.epir;
 plotsim(handles,2);
 handles.epil=tmp;
 set(handles.showRight,'Value',1);
 guidata(hObject, handles);
% --------------------------------------------------------------------
function saveSigTag_Callback(hObject, eventdata, handles)
 [FileName,PathName] = uiputfile('*.mat');
 if FileName==0,return;end
 f=fopen('signal01.bin'); All=fread(f,Inf,'double','l');fclose(f);
 n=size(All,1)/4; A =reshape(All,4,n)';t=A(:,1);[t,I]=sort(t);M=A(I,2:4);
 d=diff(diff(t));d(d<1e-5)=0;I=[0;find(d)+1;length(t)];
 save(FileName,'t','M','I','All');
% --------------------------------------------------------------------
function saveMagEvolTag_Callback(hObject, eventdata, handles)
 [FileName,PathName] = uiputfile('*.mat');
 if FileName==0,return;end
 [M,t]=readEvol(handles.sample.file,'evol',0);
 save(FileName,'t','M');
 


