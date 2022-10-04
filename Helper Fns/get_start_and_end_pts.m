% This function lets you select start and ending waypoints in your
% scenario and returns the points
function [planner_wpts,ptLabels] = get_start_and_end_pts(scenario,num_of_wpts)
rbScenario = roadBoundaries(scenario);
bep = birdsEyePlot;
lbp = laneBoundaryPlotter(bep,'DisplayName','Road boundaries');
plotLaneBoundary(lbp,rbScenario);
%view([0 90]) ;
planner_wpts=[]; ptLabels=[];
% Prompt={'Label this location'};
labels = {'TrafficLight','StopSign','RailRoadCrossing','RoundAbout'};
for i=1:num_of_wpts
    pt=drawpoint;
    planner_wpts=[planner_wpts;pt.Position];
%     pt.Label = inputdlg(Prompt,'ROI Label');
    [indx,tf] = listdlg('ListString',labels,'SelectionMode','single');
    pt.Label = labels{indx};
    ptLabels=[ptLabels;indx];
end


