#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
#include "\a3\3den\ui\resincl.inc"
#include "cba_settings.sqf"
#include "command_events.sqf"

if (isServer && is3DEN) then {
	if !(uiNamespace getVariable [QGVAR(edenEH),false]) then {
		private _edenDisplay = findDisplay IDD_DISPLAY3DEN;

		// Mark Eden display as cleared if it unloads. 
		_edenDisplay displayAddEventHandler ["Unload",{
			uiNamespace setVariable [QGVAR(edenEH),false];
			false
		}];

		add3DENEventHandler ["OnPaste",{
			{
				if ((_x get3DENAttribute QPVAR(key)) isNotEqualTo []) then {
					_x set3DENAttribute [QPVAR(key),""];
				};
			} forEach (get3DENSelected "object");

			{
				if ((_x get3DENAttribute QPVAR(auth)) isNotEqualTo []) then {
					_x set3DENAttribute [QPVAR(auth),""];
				};
			} forEach (get3DENSelected "logic");
		}];

		add3DENEventHandler ["OnDeleteUnits",{
			{_x call FUNC(authorizeConnections)} forEach (all3DENEntities # 3);
		}];

		uiNamespace setVariable [QGVAR(edenEH),true];
	};

	[QGVAR(reinitialize)] collect3DENHistory {
		{if (_x isKindOf "Module_F") then {_x call FUNC(initModule)}} forEach (all3DENEntities # 3);
	};

	[QGVAR(ConnectionChanged3DEN),FUNC(authorizeConnections)] call CBA_fnc_addEventHandler;
};

if (isServer) then {
	GVAR(services) = createHashMapFromArray (configProperties [configFile >> QPVAR(services),"isClass _x"] apply {
		[toUpper configName _x,[]]
	});

	publicVariable QGVAR(services);

	[QGVAR(addWaypointServer),{
		params ["_WP","_behaviour","_combatMode","_speed","_formation"];

		_WP setWaypointBehaviour _behaviour;
		_WP setWaypointCombatMode _combatMode;
		_WP setWaypointSpeed _speed;
		_WP setWaypointFormation _formation;
	}] call CBA_fnc_addEventHandler;

	[QGVAR(updateMarker),FUNC(updateMarker)] call CBA_fnc_addEventHandler;
	[QGVAR(respawn),FUNC(respawn)] call CBA_fnc_addEventHandler;

	[QGVAR(remoteControlTransfer),{
		params ["_unit","_clientID"];

		[{
			params ["_unit","_clientID","_ownerID"];
			_clientID == owner _unit || _ownerID != owner _unit
		},{
			[{
				params ["_unit","","","_startTime"];
				[QGVAR(remoteControlTransferred),[_unit,ceil (CBA_missionTime - _startTime)],_unit] call CBA_fnc_targetEvent;
			},_this,1] call CBA_fnc_waitAndExecute;
		},[_unit,_clientID,owner _unit,CBA_missionTime],30] call CBA_fnc_waitUntilAndExecute;
	}] call CBA_fnc_addEventHandler;
};

[QGVAR(execute),{
	params ["_args",["_fnc","",["",{}]]];

	if (_fnc isEqualType "") then {
		_args call (missionNamespace getVariable [_fnc,{}]);
	} else {
		_args call _fnc;
	}
}] call CBA_fnc_addEventHandler;

[QGVAR(notify),FUNC(notify)] call CBA_fnc_addEventHandler;

[QGVAR(tempMarkerCreated),{
	params ["_entity","_marker","_message","_lifetime"];

	[{
		params ["_args","_PFHID"];
		_args params ["_entity","_marker","_message","_timeout"];

		if (isNull _entity || _timeout < CBA_missionTime || getMarkerColor _marker isEqualTo "") exitWith {
			_PFHID call CBA_fnc_removePerFrameHandler;

			if (isServer) then {
				_marker call CBA_fnc_removeGlobalEventJIP;
				deleteMarker _marker;
				
				if (!isNull _entity) then {
					private _tempMarkers = _entity getVariable [QPVAR(tempMarkers),[]];
					_tempMarkers deleteAt (_tempMarkers find _marker);
					_entity setVariable [QPVAR(tempMarkers),_tempMarkers];
				};
			};
		};

		// Run this every second in case player switches sides
		if (side group player == (_entity getVariable QPVAR(side))) then {
			_marker setMarkerTextLocal (_message call FUNC(parseMessage));
			_marker setMarkerAlphaLocal 0.8;
		} else {
			_marker setMarkerAlphaLocal 0;
		};
	},1,[_entity,_marker,_message,CBA_missionTime + _lifetime]] call CBA_fnc_addPerFrameHandler;
}] call CBA_fnc_addEventHandler;

[QGVAR(markerUpdate),{
	params ["_entity","_marker","_message"];

	private _inScope = switch OPTION(markerScope) do {
		case "REQUESTER" : {[player,_entity] call FUNC(isAuthorized) && player == _entity getVariable [QPVAR(requester),objNull]};
		case "ACCESS" : {[player,_entity] call FUNC(isAuthorized)};
		case "SIDE" : {side group player == _entity getVariable [QPVAR(side),sideUnknown]};
		default {false};
	};

	if (_inScope) then {
		_marker setMarkerTextLocal (_message call FUNC(parseMessage));
		_marker setMarkerAlphaLocal 0.8;
	} else {
		_marker setMarkerAlphaLocal 0;
	};
}] call CBA_fnc_addEventHandler;

[QPVAR(guiOpen),{
	params ["_service","_entity"];

	private _display = uiNamespace getVariable [QEGVAR(sdf,display),displayNull];

	if (isNull _display) exitWith {};

	_display displayAddEventHandler ["KeyDown",{
		if (_this # 1 == 1) then {true call FUNC(gui_close)};
		false
	}];

	_display displayAddEventHandler ["Unload",{
		params ["_display"];
		[QPVAR(guiUnload),[GVAR(guiService),PVAR(guiEntity)]] call CBA_fnc_localEvent;
		PVAR(terminalEntity) = [PVAR(terminalEntity),objNull] select (_display getVariable [QPVAR(resetTerminalEntity),true]);
		DELETE_GUI_MARKERS;
	}];
}] call CBA_fnc_addEventHandler;

[QGVAR(terminal),{
	params ["_terminal","_entity"];

	if (OPTION(terminalActions) in ["BOTH","ACE"]) then {
		private _action = [_entity getVariable QPVAR(service),_entity getVariable QPVAR(callsign),ICON_SSS/*_entity getVariable QPVAR(icon)*/,{
			params ["_target","_player","_entity"];
			[_entity getVariable QPVAR(service),_entity,true] call EFUNC(common,openGUI);
		},{
			params ["_target","_player","_entity"];
			alive _target && {[_player,_entity,true] call EFUNC(common,isAuthorized)}
		},{},_entity] call ace_interact_menu_fnc_createAction;

		[_terminal,0,["ACE_MainActions"],_action] call ace_interact_menu_fnc_addActionToObject;
		[_terminal,1,["ACE_SelfActions"],_action] call ace_interact_menu_fnc_addActionToObject;
	};
	
	if (OPTION(terminalActions) in ["BOTH","VANILLA"]) then {
		private _actionID = _terminal addAction [
			format ["<img image='%1'/>%2",ICON_SSS,_entity getVariable QPVAR(callsign)],
			{
				params ["","","","_entity"];
				[_entity getVariable QPVAR(service),_entity,true] call EFUNC(common,openGUI);
			},
			_entity,
			10,
			false,
			true,
			"",
			QUOTE(alive _originalTarget && {[ARR_3(_this,_originalTarget getVariable str _actionID,true)] call EFUNC(common,isAuthorized)}),
			5
		];

		_terminal setVariable [str _actionID,_entity];
	};
}] call CBA_fnc_addEventHandler;

{animationState _this isEqualTo QPVAR(fastrope)} call emr_fnc_addWalkableSurfaceExitCondition; // mod compat
[QGVAR(fastroping),FUNC(fastropeUnitLocal)] call CBA_fnc_addEventHandler;
[QGVAR(fastropingDone),{
	params ["_unit","_vehicle"];
	_vehicle setVariable [QPVAR(fastropeUnits),(_vehicle getVariable [QPVAR(fastropeUnits),[]]) - [_unit],true];
}] call CBA_fnc_addEventHandler;

GVAR(slingLoadConditions) = [];

["ModuleCurator_F","init",{
	params ["_logic"];
	_logic addEventHandler ["CuratorObjectSelectionChanged",{
		params ["_logic","_object"];
		
		if (isNil {_object getVariable QGVAR(drawShape3D)}) then {
			false call FUNC(drawShape3D);
		} else {
			(_object getVariable QGVAR(drawShape3D)) call FUNC(drawShape3D);

			[{!(_this in curatorSelected # 0)},{
				if (curatorSelected # 0 isEqualTo []) then {
					false call FUNC(drawShape3D);
				};
			},_object] call CBA_fnc_waitUntilAndExecute;
		};
	}];
	_logic addEventHandler ["CuratorObjectEdited",{
		params ["_logic","_object"];
		(_object getVariable [QGVAR(drawShape3D),false]) call FUNC(drawShape3D);
	}];
	_logic addEventHandler ["CuratorObjectDeleted",{
		params ["_logic","_object"];
		
	}];
}] call CBA_fnc_addClassEventHandler;

[QGVAR(zeusDisplayUnload),{false call FUNC(drawShape3D)}] call CBA_fnc_addEventHandler;

// DEBUG
FUNC(logRequestData) = {
	params ["_player","_entity","_request","_event"];
	
	diag_log text ("SSS: Request " + _event);
	diag_log text ("    Service: " + (_entity getVariable QPVAR(service)));
	diag_log text ("    Type: " + (_entity getVariable QPVAR(supportType)));
	diag_log text ("    Callsign: " + (_entity getVariable QPVAR(callsign)));
	diag_log text ("    Class: " + (_entity getVariable QPVAR(class)));
	diag_log text ("    Parameters: " + str _this);
};

[QPVAR(requestSubmitted),{(_this + ["Submitted"]) call FUNC(logRequestData)}] call CBA_fnc_addEventHandler;
[QPVAR(requestAborted),{(_this + ["Aborted"]) call FUNC(logRequestData)}] call CBA_fnc_addEventHandler;
[QPVAR(requestCompleted),{(_this + ["Completed"]) call FUNC(logRequestData)}] call CBA_fnc_addEventHandler;

//[cameraOn,[0,-15,-5]] call sss_common_fnc_cam
FUNC(cam) = {
	params ["_vehicle",["_offset",[0,0,0]]];

	if (!isNil QGVAR(cam)) then {
		switchCamera _vehicle;
		deleteVehicle GVAR(cam);
	};

	GVAR(cam) = "camera" camCreate [0,0,0];	
	GVAR(cam) attachTo [_vehicle,_offset];
	GVAR(cam) camSetTarget _vehicle;
	GVAR(cam) camCommit 0;
	switchCamera GVAR(cam);
};

// STRAFE
#include "strafeElevationOffsets.sqf"

GVAR(ignoredWeapons) = ["rhs_weap_fcs"];

[QGVAR(strafeApproach),{
	params ["_vehicle"];
	NOTIFY(_vehicle,LSTRING(strafeFinalApproach));
}] call CBA_fnc_addEventHandler;

[QGVAR(strafeFireReady),{
	params ["_vehicle","_fireStart"];
	if !(_vehicle getVariable [QGVAR(strafeCountermeasures),true]) exitWith {};
	[_vehicle,1.5,0.1] call FUNC(fireCountermeasures);
}] call CBA_fnc_addEventHandler;

[QGVAR(strafeCleanup),{
	params ["_vehicle","_completed"];
	if (!_completed || !(_vehicle getVariable [QGVAR(strafeCountermeasures),true])) exitWith {};
	[_vehicle,1.5,0.1] call FUNC(fireCountermeasures);
}] call CBA_fnc_addEventHandler;

// REMOTE CONTROL
[QGVAR(remoteControlTransferred),{
	params ["_unit","_elapsedTime"];
	DEBUG_1("Locality transferred. [%1s]",_elapsedTime);
}] call CBA_fnc_addEventHandler;

ADDON = true;
