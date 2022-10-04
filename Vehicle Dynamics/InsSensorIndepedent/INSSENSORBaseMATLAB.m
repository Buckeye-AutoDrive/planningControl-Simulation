classdef (Hidden, StrictDefaults) INSSENSORBaseMATLAB < INSSENSORBase
%INSSENSORBaseMATLAB - Base class for insSensor MATLAB System Object
%
%   This class is for internal use only. It may be removed in the future.

%   Copyright 2020 The MathWorks, Inc.
    
%#codegen
    
    properties (Nontunable)
        % MountingLocation Mounting location (m)
        % A 3-element vector defining the offset of the sensor's origin
        % from the origin of its platform in meters. The default value is
        % [0 0 0].
        MountingLocation = [0 0 0];
    end
    
    properties
        % PositionAccuracy Position accuracy (m)
        % Position noise is modeled as a white noise process. Specify the
        % standard deviation of the noise in the position measurement as a
        % real nonnegative scalar or 3-element vector. This property is
        % tunable. The default value is [1 1 1].
        PositionAccuracy = [1 1 1];
        % AccelerationAccuracy Acceleration accuracy (m/s^2)
        % Acceleration noise is modeled as a white noise process. Specify
        % the standard deviation of the noise in the acceleration
        % measurement as a real nonnegative scalar. This property is
        % tunable. The default value is 0.
        AccelerationAccuracy = 0;
        % AngularVelocityAccuracy Angular velocity accuracy (deg/s)
        % Angular velocity noise is modeled as a white noise process.
        % Specify the standard deviation of the noise in the angular
        % velocity measurement as a real nonnegative scalar. This property
        % is tunable. The default value is 0.
        AngularVelocityAccuracy = 0;
    end
    
    properties (Nontunable)
        % TimeInput Enable input of simulation time
        % Set this property to true to enable simulation time input. The
        % default value is false.
        TimeInput (1,1) logical = false;
    end
    
    properties
        % HasGNSSFix Enable/disable GNSS fix
        % Set this property to false to simulate a loss of a GNSS receiver
        % fix. This property is tunable. The default value is true.
        HasGNSSFix (1,1) logical = true;
        % PositionErrorFactor Error factor affecting location computations when GNSS fix is lost
        % When HasGNSSFix property is set to false, the position error
        % grows at a quadratic rate due to constant bias in accelerometer
        % output. The following expression describes the error: E(t) =
        % PositionErrorFactor*t^2/2, where t is the time since the GNSS fix
        % was lost. t is computed based on the simTime input to the 
        % object's step() function. E(t) is added to the X, Y, and Z 
        % components of the Position ground truth input. 
        % Specify PositionErrorFactor as a scalar or a 1-by-3 element 
        % vector. This property is tunable. The default value is [0 0 0].
        PositionErrorFactor (1,3) = [0 0 0];
    end
    
    properties (Access = private)
        % Current time for TimeInput mode.
        pCurrTime;
        % Time when GNSS fix was lost.
        pLostGNSSStartTime;
    end
    
    properties (Access = private, Nontunable)
        pInStructFields;
    end
    
    methods
        function set.MountingLocation(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real', 'vector', 'numel', 3, 'finite'}, ...
                '', ...
                'MountingLocation');
            obj.MountingLocation = val(:).';
        end
        
        function set.PositionAccuracy(obj, inVal)
            if isa(inVal, 'numeric') && isscalar(inVal)
                val = [inVal inVal inVal];
            else
                val = inVal;
            end
            validateattributes(val, {'double','single'}, ...
                {'real','nonnegative','finite', 'vector', 'numel', 3}, ...
                '', ...
                'PositionAccuracy');
            obj.PositionAccuracy(:) = val(:);
        end
        
        function set.AccelerationAccuracy(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','scalar','nonnegative','finite'}, ...
                '', ...
                'AccelerationAccuracy');
            obj.AccelerationAccuracy = val;
        end
        
        function set.AngularVelocityAccuracy(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','scalar','nonnegative','finite'}, ...
                '', ...
                'AngularVelocityAccuracy');
            obj.AngularVelocityAccuracy = val;
        end
        
        function set.HasGNSSFix(obj, val)
            oldVal = obj.HasGNSSFix;
            obj.HasGNSSFix = val;
            
            gnssFixLost = ~val && oldVal;
            if gnssFixLost && obj.TimeInput %#ok<MCSUP>
                obj.pLostGNSSStartTime = obj.pCurrTime; %#ok<MCSUP>
            end
        end
        
        function set.PositionErrorFactor(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','finite'}, ...
                '', ...
                'PositionErrorFactor');
            obj.PositionErrorFactor = val;
        end
    end
    
    methods (Access = protected)
        function numIn = getNumInputsImpl(obj)
            if (~obj.TimeInput)
                numIn = 1;
            else
                numIn = 2;
            end
        end
        
        function setupImpl(obj, in)
            setupImpl@INSSENSORBase(obj, in);
%             setupImpl@fusion.internal.INSSENSORBase(obj, in);
            obj.pDataType = ...
                InputValidator.validateFieldOrVariableDataType(in, ...
                'Position');
%                 fusion.internal.InputValidator.validateFieldOrVariableDataType(in, ...
%                 'Position');
            if (numel(fieldnames(in)) > 3)
                obj.pInStructFields = {'Position', 'Orientation', ...
                    'Velocity', 'Acceleration', 'AngularVelocity'};
            else
                obj.pInStructFields = {'Position', 'Orientation', 'Velocity'};
            end
        end
        
        function out = stepImpl(obj, varargin)
            in = varargin{1};
%             fusion.internal.InputValidator.validateFieldsOrVariables( ...
%                 in, obj.pDataType, obj.pInStructFields);
            InputValidator.validateFieldsOrVariables( ...
                in, obj.pDataType, obj.pInStructFields);
            in = applyMountingLocation(obj, in);
            if (~obj.TimeInput)
                out = stepNoTime(obj, in);
            else
                out = stepWithTime(obj, in, varargin{2});
            end
        end
        
        function out = stepNoTime(obj, in)
            numSamples = size(in.Position, 1);
            numFields = numel(obj.pInStructFields);
            out.Orientation = in.Orientation;
            out.Position = in.Position;
            out.Velocity = in.Velocity;
            if (numFields == 5)
                out.Acceleration = in.Acceleration;
                out.AngularVelocity = in.AngularVelocity;
            end
            for i = 1:numSamples
                % Quaternion
                if isa(in.Orientation, 'quaternion')
                    out.Orientation(i,:) = outputOrientation(obj, 1, in.Orientation(i,:));
                % Rotation matrix
                elseif (size(in.Orientation, 1) == 3) && (size(in.Orientation, 3) == numSamples)
                    out.Orientation(:,:,i) = outputOrientation(obj, 1, in.Orientation(:,:,i));
                % [roll, pitch, yaw]
                else
                    out.Orientation(i,:) = outputOrientation(obj, 1, in.Orientation(i,:));
                end
                out.Position(i,:) = outputPosition(obj, 1, in.Position(i,:));
                out.Velocity(i,:) = outputVelocity(obj, 1, in.Velocity(i,:));
                if (numFields == 5)
                    out.Acceleration(i,:) = outputAcceleration(obj, 1, in.Acceleration(i,:));
                    out.AngularVelocity(i,:) = outputAngularVelocity(obj, 1, in.AngularVelocity(i,:));
                end 
            end
        end
        
        function out = stepWithTime(obj, in, t)
            validateattributes(t, {'double', 'single'}, ...
                {'real', 'nonnegative', 'finite', 'vector', 'numel', size(in.Position,1)}, '', 'Time');
            obj.pCurrTime = t(end);
            out = stepNoTime(obj, in);
            
            numSamples = size(out.Position, 1);
            numAxes = size(out.Position, 2);
            if (~obj.HasGNSSFix)
                err = repmat(obj.PositionErrorFactor, numSamples, 1); % Extend to each sample.
                tStart = obj.pLostGNSSStartTime;
                dt = repmat(t - tStart, 1, numAxes); % Extend to each axis.
                velDrift = err .* dt;
                out.Velocity = out.Velocity + velDrift;
                posDrift = velDrift .* (dt/2);
                out.Position = out.Position + posDrift;
            end
        end
        
        function in = applyMountingLocation(obj, in)
            
            % Use equations from |transformMotion| function.
            
            % Get frame transformation.
            posSFromP = obj.MountingLocation;
            
            numSamples = size(in.Position, 1);
            
            % Convert current orientation(s) to quaternion(s).
            % Quaternion
            if isa(in.Orientation, 'quaternion')
                orientPQuat = in.Orientation;
            % Rotation matrix
            elseif (size(in.Orientation, 1) == 3) && (size(in.Orientation, 3) == numSamples)
                orientPQuat = quaternion(in.Orientation, 'rotmat', 'frame');
            % [roll, pitch, yaw]
            else
                orientPQuat = quaternion(in.Orientation, 'eulerd', 'ZYX', 'frame');
            end
            
            % Transform position.
            posP = in.Position;
            posS = posP ...
                + rotatepoint(orientPQuat, posSFromP);
            in.Position = posS;
            
            % Transform acceleration and angular velocity.
            hasAccAndAngvel = (numel(fieldnames(in)) == 5);
            if hasAccAndAngvel
                angvelP = in.AngularVelocity;
                accP = in.Acceleration;
                accS = accP ...
                    + rotatepoint(orientPQuat, crossProduct(angvelP, crossProduct(angvelP, posSFromP)));
                in.Acceleration = accS;
            else
                angvelP = zeros(size(posP));
            end
            
            % Transform velocity.
            velP = in.Velocity;
            velS = velP ...
                + rotatepoint(orientPQuat, crossProduct(angvelP, posSFromP));
            in.Velocity = velS;
        end

        function outPos = outputPosition(obj, numSamples, pos)
            posAccTemplate = cast(obj.PositionAccuracy, obj.pDataType);
            posAcc = repmat(posAccTemplate, numSamples, 1);
            outPos = pos + posAcc .* stepRandomStream(obj, numSamples, 3);
        end
        
        function outAcc = outputAcceleration(obj, numSamples, acc)
            accAcc = cast(obj.AccelerationAccuracy, obj.pDataType);
            outAcc = acc + accAcc .* stepRandomStream(obj, numSamples, 3);
        end
        
        function outAngvel = outputAngularVelocity(obj, numSamples, angvel)
            velAcc = cast(obj.AngularVelocityAccuracy, obj.pDataType);
            outAngvel = angvel + velAcc .* stepRandomStream(obj, numSamples, 3);
        end
        
        function resetImpl(obj)
            resetImpl@INSSENSORBase(obj);
            obj.pCurrTime = 0;
            obj.pLostGNSSStartTime = 0;
        end
        
        function flag = isInactivePropertyImpl(obj, prop)
            flag = false;
            switch prop
                case 'Seed'
                    flag = strcmp(obj.RandomStream, 'Global stream');
                case 'HasGNSSFix'
                    flag = ~obj.TimeInput;
                case 'PositionErrorFactor'
                    flag = ~obj.TimeInput;
            end
        end
        
        function s = saveObjectImpl(obj)
            % Save public properties.
            s = saveObjectImpl@INSSENSORBase(obj);
            
            % Save private properties.
            if isLocked(obj)
                s.pInStructFields = obj.pInStructFields;
                s.pCurrTime = obj.pCurrTime;
                s.pLostGNSSStartTime = obj.pLostGNSSStartTime;
            end
        end
        
        function loadObjectImpl(obj, s, wasLocked)
            % Load public properties.
            loadObjectImpl@INSSENSORBase(obj, s, wasLocked);
            
            % Load private properties.
            if wasLocked
                if isfield(s, 'pInStructFields')
                    obj.pInStructFields = s.pInStructFields;
                else
                    obj.pInStructFields = {'Position', 'Orientation', ...
                        'Velocity'};
                end
                if isfield(s, 'pCurrTime')
                    obj.pCurrTime = s.pCurrTime;
                end
                if isfield(s, 'pLostGNSSStartTime')
                    obj.pLostGNSSStartTime = s.pLostGNSSStartTime;
                end
            end
        end
    end
end

function C = crossProduct(Ain, Bin)
%CROSSPRODUCT Cross product with limited implicit expansion
%   Ain - 1-by-3 or N-by-3 matrix
%   Bin - 1-by-3 or N-by-3 matrix
%
%   C - cross product of A and B, that are the expanded versions of Ain and
%       Bin, respectively.
numA = size(Ain, 1);
numB = size(Bin, 1);
N = max(numA, numB);
expandMat = ones(N, 3);
A = bsxfun(@times, Ain, expandMat);
B = bsxfun(@times, Bin, expandMat);

C = cross(A, B);
end
