classdef (Hidden, StrictDefaults) INSSENSORBase < matlab.System
%INSSENSORBase - Base class for insSensor
%
%   This class is for internal use only. It may be removed in the future.

%   Copyright 2017-2020 The MathWorks, Inc.
    
%#codegen
    
    properties
        % RollAccuracy Roll accuracy (deg)
        % Roll is defined as a rotation around the x-axis. Roll noise is 
        % modeled as a white noise process. Specify the standard deviation 
        % of the noise in the roll measurement as a real nonnegative 
        % scalar. This property is tunable. The default value is 0.2.
        RollAccuracy = 0.2;
        % PitchAccuracy Pitch accuracy (deg)
        % Pitch is defined as a rotation around the y-axis. Pitch noise is 
        % modeled as a white noise process. Specify the standard deviation 
        % of the noise in the pitch measurement as a real nonnegative 
        % scalar. This property is tunable. The default value is 0.2.
        PitchAccuracy = 0.2;
        % YawAccuracy Yaw accuracy (deg)
        % Yaw is defined as a rotation around the z-axis. Yaw noise is 
        % modeled as a white noise process. Specify the standard deviation 
        % of the noise in the yaw measurement as a real nonnegative scalar.
        % This property is tunable. The default value is 1.
        YawAccuracy = 1;
    end
    
    properties (Abstract)
        PositionAccuracy;
    end
    
    properties
        % VelocityAccuracy Velocity accuracy (m/s)
        % Velocity noise is modeled as a white noise process. Specify the 
        % standard deviation of the noise in the velocity measurement as a 
        % real nonnegative scalar. This property is tunable. The default 
        % value is 0.05.
        VelocityAccuracy = 0.05;
    end
    
    properties (Nontunable)
        % RandomStream Random number source
        % Specify the source of the random number stream as one of the
        % following:
        %
        % 'Global stream' - Random numbers are generated using the current
        %     global random number stream.
        % 'mt19937ar with seed' - Random numbers are generated using the
        %     mt19937ar algorithm with the seed specified by the Seed 
        %     property.
        %
        % The default value is 'Global stream'.
        RandomStream = 'Global stream';
        
        % Seed Initial seed
        % Specify the initial seed of an mt19937ar random number generator
        % algorithm as a real, nonnegative integer scalar. This property
        % applies when you set the RandomStream property to
        % 'mt19937ar with seed'. The default value is 67.
        Seed = uint32(67);
    end
    
    properties (Constant, Hidden)
        RandomStreamSet = matlab.system.StringSet({...
            'Global stream', ...
            'mt19937ar with seed'});
    end
    
    properties (Access = private)
        % Random stream object (used in 'mt19937ar with seed' mode).
        pStream;
        % Random number generator state.
        pStreamState;
    end
    
    properties (Access = protected, Nontunable)
        pDataType;
    end
    
    methods
        function set.RollAccuracy(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','scalar','nonnegative','finite'}, ...
                '', ...
                'RollAccuracy');
            obj.RollAccuracy = val;
        end
        
        function set.PitchAccuracy(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','scalar','nonnegative','finite'}, ...
                '', ...
                'PitchAccuracy');
            obj.PitchAccuracy = val;
        end
        
        function set.YawAccuracy(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','scalar','nonnegative','finite'}, ...
                '', ...
                'YawAccuracy');
            obj.YawAccuracy = val;
        end
        
        function set.VelocityAccuracy(obj, val)
            validateattributes(val, {'double','single'}, ...
                {'real','scalar','nonnegative','finite'}, ...
                '', ...
                'VelocityAccuracy');
            obj.VelocityAccuracy = val;
        end
        
        function set.Seed(obj, val)
            validateattributes(val,{'numeric'}, ...
                {'real','scalar','integer','>=',0,'<',2^32}, ...
                '', ...
                'Seed');
            obj.Seed = uint32(val);
        end
    end
    
    methods (Access = protected)
        function setupImpl(obj, in)
            obj.pDataType = ...
                fusion.internal.InputValidator.validateFieldOrVariableDataType(in, 'Position');
            
            setupRandomStream(obj);
        end
        
        function setupRandomStream(obj)
            % Setup Random Stream object if required.
            if strcmp(obj.RandomStream, 'mt19937ar with seed')
                if isempty(coder.target)
                    obj.pStream = RandStream('mt19937ar', 'seed', obj.Seed);
                else
                    obj.pStream = coder.internal.RandStream('mt19937ar', 'seed', obj.Seed);
                end
            end
        end
        
        function out = stepImpl(obj, in)
            fusion.internal.InputValidator.validateFieldsOrVariables( ...
                in, obj.pDataType, {'Orientation', 'Position', 'Velocity'});
            
            numSamples = size(in.Position, 1);
            out.Orientation = in.Orientation;
            out.Position = in.Position;
            out.Velocity = in.Velocity;
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
            end
        end

        function orientation = outputOrientation(obj, numSamples, att)
            dataType = obj.pDataType;
            rpyStd = cast([obj.RollAccuracy, obj.PitchAccuracy, obj.YawAccuracy], dataType);
            rpyStd = deg2rad(rpyStd);
            randNums = stepRandomStream(obj, numSamples, 3);
            rotVecErr = bsxfun(@times, randNums, rpyStd);
            quatErr = quaternion(rotVecErr, 'rotvec');
            
            % Quaternion
            if isa(att, 'quaternion')
                orientation = att .* quatErr;
            % Rotation matrix
            elseif (size(att, 1) == 3) && (size(att, 3) == numSamples)
                rotmatErr = rotmat(quatErr, 'frame');
                orientation = zeros(size(rotmatErr), dataType);
                for i = 1:numSamples
                    orientation(:,:,i) = rotmatErr(:,:,i) * att(:,:,i);
                end
            % [roll, pitch, yaw]
            else
                q = quaternion(att, 'eulerd', 'ZYX', 'frame') .* quatErr;
                orientation = eulerd(q, 'ZYX', 'frame');
            end
        end

        function outPos = outputPosition(obj, numSamples, pos)
            posAcc = cast(obj.PositionAccuracy, obj.pDataType);
            outPos = pos + posAcc .* stepRandomStream(obj, numSamples, 3);
        end
        
        function outVel = outputVelocity(obj, numSamples, vel)
            velAcc = cast(obj.VelocityAccuracy, obj.pDataType);
            outVel = vel + velAcc .* stepRandomStream(obj, numSamples, 3);
        end
        
        function whiteNoise = stepRandomStream(obj, numSamples, numChannels)
            dataType = obj.pDataType;
            % Noise (random number) generation.
            if strcmp(obj.RandomStream, 'Global stream')
                whiteNoise = randn(numSamples, numChannels, dataType);
            else
                whiteNoise = randn(obj.pStream, numSamples, numChannels, dataType);
            end 
        end
        
        function resetImpl(obj)
            resetRandomStream(obj);
        end
        
        function resetRandomStream(obj)
            if strcmp(obj.RandomStream, 'mt19937ar with seed')
                obj.pStream.reset;
            end
        end
        
        function flag = isInactivePropertyImpl(obj, prop)
            flag = false;
            if strcmp(prop, 'Seed')
                if strcmp(obj.RandomStream, 'Global stream')
                    flag = true;
                end
            end
        end
        
        function s = saveObjectImpl(obj)
            % Save public properties.
            s = saveObjectImpl@matlab.System(obj);
            
            % Save private properties.
            if isLocked(obj)
                s.pDataType = obj.pDataType;
                
                if strcmp(obj.RandomStream, 'mt19937ar with seed')
                    if ~isempty(obj.pStream)
                        s.pStreamState = obj.pStream.State;
                    end
                end
            end
        end
        
        function loadObjectImpl(obj, s, wasLocked)
            % Load public properties.
            loadObjectImpl@matlab.System(obj, s, wasLocked);
            
            % Load private properties.
            if wasLocked
                obj.pDataType = s.pDataType;
                
                if strcmp(s.RandomStream, 'mt19937ar with seed')
                    obj.pStream = RandStream('mt19937ar', ...
                        'seed', obj.Seed);
                    if ~isempty(s.pStreamState)
                        obj.pStream.State = s.pStreamState;
                    end
                end
            end
        end
    end
end
