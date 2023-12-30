#include "script_component.hpp"
#include "\A3\ui_f_curator\ui\defineResinclDesign.inc"

params ["_logic","_synced"];

if (!local _logic) exitWith {};

[{
	params ["_logic","_synced"];

	if (isNull findDisplay IDD_RSCDISPLAYCURATOR) then {
		private _entity = [
			_logic getVariable ["AircraftClass",""],
			[west,east,independent] # (_logic getVariable ["Side",0]),
			_logic getVariable ["Callsign",""],
			[_logic getVariable ["Cooldown",60],_logic getVariable ["ItemCooldown",10]],
			_logic getVariable ["Altitude",500],
			_logic getVariable ["VirtualRunway",[0,0,0]],
			_logic getVariable ["SpawnDistance",6000],
			_logic getVariable ["SpawnDelay",[0,0]],
			_logic getVariable ["OpenAltitudeAI",-1],
			_logic getVariable ["OpenAltitudeObjects",-1],
			_logic getVariable ["Capacity",10],
			synchronizedObjects _logic select {_x isKindOf QGVAR(moduleReferenceArea)},
			_logic getVariable ["ListFunction",""],
			_logic getVariable ["ItemInit",""],
			_logic getVariable ["VehicleInit",""],
			_logic getVariable ["RemoteAccess",true],
			[_logic getVariable ["AccessItems","itemMap"]] call EFUNC(common,parseList),
			_logic getVariable ["AccessItemsLogic",0] isEqualTo 1,
			_logic getVariable ["AccessCondition","true"],
			_logic getVariable ["RequestCondition","true"],
			[_logic getVariable [QPVAR(auth),""]] call EFUNC(common,parseArray)
		] call FUNC(addAirdrop);

		[_logic,_entity] call EFUNC(common,addTerminals);
	} else {
		private _vehicle = attachedTo _logic;

		if (alive _vehicle && _vehicle isKindOf "Air") then {
			typeOf _vehicle call FUNC(moduleAddAirdrop_zeus);
		} else {
			"" call FUNC(moduleAddAirdrop_zeus);
		};
	};

	deleteVehicle _logic;
},_this] call CBA_fnc_execNextFrame;