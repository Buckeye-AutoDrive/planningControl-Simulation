% This function finds the traffic light, stop sign ID to be used in the SImulink model
function [TL,ss]=findActorID(scenario)
    TL =0; ss=0; ego=0;
    TL=find(contains(cellstr({scenario.Actors(:).Name}),'Traffic_Light'));
    ss=find(contains(cellstr({scenario.Actors(:).Name}), {'Stop Sign'}));
    
    if(isempty(ss))
        ss=0;
    end
    if(isempty(TL))
        TL=0;
    end
              
end
