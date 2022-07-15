#include <sourcemod>
#include <sdktools>

/*
Signature for CWeaponCSBase__GetCSWpnData:
55 8B EC 81 EC 0C 01 00 00 53 8B D9 
\x55\x8B\xEC\x81\xEC\x0C\x01\x00\x00\x53\x8B\xD9
*/

Handle g_hGetCSWpnData;
Handle g_hGetDamage;

public void OnPluginStart()
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x81\xEC\x0C\x01\x00\x00\x53\x8B\xD9", 12);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Pointer);
	if ((g_hGetCSWpnData = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CWeaponCSBase::GetCSWpnData signature!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(402);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if ((g_hGetDamage = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for g_hGetDamage signature!");
	
	RegConsoleCmd("sm_weapondata", Command_Data);
}

public Action Command_Data(int client, int args)
{
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(!IsValidEntity(weapon))
		return Plugin_Handled;

	Address weapondata = SDKCall(g_hGetCSWpnData, weapon);
	
	PrintToServer("weapondata 0x%X", weapondata);
	
	float dmg = SDKCall(g_hGetDamage, weapon);
	PrintToServer("damage %f", dmg);

	return Plugin_Handled;
}