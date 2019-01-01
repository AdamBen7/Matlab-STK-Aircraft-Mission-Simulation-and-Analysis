%for aviator
function GHawkWaypointGeneratorAviator(root, defaultGHawkWPs, round)
    
    if (round == 1)
        root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Procedure Add AsFirst SiteType Runway ProcedureType "Takeoff"']);
        root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Site 1 SetValue Latitude -78.1800 deg']);
        root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk Site 1 SetValue Longitude 167.0000 deg']);
        root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk SendNtfUpdate']);

    %    %reset waypoint for GHawk before adding first waypoint
    %    root.ExecuteCommand('Waypoints */Aircraft/GlobalHawk Clear')
    end
    
    ProcedurePrefix = 'MissionModeler */Aircraft/GlobalHawk Procedure Add After ';
    ProcedureSuffix = ' SiteType Waypoint ProcedureType "Basic Point to Point"';
    PointToPointCmd = [ProcedurePrefix num2str(round) ProcedureSuffix]
    root.ExecuteCommand(PointToPointCmd);

    LatLongCmdPrefix = 'MissionModeler */Aircraft/GlobalHawk Site ';
    LatCmdSuffix = ' SetValue Latitude ';
    LatCmd = [LatLongCmdPrefix num2str(round+1) LatCmdSuffix num2str(defaultGHawkWPs(round,1)) ' deg'];
    root.ExecuteCommand([LatCmd]);
    
    LongCmdSuffix = ' SetValue Longitude ';
    LongCmd = [LatLongCmdPrefix num2str(round+1) LongCmdSuffix num2str(defaultGHawkWPs(round,2)) ' deg'];
    root.ExecuteCommand([LongCmd]);
    
    root.ExecuteCommand(['MissionModeler */Aircraft/GlobalHawk SendNtfUpdate']);
end
    