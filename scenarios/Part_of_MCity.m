function [allData, scenario, sensors] = Part_of_MCity()
%Part_of_MCity - Returns sensor detections
%    allData = Part_of_MCity returns sensor detections in a structure
%    with time for an internally defined scenario and sensor suite.
%
%    [allData, scenario, sensors] = Part_of_MCity optionally returns
%    the drivingScenario and detection generator objects.

% Generated by MATLAB(R) 9.11 (R2021b) and Automated Driving Toolbox 3.4 (R2021b).
% Generated on: 05-Jun-2022 11:34:13

% Create the drivingScenario object and ego car
[scenario, egoVehicle] = createDrivingScenario;

% Create all the sensors
[sensors, numSensors] = createSensors(scenario);

allData = struct('Time', {}, 'ActorPoses', {}, 'ObjectDetections', {}, 'LaneDetections', {}, 'PointClouds', {}, 'INSMeasurements', {});
running = true;
while running

    % Generate the target poses of all actors relative to the ego vehicle
    poses = targetPoses(egoVehicle);
    time  = scenario.SimulationTime;

    objectDetections = {};
    laneDetections   = [];
    ptClouds = {};
    insMeas = {};
    isValidTime = false(1, numSensors);
    isValidLaneTime = false(1, numSensors);
    isValidPointCloudTime = false(1, numSensors);
    isValidINSTime = false(1, numSensors);

    % Generate detections for each sensor
    for sensorIndex = 1:numSensors
        sensor = sensors{sensorIndex};
        % Generate the ego vehicle lane boundaries
        if isa(sensor, 'visionDetectionGenerator')
            maxLaneDetectionRange = min(500,sensor.MaxRange);
            lanes = laneBoundaries(egoVehicle, 'XDistance', linspace(-maxLaneDetectionRange, maxLaneDetectionRange, 101));
        end
        type = getDetectorOutput(sensor);
        if strcmp(type, 'Objects only')
            [objectDets, numObjects, isValidTime(sensorIndex)] = sensor(poses, time);
            objectDetections = [objectDetections; objectDets(1:numObjects)]; %#ok<AGROW>
        elseif strcmp(type, 'Lanes only')
            [laneDets, ~, isValidTime(sensorIndex)] = sensor(lanes, time);
            laneDetections   = [laneDetections laneDets]; %#ok<AGROW>
        elseif strcmp(type, 'Lanes and objects')
            [objectDets, numObjects, isValidTime(sensorIndex), laneDets, ~, isValidLaneTime(sensorIndex)] = sensor(poses, lanes, time);
            objectDetections = [objectDetections; objectDets(1:numObjects)]; %#ok<AGROW>
            laneDetections   = [laneDetections laneDets]; %#ok<AGROW>
        elseif strcmp(type, 'Lanes with occlusion')
            [laneDets, ~, isValidLaneTime(sensorIndex)] = sensor(poses, lanes, time);
            laneDetections   = [laneDetections laneDets]; %#ok<AGROW>
        elseif strcmp(type, 'PointCloud')
            if sensor.HasRoadsInputPort
                rdmesh = roadMesh(egoVehicle,min(500,sensor.MaxRange));
                [ptCloud, isValidPointCloudTime(sensorIndex)] = sensor(poses, rdmesh, time);
            else
                [ptCloud, isValidPointCloudTime(sensorIndex)] = sensor(poses, time);
            end
            ptClouds = [ptClouds; ptCloud]; %#ok<AGROW>
        elseif strcmp(type, 'INSMeasurement')
            insMeasCurrent = sensor(actorState, time);
            insMeas = [insMeas; insMeasCurrent]; %#ok<AGROW>
            isValidINSTime(sensorIndex) = true;
        end
    end

    % Aggregate all detections into a structure for later use
    if any(isValidTime) || any(isValidLaneTime) || any(isValidPointCloudTime) || any(isValidINSTime)
        allData(end + 1) = struct( ...
            'Time',       scenario.SimulationTime, ...
            'ActorPoses', actorPoses(scenario), ...
            'ObjectDetections', {objectDetections}, ...
            'LaneDetections', {laneDetections}, ...
            'PointClouds',   {ptClouds}, ... %#ok<AGROW>
            'INSMeasurements',   {insMeas}); %#ok<AGROW>
    end

    % Advance the scenario one time step and exit the loop if the scenario is complete
    running = advance(scenario);
end

% Restart the driving scenario to return the actors to their initial positions.
restart(scenario);

% Release all the sensor objects so they can be used again.
for sensorIndex = 1:numSensors
    release(sensors{sensorIndex});
end

%%%%%%%%%%%%%%%%%%%%
% Helper functions %
%%%%%%%%%%%%%%%%%%%%

% Units used in createSensors and createDrivingScenario
% Distance/Position - meters
% Speed             - meters/second
% Angles            - degrees
% RCS Pattern       - dBsm

function [sensors, numSensors] = createSensors(scenario)
% createSensors Returns all sensor objects to generate detections

% Assign into each sensor the physical and radar profiles for all actors
profiles = actorProfiles(scenario);
sensors{1} = visionDetectionGenerator('SensorIndex', 1, ...
    'UpdateInterval', 0.01, ...
    'SensorLocation', [1.918 0], ...
    'MinObjectImageSize', [2 2], ...
    'DetectorOutput', 'Lanes and objects', ...
    'Intrinsics', cameraIntrinsics([200 799.999999999999],[320 240],[480 640]), ...
    'ActorProfiles', profiles);
sensors{2} = drivingRadarDataGenerator('SensorIndex', 2, ...
    'UpdateRate', 100, ...
    'MountingLocation', [3.729 0 0.2], ...
    'RangeLimits', [0 100], ...
    'TargetReportFormat', 'Detections', ...
    'FieldOfView', [180 5], ...
    'Profiles', profiles);
numSensors = 2;

function [scenario, egoVehicle] = createDrivingScenario
% createDrivingScenario Returns the drivingScenario defined in the Designer

% Construct a drivingScenario object.
scenario = drivingScenario('StopTime', 60, ...
    'GeographicReference', [42.30084 -83.69825 0], ...
    'VerticalAxis', 'Y');

% Add all road segments
roadCenters = [-32.711 59.361 -0.00036059;
    -32.613 39.167 -0.00020377];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'State Street');

roadCenters = [-32.613 39.167 -0.00020377;
    -32.497 15.973 -0.00010271];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'State Street');

roadCenters = [-32.497 15.973 -0.00010271;
    -32.439 4.3211 -8.3838e-05];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'State Street');

roadCenters = [-32.439 4.3211 -8.3838e-05;
    -32.176 -50.008 -0.0002775];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'State Street');

roadCenters = [59.923 15.507 -0.00029996;
    39.086 15.496 -0.00013844;
    34.666 15.496 -0.00011293;
    26.28 15.551 -7.3059e-05];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [26.28 15.551 -7.3059e-05;
    -32.497 15.973 -0.00010271];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [-32.497 15.973 -0.00010271;
    -71.039 16.218 -0.00041567];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [-71.039 16.218 -0.00041567;
    -77.594 16.207 -0.00049191;
    -80.703 15.074 -0.00052765;
    -82.228 13.341 -0.00054323;
    -82.674 9.3756 -0.0005419;
    -81.346 6.2987 -0.00052107;
    -77.817 4.7546 -0.00047576;
    -71.195 4.6213 -0.00039843];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [-71.195 4.6213 -0.00039843;
    -32.439 4.3211 -8.3838e-05];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [-32.439 4.3211 -8.3838e-05;
    26.197 3.9323 -5.4934e-05];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [26.197 3.9323 -5.4934e-05;
    34.872 3.799 -9.632e-05;
    39.308 3.7546 -0.00012205;
    59.915 3.5881 -0.000282];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Main Street');

roadCenters = [-23.0141 81.8431 -0.000567693;
    -18.7593 86.2085 -0.000611416;
    -12.5666 91.5959 -0.000671485;
    -5.60716 97.2165 -0.000744959;
    -2.45725 99.1492 -0.000772787;
    1.57495 101.082 -0.000802912];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [1.57495 101.082 -0.000802912;
    4.57643 102.504 -0.000827097;
    7.66861 103.17 -0.000840831;
    11.4287 103.615 -0.00085367;
    15.4197 103.615 -0.000862058];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [15.4197 103.615 -0.000862058;
    19.6085 103.615 -0.000873543;
    25.8671 103.604 -0.000895641;
    27.4586 103.592 -0.000902102];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [27.4586 103.592 -0.000902102;
    29.7509 103.581 -0.000912186;
    36.5125 103.581 -0.000947256;
    48.7245 103.604 -0.0010291];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [26.09 -50.73 -0.00025546;
    -32.176 -50.008 -0.0002775];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Liberty Street');

roadCenters = [26.3534 152.912 -0.00189131;
    27.3596 117.411 -0.0011416];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Wolverine Avenue');

roadCenters = [27.3596 117.411 -0.0011416;
    27.3596 108.802 -0.000988607;
    27.4586 103.592 -0.000902102];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Wolverine Avenue');

roadCenters = [27.4586 103.592 -0.000902102;
    26.7578 69.8799 -0.000439679];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Wolverine Avenue');

roadCenters = [26.758 69.88 -0.00043968;
    26.494 48.22 -0.00023761;
    26.28 15.551 -7.3059e-05];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Wolverine Avenue');

roadCenters = [26.78 15.051 -7.3059e-05;
    26.697 3.4323 -5.4934e-05];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Wolverine Avenue');

roadCenters = [26.197 3.9323 -5.4934e-05;
    25.958 -31.113 -0.0001288;
    26.3 -53.8 -0.00025546];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Wolverine Avenue');

roadCenters = [-32.613 39.167 -0.00020377;
    1.4018 54.407 -0.00023271];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Carrier & Gable Drive');

roadCenters = [1.4018 54.407 -0.00023271;
    10.67 58.561 -0.00027833;
    17.415 61.704 -0.00032286;
    21.06 63.582 -0.00035232;
    23.163 65.448 -0.00037851;
    24.82 67.214 -0.00040314;
    26.758 69.88 -0.00043968];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Carrier & Gable Drive');

roadCenters = [26.7578 69.8799 -0.000439679;
    29.0089 72.046 -0.000473658;
    31.9609 74.2898 -0.000513542;
    36.9331 76.9335 -0.000571764;
    40.5201 78.933 -0.000617993;
    43.3896 81.0101 -0.000662941;
    45.1542 83.4206 -0.000706309;
    46.2591 85.7199 -0.00074477;
    47.4465 89.8188 -0.000810004;
    48.4112 94.9062 -0.000891074;
    48.5679 98.5163 -0.00094712;
    48.7245 103.604 -0.0010291];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Carrier & Gable Drive');

roadCenters = [48.7245 103.604 -0.0010291;
    48.3617 108.502 -0.00110797;
    47.4711 112.357 -0.00116817;
    44.7087 117.977 -0.00124994;
    37.9636 127.886 -0.00139768;
    32.6533 136.483 -0.00154689;
    28.6705 145.081 -0.00171795;
    26.3534 152.912 -0.00189131];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Carrier & Gable Drive');

roadCenters = [-32.711 59.361 -0.00036059;
    -28.234 59.938 -0.00034464;
    -24.21 61.993 -0.00034781;
    -21.134 65.281 -0.00036977;
    -19.353 69.413 -0.00040785;
    -19.081 73.901 -0.00045756;
    -20.351 78.211 -0.00051298;
    -23.014 81.843 -0.00056769];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', '453870101');

roadCenters = [-23.014 81.843 -0.00056769;
    -26.189 84.098 -0.00060932;
    -29.891 85.32 -0.00064183;
    -33.791 85.409 -0.00066247;
    -37.535 84.342 -0.00066915;
    -40.809 82.232 -0.0006616;
    -43.324 79.266 -0.00064053;
    -44.841 75.689 -0.00060746;
    -45.237 71.824 -0.00056546];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', '453870101');

roadCenters = [-45.237 71.824 -0.00056546;
    -44.495 68.036 -0.00051862;
    -42.664 64.637 -0.00047071;
    -39.926 61.905 -0.00042584;
    -36.504 60.105 -0.00038812;
    -32.711 59.361 -0.00036059];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', '453870101');

roadCenters = [27.3596 117.411 -0.0011416;
    25.8176 113.656 -0.00106702;
    24.1602 110.568 -0.00100614;
    22.3874 108.369 -0.000961853;
    19.0726 105.725 -0.000906629;
    15.4197 103.615 -0.000862058];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', '453872618');

roadCenters = [-75.583 -49.863 -0.00064249;
    -72.317 -24.937 -0.00045821;
    -72.078 -23.115 -0.00044863;
    -71.418 -15.184 -0.00041735;
    -71.195 -5.0648 -0.00039877;
    -71.195 4.6213 -0.00039843];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [-71.195 4.6213 -0.00039843;
    -71.039 16.218 -0.00041567];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [-71.039 16.218 -0.00041567;
    -71.195 35.49 -0.0004957;
    -70.313 48.053 -0.00056839;
    -69.76 51.697 -0.00059088;
    -68.762 55.329 -0.0006106;
    -66.214 60.061 -0.00062658;
    -62.57 64.137 -0.00062961;
    -58.364 67.447 -0.00062402;
    -55.379 69.325 -0.00061762;
    -53.145 70.413 -0.00061059;
    -50.819 71.18 -0.00060019;
    -48.717 71.513 -0.00058754;
    -45.237 71.824 -0.00056546];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Pontiac Trail');

roadCenters = [-32.176 -50.008 -0.0002775;
    -32.061 -73.668 -0.00050681];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'State Street');

roadCenters = [-32.176 -50.008 -0.0002775;
    -78.8 -50.5 -0.00064249];
laneSpecification = lanespec([1 1]);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Liberty Street');

roadCenters = [-30.53 -42.33 0;
    -28.56 -45.88 0;
    -26.12 -48.24 0];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road');

roadCenters = [-34.17 -42.38 0;
    -36.02 -46.11 0;
    -39.55 -48.66 0];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road1');

roadCenters = [-39.21 -51.75 0;
    -35.5 -53.47 0;
    -33.92 -56.61 0];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road2');

roadCenters = [-24.47 -51.75 0;
    -28.34 -53.75 0;
    -30.63 -58.76 0];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road3');

roadCenters = [34.4 3.3 0;
    29.9 2.1 0;
    28.5 -1.6 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road4');

roadCenters = [-24.8 4.3 0;
    -28.06 3.7378 0;
    -30.5 -0.6 0];
laneSpecification = lanespec(1, 'Width', 3);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road12');

roadCenters = [-25.8 15.8 0;
    -29.9 14.4 0;
    -30.7 12.7 0];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road13');

roadCenters = [-30.5 19.1 0;
    -30.033 18.1 0;
    -26.133 16 0];
laneSpecification = lanespec(1);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road14');

roadCenters = [-30.7 9.4 0;
    -30.3 6.8 0;
    -26.633 4.4 0];
laneSpecification = lanespec(1, 'Width', 3);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road15');

roadCenters = [-21.5 41.2 0;
    -29.2 36.6 0;
    -29.9 33.9 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road5');

roadCenters = [33.8 15.4 0;
    30.267 13.633 0;
    28.3 9.4 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road6');

roadCenters = [23.9 21.1 0;
    22.6 17.4 0;
    19.4 15.9 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road7');

roadCenters = [24.2 10.3 0;
    22.2 5 0;
    19.433 4.3 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road8');

roadCenters = [17 3.8 0;
    22.7 2.9 0;
    24 -3.1 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road9');

roadCenters = [17.167 15.7 0;
    22.867 14.8 0;
    24.6 8.4 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road10');

roadCenters = [29.1 9.9 0;
    29.8 5.7 0;
    35.267 4.1 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road11');

roadCenters = [28.511 21.633 0;
    29.211 17.433 0;
    34.678 15.833 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road16');

roadCenters = [-41.533 4 0;
    -36.2 2.7 0;
    -34.533 -2.9 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road17');

roadCenters = [-41.533 15.9 0;
    -36.2 14.8 0;
    -34.533 9 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road18');

roadCenters = [-34.467 21.267 0;
    -36.2 17.6 0;
    -38.967 16.067 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road19');

roadCenters = [-34.367 9.6667 0;
    -35.667 5.9667 0;
    -38.867 4.4667 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road20');

roadCenters = [-30.9 48.9 0;
    -29 46.3 0;
    -23.3 45.9 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road21');

roadCenters = [-17.9 83.2 0;
    -18.333 80.467 0;
    -17.3 78.1 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road22');

roadCenters = [-20.5 88.3 0;
    -21.4 87.6 0;
    -27.6 87.2 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road23');

roadCenters = [-24.8 58.7 0;
    -29 56.3 0;
    -29.9 54.4 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road24');

roadCenters = [-38 57.9 0;
    -35.9 56.1 0;
    -35 54.6 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road25');

roadCenters = [-46.5 78.3 0;
    -48 75.8 0;
    -51.2 73.9 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road26');

roadCenters = [-53.5 67.5 0;
    -50.1 68.5 0;
    -46.3 65.9 0];
laneSpecification = lanespec(1, 'Width', 2);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road27');

roadCenters = [-63.533 4.6333 0;
    -68.033 3.4333 0;
    -69.433 -0.26667 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road28');

roadCenters = [-63.033 15.933 0;
    -67.533 14.733 0;
    -68.933 11.033 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road29');

roadCenters = [-68.889 22.633 0;
    -68.189 18.433 0;
    -62.722 16.833 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road30');

roadCenters = [-69.289 10.933 0;
    -68.589 6.7333 0;
    -63.122 5.1333 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road31');

roadCenters = [-72.767 21.367 0;
    -74.067 17.667 0;
    -77.267 16.167 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road32');

roadCenters = [-72.767 10.067 0;
    -74.067 6.3667 0;
    -77.267 4.8667 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road33');

roadCenters = [-79.911 4.7333 0;
    -74.578 3.4333 0;
    -72.911 -2.1667 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road34');

roadCenters = [-78.3 16.1 0;
    -74.7 14.8 0;
    -73.3 12.4 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road35');

roadCenters = [19.1 101.6 0;
    23.1222 100.333 0;
    24.6 96.9 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road36');

roadCenters = [17.5 59.5 0;
    22.4 58.6 0;
    24.1 55.9 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road37');

roadCenters = [33.9 101.2 0;
    31.2778 100.122 0;
    29.3111 95.8889 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road38');

roadCenters = [29.2111 111.433 0;
    29.9111 107.233 0;
    35.3778 105.633 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road39');

roadCenters = [23.6 -44.6 0;
    20.1 -48.3 0;
    19.6 -48.7 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road40');

roadCenters = [-72.489 -43.367 0;
    -72.089 -45.967 0;
    -68.422 -48.367 0];
laneSpecification = lanespec(1, 'Width', 3);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road41');

roadCenters = [32.52 71.99 0;
    30.568 69.972 0;
    28.92 65.55 0];
laneSpecification = lanespec(1, 'Width', 2.5);
road(scenario, roadCenters, 'Lanes', laneSpecification, 'Name', 'Road42');

roadCenters = [-75.7 -20.3 0;
    -68.2 -20.5 0];
road(scenario, roadCenters, 'Name', 'Road43');

% Add the ego vehicle
egoVehicle = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [-30.3 -71.5 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'PlotColor', [0 114 189] / 255, ...
    'Name', 'Car');
waypoints = [-30.3 -71.5 0;
    -30.4 -62.58 0.01;
    -30.4 -54.41 0.01;
    -30.4 -38.4 0;
    -30.4 -24 0;
    -30.6 -10.5 0;
    -30.7 -1.23 0.01;
    -30.77 9.38 0.01;
    -30.7 22.6 0;
    -30.82 30.54 0;
    -30.8 32.8 0;
    -30.71 34.73 0;
    -30.23 36.56 0.01;
    -29.37 38.05 0;
    -28.23 39.13 0.01;
    -26.42 40.25 0;
    -24.74 41.09 0.01;
    -22.13 42.27 0;
    -19.1 43.6 0;
    -15.15 45.34 0;
    -10.8 47.3 0;
    -1.34 51.58 0.01;
    7.4 55.2 0;
    16.2 59.1 0;
    18.61 60.16 0;
    21.04 61.32 0.01;
    23.83 63.35 0;
    25.86 65.65 0.01;
    27.52 68.89 0.01;
    28.3 71.89 0;
    28.5 73 0;
    28.73 75.32 0;
    28.8 77.95 0;
    28.8 80.4 0;
    28.89 85.16 0;
    29 90.4 0;
    29.12 95.97 0.01;
    29.16 99.96 0.01;
    29.27 103.68 0.01;
    29.29 108.76 0;
    29.2 112.9 0;
    29.05 118.33 0;
    28.89 123.54 0.01;
    28.61 131.68 0.01;
    28.17 141.15 0.01];
speed = [30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30;30];
trajectory(egoVehicle, waypoints, speed);

% Add the non-ego actors
car1 = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [6.9 -48.4 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'PlotColor', [0.494 0.184 0.556], ...
    'Name', 'Car1');
waypoints = [6.9 -48.4 0;
    -0.8 -48.4 0;
    -8.2 -48.4 0;
    -14.1 -48.4 0;
    -21 -48.4 0;
    -29.2 -48.2 0;
    -36.5 -48.3 0;
    -44.5 -48.2 0;
    -53.4 -48.4 0;
    -60.7 -48.4 0;
    -67.8 -48.4 0;
    -70.3 -47.7 0;
    -72.4 -44.9 0;
    -73 -41.9 0;
    -71.7 -36 0;
    -71 -29.2 0;
    -70.6 -23.3 0;
    -69.7 -13.3 0;
    -69.5 -5.3 0;
    -69.5 2.4 0;
    -69.6 8.5 0;
    -69.6 12.6 0;
    -70.5 14.8 0;
    -73.4 16.1 0;
    -76.8 16.3 0;
    -81.3 14.6 0;
    -83 11.7 0];
speed = [10;10;10;10;0;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10];
waittime = [0;0;0;0;3;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
trajectory(car1, waypoints, speed, waittime);

car2 = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [-30.9 50.1 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'PlotColor', [0.466 0.674 0.188], ...
    'Name', 'Car2');
waypoints = [-30.9 50.1 0;
    -31 56.9 0;
    -24.4 59.6 0;
    -19.3 65.2 0;
    -17.4 70.8 0;
    -17.6 76.6 0;
    -19.5 80.7 0;
    -19.5 82.9 0;
    -16.5 86.4 0;
    -9.4 91.8 0;
    -2.2 97.3 0;
    4.1 100.2 0;
    9.9 101.6 0;
    15.9 102.2 0;
    24 102.2 0;
    29.6 102.1 0;
    35.6 101.7 0;
    40.6 101.7 0;
    44.83 101.28 0.01;
    46.4 99.4 0;
    45.9 94 0;
    45.3 89.6 0;
    43.5 84.6 0;
    40.3 81.1 0;
    34.5 77.6 0;
    28.5 73 0;
    22.1 67.3 0;
    14.9 62.7 0;
    3.3 57.6 0;
    -7.9 52.4 0;
    -18.2 47.9 0;
    -22.5 46 0;
    -27.42 43.56 0.01;
    -30.81 41.75 0.01;
    -32.88 39.68 0.01;
    -34.2 36.57 0.01;
    -34.46 31.18 0.01;
    -34.33 22.22 0.01];
speed = [10;10;10;10;10;10;10;10;10;10;10;10;10;0;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;10;0;10;10;10;10;10;10];
waittime = [0;0;0;0;0;0;0;0;0;0;0;0;0;3;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;3;0;0;0;0;0;0];
trajectory(car2, waypoints, speed, waittime);

car3 = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [32.8 132.2 0], ...
    'Mesh', driving.scenario.carMesh, ...
    'PlotColor', [0.301 0.745 0.933], ...
    'Name', 'Car3');
waypoints = [32.8 132.2 0;
    37.2 125.7 0;
    40.5 120.1 0;
    43.8 114.8 0;
    46.4 110.1 0;
    46.48 106.63 0.01;
    43.3 105.1 0;
    39 104.9 0;
    34.6 105 0;
    27.2 105.4 0;
    20.6 105.5 0;
    14.1 105.5 0;
    3.7 103.8 0;
    -3.3 101.2 0;
    -9.8 97.4 0;
    -16.4 91.4 0;
    -22 86.7 0;
    -27.3 85.7 0;
    -30.9 86.8 0];
speed = [7;7;7;7;7;7;7;7;0;7;7;7;7;7;7;7;7;7;7];
waittime = [0;0;0;0;0;0;0;0;3;0;0;0;0;0;0;0;0;0;0];
trajectory(car3, waypoints, speed, waittime);

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-27 -59.8 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-23.1333333333333 -44.5 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light1');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-37.2666666666667 -40.6 0], ...
    'Name', 'Traffic_Light2');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-40.6 -54.9 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light3');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [17.7666666666667 -55.4 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light4');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [21.4333333333333 -41.8 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light5');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-66.6 -45.8 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light6');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-79.4333333333333 -41.3 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light7');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-66.4666666666667 -0.100000000000003 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light8');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-75.7 22.5 0], ...
    'Name', 'Traffic_Light9');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-65.0333333333333 19.5 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light10');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-25.3666666666667 19 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light11');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-27.3 -2 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light12');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-39.7333333333333 0.900000000000003 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light13');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-37.8666666666667 20.7 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light14');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [20.5 1.1 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light15');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [21.1666666666667 22.2 0], ...
    'Name', 'Traffic_Light16');

actor(scenario, ...
    'ClassID', 8, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [31.5333333333333 -3.9 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Traffic_Light17');

actor(scenario, ...
    'ClassID', 9, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-27.6 54 0], ...
    'PlotColor', [0.494 0.184 0.556], ...
    'Name', 'Roundabout');

actor(scenario, ...
    'ClassID', 9, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-50.8333333333333 65.5 0], ...
    'PlotColor', [0.494 0.184 0.556], ...
    'Name', 'Roundabout1');

actor(scenario, ...
    'ClassID', 9, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-22.8666666666667 90 0], ...
    'Name', 'Roundabout2');

actor(scenario, ...
    'ClassID', 7, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [17.3 56.5 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Stop Sign');

actor(scenario, ...
    'ClassID', 7, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [32.2333333333333 54.4 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Stop Sign2');

actor(scenario, ...
    'ClassID', 7, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [32.4 95.4 0], ...
    'Name', 'Stop Sign3');

actor(scenario, ...
    'ClassID', 7, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [18.2666666666667 99 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Stop Sign4');

actor(scenario, ...
    'ClassID', 7, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [33.8333333333333 108.8 0], ...
    'PlotColor', [0.635 0.078 0.184], ...
    'Name', 'Stop Sign5');

actor(scenario, ...
    'ClassID', 9, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-67.94 -24.74 0], ...
    'PlotColor', [0.301 0.745 0.933], ...
    'Name', 'Roundabout3');

actor(scenario, ...
    'ClassID', 9, ...
    'Length', 1, ...
    'Width', 1, ...
    'Height', 1, ...
    'Position', [-76.4033333333333 -16.32 0], ...
    'PlotColor', [0.301 0.745 0.933], ...
    'Name', 'Roundabout4');

car4 = vehicle(scenario, ...
    'ClassID', 1, ...
    'Position', [-30.4485315326727 -27.0080041713684 0.01], ...
    'Mesh', driving.scenario.carMesh, ...
    'PlotColor', [255 105 41] / 255, ...
    'Name', 'Car4');
waypoints = [-30.4485315326727 -27.0080041713684 0.01;
    -30.4 -18.8 0;
    -30.5 -12.6 0;
    -30.8 -6.3 0;
    -30.9 -3.4 0;
    -30.9 1.3 0;
    -30.7 12.3 0;
    -30.7 24 0;
    -30.81 35.31 0.01;
    -30.87 45.99 0.01;
    -30.93 53.46 0.01];
speed = [5;5;5;0;5;5;5;5;5;5;5];
waittime = [0;0;0;5;0;0;0;0;0;0;0];
trajectory(car4, waypoints, speed, waittime);

pedestrian = actor(scenario, ...
    'ClassID', 4, ...
    'Length', 0.24, ...
    'Width', 0.45, ...
    'Height', 1.7, ...
    'Position', [19.27 57.73 0], ...
    'RCSPattern', [-8 -8;-8 -8], ...
    'Mesh', driving.scenario.pedestrianMesh, ...
    'PlotColor', [0.85 0.325 0.098], ...
    'Name', 'Pedestrian');
waypoints = [19.27 57.73 0;
    18.49 59.11 0.01;
    17.99 59.86 0.01;
    15.18 64.92 0];
speed = [1.5;1.5;0;3];
waittime = [0;0;28;0];
trajectory(pedestrian, waypoints, speed, waittime);

function output = getDetectorOutput(sensor)

if isa(sensor, 'visionDetectionGenerator')
    output = sensor.DetectorOutput;
elseif isa(sensor, 'lidarPointCloudGenerator')
    output = 'PointCloud';
elseif isa(sensor, 'insSensor')
    output = 'INSMeasurement';
else
    output = 'Objects only';
end

