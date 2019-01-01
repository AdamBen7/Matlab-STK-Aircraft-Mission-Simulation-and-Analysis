%Developped by Adam Benabbou
%abenabbou@crimson.ua.edu
%The University of Alabama
%Version 2: URCA 
%03/29/2018

% === Phase 1 ===
clear;clc;
pause on;
fprintf('\n Welcome to Adam Benabbou''s Submission for the EAP Competition \n');
prompt = (' Please Input Scenario Timestep. (Recommended Value: 20)... ');
timestep = input(prompt);

prompt1 = ('\n Would you like to use preloaded data? (Enter 1 for Yes, 0 for No) \n');
preloaded = input(prompt1);


%% Initialize Matlab and Create New STK Scenario
%clc;clear;
app = actxserver('STK11.application'); 
root = app.Personality2; 
scenario = root.Children.New('eScenario', 'MATLAB_McMurdoMission');
scenario.SetTimePeriod('01 Oct 2017 19:00:00.000','04 Oct 2017 19:00:00.000');
scenario.StartTime = '01 Oct 2017 19:00:00.000';
scenario.StopTime = '04 Oct 2017 19:00:00.000';
root.ExecuteCommand('SetAnimation * StartTimeOnly "01 Oct 2017 19:00:00.0" TimeStep 1 RefreshDelta 0.5 RefreshMode RefreshDelta');
%timestep = 25;
root.ExecuteCommand('Animate * Reset');
root.ExecuteCommand('VO * Declutter Enable On');

%% Instantiating Objects and Defining Object Properties
McMurdo = scenario.Children.New('ePlace','McMurdo_Station');
McMurdo.Position.AssignGeodetic(-77.8391, 166.667,0);
McMurdo.UseTerrain = true;

% Create Sensor on McMurdo Station
StationSensor = McMurdo.Children.New('eSensor', 'BaseServo');
StationSensorPattern = StationSensor.Pattern;
StationSensorPattern.ConeAngle = 90;
root.ExecuteCommand(['SetConstraint */Place/McMurdo_Station/Sensor/' 'BaseServo' ' Range Max 200000.0']);
root.ExecuteCommand(['Graphics */Place/McMurdo_Station/Sensor/BaseServo Show off']);
%Mounting default Transmitter on Sensor
BaseTransmitter = StationSensor.Children.New('eTransmitter', 'BaseTransmitter');

%% Creating Rover as Target Object
assumedlocation_lat = -78.18972884;
assumedlocation_long = 161.52012316;

installDirectory = root.ExecuteCommand('GetDirectory / STKHome').Item(0);
inactiveVehicle = scenario.Children.New('eTarget', 'inactiveRover');
    inactiveVehicle.Position.AssignGeodetic(assumedlocation_lat,assumedlocation_long,0);
    inactiveVehicle.UseTerrain = true;
    %inactiveVehicle.SetAzElMask('eTerrainData',0);
    inactiveVehicle.Graphics.LabelVisible = false;
    root.ExecuteCommand(['VO */Target/' 'inactiveRover' ' Model Show On']);
    model = inactiveVehicle.VO.Model;
    model.ModelData.FileName = [installDirectory 'STKData\VO\Models\Land\groundvehicle.mdl'];
    root.ExecuteCommand(['SetConstraint */Target/inactiveRover' ' AzElMask On']);
    
% Create Sensor on Target (Rx)
RoverSensor = inactiveVehicle.Children.New('eSensor', 'grndReceiver');
pattern1 = RoverSensor.Pattern;
pattern1.ConeAngle = 90;
root.ExecuteCommand(['SetConstraint */Target/inactiveRover/Sensor/' 'grndReceiver' ' Range Max 150000.0']);
root.ExecuteCommand(['Graphics */Target/inactiveRover/Sensor/grndReceiver Show off']);

%Set Up Receiver on Sensor
RoverReceiver = RoverSensor.Children.New('eReceiver', 'grndReceiver');
root.ExecuteCommand(['SetConstraint */Target/inactiveRover/Sensor/grndReceiver/Receiver/' 'grndReceiver' ' Range Max 150000.0']);

% Compute Whether there is Direct Link Between GS and Target
accessProblem = McMurdo.GetAccessToObject(inactiveVehicle);
accessProblem.ComputeAccess();

%% Move target and obtain altitude data
masternum = 50; %I'll want 100 with 0.1 as "granularity"
if (preloaded == 0) 
    for i = 1:masternum 
        Target_lat(i) = assumedlocation_lat + 0.15*(i -(0.5*masternum +1)); 
        for j = 1:masternum 
            Target_long(j) = assumedlocation_long + 0.15*(j -(0.5*masternum +1));
            inactiveVehicle.Position.AssignGeodetic (Target_lat(i), Target_long(j), 0);
            inactiveVehicle.UseTerrain = true;
            GeodeticData = inactiveVehicle.DataProviders.Item('All Position'); %find better var name for this
            GeodeticData = GeodeticData.Exec();
            alt(i,j) = GeodeticData.DataSets.GetDataSetByName('Ground Alt').GetValues;
            position(1:3,i,j) = [Target_lat(i), Target_long(j), alt(i,j)];      
        %MyMap = [Target_lat, Target_long, ]
        %inactiveVehicle.SetAzElMask('eTerrainData', 0);
        %azelMask(i) = target(i).Graphics.AzElMask;
        %azelMask(i) =.RangeVisible = false; %hides gigantic azelmask  
        end
    end
    alt = cell2mat(alt);
else
    load sampleTarget_lat
    load sampleTarget_long
    load sampleAlt
    load sampleGeodeticData %probably unnecessary
    load sampleposition
end

inactiveVehicle.Position.AssignGeodetic(assumedlocation_lat,assumedlocation_long,0); %return our poor iterated target back to where it's supposed to be


%% Generate Area Target of Interest
areaOfInterest = scenario.Children.New('eAreaTarget', 'AreaOfInterest');
root.BeginUpdate();
areaOfInterest.AreaType= 'ePattern';
patterns = areaOfInterest.AreaTypeData;
patterns.Add(Target_lat(1), Target_long(1));
patterns.Add(Target_lat(masternum), Target_long(1));
patterns.Add(Target_lat(masternum), Target_long(masternum));
patterns.Add(Target_lat(1), Target_long(masternum));
root.EndUpdate();

%% Place target at decently random offset from estimation
realTarget_lat = assumedlocation_lat + 0.2*rand; %change to pseudorandom
realTarget_long = assumedlocation_long + 0.2*rand; %change to pseudorandom
inactiveVehicle.Position.AssignGeodetic(realTarget_lat,realTarget_long,0); %return our poor iterated target back to where it's supposed to be


%% Identifying highpoints (find mountain range peak)
for i = 1:masternum
    [LatHighest(i),LatHighpoint_index(i)] = max(alt(i,1:50));
end

%% Create Aircraft 

        GHawk = scenario.Children.New('eAircraft', 'GlobalHawk');
        GHawk.SetRouteType('ePropagatorAviator');
        root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Aircraft Choose "Basic UAV"']); %77
        GHawkRoute = GHawk.Route;

model = GHawk.VO.Model; %don't really care about Model data variable
model.ModelData.FileName = [installDirectory 'STKData\VO\Models\Air\rq-4a_globalhawk.mdl'];

McMurdoPointer = GHawk.Children.New('eSensor', 'McMurdoPointer');
pattern1 = McMurdoPointer.Pattern;
pattern1.ConeAngle = 1;
McMurdoPointer.SetPointingType('eSnPtTargeted');
pointing1 = McMurdoPointer.Pointing;
pointing1.Targets.AddObject(McMurdo);
root.ExecuteCommand(['Graphics */Aircraft/GlobalHawk/Sensor/McMurdoPointer Show off']);

%Mounting default Receiver on Sensor
GHReceiver = McMurdoPointer.Children.New('eReceiver', 'GHReceiver');

%generate target pointing pattern based on time later
RoverPointer = GHawk.Children.New('eSensor', 'RoverPointer');
pattern2 = RoverPointer.Pattern;
pattern2.ConeAngle = 1;
RoverPointer.SetPointingType('eSnPtTargeted');
pointing2 = RoverPointer.Pointing;
%pointing2.Targets.AddObject(grndVehicle);
root.ExecuteCommand(['Graphics */Aircraft/GlobalHawk/Sensor/RoverPointer Show off']);

Relayer = RoverPointer.Children.New('eTransmitter', 'Relayer');
root.ExecuteCommand(['SetConstraint */Aircraft/GlobalHawk/Sensor/RoverPointer/Transmitter/' 'Relayer' ' Range Max 50000.0']);

%% Waypoint Generation
notclose = true;
round = 0;
root.ExecuteCommand('Waypoints */Aircraft/GlobalHawk Clear');

root.UnitPreferences.Item('DateFormat').SetCurrentUnit('EpSec'); %do I want to do this? maybe not... investigate further
defaultGHawkWPs = [Target_lat(masternum), Target_long(LatHighpoint_index(masternum));
                   Target_lat(masternum), Target_long(1);
                   Target_lat(1),         Target_long(1);
                   Target_lat(1),         Target_long(LatHighpoint_index(1));
                   assumedlocation_lat,   assumedlocation_long;]; %last one is centroid

while (notclose)
    round = round + 1;
    GHawkWaypointGeneratorAviator(root, defaultGHawkWPs, round) 
        
    GHawk_Target_Access = GHawk.GetAccessToObject(inactiveVehicle);
    GHawk_Target_Access.ComputeAccess();
    VectorsFixed = GHawk_Target_Access.DataProviders.Item('Vectors(Fixed)').Group.Item('From-To-RelPos'); %find better var name for this as well
    VectorsFixedDP = VectorsFixed.Exec(scenario.StartTime, scenario.StopTime, 60); % stoptime might become max epoch? increase aircraft speed? decrease search location?
    GHawk_Target_Dist = [cell2mat(VectorsFixedDP.DataSets.GetDataSetByName('Time').GetValues) cell2mat(VectorsFixedDP.DataSets.GetDataSetByName('Magnitude').GetValues)]; %time and distance in km (data is correct. Dont panic... see matrix multiplier.
    if min(GHawk_Target_Dist(:,2)) < 50 %optimize this part in the future
        notclose = false;
    end
end



close_index = find(GHawk_Target_Dist(:,2)<50,1);

%% Fly to Found Target. Future: hover around with figure of 8 using aviator
%maybe generate box flight path?
vall = (GHawk_Target_Dist(close_index,1)); %might need to change to num2str()

root.CurrentTime = scenario.StartTime;
        root.ExecuteCommand(['VO * View FromTo FromRegName "STK Object" FromName "/Aircraft/GlobalHawk" ToRegName "STK Object" ToName "/Aircraft/GlobalHawk" WindowID 1']);
for i = root.CurrentTime : timestep: vall
    root.currentTime = i;
end

GHawkLLA = GHawk.DataProviders.Item('LLA State').Group.Item('Fixed'); %find better var name for this
GHawkLLAData = GHawkLLA.Exec(scenario.StartTime, root.CurrentTime, timestep);
GHawk_Partial_LLA = [cell2mat(GHawkLLAData.DataSets.GetDataSetByName('Time').GetValues) cell2mat(GHawkLLAData.DataSets.GetDataSetByName('Lat').GetValues) cell2mat(GHawkLLAData.DataSets.GetDataSetByName('Lon').GetValues)]; %time and distance in km (data is correct. Dont panic... see matrix multiplier.
matLength = length(GHawk_Partial_LLA); %get index of last row

%%
%check if waypoints already exist
% maybe try a different algorithm
done = false;
round2 = 0;
LastProcedureRemovalCmd = ['MissionModeler */Aircraft/GlobalHawk Procedure Remove ' num2str(round+1)];
root.ExecuteCommand(LastProcedureRemovalCmd);
root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk ConfigureAll']); 
root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk SendNtfUpdate']);
round = round +1; %the untimely correction. best practice would be to change starting value of round
PointToPointCmd = ['MissionModeler */Aircraft/GlobalHawk Procedure Add After ' num2str(round-1) ' SiteType Waypoint ProcedureType "Basic Point to Point"']
root.ExecuteCommand(PointToPointCmd);
LatCmd = ['MissionModeler */Aircraft/GlobalHawk Site ' num2str(round) ' SetValue Latitude ' num2str(GHawk_Partial_LLA(matLength,2)) ' deg'];
root.ExecuteCommand([LatCmd]);
LongCmd = ['MissionModeler */Aircraft/GlobalHawk Site ' num2str(round) ' SetValue Longitude ' num2str(GHawk_Partial_LLA(matLength,3)) ' deg'];
root.ExecuteCommand([LongCmd]);
root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk SendNtfUpdate']);
    
%maybe do figure of 8 here instead?
round = round +1;
PointToPointCmd = ['MissionModeler */Aircraft/GlobalHawk Procedure Add After ' num2str(round-1) ' SiteType Waypoint ProcedureType "Basic Point to Point"']
root.ExecuteCommand(PointToPointCmd);
LatCmd = ['MissionModeler */Aircraft/GlobalHawk Site ' num2str(round) ' SetValue Latitude ' num2str(realTarget_lat) ' deg'];
root.ExecuteCommand([LatCmd]);
LongCmd = ['MissionModeler */Aircraft/GlobalHawk Site ' num2str(round) ' SetValue Longitude ' num2str(realTarget_long) ' deg'];
root.ExecuteCommand([LongCmd]);
root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk SendNtfUpdate']);


%% Establish connection and start ground vehicle 
root.CurrentTime = scenario.StartTime;
for i = root.CurrentTime : timestep: GHawk_Partial_LLA(matLength,1)
    root.currentTime = i;
end
pointing2.Targets.AddObject(inactiveVehicle);

% Create Chain
UAVRelayedChain = scenario.Children.New('eChain', 'UAVRelayedChain');
UAVRelayedChain.Objects.AddObject(BaseTransmitter);
UAVRelayedChain.Objects.AddObject(GHReceiver);
UAVRelayedChain.Objects.AddObject(Relayer);
UAVRelayedChain.Objects.AddObject(RoverReceiver);
UAVRelayedChain.ComputeAccess();

for i = root.CurrentTime : timestep: (root.CurrentTime + 200)
    root.currentTime = i;
    disp(i)
end

root.ExecuteCommand(['Unload / */Target/inactiveRover RemAssignedObjs']);
grndVehicle = scenario.Children.New('eGroundVehicle', 'DaRover');
% Create Sensor on Target (Rx)?
RoverSensor = grndVehicle.Children.New('eSensor', 'grndReceiver');
pattern1 = RoverSensor.Pattern;
pattern1.ConeAngle = 90;
root.ExecuteCommand(['SetConstraint *//GroundVehicle/DaRover/Sensor/' 'grndReceiver' ' Range Max 150000.0']);
root.ExecuteCommand(['Graphics *//GroundVehicle/DaRover/Sensor/grndReceiver Show off']);

%Set Up Receiver on Sensor
RoverReceiver = RoverSensor.Children.New('eReceiver', 'grndReceiver');
root.ExecuteCommand(['SetConstraint */GroundVehicle/DaRover/Sensor/grndReceiver/Receiver/' 'grndReceiver' ' Range Max 150000.0']);

grndVehicle.SetRouteType('ePropagatorGreatArc');
RoverRoute = grndVehicle.Route;
%figure out how to get waypoint data from STK. IMPORTANT
%figure out rover speed
ptsArray = {realTarget_lat,realTarget_long,0,0,0; %switch altitude to terrain?
            -78.9514,161.7101231,0,0.005556,0;
            -78.7787,166.4142571,0,0.005556,0;
            -77.9887,166.7652571,0,0.005556,0};
startEpochRover = RoverRoute.EphemerisInterval.GetStartEpoch();
startEpochRover.SetExplicitTime(root.currentTime);
RoverRoute.EphemerisInterval.SetStartEpoch(startEpochRover);
RoverRoute.SetPointsSmoothRateAndPropagate(ptsArray);
RoverRoute.SetAltitudeRefType('eWayPtAltRefTerrain');

pointing2.Targets.AddObject(RoverReceiver);

%% generate a few more waypoints for Global Hawk 

for i = 8:11
root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Procedure Add AfterLast 0 SiteType "End of previous procedure" ProcedureType "Holding - Circular"'])
CircularCmd = ['MissionModeler */Aircraft/GlobalHawk Procedure ' num2str(i) ' SetValue Diameter 75 km'];
root.ExecuteCommand(CircularCmd)
CircularCmd = ['MissionModeler */Aircraft/GlobalHawk Procedure ' num2str(i) ' SetValue Turns 4'];
root.ExecuteCommand(CircularCmd)
%root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Procedure 8 SetValue Diameter 75 km'])    
%root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Procedure 8 SetValue Turns 2'])
root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk SendNtfUpdate']); 
end


%% === Phase 2 === Master Scenario Player
Done = 0;

while (Done == 0)
    
    fprintf('\n Scenario Loading Complete. \n');
    fprintf('1_ Run through scenario \n');
    fprintf('2_ Change Timestep \n');
    fprintf('3_ Exit Program \n \n');
    prompt2 = ('Please Enter Option Number: ');
    option = input(prompt2);

    switch option
        case 1        
            root.CurrentTime = scenario.StartTime;
        try
            root.ExecuteCommand(['Unload / */Target/inactiveRover RemAssignedObjs']);
            BaseTransmitter = StationSensor.Children.New('eTransmitter', 'BaseTransmitter');
            GHReceiver = McMurdoPointer.Children.New('eReceiver', 'GHReceiver');
            Relayer = RoverPointer.Children.New('eTransmitter', 'Relayer');
            root.ExecuteCommand(['SetConstraint */Aircraft/GlobalHawk/Sensor/RoverPointer/Transmitter/' 'Relayer' ' Range Max 50000.0']);
        catch
        end
        try
            root.ExecuteCommand(['Unload / */GroundVehicle/DaRover RemAssignedObjs']);
        catch    
        end
        try
            root.ExecuteCommand(['Unload / */Chain/UAVRelayedChain RemAssignedObjs']);
        catch    
        end        
        try
        %these apparently get removed by the try/catch lines since they're
        %assigned objects
        BaseTransmitter = StationSensor.Children.New('eTransmitter', 'BaseTransmitter');
        GHReceiver = McMurdoPointer.Children.New('eReceiver', 'GHReceiver');
        Relayer = RoverPointer.Children.New('eTransmitter', 'Relayer');
        root.ExecuteCommand(['SetConstraint */Aircraft/GlobalHawk/Sensor/RoverPointer/Transmitter/' 'Relayer' ' Range Max 50000.0']);
        catch
        end
        
        
        
        inactiveVehicle = scenario.Children.New('eTarget', 'inactiveRover');
        inactiveVehicle.Position.AssignGeodetic(assumedlocation_lat,assumedlocation_long,0);
        inactiveVehicle.UseTerrain = true;
        %inactiveVehicle.SetAzElMask('eTerrainData',0);
        inactiveVehicle.Graphics.LabelVisible = false;
        root.ExecuteCommand(['VO */Target/' 'inactiveRover' ' Model Show On']);
        model = inactiveVehicle.VO.Model;
        model.ModelData.FileName = [installDirectory 'STKData\VO\Models\Land\groundvehicle.mdl'];
        root.ExecuteCommand(['SetConstraint */Target/inactiveRover' ' AzElMask On']);
    
        % Create Sensor on Target (Rx)
        RoverSensor = inactiveVehicle.Children.New('eSensor', 'grndReceiver');
        pattern1 = RoverSensor.Pattern;
        pattern1.ConeAngle = 90;
        root.ExecuteCommand(['SetConstraint */Target/inactiveRover/Sensor/' 'grndReceiver' ' Range Max 150000.0']);
        root.ExecuteCommand(['Graphics */Target/inactiveRover/Sensor/grndReceiver Show off']);
        
        %Set Up Receiver on Sensor
        RoverReceiver = RoverSensor.Children.New('eReceiver', 'grndReceiver');
        root.ExecuteCommand(['SetConstraint */Target/inactiveRover/Sensor/grndReceiver/Receiver/' 'grndReceiver' ' Range Max 150000.0']);
        root.ExecuteCommand(['Zoom * Object */Aircraft/GlobalHawk 20']);
        root.ExecuteCommand(['VO * View FromTo FromRegName "STK Object" FromName "/Aircraft/GlobalHawk" ToRegName "STK Object" ToName "/Aircraft/GlobalHawk" WindowID 1']);
        for i = scenario.StartTime: timestep: scenario.StopTime
            root.CurrentTime = i;
            
            if root.CurrentTime == (GHawk_Partial_LLA(matLength,1))
                UAVRelayedChain = scenario.Children.New('eChain', 'UAVRelayedChain');
                UAVRelayedChain.Objects.AddObject(BaseTransmitter);
                UAVRelayedChain.Objects.AddObject(GHReceiver);
                UAVRelayedChain.Objects.AddObject(Relayer);
                UAVRelayedChain.Objects.AddObject(RoverReceiver);
                UAVRelayedChain.ComputeAccess();
            end
            
            if root.CurrentTime == (GHawk_Partial_LLA(matLength,1) + 200)  
                root.ExecuteCommand(['Unload / */Target/inactiveRover RemAssignedObjs']);
                grndVehicle = scenario.Children.New('eGroundVehicle', 'DaRover');
                % Create Sensor on Rover (Rx)
                RoverSensor = grndVehicle.Children.New('eSensor', 'grndReceiver');
                pattern1 = RoverSensor.Pattern;
                pattern1.ConeAngle = 90;
                root.ExecuteCommand(['SetConstraint */GroundVehicle/DaRover/Sensor/' 'grndReceiver' ' Range Max 150000.0']);
                root.ExecuteCommand(['Graphics */GroundVehicle/DaRover/Sensor/grndReceiver Show off']);

                %Set Up Receiver on Sensor
                RoverReceiver = RoverSensor.Children.New('eReceiver', 'grndReceiver');
                root.ExecuteCommand(['SetConstraint */GroundVehicle/DaRover/Sensor/grndReceiver/Receiver/' 'grndReceiver' ' Range Max 150000.0']);

                grndVehicle.SetRouteType('ePropagatorGreatArc');
                RoverRoute = grndVehicle.Route;
                ptsArray = {realTarget_lat,realTarget_long,0,0,0; %switch altitude to terrain?
                            -78.9514,161.7101231,0,0.005556,0;
                            -78.7787,166.4142571,0,0.005556,0;
                            -77.9887,166.7652571,0,0.005556,0};
                startEpochRover = RoverRoute.EphemerisInterval.GetStartEpoch();
                startEpochRover.SetExplicitTime(root.currentTime);
                RoverRoute.EphemerisInterval.SetStartEpoch(startEpochRover);
                RoverRoute.SetPointsSmoothRateAndPropagate(ptsArray);
                RoverRoute.SetAltitudeRefType('eWayPtAltRefTerrain');
                
                pointing2.Targets.AddObject(RoverReceiver);
                
                UAVRelayedChain.Objects.AddObject(RoverReceiver);
                UAVRelayedChain.ComputeAccess();
                
                root.ExecuteCommand(['VO * View FromTo FromRegName "STK Object" FromName "/GroundVehicle/DaRover" ToRegName "STK Object" ToName "/GroundVehicle/DaRover" WindowID 1'])
            end
            disp(i);
            if mod(i,5000) == 0
                mypause = ('Press ENTER to keep running the scenario? ');
                input(mypause);
            end
            
                
        end

    case 2
        fprintf('\n Current Timestep value: ')
        disp(timestep);
        prompt = ('Please Input New Timestep. (Recommended: 20) \n'); %loaded data uses 20 
        timestep = input(prompt);
        
    case 3
        Done = 1;
    end
end

%%
figure(1)
surf(Target_long,Target_lat,alt);
title('Elevation based on Longitude and Latitude');
xlabel('Longitude (deg)');
ylabel('Latitude (deg)');
zlabel('Elevation (m)');
rotate3d;

figure(2)
surf(Target_long,Target_lat,alt);
title('Elevation based on Longitude and Latitude');
xlabel('Longitude (deg)');
ylabel('Latitude (deg)');
zlabel('Elevation (m)');
rotate3d;
colorbar('vert')
%%
newMat = zeros(50,50);
for i = 1:50
    newMat(i,LatHighpoint_index(i)) = LatHighest(i);
end

for i = 1:50
    LongPart(i) = assumedlocation_long + 0.15*(LatHighpoint_index(i) -(0.5*masternum +1));
end

figure(3)
%surf(Target_long,Target_lat,newMat);
%scatter(Target_long,Target_lat)
scatter3(LongPart,Target_lat,LatHighest)
title('Elevation based on Longitude and Latitude');
xlabel('Longitude (deg)');
ylabel('Latitude (deg)');
zlabel('Elevation (m)');
rotate3d;
line(LongPart,Target_lat,LatHighest)
%colorbar('vert')
    