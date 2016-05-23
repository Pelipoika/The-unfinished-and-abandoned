#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

static int g_iPlayerMarker[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... }; 
bool g_bDontSpawn[MAXPLAYERS + 1];

public void OnPluginStart() 
{
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_team", Event_OnPlayerTeam);
}

public void OnClientPutInServer(int client)
{
	g_iPlayerMarker[client] = INVALID_ENT_REFERENCE;
	g_bDontSpawn[client] = false;
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontbroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int iFlags = GetEventInt(event, "death_flags");
	
	if(iFlags & TF_DEATHFLAG_DEADRINGER) 
		return;

	if(!g_bDontSpawn[client])
		spawnReviveMarker(client);
	
	g_bDontSpawn[client] = false;
}

public Action Event_OnPlayerTeam(Handle event, const char[] name, bool dontbroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_bDontSpawn[client] = true;
}

public Action Event_OnPlayerSpawn(Handle event, const char[] name, bool dontbroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	int ent = EntRefToEntIndex(g_iPlayerMarker[client]);
	if (ent && ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Kill");
	}
	
	g_iPlayerMarker[client] = INVALID_ENT_REFERENCE;
}

public void spawnReviveMarker(int client) 
{
	float flPos[3], flAng[3];
	GetClientAbsOrigin(client, flPos);
	GetClientAbsAngles(client, flAng);
	
	int reviveMarker = CreateEntityByName("entity_revive_marker");
	if (IsValidEntity(reviveMarker)) 
	{
		DispatchKeyValueVector(reviveMarker, "origin", flPos);
		DispatchKeyValueVector(reviveMarker, "angles", flAng);
		
		//Just in case it doesnt despawn for some reason
		SetVariantString("OnUser1 !self:kill::30:1");
		AcceptEntityInput(reviveMarker, "AddOutput");
		AcceptEntityInput(reviveMarker, "FireUser1");
		
		SetEntPropEnt(reviveMarker, Prop_Send, "m_hOwner", client);
		SetEntProp(reviveMarker, Prop_Send, "m_nSolidType", 2);
		SetEntProp(reviveMarker, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(reviveMarker, Prop_Send, "m_fEffects", 16);
		SetEntProp(reviveMarker, Prop_Send, "m_iTeamNum", GetClientTeam(client));
		SetEntProp(reviveMarker, Prop_Send, "m_CollisionGroup", 1);
		SetEntProp(reviveMarker, Prop_Send, "m_bSimulatedEveryTick", 1);
		SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin") + 4, reviveMarker);
		SetEntProp(reviveMarker, Prop_Send, "m_nBody", (view_as<int>(TF2_GetPlayerClass(client))) - 1);
		SetEntProp(reviveMarker, Prop_Send, "m_nSequence", 1);
		SetEntPropFloat(reviveMarker, Prop_Send, "m_flPlaybackRate", 1.0);
		SetEntProp(reviveMarker, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));
		if(TF2_GetClientTeam(client) == TFTeam_Blue)
			SetEntityRenderColor(reviveMarker, 0, 0, 255); // make the BLU Revive Marker distinguishable from the red one
		
		DispatchSpawn(reviveMarker);
		
		g_iPlayerMarker[client] = EntIndexToEntRef(reviveMarker);
	}
}