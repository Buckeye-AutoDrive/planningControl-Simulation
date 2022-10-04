function [MaxVCurve] = MaxCurveVelocity(curvature)
%Find max velocity around a curve
% Find the raidus of the curve
r = 1/curvature;

%Max velocity around a flat road (Assuming no wet road)
MaxVCurve = sqrt(9.81*r*.7);
%Max velocity around a flat road (Assuming wet road)
%outputArg1 = sqrt(9.81*r*.7);
end