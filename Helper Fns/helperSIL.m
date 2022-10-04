function helperSIL(model,modelName)
%comment out visualization block
set_param(append(modelName,'/Visualization'),'commented','on');
helperSetModelParametersForSIL(modelName);
set_param(modelName,'SimulationMode','Software-in-the-loop (SIL)');
sim(modelName);
helperCoverageSettings(modelName);
cvDataObj=cvsim(modelName);
cvhtml(append('CoverageResults/',modelName),cvDataObj);

    function helperCoverageSettings(mdl)
    %helperCoverageSettings enables the flags required for coverage analysis.
    % To get the coverage, you need to configure reference model in SIL mode.

    %   This is a helper function for example purposes and
    %   may be removed or modified in the future.

    % Copyright 2020 The MathWorks, Inc.

    %% Enable flags in Verification -> Code Coverage for SIL or PIL.
    set_param(mdl,'CovEnable','on')
    set_param(mdl,'CovScope','ReferencedModels')
    set_param(mdl,'CovMetricStructuralLevel','Decision') % Default is Decision

    %% Enable flags in Coverage -> Include in analysis
    set_param(mdl,'CovExternalEMLEnable','on') % MATLAB files, default is 'on'
    set_param(mdl,'CovSFcnEnable','on') % C/C++ S-Functions, default is 'on'

    %% Enable flags in Coverage -> Coverage Metrics
    set_param(mdl,'CovMetricLookupTable','on')
    set_param(mdl,'CovMetricSignalRange','on')
    set_param(mdl,'CovMetricSignalSize','on')
    set_param(mdl,'CovMetricObjectiveConstraint','on')
    set_param(mdl,'CovMetricSaturateOnIntegerOverflow','on')
    set_param(mdl,'CovMetricRelationalBoundary','on')
    end

    function helperSetModelParametersForSIL(algorithmModel)
        paramNameValueDescription = {...
            'SystemTargetFile', 'ert.tlc', 'Code Generation>System target file';
            'TargetLang', 'C++', 'Code Generation>Language';
            'CodeExecutionProfiling', 'on', 'Code Generation>Verification>Measure task execution time';
            'CodeProfilingSaveOptions', 'AllData', 'Code Generation>Verification>Save options';
            'CodeExecutionProfileVariable', 'executionProfile', 'Code Generation>Verification>Workspace variable'};


        for index = 1:size(paramNameValueDescription,1)
            set_param(algorithmModel,paramNameValueDescription{index,1},paramNameValueDescription{index,2});
        end

        disp(' ');
        disp([algorithmModel ' configuration parameters:']);
        disp(' ');
        disp(cell2table(paramNameValueDescription,...
            'VariableNames',{'Parameter', 'Value', 'Description'}));
    end

set_param(append(modelName,'/Visualization'),'commented','off');
end