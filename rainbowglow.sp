#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

int g_iPlayerGlowEntity[MAXPLAYERS + 1];

ConVar g_hRainbowCycleRate;

public Plugin myinfo = 
{
	name = "[TF2] Rainbow Glow",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_rainbowme", Command_Rainbow, ADMFLAG_ROOT);
	
	g_hRainbowCycleRate = CreateConVar("sm_rainbow_cycle_rate", "1.0", "Constrols the speed of which the rainbow glow changes color");
}

public void OnPluginEnd()
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, "RainbowGlow"))
		{
			AcceptEntityInput(index, "Kill");
		}
	}
}

public Action Command_Rainbow(int client, int argc)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if(!TF2_HasGlow(client))
		{	
			int iGlow = TF2_CreateGlow(client);
			if(IsValidEntity(iGlow))
			{
				g_iPlayerGlowEntity[client] = EntIndexToEntRef(iGlow);
				SDKHook(client, SDKHook_PreThink, OnPlayerThink);
			}
		}
		else
		{
			int iGlow = g_iPlayerGlowEntity[client];
			if(iGlow != INVALID_ENT_REFERENCE)
			{
				AcceptEntityInput(iGlow, "Kill");
				g_iPlayerGlowEntity[client] = INVALID_ENT_REFERENCE;
				SDKUnhook(client, SDKHook_PreThink, OnPlayerThink);
			}
		}
	}

	return Plugin_Handled;
}

public Action OnPlayerThink(int client)
{
	int iGlow = EntRefToEntIndex(g_iPlayerGlowEntity[client]);
	if(iGlow != INVALID_ENT_REFERENCE)
	{
		char strGlowColor[18];
		
		float flRate = g_hRainbowCycleRate.FloatValue;
		
		int red = RoundToNearest(Cosine((GetGameTime() * flRate) + client + 0) * 127.5 + 127.5);
		int grn = RoundToNearest(Cosine((GetGameTime() * flRate) + client + 2) * 127.5 + 127.5);
		int blu = RoundToNearest(Cosine((GetGameTime() * flRate) + client + 4) * 127.5 + 127.5);
		
		Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", red, grn, blu, 255);
		
		PrintCenterText(client, "%s", strGlowColor);
		
		SetVariantString(strGlowColor);
		AcceptEntityInput(iGlow, "SetGlowColor");
	}
}

stock int TF2_CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));

	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	char strGlowColor[18];
	Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(180, 255));
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchKeyValue(ent, "GlowColor", strGlowColor);
	DispatchSpawn(ent);
	
	AcceptEntityInput(ent, "Enable");
	
	//Change name back to old name because we don't need it anymore.
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);

	return ent;
}

stock bool TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return true;
		}
	}
	
	return false;
}