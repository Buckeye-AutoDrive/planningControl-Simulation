% This function loads in the sensor configuration chosen in the startup
% script and returns sensor detections

function [sensors, numSensors] = createSensors(scenario)
d = dir('Sensor Configs/*.m');
fn = {d.name};
[indx,~] = listdlg('PromptString',{'Select a sensor configuration.',...
    'Only one file can be selected at a time.',''},...
    'SelectionMode','single','ListString',fn);
[~,SelectedConfigName,~] = fileparts(d(indx).name);
[sensors,numSensors]=feval(SelectedConfigName,scenario);

        



