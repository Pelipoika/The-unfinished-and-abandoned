#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

float g_flModelScale[MAXPLAYERS + 1];
bool g_bResized[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] Auto Resize",
	author = "Pelipoika",
	description = "Automatically resize large players to make them fit through low ceilings",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon)
{
	if(!IsPlayerAlive(client))
		return Plugin_Continue;

	float flModelScale = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
	if(!g_bResized[client])
		g_flModelScale[client] = flModelScale;
	
	//Default player mins/maxs (flModelScale 1.0)
	float flMins[3] = {-24.0, -24.0, 0.0};
	float flMaxs[3] = {24.0, 24.0, 82.0};
	
	ScaleVector(flMaxs, g_flModelScale[client]);
	ScaleVector(flMins, g_flModelScale[client]);
	
	float flPosition[3], flAngles[3];
	GetClientAbsOrigin(client, flPosition);
	GetClientEyeAngles(client, flAngles);
	flAngles[0] = 0.0;
	
	flMaxs[0] += 2.5;
	flMaxs[1] += 2.5;
	flMins[0] -= 2.5;
	flMins[1] -= 2.5;
	
	//If you uncomment this the player wont get resized walking down / up hills but will ocasionally get stuck
//	flPosition[2] += 18.0;
	
	Handle TraceRay = TR_TraceHullFilterEx(flPosition, flPosition, flMins, flMaxs, MASK_ALL, TraceFilterSelf, client);
	bool bHit = TR_DidHit(TraceRay);
	delete TraceRay;
	
	float flOriginalPos[3];
	GetClientAbsOrigin(client, flOriginalPos);
	
	if (bHit && !g_bResized[client])
	{
		SetVariantString("1.0");
		AcceptEntityInput(client, "SetModelScale");
		
		g_bResized[client] = true;
	}
	else if(!bHit && g_bResized[client])
	{
		char strSize[8];
		FloatToString(g_flModelScale[client], strSize, sizeof(strSize));
		
		SetVariantString(strSize);
		AcceptEntityInput(client, "SetModelScale");
		
		g_bResized[client] = false;
	}
	
	return Plugin_Continue;
}

public bool TraceFilterSelf(int entity, int contentsMask, any iSelf)
{
	if(entity == iSelf || entity > MaxClients || (entity >= 1 && entity <= MaxClients))
		return false;
	
	return true;
}