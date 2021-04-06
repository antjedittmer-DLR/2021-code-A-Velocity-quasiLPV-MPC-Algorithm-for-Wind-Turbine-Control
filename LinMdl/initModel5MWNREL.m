function [wecs, M, Ce, K, Q, L, rho, tau, kappa, lambda, pitch, Cq, Ct ] = initModel5MWNREL(plotOn, Rotor_Lamda, Rotor_Pitch, Rotor_cQ, Rotor_cT, figDir)
% initModel5MWNREL initializes parameters of NREL 5 MW turbine.
% Aerodynamic force and thrust LUT can be plotted. 
% All inputs are optional.
% - plotOn: Plots aerodynamic torque and force dependent on pitch and tip 
%   speed ratio (Default: 0)
% - Rotor_Lamda: tip speed ratio vector (from mat file NREL5MW_CPdata)
% - Rotor_Pitch: blade pitch vector (from mat file NREL5MW_CPdata)
% - Rotor_cQ: aerodynamic torque look-up table
% - Rotor_cT: aerodynamic force look-up table
% - figDir: output figure directory (Default: 1)
%
% Outputs:
% - wecs: Structure with NREL 5 WM information
% - M: mass matrix Lagrange's equation 
% - Ce: damping matrix Lagrange's equation 
% - K: stiffness matrix Lagrange's equation
% - Q: term for input matrix based on Lagrange's equation
% - L: term for system matrix based on Lagrange's equation
% - rho: air density
% - tau: time constant pitch actuator
% - kappa: time constant torque actuator
% - Cq: aerodynamic torque
% - Ct: aerodynamic force

%% Set path for input data and output figure directory

% Set path to input data directory
workDir = fileparts(mfilename('fullpath'));
mainDir = fileparts(workDir);

% Switch for plots
if ~nargin
    plotOn = 0;
end

% Load data for cT, cQ LUT if not passed as input
if nargin < 5 || isempty(Rotor_Lamda) || isempty(Rotor_Pitch) || ....
        isempty(Rotor_cQ) || isempty(Rotor_Pitch)
    dataInDir = fullfile(mainDir,'dataIn');
    load(fullfile(dataInDir,'NREL5MW_CPdata.mat'),...
    'Rotor_Lamda','Rotor_Pitch','Rotor_cQ','Rotor_cT');
end

% Set path to figure directory
if nargin < 6
    figDir = fullfile(mainDir,'figDir');
    if ~isfolder(figDir)
        mkdir(figDir)
    end
end

%% Define parameters
% 5MW FAST WIND TURBINE (NREL/TP-500-38060) Definition of a 5-MW Reference
% Wind Turbine for Offshore System Development
% Cut-In, Rated, Cut-Out Wind Speed 3 m/s, 11.4 m/s, 25 m/s
% Cut-In, Rated Rotor Speed 6.9 rpm, 12.1 rpm
% Tower equivalent mass, MT 438,000 kg
% Tower equivalent damping, CT 6421 wecs.N s/m
% Tower equivalent stiffness, KT 1,846,000 wecs.N/m

% Constants: Air density and actuator time constants
rho = 1.225; % Air density (kg/m^3)
tau = 0.01; % time constant pitch actuator
kappa = 0.01; % time constant torque  actuator
% Bg = 0.9; % Tg= Bg(wg - wz). Unused because we use Tg as input

% Turbine constants
wecs.N = 3;% Number of blades
wecs.Ng = 97; % Gearbox ratio
wecs.mh = 56780; % kg;  Hub mass
wecs.mb =  0.25 * 17740; %kg;  Modal mass of each blade
wecs.mn = 240000; % kg;  Nacellle mass
wecs.mtower = 347460;% kg; Mass of the tower and nacelle
wecs.mt = 0.25*wecs.mtower + wecs.mn + wecs.mh;
wecs.H =  87.6;

wecs.Jrg = 534.116;%  kg*m^2; Inertia of the generator
wecs.Jr = 115926 + 3 * 11.776e6; % kg*m^2; Inertia of the rotor (Hub inertia + 3 blades)
f0 = 0.324; % Hz, First natural tower fore-aft frequency
% f0sw = 0.3120; % First natural tower sidewards frequency
wecs.wnb = 0.6993 * 2*pi; % rad/s First natural blade frequency 
wecs.wnt = f0 * 2*pi; % wecs.wnb; 0.3240
wecs.zetat = 1/100; %damping ratio of tower (Table 6.2)
wecs.zetab = 0.477465/100;% damping ratio of blade

wecs.Kt = wecs.wnt^2 * wecs.mt; % Stiffness of the tower s^2 + B/Ms + K/m
wecs.Bt = 2 *wecs.zetat * wecs.wnt *wecs.mt; % tower 2*6421;
wecs.Kb = wecs.wnb^2 * wecs.mb; %Stiffness of each blade
wecs.Bb = 2 *wecs.zetab*wecs.wnb *wecs.mb; %Damping of the blade
wecs.Ks = 867637000; %Nm/rad Stiffness of the transmission
% 2*zeta*wn = B
wecs.Bs = 6215000;  %Nm/rad/sec %Damping of the transmission
wecs.rb = 63; % m blade radius
wecs.etag = 0.944; %Drivetrain.Generator.Efficiency = 0.944;

%% Lagrange's Model matrices
% Force input w = [Ft_fa,Ft_sw,Tr,Tg]; Ft_fa = Ft, Ft_sw = 3/2*Tg
% States q: xdot_fa, zeta, xdot_sw, omega_r, omega_gr

M =[wecs.mt + wecs.N*wecs.mb wecs.N*wecs.mb*wecs.rb 0 0 0; % 
    wecs.N*wecs.mb*wecs.rb  wecs.N*wecs.mb*wecs.rb^2 0 0 0;
    0 0 wecs.mt 0 0;
    0 0 0 wecs.Jr 0;
    0 0 0 0 wecs.Jrg*wecs.Ng^2];

Ce = [wecs.Bt 0 0 0 0;
    0 wecs.N*wecs.Bb*wecs.rb^2 0 0 0 ; %
    0 0 wecs.Bt 0 0
    0 0 0  wecs.Bs -wecs.Bs;
    0 0 0 -wecs.Bs wecs.Bs];

K = [wecs.Kt 0 0 0;
    0 wecs.N*wecs.Kb*wecs.rb^2 0 0; %
    0 0 wecs.Kt 0
    0 0 0 wecs.Ks;
    0 0 0 -wecs.Ks];

Q = [1 0 0 0;
    wecs.rb 0 0 0;
    0 1 0 0;
    0 0 1 0;
    0 0 0 -wecs.Ng];

L = [eye(4), [0;0;0;-1]];

%% Ct/Cq for LUT for Model
idxPitch = Rotor_Pitch >= -8;
idxTSR = Rotor_Lamda < 15;

betaDeg = Rotor_Pitch(idxPitch);
pitch = betaDeg * pi/180;
lambda = Rotor_Lamda(idxTSR);

Cq = Rotor_cQ(idxPitch,idxTSR);
Ct = Rotor_cT(idxPitch,idxTSR);

%% Plot aerodynamic torque and force dependent on pitch and tip speed ratio 

% Plot not generated by default 
if plotOn
    [Xq,Yq] = meshgrid(lambda,betaDeg);
    
    % Plot aerodynamic force C_T
    xlabelStr = 'tip speed ratio \lambda [-]';
    ylabelStr = 'pitch angle \beta [deg]';
    zlabelStr = 'Force coefficient C_T [-]';
    titleStrData1Interp = ['Aerodynamique ',zlabelStr,'  from NREL FAST 5 MW'];
    
    figure(1); surf(Xq,Yq,Ct,'FaceColor','interp','EdgeColor','none'); hold on
    axis tight;
    xlabel(xlabelStr); ylabel(ylabelStr ); zlabel(zlabelStr);
    title(titleStrData1Interp);
    view(60,30)
    
    print(gcf,fullfile(figDir,'Ct_NRRLFAST5MW'), '-dpng');
    print(gcf,fullfile(figDir,'Ct_NRRLFAST5MW'), '-depsc');
    
    % Plot aerodynamic torque C_Q
    zlabelStr = 'Torque coefficient C_Q [-]';
    titleStrData1Interp = ['Aerodynamique ',zlabelStr,' from NREL FAST 5 MW'];
    
    figure(2); surf(Xq,Yq,Cq,'FaceColor','interp','EdgeColor','none'); hold on
    axis tight;
    xlabel(xlabelStr); ylabel(ylabelStr ); zlabel(zlabelStr);
    title(titleStrData1Interp)
    view(60,30)
    
    print(gcf,fullfile(figDir,'Cq_NRRLFAST5MW'), '-dpng');
    print(gcf,fullfile(figDir,'Cq_NRRLFAST5MW'), '-depsc');
end
