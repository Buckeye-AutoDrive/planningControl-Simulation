classdef (Hidden) InputValidator
%   Internal class used to validate struct or timetable inputs.
%
%   This class is for internal use only. It may be removed in the future.

%   Copyright 2017-2020 The MathWorks, Inc.

%#codegen
    
    methods (Static)
        function numSamples = validateFieldsOrVariables(in, expectedDataType, expectedNames)
            % Checks that input in has fields/variables expectedNames with
            % data of type expectedDataType.
            % 
            % The struct field/variable 'Orientation' is expected to be a
            % quaternion, rotation matrix array, or array of [roll, pitch,
            % yaw] vectors.
            % All other fields/variables are expected to have 3 columns. 
            numSamples = -1;
            if strcmp(expectedNames{1}, 'Orientation')
                iters = numel(expectedNames):-1:1;
            else
                iters = 1:numel(expectedNames);
            end
            for i = iters
                field = expectedNames{i};
                InputValidator.verifyFieldOrVariableExists(in, field);
%                 fusion.internal.InputValidator.verifyFieldOrVariableExists(in, field);
                val = in.(field);

                if strcmp(field, 'Orientation')
                    if isa(val, 'quaternion')
                        fusion.internal.InputValidator.validateQuaternion(val, expectedDataType);
                        rowIdx = 1;
                    else
                        validateattributes(val, {expectedDataType}, ...
                            {'real', 'finite'}, '', field);
                        if (size(val, 1) == 3) && (size(val, 3) == numSamples)
                            validateattributes(val, {expectedDataType}, ...
                                {'real', 'finite', '3d', 'size', [3 3 NaN]}, '', field);
                            rowIdx = 3;
                        else
                            validateattributes(val, {expectedDataType}, ...
                                {'real', 'finite', '2d', 'size', [NaN 3]}, '', field);
                            rowIdx = 1;
                        end
                    end
                else
                    validateattributes(val, {expectedDataType}, ...
                        {'real', 'finite', '2d', 'ncols', 3}, '', field);
                    rowIdx = 1;
                end
                if numSamples >= 0
                    coder.internal.errorIf(size(val, rowIdx) ~= numSamples, ...
                        'shared_fusionutils:internal:InputValidator:incorrectNumrows', field, class(val), numSamples);
                else
                    numSamples = size(val, rowIdx);
                end
            end
        end
        
        function dataType = validateFieldOrVariableDataType(in, name)
            % Checks that input field/variable name is a single or double. 
            InputValidator.verifyFieldOrVariableExists(in, name);
            validateattributes(in.(name), {'single', 'double'}, {}, '', name);
            dataType = class(in.(name));
        end
    end
    
    methods (Static, Access = private)
        function verifyFieldOrVariableExists(in, name)
            % Private helper method used to check the existence of a 
            % field/variable. 
            if isa(in, 'struct') && isscalar(in)
                noField = ~isfield(in, name);
                coder.internal.errorIf(noField, ...
                    'shared_fusionutils:internal:InputValidator:expectedField', name);
            elseif isa(in, 'timetable')
                varNames = in.Properties.VariableNames;
                noVar = all(~strcmp(name, varNames));
                coder.internal.errorIf(noVar, ...
                    'shared_fusionutils:internal:InputValidator:expectedVariable', name, 'VariableNames');
            else
                error(message('shared_fusionutils:internal:InputValidator:StructOrTimeTable'));
            end
        end

        function validateQuaternion(q, expectedDataType)
            % Private helper method used to validate a quaternion input. 
            coder.internal.errorIf(~isa(q, 'quaternion'), ...
                'shared_fusionutils:internal:InputValidator:invalidType', 'Orientation', 'quaternion');
            coder.internal.errorIf(~strcmp(classUnderlying(q), expectedDataType), ...
                'shared_fusionutils:internal:InputValidator:invalidUnderlyingType', expectedDataType, classUnderlying(q));
            [w,x,y,z] = parts(q);
            validateattributes([w x y z], {expectedDataType}, {'finite', '2d'}, '', 'Orientation');
            coder.internal.errorIf(size(q, 2) ~= 1, ...
                'shared_fusionutils:internal:InputValidator:incorrectNumcols', 'Orientation', 'quaternion');
        end
    end
end
