classdef (Hidden) insSensorCG < INSSENSORBaseMATLAB
%INSSENSORCG - Codegen class for insSensor
%
%   This class is for internal use only. It may be removed in the future.

%   Copyright 2017-2020 The MathWorks, Inc.

%#codegen

    methods
        function obj = insSensorCG(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Static, Hidden)
        function name = matlabCodegenUserReadableName
            name = 'insSensor';
        end
    end
end
