function [sensors,numSensors]=SensorConfigDefault(scenario)
% Assign into each sensor the physical and radar profiles for all actors
profiles = actorProfiles(scenario);
sensors{1} = visionDetectionGenerator('SensorIndex', 1, ...
    'MinObjectImageSize', [5 5], ...
    'DetectorOutput', 'Objects only', ...
    'ActorProfiles', profiles);
sensors{2} = drivingRadarDataGenerator('SensorIndex', 2, ...
    'MountingLocation', [3.7 0 0.5], ...
    'RangeLimits', [0 100], ...
    'HasNoise', false, ...
    'TargetReportFormat', 'Detections', ...
    'HasElevation', true, ...
    'HasOcclusion', false, ...
    'HasFalseAlarms', false, ...
    'FieldOfView', [35 50], ...
    'Profiles', profiles);
numSensors = 2; % change based on number of sensors in this configuration