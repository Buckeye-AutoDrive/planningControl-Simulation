# AD2_Y1_SimulationPkg

This contains the work done on the AutoDrive 2 Y1 Simulation Challenge Simulation package. It contains DSD scenarios with traffic lights and stop signs in cuboid world.
Please watch the videos befor eyou open and use the package!

File structure:
project_start - automatically runs on project startup
TL_start – startup script – run first. Uncomment and comment lines as needed
Misc models – Predefined_with_GroundTruth – contains model with ground truth information of all actors and predefined ego waypoints
Predefined_with_sensors – contains models with sensor detections information of all actors and pre defined ego waypoints
Reqs – contains created requirements and the associated model ReqsGroundTruth with Vehicle dynamics, ground truth, ego waypoints from signal builder block, and block with requirements and test harness
Scenarios – contains scenario .m and .mat files
Sensor Configs – contains sensor configuration .m files
Vehicle dynamics – contains the vehicle dynamics subsystem
codeGeneration - this folder contains the models that are used in the code generation video. 

Examples related to model blocks:
Traffic light stateflow: https://www.mathworks.com/help/mpc/ug/traffic-light-negotiation.html
Automatic scenario generaion: https://www.mathworks.com/help/driving/ug/automatic-scenario-generation.html

