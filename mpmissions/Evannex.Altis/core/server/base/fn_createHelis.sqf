// The group of units
_chopperUnits = nil;
// The helicopter
_helicopterVech = nil;
// The position where the AI will spawn
_heliPad = _this select 0;
_heliIndex = _this select 1;
// If te helicopter is a evac helicopter or not
_evacChopper = _this select 2;
// Used to tell the AI where to land
_landMarker = nil;

// Type of transport helicopters that can spawn
br_heli_units = [
	"B_Heli_Transport_03_F",
	"B_Heli_Transport_03_unarmed_F",
	"B_Heli_Transport_03_black_F",
	"B_Heli_Transport_03_unarmed_green_F",
	"B_CTRG_Heli_Transport_01_sand_F",
	"B_CTRG_Heli_Transport_01_tropic_F",
	"B_Heli_Light_01_F",
	"B_Heli_Transport_01_F",
	"B_Heli_Transport_01_camo_F",
	"I_Heli_Transport_02_F",
	"I_Heli_light_03_unarmed_F",
	"O_Heli_Light_02_v2_F",
	"O_Heli_Transport_04_bench_F",
	"O_Heli_Transport_04_covered_F"
];

// Gets a random location on the plaer
br_fnc_getGroundUnitLocation = {
	// Gets a random location within the zone radius
	(getMarkerPos "marker_ai_spawn_friendly_ground_units") getPos [5 * sqrt random 180, random 360];
};

// Commands groups in or out of the chopper
br_fnc_commandGroupIntoChopper = {
	_group = _this select 0;
	_getOut = _this select 1;
	if (_getOut) then {
		_group leaveVehicle _helicopterVech;
	} else {
		_group addVehicle _helicopterVech;
	};
	{
		//_x assignAsCargo _helicopterVech;
		if (_getOut) then { _x action ["Eject", _helicopterVech]; } else { [_x] orderGetIn true; };
	} foreach (units _group);
};

// Eject all crew
br_fnc_ejectCrew = {
	{
		_x action ["Eject", _helicopterVech]; _x leaveVehicle _helicopterVech;
	} foreach (crew _helicopterVech);
};

// Create a landing pad
br_fnc_createHeliPad = {
	_landMarker = createVehicle [ "Land_HelipadEmpty_F", getMarkerPos _heliPad, [], 0, "CAN_COLLIDE" ];
};

// Spawn custom units
br_fnc_createChopperUnit = {
	_helicopterVech = (selectrandom br_heli_units) createVehicle getMarkerPos _heliPad;
	//createVehicleCrew _helicopterVech;
	[] call br_fnc_createHeliUnits;
	waitUntil { {_x in _helicopterVech} count (units _chopperUnits) == {(alive _x)} count (units _chopperUnits) };
	//br_helisWaiting append [_chopper];
};

br_fnc_deleteOldChopperUnit = {
	br_heliGroups deleteAt (br_heliGroups find _chopperUnits);
	{ deleteVehicle _x } forEach units _chopperUnits;
	deleteGroup _chopperUnits;
};

// Checks if units in chooper are dead but false is if they are alive
br_fnc_checkHeliDead = {
	if (({(alive _x)} count (units _chopperUnits) > 0) && {(alive _helicopterVech)} && {(((leader _chopperUnits) distance _helicopterVech) < 30)}) then { false;} else { true; };
};

// Creates the helicopter units
br_fnc_createHeliUnits = {
	_chopperUnits = [[] call br_fnc_getGroundUnitLocation, WEST, ["B_Pilot_F"],[],[],[],[],[],180] call BIS_fnc_spawnGroup;
	{_x disableAI "TARGET"; _x disableAI "AUTOTARGET" ; _x disableAI "FSM" ; _x disableAI "AUTOCOMBAT"; _x disableAI "AIMINGERROR"; _x disableAI "SUPPRESSION"; _x disableAI "MINEDETECTION" ; _x disableAI "WEAPONAIM"; _x disableAI "CHECKVISIBLE"; } forEach units _chopperUnits;
	//_chopperUnits addVehicle _helicopterVech;
	{_x moveInDriver _helicopterVech} forEach units _chopperUnits;
	{ _x setSkill br_ai_skill } forEach units _chopperUnits;
	br_heliGroups append [_chopperUnits];
	_helicopterVech engineOn false;
};

// Gets the LZ for the zone
br_fnc_createLandingSpotNearZone = {
	_pos = [getMarkerPos "ZONE_RADIUS", (br_zone_radius * 2) * sqrt br_max_radius_distance, 600, 24, 0, 0.25, 0] call BIS_fnc_findSafePos;
	[format ["LZ - %1", _heliIndex], _pos, format ["LZ - %1", _heliIndex], "ColorGreen"] call (compile preProcessFile "core\server\functions\fn_createTextMarker.sqf");
	_landMarker = createVehicle [ "Land_HelipadEmpty_F", _pos, [], 0, "CAN_COLLIDE" ];
	_pos;
};

// Gets the LZ for the zone
br_fnc_createLandingSpotLZ = {
	_pos = _this select 0;
	[format ["EVAC - %1", _heliIndex], _pos, format ["EVAC - %1", _heliIndex], "colorCivilian"] call (compile preProcessFile "core\server\functions\fn_createTextMarker.sqf");
	_landMarker = createVehicle [ "Land_HelipadEmpty_F", _pos, [], 0, "CAN_COLLIDE" ];
};

// Get how many units from a group are in the chopper
br_fnc_getUnitsInHeli = {
	_tempGroup = _this select 0;
	_count = 0;
	{ if (_x in _helicopterVech) then {_count = _count + 1}; } forEach (units _tempGroup);
	_count;
};

// Get units alive in a group
br_fnc_getUnitsAlive = {
	_tempGroup = _this select 0;
	_count = 0;
	{ if (alive _x) then {_count = _count + 1}; } forEach (units _tempGroup);
	_count;
};

// Wait for a group to enter the chopper
br_fnc_waitForUntsToEnterChopper = {
	_tempGroup = _this select 0;
	{_x selectweapon primaryWeapon _x; _x setDamage 0} foreach (units _tempGroup);
	waitUntil { {_x in _helicopterVech} count (units _tempGroup) == {(alive _x)} count (units _tempGroup) || [] call br_fnc_checkHeliDead || _helicopterVech emptyPositions "cargo" == 0 };
};

// Tell helicopter to goto and land, wait until this has happened
br_fnc_movetoAndLand = {
	_pos = _this select 0; // Position to land
	// If group already exists delete it
	[] call br_fnc_deleteOldChopperUnit;
	// Create units
	[] call br_fnc_createHeliUnits;
	_helicopterVech setFuel 1;
	_chopperUnits setBehaviour "CARELESS";
	_wp = _chopperUnits addWaypoint [_pos, 0];
	_wp setWaypointType "GETOUT";
	_helicopterVech engineOn true;
	// Wait untill landed
	waitUntil {(getPos _helicopterVech select 2 > 10) || {[] call br_fnc_checkHeliDead} || {!(isEngineOn _helicopterVech)} || {br_zone_taken}};
	// Has landed
	waitUntil {(getPos _helicopterVech select 2 < 1) || {[] call br_fnc_checkHeliDead} || {br_zone_taken}};
	[] call br_fnc_deleteOldChopperUnit;
	_helicopterVech engineOn false;
};

// Find groups waiting for transport
br_fuc_findGroupsInQueue = {
	// Group to append to
	_groups = _this select 0;
	// Number of people
	_Peps = 0;	
	{
		_unitsAlive = [_x] call br_fnc_getUnitsAlive;
		if (_unitsAlive > 0) then {
			if ((_Peps + _unitsAlive) <= _helicopterVech emptyPositions "cargo") then {
				br_friendlyGroupsWaiting deleteAt (br_friendlyGroupsWaiting find _x);
				_groups append [_x];
				_Peps = _Peps + _unitsAlive;
				sleep 3;
			};
		};
	} forEach br_friendlyGroupsWaiting;
	_groups;
};

// Check if any players are waiting at chopper and return them
br_fuc_playersInChopper = {
	_group = [];
	{
		if (_x in _helicopterVech) then { _group append [group _x] };
	} forEach allPlayers;	
	_group;
};

// Go and land at zone
br_fuc_landGroupAtZone = {
	_groups = _this select 0;
	// Add groups to transit
	{ br_groupsInTransit append [_x]; } forEach _groups;
	// Command groups into helicopter
	{ [_x, false] call br_fnc_commandGroupIntoChopper; } forEach _groups;
	// Wait for the units to enter the helicopter
	{ [_x] call br_fnc_waitForUntsToEnterChopper; } forEach _groups;
	// Generate landing zone and move to it and land
	[[] call br_fnc_createLandingSpotNearZone] call br_fnc_movetoAndLand;
	// Tell the groups to getout
	[] call br_fnc_ejectCrew;
	// Wait untill all units are out
	{ waitUntil { [_x] call br_fnc_getUnitsInHeli == 0}; } forEach _groups;
	// Set group as aware
	{ _x setBehaviour "AWARE"; } forEach _groups;	
	// Remove groups from transit
	{ br_groupsInTransit deleteAt (br_groupsInTransit find _x); } forEach _groups;
	// Move groups into commanding zone group
	{ br_FriendlyAIGroups append [_x]; } forEach _groups;
	// Delete un-needed things
	deleteVehicle _landMarker;
	deleteMarker format ["LZ - %1", _heliIndex];
	// Goto helipad and land
	[getMarkerPos _heliPad] call br_fnc_movetoAndLand;
	// Create a temp group
	[] call br_fnc_createHeliUnits;
};

// If the chopper is transport
br_fnc_runTransportChopper = {
	// Check if any groups are waiting
	if (count br_friendlyGroupsWaiting > 0) then {
		_groups = [];
		// Get some waiting groups, if any
		_groups = [_groups] call br_fuc_findGroupsInQueue; 
		if (count _groups > 0) then {
			[_groups] call br_fuc_landGroupAtZone;
		};		
	} else { 
		// Check if any players are waiting in helicopter
		_playersGroups = [] call br_fuc_playersInChopper;
		if (count _playersGroups > 0) then {
			[_playersGroups] call br_fuc_landGroupAtZone;
		};
	};
};

// If the chopper is evac
// using an old system... Takes one group at a time...
br_fnc_runEvacChopper = {
	if ((count br_friendlyGroupsWatingForEvac > 0)) then {
		_group = br_friendlyGroupsWatingForEvac select 0;
		br_friendlyGroupsWatingForEvac deleteAt (br_friendlyGroupsWatingForEvac find _group);
		br_groupsInTransit append [_group];
		_group setBehaviour "SAFE";	
		// Get landing position
		_pos = [getpos (leader _group), 0, 300, 24, 0, 0.25, 0] call BIS_fnc_findSafePos;
		// Create LZ
		[_pos] call br_fnc_createLandingSpotLZ;
		// Moveto LZ
		[_pos] call br_fnc_movetoAndLand;
		// Wait for group to get in
		[_group, false] call br_fnc_commandGroupIntoChopper;
		// Switch groups weapons (Sometimes they just stand holding binoculars and won't get in..)
		{_x selectweapon primaryWeapon _x} foreach (units _group);
		// Wait untill units are in
		waitUntil { {{_x in _helicopterVech} count (units _group) == {(alive _x)} count (units _group)} || {[] call br_fnc_checkHeliDead} || {_helicopterVech emptyPositions "cargo" == 0} };
		// Delete LZ
		deleteVehicle _landMarker;
		deleteMarker format ["EVAC - %1", _heliIndex];
		// Move back to base
		[getMarkerPos _heliPad] call br_fnc_movetoAndLand;
		// Eject the crew at base
		[] call br_fnc_ejectCrew;
		// Wait untill chopper is empty
		waitUntil { {_x in _helicopterVech} count (units _group) == 0};
		// Move group to waiting groups
		br_friendlyGroupsWaiting append [_group];
		// Delete from transit group
		br_groupsInTransit deleteAt (br_groupsInTransit find _group);
		[] call br_fnc_createHeliUnits;	
	};
};

// Run AI
br_fnc_createHelis = {
	// Create the base helipad
	[] call br_fnc_createHeliPad;
	while {True} do {
		// Create chopper units
		[] call br_fnc_createChopperUnit;
		// Check if units inside chopper are dead, or helicopter is dead or pilot ran away
		while {({(alive _x)} count (units _chopperUnits) > 0) && {(alive _helicopterVech)} && {(((leader _chopperUnits) distance _helicopterVech) < 30)};} do {
			sleep 10;
			if (_evacChopper) then { [] call br_fnc_runEvacChopper; } else { [] call br_fnc_runTransportChopper; };
			_helicopterVech setFuel 1;
			_helicopterVech setDamage 0;
		};
		sleep 15;
		// Do the below because the heli died or some bullcrap happened
		[] call br_fnc_deleteOldChopperUnit;
		deleteVehicle _helicopterVech;
	};
};

[] call br_fnc_createHelis;