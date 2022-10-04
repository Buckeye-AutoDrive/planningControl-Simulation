% This function helps you choose a scenario from a list of scenarios saved
% in the Scenarios folder. These are saved as .mat and .m files. 

function [allData, scenario, sensors,SelectedConfigName] = choose_scenario()
d = [dir('scenarios/*.m');dir('scenarios/*.mlx')];
fn = {d.name};
[indx,~] = listdlg('PromptString',{'Select a scenario.',...
    'Only one file can be selected at a time.',''},...
    'SelectionMode','single','ListString',fn);
[~,SelectedConfigName,~] = fileparts(d(indx).name);
[allData, scenario, sensors]=feval(SelectedConfigName);

