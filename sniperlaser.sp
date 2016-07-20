#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required

#define LASERBEAM "sprites/laserbeam.vmt"

ConVar g_cvarLaserEnabled;

int g_iEyeProp[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[TF2] Sniperlaser",
	author = "Pelipoika",
	description = "Sniper rifles emit lasers",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	g_cvarLaserEnabled = CreateConVar("tf2_sniperlaser_enabled", "1", "Sniper rifles emit lasers", _, true, 0.0, true, 1.0);
}

public void OnMapStart()
{
	PrecacheModel(LASERBEAM);
}

public void OnClientPutInServer(int client)
{
	g_iEyeProp[client] = INVALID_ENT_REFERENCE;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "env_sniperdot") && g_cvarLaserEnabled.BoolValue)
	{
		SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
	}
}

public Action SpawnPost(int entity)
{
	RequestFrame(SpawnPostPost, entity);	
}

public void SpawnPostPost(int ent)
{
	if (IsValidEntity(ent))
	{
		int client = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		if(client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			TFTeam iTeam = TF2_GetClientTeam(client);
			
			switch(iTeam)
			{
				case TFTeam_Red:  ConnectWithBeam(client, ent, 255, 0, 0, 0.75, 1.0);
				case TFTeam_Blue: ConnectWithBeam(client, ent, 0, 0, 255, 0.75, 1.0);
				default:          ConnectWithBeam(client, ent, 255, 255, 255, 1.0, 1.0);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if(TF2_GetPlayerClass(client) == TFClass_Sniper && condition == TFCond_Zoomed)
	{
		int iEyeProp = EntRefToEntIndex(g_iEyeProp[client])
		if(iEyeProp != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(iEyeProp, "ClearParent");
			AcceptEntityInput(iEyeProp, "Kill");
			
			g_iEyeProp[client] = INVALID_ENT_REFERENCE;
		}
	}
}

stock int ConnectWithBeam(int client, int iEnt2, int iRed = 255, int iGreen = 255, int iBlue = 255, float fStartWidth = 1.0, float fEndWidth = 1.0)
{
	int iEyeAttachment = CreateEntityByName("info_target");
	DispatchSpawn(iEyeAttachment);
	
	SetVariantString("!activator");
	AcceptEntityInput(iEyeAttachment, "SetParent", client);
	
	SetVariantString("righteye");
	AcceptEntityInput(iEyeAttachment, "SetParentAttachment", client);
	
	g_iEyeProp[client] = EntIndexToEntRef(iEyeAttachment);
	
	int iBeam = CreateEntityByName("env_beam");
	SetEntityModel(iBeam, LASERBEAM);
	
	char sColor[16];
	Format(sColor, sizeof(sColor), "%d %d %d 1", iRed, iGreen, iBlue);
	
	DispatchKeyValue(iBeam, "rendercolor", sColor);
	DispatchKeyValue(iBeam, "life", "0");
	DispatchSpawn(iBeam);
	
	SetEntPropEnt(iBeam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(iEyeAttachment));
	SetEntPropEnt(iBeam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(iEnt2), 1);
	SetEntProp(iBeam, Prop_Send, "m_nNumBeamEnts", 2);
	SetEntProp(iBeam, Prop_Send, "m_nBeamType", 2);
	SetEntPropFloat(iBeam, Prop_Data, "m_fWidth", fStartWidth);
	SetEntPropFloat(iBeam, Prop_Data, "m_fEndWidth", fEndWidth);

	AcceptEntityInput(iBeam, "TurnOn");
	
	SetVariantString("!activator");
	AcceptEntityInput(iBeam, "SetParent", iEnt2);
	
	return iBeam;
}