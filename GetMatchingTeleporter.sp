#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	RegAdminCmd("sm_getmatching", Command_Get, ADMFLAG_ROOT);
}

public Action Command_Get(int client, int args)
{
	if(client <= 0 || client > MaxClients)
		return Plugin_Handled;

	int target = GetClientAimTarget(client, false);
	if(!IsValidEntity(target) || !HasEntProp(target, Prop_Send, "m_bMatchBuilding"))
		return Plugin_Handled;
		
	//Windows 2748
	//Linux 2768
	
	int offset = FindSendPropInfo("CObjectTeleporter", "m_bMatchBuilding");
	offset += 4;
	
	int m_hMatchingTeleporter = GetEntDataEnt2(target, offset);
	ReplyToCommand(client, "Matching teleporter of teleporter %i is %i", target, m_hMatchingTeleporter);

	return Plugin_Handled;
}