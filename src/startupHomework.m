close hidden all;
clear hidden all;
clear all classes;

format compact;
dbstop if error;
% dbstop if caught error;
set(groot, 'defaulttextinterpreter','none') 
set(groot, 'DefaultTextInterpreter', 'none')
set(groot, 'DefaultLegendInterpreter', 'none')
set(groot, 'defaultFigurePaperPositionMode', 'auto')

%% clean up class definitions
clear mclasses;

%% path variables
rootpath = fullfile('D:\02PHBS_G2\m1\SE\Proj\PairTrading\src');
addpath(fullfile(rootpath, 'sharedLibrary',  'utils'));
addpath(genpath_exclude(rootpath, {'.git', '.ignore', 'data', 'results', 'serializedData', 'reports', 'doc', '+mclasses'}));

STATICPARS = mclasses.staticParameters.StaticParameters;

%% add CVX path (CAUTIOM: make sure CVX is installed OUTSIDE of the above rootpath directory)
% cvxPath = '/Users/cescqi/Downloads/PHBS Lecture/21-22 Fall I/Software Engineering/cvx/cvx';
% cd(cvxPath)
% %% cvx_setup '/Users/cescqi/Downloads/PHBS Lecture/21-22 Fall I/Software Engineering/cvx/cvx/cvx_license.p'
% cvx_setup

%% project directory
PROJECTPATH = fullfile(rootpath);

%% final touch
cd(PROJECTPATH); 
