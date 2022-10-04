
classdef TL_vis < matlab.System 
    %HelperTrafficLightNegotiationVisualization Visualization helper class.
    %   This is a helper class which plots the run time simulation result
    %   for the traffic light negotiation example.
    
    % NOTE: The name of this System Object and its functionality may
    % change without notice in a future release,
    % or the System Object itself may be removed.
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties(Access = private)
        %Figure Store the figure handle.
        Figure;
        
        %AxesHandle.
        AxesHandle;
        
        %Scenario Store scenario variable from the workspace.
        Scenario;
        
        %TrafficLightGraphicObjects Store graphic objects to change marker
        %face color.
        TrafficLightGraphicObjects = [];
        StopSignGraphicObjects = [];
    end
    
    methods(Access = protected)
        %------------------------------------------------------------------
        function setupImpl(obj,varargin) %#codegen
            %setupImpl Perform one-time calculations.
            figureName = 'Traffic Light Negotiation';
            obj.Figure = findobj('Type','Figure','Name',figureName);
            
            % create the figure only if it is not already open.
            if isempty(obj.Figure)
                obj.Figure = figure('Name',figureName);
                obj.Figure.NumberTitle = 'off';
                obj.Figure.MenuBar = 'none';
                obj.Figure.ToolBar = 'none';
            end
            
            % Clear figure.
            clf(obj.Figure);
            obj.AxesHandle = axes(obj.Figure);
            
            % Get the scenario object from the base workspace.
            obj.Scenario = evalin('base', 'scenario');
            
            % Plot the scenario.
            plot(obj.Scenario,'Parent',obj.AxesHandle,'RoadCenters',...
                'off','Centerline','off');
            hold on;
            
            
            
            % preallocate an array to store graphics handles.
            TLn=evalin('base', 'TL_ID');
            SSn=evalin('base','stopSign_ID');
           
            obj.TrafficLightGraphicObjects = gobjects(length(TLn),1);
            obj.StopSignGraphicObjects = gobjects(length(SSn),1);

            
%             % Plot traffic light sensor positions.
%             for i=1:size(trafficLightPositions)
%                 
%                 obj.TrafficLightGraphicObjects(i) = plot(trafficLightPositions(i,1),trafficLightPositions(i,2), ...
%                     'Marker','^','MarkerFaceColor','r','MarkerSize',8,...
%                     'Parent',obj.AxesHandle);
%                 
%             end

            % set current figure handle position.
            set(gcf, 'Position', [1 1 800 600]);
            
            % Add legend information.
            f=get(gca,'Children');
            
            

            
             
            

        end
        
        %------------------------------------------------------------------
        function stepImpl(obj,TL,...
                targetPoses, egoInfo,SS)
            %stepImpl Implements the main logic that updates the plot with
            %   new actor positions and traffic light states for all
            %   traffic lights.

            % Get the number of actors along with ego vehicle.
            numActors = targetPoses.NumActors + 1;
            
%             % Update ego position and yaw.
            obj.Scenario.Actors(1).Position = egoInfo.Position;
            obj.Scenario.Actors(1).Yaw = egoInfo.Yaw;
            
            % Update other vehicle positions in the scenario.
            for n = 2:numActors
                obj.Scenario.Actors(n).Position = ...
                    targetPoses.Actors(n-1).Position;
                obj.Scenario.Actors(n).Yaw   = targetPoses.Actors(n-1).Yaw;
            end
            
            if (isvalid(obj.AxesHandle))
                            
                 for i=1:height(TL)
                    
                    obj.TrafficLightGraphicObjects(i,1) = plot(TL(i,1),TL(i,2), 'Marker','o','MarkerFaceColor','r','MarkerEdgeColor','r','MarkerSize',7,'Parent',obj.AxesHandle,'DisplayName','TL');
                 end
                 
                 for i=1:height(SS)
                     if(isnan(SS))
                         break;
                     else
                         obj.StopSignGraphicObjects(i,1) = plot([nsidedpoly(8,'Center',[SS(i,1) SS(i,2)],'SideLength',0.7)],'Parent',obj.AxesHandle,'FaceColor','red','FaceAlpha',1,'DisplayName','StopSign');
                         text(SS(i,1)+2,SS(i,2)+1, 'STOP');
                     end
                 end
                    


                 for i = 1:size(obj.TrafficLightGraphicObjects)
                    switch(TL(i,4))
                        case 1
                            % Set the marker color to red.
                            obj.TrafficLightGraphicObjects(i,1).MarkerFaceColor = 'r';
                            obj.TrafficLightGraphicObjects(i,1).MarkerEdgeColor = 'r';
                        case 2
                            % Set the marker color to yellow.
                            obj.TrafficLightGraphicObjects(i,1).MarkerFaceColor = 'y';
                            obj.TrafficLightGraphicObjects(i,1).MarkerEdgeColor = 'y';
                        case 3
                            % Set the marker color to green.
                            obj.TrafficLightGraphicObjects(i,1).MarkerFaceColor = 'g';
                            obj.TrafficLightGraphicObjects(i,1).MarkerEdgeColor = 'g';
                        otherwise
                            % Set the marker color to black.
                            obj.TrafficLightGraphicObjects(i,1).MarkerFaceColor = 'k';
                            obj.TrafficLightGraphicObjects(i,1).MarkerEdgeColor = 'k';
                    end
                 end
                    
                    

                    
             end
                
                % update existing scenario plot.
                updatePlots(obj.Scenario); pause(0.1);
                
                % limits the number of updates to 20 frames per second.
                drawnow limitrate
                
            end
        end
    
    
    methods(Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog.
            simMode = "Interpreted execution";
        end
        
        function flag = showSimulateUsingImpl
            % Return false if simulation mode hidden in System block
            % dialog.
            flag = false;
        end
        
        function [name1,name5,name6,name7] = getInputNamesImpl(~)
            % Return input port names for System block.
            name1 = 'TL';
            name5 = 'TargetPoses';
            name6 = 'EgoInfo';
            name7 = 'SS';
           
            
        end
    end
    
end
