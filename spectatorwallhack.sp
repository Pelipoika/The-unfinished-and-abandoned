#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>

static g_iPlayerInteractiveGlowEntity[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
static g_iBuildingInteractiveGlowEntity[2049] = { INVALID_ENT_REFERENCE, ... };

bool g_bWallHack[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[TF2] Wallhacks",
	author = "Pelipoika",
	description = "Wallhack for Pelipoika.",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	for(int i = 0; i <= MaxClients; i++)
	{
		if(i > 0 && i <= MaxClients && IsClientInGame(i))
			g_bWallHack[i] = false;
	}
	
	RegAdminCmd("sm_wallhack", Command_Glow, ADMFLAG_ROOT);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_builtobject", OnObjectBuilt);
}	

public void OnClientPutInServer(int client)
{
	g_bWallHack[client] = false;
}

public Action Event_PlayerSpawn(Handle hEvent, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if(TF2_GetClientTeam(client) == TFTeam_Spectator)
		{
			ClientRemoveInteractiveGlow(client);
		}
		else
		{
			ClientCreateInteractiveGlow(client);
		}
	}
	
	return Plugin_Continue;
}

public Action OnObjectBuilt(Handle event, const char[] name, bool dontBroadcast)	//Object built
{
	int objectEnt = GetEventInt(event,"index");
	int objectType = GetEventInt(event, "object");

	if (objectType == view_as<int>TFObject_Sapper)
		return;
	
	if (IsValidEntity(objectEnt))
	{
		CreateTimer(0.1, Timer_GlowTest, EntIndexToEntRef(objectEnt));
	}
}

public Action Command_Glow(int client, int args)
{
	if(!g_bWallHack[client])
	{
		PrintToChat(client, "Wallhack: On");
		g_bWallHack[client] = true;
	}
	else
	{
		PrintToChat(client, "Wallhack: Off");
		g_bWallHack[client] = false;	
	}

	return Plugin_Handled;
}

bool BuildingCreateInteractiveGlow(int iEnt)
{
	int glow = EntRefToEntIndex(g_iBuildingInteractiveGlowEntity[iEnt]);
	if (glow && glow != INVALID_ENT_REFERENCE)
	{		
		char iBuildingModel[PLATFORM_MAX_PATH], iBuildingGlowModel[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", iBuildingModel, sizeof(iBuildingModel));
		GetEntPropString(glow, Prop_Data, "m_ModelName", iBuildingGlowModel, sizeof(iBuildingGlowModel));
		
		if(strcmp(iBuildingModel, iBuildingGlowModel) == 0)
			return false;
		else
			AcceptEntityInput(glow, "Kill");
	}
	
	g_iBuildingInteractiveGlowEntity[iEnt] = INVALID_ENT_REFERENCE;

	char sBuffer[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));
	
	if (strlen(sBuffer) == 0) 
		return false;
	
	int ent = CreateEntityByName("obj_dispenser");
	if (ent != -1)
	{
		float flModelScale = GetEntPropFloat(iEnt, Prop_Send, "m_flModelScale");
		
		DispatchKeyValue(ent, "targetname", "bESP");
		DispatchSpawn(ent);

		SetEntityModel(ent, sBuffer);
		
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		SetEntityRenderColor(ent, 0, 0, 0, 0);
		
		SetEntProp(ent, Prop_Send, "m_bGlowEnabled", 1);
		SetEntProp(ent, Prop_Send, "m_bDisabled", 1);
		SetEntProp(ent, Prop_Data, "m_takedamage", 0);
		SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(ent, Prop_Send, "m_nBody", GetEntProp(iEnt, Prop_Send, "m_nBody"));
		SetEntProp(ent, Prop_Send, "m_iTeamNum", GetEntProp(iEnt, Prop_Send, "m_iTeamNum"));
		SetEntPropFloat(ent, Prop_Send, "m_flModelScale", flModelScale);

		int iFlags = GetEntProp(ent, Prop_Send, "m_fEffects");
		SetEntProp(ent, Prop_Send, "m_fEffects", iFlags | (1 << 0) | (1 << 4) | (1 << 9));

		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", iEnt);
		
		SDKHook(ent, SDKHook_SetTransmit, Hook_InterativeGlowSetTransmit);
		
		g_iBuildingInteractiveGlowEntity[iEnt] = EntIndexToEntRef(ent);
		
		return true;
	}

	return false;
}

public Action Timer_GlowTest(Handle timer, any entity)
{
	int ent = EntRefToEntIndex(entity);
	
	if (ent != INVALID_ENT_REFERENCE)
	{
		BuildingCreateInteractiveGlow(ent);
		
		CreateTimer(0.1, Timer_GlowTest, EntIndexToEntRef(ent));
	}
}

bool ClientCreateInteractiveGlow(int iEnt)
{
	ClientRemoveInteractiveGlow(iEnt);
	
	if (!iEnt || !IsValidEntity(iEnt)) return false;
	
	char sBuffer[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));
	
	if (strlen(sBuffer) == 0) 
		return false;
	
	int ent = CreateEntityByName("obj_dispenser");
	if (ent != -1)
	{
		g_iPlayerInteractiveGlowEntity[iEnt] = EntIndexToEntRef(ent);
			
		float flModelScale = GetEntPropFloat(iEnt, Prop_Send, "m_flModelScale");
		
		DispatchKeyValue(ent, "targetname", "ESP");
		DispatchSpawn(ent);

		SetEntityModel(ent, sBuffer);
		
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		SetEntityRenderColor(ent, 0, 0, 0, 0);
		
		SetEntProp(ent, Prop_Send, "m_bGlowEnabled", 1);
		SetEntProp(ent, Prop_Send, "m_bDisabled", 1);
		SetEntProp(ent, Prop_Data, "m_takedamage", 0);
		SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(ent, Prop_Send, "m_nBody", GetEntProp(iEnt, Prop_Send, "m_nBody"));
		SetEntProp(ent, Prop_Send, "m_iTeamNum", GetEntProp(iEnt, Prop_Send, "m_iTeamNum"));
		SetEntPropFloat(ent, Prop_Send, "m_flModelScale", flModelScale);

		int iFlags = GetEntProp(ent, Prop_Send, "m_fEffects");
		SetEntProp(ent, Prop_Send, "m_fEffects", iFlags | (1 << 0) | (1 << 4) | (1 << 9));

		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", iEnt);
		
		SDKHook(ent, SDKHook_SetTransmit, Hook_InterativeGlowSetTransmit);

		return true;
	}

	return false;
}

void ClientRemoveInteractiveGlow(int client)
{
	int ent = EntRefToEntIndex(g_iPlayerInteractiveGlowEntity[client]);
	if (ent && ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Kill");
	}
	
	g_iPlayerInteractiveGlowEntity[client] = INVALID_ENT_REFERENCE;
}

public Action Hook_InterativeGlowSetTransmit(int ent, int other)
{
	if(other > 0 && other <= MaxClients && IsClientInGame(other))
	{
		if(!g_bWallHack[other])
		{
			return Plugin_Handled;
		}	
	}

	return Plugin_Continue;
}