function GHawkWaypointGeneratorGA(GHawkRoute, defaultGHawkWPs, round) %include root if using connect

    if (round == 1)
        waypoint = GHawkRoute.Waypoints.Add();
        waypoint.Latitude = -78.1800;
        waypoint.Longitude = 167.0000;
        waypoint.Altitude = 0; %km
        waypoint.Speed = 0.20; %km/sec
        waypoint.TurnRadius = 0; %km
    %    %reset waypoint for GHawk before adding first waypoint
    %    root.ExecuteCommand('Waypoints */Aircraft/GlobalHawk Clear')
    end
    
  switch round
    %case 0
        %Place Takeoff waypoint

    case 1
        waypoint = GHawkRoute.Waypoints.Add();
        waypoint.Latitude = defaultGHawkWPs(round,1);
        waypoint.Longitude = defaultGHawkWPs(round,2);
        waypoint.Altitude = 8; %km
        waypoint.Speed = 0.20; %km/sec
        waypoint.TurnRadius = 0; %km
    case 2
        waypoint = GHawkRoute.Waypoints.Add();
        waypoint.Latitude = defaultGHawkWPs(round,1);
        waypoint.Longitude = defaultGHawkWPs(round,2);
        waypoint.Altitude = 8; %km
        waypoint.Speed = 0.20; %km/sec
        waypoint.TurnRadius = 0; %km
    case 3
        waypoint = GHawkRoute.Waypoints.Add();
        waypoint.Latitude = defaultGHawkWPs(round,1);
        waypoint.Longitude = defaultGHawkWPs(round,2);
        waypoint.Altitude = 8; %km
        waypoint.Speed = 0.20; %km/sec\
        waypoint.TurnRadius = 0; %km
    case 4
        waypoint = GHawkRoute.Waypoints.Add();
        waypoint.Latitude = defaultGHawkWPs(round,1);
        waypoint.Longitude = defaultGHawkWPs(round,2);
        waypoint.Altitude = 8; %km
        waypoint.Speed = 0.20; %km/sec
        waypoint.TurnRadius = 0; %km

    case 5 %fly to centroid of area target
        waypoint = GHawkRoute.Waypoints.Add();
        waypoint.Latitude = defaultGHawkWPs(round,1);
        waypoint.Longitude = defaultGHawkWPs(round,2);
        waypoint.Altitude = 8; %km
        waypoint.Speed = 0.20; %km/sec\
        waypoint.TurnRadius = 0; %km
  end      
GHawkRoute.Propagate;
end