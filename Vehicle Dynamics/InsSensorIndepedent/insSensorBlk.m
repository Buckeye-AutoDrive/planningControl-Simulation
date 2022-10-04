classdef insSensorBlk < matlab.System
    % insSensor Inertial navigation and GPS simulation model
    %
    % This template includes the minimum set of functions required
    % to define a System object with discrete state.

    % Public, tunable properties
    properties (Nontunable)
        % Mounting Location (m)
        MountingLocation = [1.9 0 0];
        % Roll Accuracy (deg)
        RollAccuracy     = 0.2;
        % Pitch Accuracy (deg)
        PitchAccuracy    = 0.2;
        % Yaw Accuracy (deg)
        YawAccuracy      = 1;
        % Position Accuracy (m)
        PositionAccuracy = [1 1 1];
        % Velocity Accuracy (m/s)
        VelocityAccuracy = 0.05;
        % Acceleration Accuracy (m/s^2)
        AccelerationAccuracy = 0;
        % Angular Velocity Accuracy (deg/s)
        AngularVelocityAccuracy = 0;
        % Position error factor without GNSS fix
        PositionErrorFactor = [0 0 0];
        % Output Bus Name
        OutputBusName1 = 'BusActorState';
    end

    properties(DiscreteState)

    end

    % Pre-computed constants
    properties(Access = private)
        insSensorObj
    end

    methods(Access = protected)
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            obj.insSensorObj = insSensor('TimeInput', true, ...
            'MountingLocation', obj.MountingLocation,'RollAccuracy',obj.RollAccuracy,...
            'PitchAccuracy',obj.PitchAccuracy,'YawAccuracy',obj.YawAccuracy,...
            'PositionAccuracy',obj.PositionAccuracy,'VelocityAccuracy',obj.VelocityAccuracy,...
            'AccelerationAccuracy',obj.AccelerationAccuracy,'AngularVelocityAccuracy',obj.AngularVelocityAccuracy,...
            'PositionErrorFactor',obj.PositionErrorFactor);
        end

        function insMeas = stepImpl(obj,ActorStateIn)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            ActorState.Orientation = [ActorStateIn.Roll ActorStateIn.Pitch ActorStateIn.Yaw];
            ActorState.Position = ActorStateIn.Position;
            ActorState.Velocity = ActorStateIn.Velocity;
            ActorState.AngularVelocity = ActorStateIn.AngularVelocity;
            ActorState.Acceleration = ActorStateIn.Acceleration;
            time = getCurrentTime(obj);
            insMeas = obj.insSensorObj(ActorState, time);
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties
        end
        
        function [out1] = getOutputSizeImpl(obj)
            % Return size for each output port
            out1 = [1 1];
            % Example: inherit size from first input port
            % out = propagatedInputSize(obj,1);
        end

        function [out1] = getOutputDataTypeImpl(obj)
            % Return data type for each output port
            out1 = obj.OutputBusName1;
            % Example: inherit data type from first input port
            % out = propagatedInputDataType(obj,1);
        end

        function [out1] = isOutputComplexImpl(obj)
            % Return true for each output port with complex data
            out1 = false;
            % Example: inherit complexity from first input port
            % out = propagatedInputComplexity(obj,1);
        end

        function [out1] = isOutputFixedSizeImpl(obj)
            % Return true for each output port with fixed size
            out1 = true;
            % Example: inherit fixed-size status from first input port
            % out = propagatedInputFixedSize(obj,1);
        end
    end
end
