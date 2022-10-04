% This function helps plot the sensor converages, chase plot, and scenario
% plot with traffic lights and signs

function PlotterHelper(scenario,sensors,planner_wpts,ptLabels,EgoWayPts,ego)
restart(scenario);

hFigure2= figure;
hAxes1 = axes('Parent',hFigure2);

%% Sensor Coverages Plot
bep = birdsEyePlot('XLim',[0 150],'YLim',[-50 50],'Parent',hAxes1);
for i=1:length(sensors)
    if(isa(sensors{i},'visionDetectionGenerator'))
        cp = coverageAreaPlotter(bep,'DisplayName','Vision coverage area','FaceColor','blue','EdgeColor','blue');
        plotCoverageArea(cp, sensors{i}.SensorLocation,...
            sensors{i}.MaxRange, sensors{i}.Yaw, sensors{i}.FieldOfView(1));
        
    elseif(isa(sensors{i},'drivingRadarDataGenerator'))
        cp = coverageAreaPlotter(bep,'DisplayName','Radar coverage area','FaceColor','red','EdgeColor','red');
        plotCoverageArea(cp, sensors{i}.MountingLocation(1:2),...
            sensors{i}.RangeLimits(2), sensors{i}.MountingAngles(3), sensors{i}.FieldOfView(1));
    end
    %pause(0.1);
    hold on;
end
title('Sensor Coverages');
pause(1);

hFigure = figure;

hFigure.Position = [20,100,1200,500];

%hPanel1 = uipanel(hFigure,'Units','Normalized','Position',[0 0.45 1/2 0.55],'Title','Sensor Configurations');
hPanel2 = uipanel(hFigure,'Units','Normalized','Position',[0 0 1/2 1],'Title','Chase Plot');
hPanel3 = uipanel(hFigure,'Units','Normalized','Position',[1/2 0 1/2 1],'Title','Birds Eye View');

hAxes3 = axes('Parent',hPanel3);
hAxes2 = axes('Parent',hPanel2);


%% Birds Eye Plot with waypoints
plot(scenario, 'Parent', hAxes3); hold on;
scatter(planner_wpts(:,1),planner_wpts(:,2),'or','filled');
% text(planner_wpts(:,1)+2, planner_wpts(:,2)+2, ptLabels);
plot(EgoWayPts(:,1),EgoWayPts(:,2),'-b','Parent',hAxes3);


%% Chase plot
chasePlot(scenario.Actors(1,ego),'Centerline','on','Parent',hAxes2);

while advance(scenario)
    pause(0.01);
end

close(hFigure);
close(hFigure2);
end