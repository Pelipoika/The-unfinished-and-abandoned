#include <sdktools>
#include <tf2>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Revive Marker Imitator",
	author = "Pelipoika",
	description = "Imitates the healing of a revive marker",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_addmarkerhealth", Command_Add);
}

public Action Command_Add(int client, int args)
{
	char strHP[8];
	GetCmdArgString(strHP, sizeof(strHP));
	
	int iHP = StringToInt(strHP);

	int index = -1;
	while ((index = FindEntityByClassname(index, "entity_revive_marker")) != -1)
	{
		TF2_AddMarkerHealth(client, index, iHP);
	}
	
	return Plugin_Handled;
}

stock bool TF2_AddMarkerHealth(int iReviver, int iMarker, int iHealthAdd)
{
	int iHealth = GetEntProp(iMarker, Prop_Send, "m_iHealth");
	int iMaxHealth = GetEntProp(iMarker, Prop_Send, "m_iMaxHealth");
	int iOwner = GetEntPropEnt(iMarker, Prop_Send, "m_hOwner");
	
	SetEntProp(iMarker, Prop_Send, "m_iHealth", iHealth + iHealthAdd);
	iHealth += iHealthAdd;
	
	if(iHealth >= iMaxHealth && IsClientInGame(iOwner))
	{
		//Do revive
		float vecMarkerPos[3];
		GetEntPropVector(iMarker, Prop_Send, "m_vecOrigin", vecMarkerPos);
		
		EmitGameSoundToAll("MVM.PlayerRevived", iMarker);
		
		float flMins[3], flMaxs[3];
		GetEntPropVector(iOwner, Prop_Send, "m_vecMaxs", flMaxs);
		GetEntPropVector(iOwner, Prop_Send, "m_vecMins", flMins);
		
		Handle TraceRay = TR_TraceHullFilterEx(vecMarkerPos, vecMarkerPos, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterNotSelf, iMarker);
		if(TR_DidHit(TraceRay)) //Can't spawn the player here or they would get stuck, teleport to reviver.
		{
			float vecReviverPos[3];
			GetClientAbsOrigin(iReviver, vecReviverPos);
			
			TF2_RespawnPlayer(iOwner);
			TeleportEntity(iOwner, vecReviverPos, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			TF2_RespawnPlayer(iOwner);
			TeleportEntity(iOwner, vecMarkerPos, NULL_VECTOR, NULL_VECTOR);
		}
		
		delete TraceRay;
		
		return true;
	}
	
	return false;
}

public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entity == 0 && entityhit != entity)
		return true;
	
	return false;
}