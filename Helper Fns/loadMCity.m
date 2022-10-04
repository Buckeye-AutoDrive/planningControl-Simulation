% This function loads in the OSM MCity into DSD and adds sensors
function [scenario,scenarioName,sensors]=loadMCity()

scenario = loadScenario('MCity_fromStaticDump_v1_ROI_actors_trafficLight.mat');  
% scenario = loadScenario('MCity_Scene_recognition.mat');  
assignin('base','Ts', 0.05); % sampling time (0.05sec)
stopTime=scenario.StopTime;
assignin('base','stopTime',stopTime);
scenarioName='MCity_fromStaticDump_v1_ROI_actors_trafficLight';
% scenarioName='MCity_Scene_recognition';
[sensors, numSensors] = createSensors(scenario);
end





