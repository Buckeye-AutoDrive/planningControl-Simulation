function scenario = helperOSMImport(bbox)
% Specify the Geometric Bounding Box Coordinates

% Origin 42.299847, -83.698854 to match Mcity game origin
originLat = 42.299847;
originLon = -83.698854;

%Bounding box latitude and longitude limets
minLat =  bbox(1,1);
maxLat =  bbox(1,2);
minLon = bbox(2,1);
maxLon = bbox(2,2);

% Fetch the OpenStreetMap XML
url = ['https://api.openstreetmap.org/api/0.6/map?bbox=' ...
    num2str(minLon) ',' num2str(minLat) ',' ...
    num2str(maxLon) ',' num2str(maxLat)];
fileName = websave('drive_map.osm', url,weboptions('ContentType', 'xml'));

% Create a driving scenario
importedScenario = drivingScenario;
% Import the OpenStreetMap Roadnetwork
roadNetwork(importedScenario, 'OpenStreetMap', fileName);

% Transform centroid of Bounding box into local Cartesian Coordinates
[tX,tY,tZ] = latlon2local(originLat, originLon,...
    0, importedScenario.GeoReference);

% Map the fetched scenario into a new scenario with Shifted RoadCenters as
% per the Bounding Box Centroid
scenario = drivingScenario;
hist = importedScenario.RoadHistory;

for indx = 1 : size(hist, 2)
    % Skipping "Access drive" road from Mcity map
    if (hist{1,indx}{1,6}=="Access Drive")
        continue;
    end
    
    % Fetching Road Centers
    roadCenters = hist{1,indx}{1,2};
    roadCenters = translate(roadCenters, tX, tY, tZ);
    % Translating the map to desired origin
    road(scenario, roadCenters,...
        'Lanes', hist{1,indx}{1,5},...
        'Name',hist{1,indx}{1,6});
end
scenario.VerticalAxis = 'Y';
end

function shiftedRoadCenters = translate(roadCenters,x1,y1,z1)
% This function translates the roadcenters as per the passed local
% coordinates
x = roadCenters(:,1);
y = roadCenters(:,2);
z = roadCenters(:,3);
x = x - x1;
y = y - y1;
z = z - z1;
shiftedRoadCenters = [x y z];
end
