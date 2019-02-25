_group = _this select 0;
_position = _this select 1;
_radius = _this select 2;

While {({alive _x} count units _group) > 0} do {
	// Check number of waypoints, if less then 3 add more.
	if (count (waypoints _group) < 3) then {
		_pos = [_position, 0, _radius * sqrt br_max_radius_distance, 2, 0, 60, 0] call BIS_fnc_findSafePos;
		_wp = _group addWaypoint [_pos, 0];
		_wp setWaypointStatements ["true","deleteWaypoint [group this, currentWaypoint (group this)]"];
	};
	sleep br_command_delay;
};

{ deleteVehicle _x; } forEach units _group; 
deleteGroup _group;  
_group = grpNull; 
_group = nil;
