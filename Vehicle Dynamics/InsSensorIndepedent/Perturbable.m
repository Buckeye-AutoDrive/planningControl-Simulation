classdef(Hidden, Abstract) Perturbable < handle
    %Perturbable  Defines a perturbable class
    % This abstract class defines the interface of a perturbable class.
    % Inherit from this class and implement the interface to add
    % perturb-ability to your scenario objects.
    %
    % There are no public properties, but you must add a call to
    % saveObjectImpl and loadObjectImpl to access the protected properties
    % that save and load the perturbation definitions.
    %
    % Perturbable methods:
    %   perturbations - Perturbations defined on the object
    %   perturb       - Apply perturbations to the object
    %
    % In addition, you must implement the protected abstract method
    % defaultPerturbations(obj) to get the default list of perturbations.
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    %#codegen
    
    properties(Access = protected)
        pPerturbableProperties
        pPerturbations
        pIntegerProperties
        pFirstCall = true
    end
    
    methods(Abstract, Access=protected)
        perts = defaultPerturbations(obj)
    end
    
    methods(Access = protected)
        function intProps = integerProperties(~)
            %integerProperties Get the list of integer-valued properties
            % The default methods returns an empty list. Overload this
            % method if your object has integer-valued perturbable
            % properties.
            intProps = repmat("",1,0); % An empty array of strings
        end
    end
    
    methods
        function offsets = perturb(obj)
            %PERTURB Apply perturbations to the object
            % OFFSETS = PERTURB(OBJ) apply the perturbations defined for
            % the object. Object properties will be perturbed by an offset
            % as defined in the perturbations. See the perturbations
            % method. OFFSETS is a struct with fields Property and Offset,
            % which provide the offset value in this call to perturb.
            
            % Release a system object if it is locked
            if isa(obj, 'matlab.System')
                release(obj)
            end
            
            % Note: the perturb method assumes that all the properties are
            % public and can be tuned at the time the perturbation is
            % applied. 
            offsets = struct('Property', {}, 'Offset', {}, 'PerturbedValue', {});
            for i = 1:numel(obj.pPerturbations)
                perturbation = obj.pPerturbations(i);
                ofs = offset(obj, perturbation);
                if any(ofs,'all')
                    obj.(perturbation.Property) = obj.(perturbation.Property) + ...
                    ofs;
                    offsets = [offsets; struct(...
                        'Property', perturbation.Property, ...
                        'Offset', ofs, ...
                        'PerturbedValue', obj.(perturbation.Property))]; %#ok<AGROW>
                end
            end
        end
        
        function pertsTable = perturbations(obj, varargin)
            %PERTURBATIONS   Perturbations defined on the object
            % PERTS = PERTURBATIONS(OBJ) returns the list of property
            % perturbations, PERTS, defined for the object, OBJ. By
            % default, this list is populated by all the properties that
            % can be perturbed and each property has the "None"
            % perturbation defined. The latest definition of property
            % perturbation is saved.
            %
            % PERTS = PERTURBATIONS(OBJ, PROP) allows you to view the
            % current perturbation defined for the property, PROP.
            %
            % PERTS = PERTURBATIONS(OBJ, PROP, "None") allows you to define
            % that property PROP should not be perturbed.
            %
            % PERTS = PERTURBATIONS(OBJ, PROP, "Selection", VALUES, PROBS)
            % allows you to specify a set offset values, VALUES, and their
            % respective probabilities, PROBS. VALUES must be a cell
            % {X1,...,Xn}, where the X values are valid values for the
            % property PROP. PROBS must be an array [p1,...,pn], where
            % sum([p1,...,pn]) is normalized to 1. The offset value is then
            % drawn from the set of values with the probability defined. If
            % PROBS is not provided, selection is done with equal
            % probability for each value.
            %
            % PERTS = PERTURBATIONS(OBJ, PROP, "Normal", MEAN, SIGMA)
            % allows you to specify that the offset is drawn with a normal
            % distribution defined by the mean, MEAN, and standard
            % deviation, SIGMA.
            %
            % PERTS = PERTURBATIONS(OBJ, PROP, "Uniform", MINVAL, MAXVAL)
            % allows you to specify that the offset is drawn with a uniform
            % distribution from a range defined by the interval
            % [MINVAL,MAXVAL].
            %
            % PERTS = PERTURBATIONS(OBJ, PROP, "Custom", FCN) allows you to
            % define a custom function, FCN, that draws the offset value.
            % The function must have the following syntax: 
            %     offset = f(propVal) 
            % where propVal is the value of the property, PROP.
            
            narginchk(1,5)
            
            if obj.pFirstCall
                perts = defaultPerturbations(obj);
                obj.pPerturbableProperties = [perts.Property];
                obj.pPerturbations = perts;
                obj.pIntegerProperties = integerProperties(obj);
                obj.pFirstCall = false;
            end
            
            % No arguments in: only show existing values
            if isempty(varargin)
                perts = obj.pPerturbations;
                pertsTable = struct2table(perts, 'AsArray', true);
                return
            end
            
            % One varargin: it must the property
            prop = varargin{1};
            ind = findProperty(obj, prop);
            if numel(varargin) == 1 % Just output the property
                perts = obj.pPerturbations(ind);
                pertsTable = struct2table(perts, 'AsArray', true);
                return
            end
            
            % At least 2 varargins: the second is the type of perturbation
            type = validatestring(varargin{2}, ...
                ["None", "Selection", "Normal", "Uniform", "Custom"], ...
                'perturbations', 'Type');
            obj.pPerturbations(ind).Type = type;
            switch type
                case "None"
                    obj.pPerturbations(ind).Value{1} = NaN; % "None" takes no values
                    obj.pPerturbations(ind).Value{2} = NaN; % "None" takes no values
                case "Selection"
                    narginchk(4,5)
                    parseSelectionValues(obj, ind, varargin{:});
                case "Normal"
                    narginchk(4,5)
                    parseNormalValues(obj, ind, varargin{:});
                case "Uniform"
                    narginchk(5,5)
                    parseUniformValues(obj, ind, varargin{:});
                case "Custom"
                    narginchk(4,4)
                    parseCustomValues(obj, ind, varargin{:});
            end
            perts = obj.pPerturbations;
            pertsTable = struct2table(perts, 'AsArray', true);
        end
    end
    methods(Access = protected)
        function props = getPerturbableProperties(obj)
            perts = perturbations(obj);
            props = {perts.Property};
        end
        function ind = findProperty(obj, prop)
            fullProp = validatestring(prop, obj.pPerturbableProperties, ...
                'perturbations', 'Property');
            inProps = strcmpi(fullProp, obj.pPerturbableProperties);
            ind = find(inProps);
        end
        function s = savePerts(obj, s)
            s.pPerturbableProperties = obj.pPerturbableProperties;
            s.pPerturbations = obj.pPerturbations;
            s.pIntegerProperties = obj.pIntegerProperties;
            s.pFirstCall = obj.pFirstCall;
        end
        function loadPerts(obj,s)
            if isfield(s, 'pPerturbableProperties')
                obj.pPerturbableProperties = s.pPerturbableProperties;
            else
                perts = defaultPerturbations(obj);
                obj.pPerturbableProperties = [perts.Property];
            end
            if isfield(s, 'pPerturbations')
                obj.pPerturbations = s.pPerturbations;
            else
                perts = defaultPerturbations(obj);
                obj.pPerturbations = perts;
            end
            if isfield(s, 'pIntegerProperties')
                obj.pIntegerProperties = s.pIntegerProperties;
            else
                obj.pIntegerProperties = integerProperties(obj);
            end
            if isfield(s, 'pFirstCall')
                obj.pFirstCall = s.pFirstCall;
            else
                obj.pFirstCall = true;
            end
        end
        function value = offset(obj, perturbation)
            %OFFSET  Offset value based on the perturbation
            %  VALUE = OFFSET(obj) provides a scalar offset value based on
            %  the definition of the perturbation.
            
            objProp = obj.(perturbation.Property);
            propSize = size(objProp);
            
            switch perturbation.Type
                case "None"
                    value = zeros(propSize, 'like', objProp);
                case "Selection"
                    r = rand;
                    i = find(r < cumsum(perturbation.Value{2}),1,'first');
                    value = perturbation.Value{1}{i};
                case "Normal"
                    % obj.Value contains: mean and sigma
                    % The result should be:
                    %   mean + randn(propSize) .* sigma
                    mean  = perturbation.Value{1};
                    sigma = perturbation.Value{2};
                    
                    value = mean + randn(propSize) .* sigma;
                    
                    if any(strcmpi(perturbation.Property, obj.pIntegerProperties))
                        value = round(value);
                    end
                case "Uniform"
                    % obj.Value contains: min and max
                    % The result should be:
                    %   min + rand(propSize) .* (max-min)
                    minval = perturbation.Value{1};
                    maxval = perturbation.Value{2};
                    
                    value = minval + rand(propSize) .* (maxval - minval);
                    
                    if any(strcmpi(perturbation.Property, obj.pIntegerProperties))
                        value = round(value);
                    end
                case "Custom"
                    fh = perturbation.Value{1};
                    value = fh(objProp);
            end
        end
        
        function parseSelectionValues(obj, ind, varargin)
            % Parses the "Selection" case. varargin is expected to be:
            % {propName, "Selection", values, probabilities}
            % ind already gives the property, no need to parse again
            numvargs = numel(varargin);
            values = varargin{3};
            validateattributes(values, {'cell'}, {}, 'perturbations', 'Selection values');
            numVals = numel(values);
            obj.pPerturbations(ind).Value{1} = values;
            if numvargs > 3
                probs = varargin{4};
                validateattributes(probs, {'double','single'}, ...
                    {'real', 'positive', 'vector', 'numel', numVals}, ...
                    'perturbations', 'Selection probabilities');
                obj.pPerturbations(ind).Value{2} = probs / sum(probs);
            else
                probs = ones(1,numVals) / numVals;
                obj.pPerturbations(ind).Value{2} = probs;
            end
        end
        
        function parseNormalValues(obj, ind, varargin)
            % Parses the "Normal" case. varargin is expected to be:
            % {propName, "Normal", [mean], stdDev}
            % ind already gives the property, no need to parse again
            numvargs = numel(varargin);
            
            if numvargs == 3 % Only stdDev is given
                stdDev = varargin{3};
                validateattributes(stdDev, {'double','single'}, {'real','2d'}, ...
                    'perturbations', 'sigma');
                obj.pPerturbations(ind).Value{1} = zeros(size(stdDev), 'like', stdDev);
                obj.pPerturbations(ind).Value{2} = stdDev;
            else
                meanVal = varargin{3};
                validateattributes(meanVal, {'double','single'}, {'real','2d'},...
                    'perturbations', 'mean');
                stdDev  = varargin{4};
                validateattributes(stdDev, {'double','single'}, ...
                    {'real','2d','size',size(meanVal)}, ...
                    'perturbations', 'sigma');
                obj.pPerturbations(ind).Value{1} = meanVal;
                obj.pPerturbations(ind).Value{2} = stdDev;
            end
        end
        
        function parseUniformValues(obj, ind, varargin)
            % Parses the "Uniform" case. varargin is expected to be:
            % {propName, "Uniform", minRange, maxRange}
            % ind already gives the property, no need to parse again
            minRange = varargin{3};
            maxRange = varargin{4};
            validateattributes(minRange, {'double','single'}, {'real', '2d'}, 'perturbations', 'minRange');
            validateattributes(maxRange, {'double','single'}, {'real', '2d', 'size', size(minRange)}, 'perturbations', 'maxRange');
            obj.pPerturbations(ind).Value{1} = minRange;
            obj.pPerturbations(ind).Value{2} = maxRange;
        end
        
        function parseCustomValues(obj, ind, varargin)
            % Parses the "Custom" case. varargin is expected to be:
            % {propName, "Custom", fcn}
            % ind already gives the property, no need to parse again
            value = varargin{3};
            validateattributes(value, {'char','string','function_handle'}, ...
                {}, 'perturbations', 'Custom function');
            if ischar(value) || isstring(value)
                obj.pPerturbations(ind).Value{1} = str2func(value);
                obj.pPerturbations(ind).Value{2} = NaN;
            else
                obj.pPerturbations(ind).Value{1} = value; 
                obj.pPerturbations(ind).Value{2} = NaN;
            end
        end
    end
end