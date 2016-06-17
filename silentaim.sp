#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

bool g_bAimbot[MAXPLAYERS + 1];

Handle g_hHudInfo;
Handle g_hHudInfo2;

public Plugin myinfo = 
{
	name = "[TF2] Silent Aim test",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	g_hHudInfo = CreateHudSynchronizer();
	g_hHudInfo2 = CreateHudSynchronizer();

	RegAdminCmd("sm_aimbot", Command_Aimbot, ADMFLAG_ROOT);
}

public void OnClientDisconnect(int client)
{
	g_bAimbot[client] = false;
}

public Action Command_Aimbot(int client, int argc)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if(g_bAimbot[client])
		{
			g_bAimbot[client] = false;
			PrintToChat(client, "Aimbot: OFF");
		}
		else
		{
			g_bAimbot[client] = true;
			PrintToChat(client, "Aimbot: ON");
		}
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
/*	if(IsFakeClient(client))
	{
		buttons &= ~IN_JUMP;
		vel[0] = 500.0;
		return Plugin_Changed;
	}
*/
	if(IsFakeClient(client) || !g_bAimbot[client])
		return Plugin_Continue;	

	int iPlayerarray[MAXPLAYERS+1];
	int iPlayercount;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && TF2_IsKillable(i))
		{
			float flTPos[3], flPos[3];
			GetClientAbsOrigin(i, flTPos);
			GetClientEyePosition(client, flPos);
			
			float flMaxs[3];
			GetEntPropVector(i, Prop_Send, "m_vecMaxs", flMaxs);
			flTPos[2] += flMaxs[2] / 2;
			
			TR_TraceRayFilter(flPos, flTPos, MASK_SHOT, RayType_EndPoint, AimTargetFilter, client);
			if(TR_DidHit())
			{
				int entity = TR_GetEntityIndex();
				if(entity == i)
				{
					iPlayerarray[iPlayercount] = i;
					iPlayercount++;
				}
			}
		}						
	}
	
	if(iPlayercount)
	{
		char strTargets[32 * MAX_NAME_LENGTH];
		for (int i = 0; i < iPlayercount; i++)
		{
			float flTPos[3], flPos[3];
			GetClientAbsOrigin(iPlayerarray[i], flTPos);
			GetClientEyePosition(client, flPos);
		
			float flDistance = GetVectorDistance(flPos, flTPos) * 0.0254;
			int target = iPlayerarray[i];
			Format(strTargets, sizeof(strTargets), "%s\n%N - %.0f", strTargets, target, flDistance);
		}
		
		SetHudTextParams(-0.6, 0.55, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudInfo2, "%i VISIBLE:%s", iPlayercount, strTargets);
	}

	if(!(buttons & IN_ATTACK))
		return Plugin_Continue;
		
	int iTarget = FindTargetInViewCone(client);
	if(iTarget != -1)
	{
		SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudInfo, "[AIMING AT: %N [%i HP]", iTarget, GetEntProp(iTarget, Prop_Send, "m_iHealth"));
	
		float flPPos[3], flTPos[3];
		GetClientEyePosition(client, flPPos);
		GetClientAbsOrigin(iTarget, flTPos);
		
		float flMaxs[3];
		GetEntPropVector(iTarget, Prop_Send, "m_vecMaxs", flMaxs);
		
		flTPos[2] += flMaxs[2] / 2;
	
		float flAimDir[3];
		MakeVectorFromPoints(flPPos, flTPos, flAimDir);
		GetVectorAngles(flAimDir, flAimDir);
		
		angles = flAimDir;
	}
	
	return Plugin_Changed;
}

stock int FindTargetInViewCone(int iViewer, float iOffz = 0.0)
{
	float flPos[3];
	GetClientEyePosition(iViewer, flPos);
	
	float flBestDistance = 99999.0;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer) && TF2_IsKillable(i))
		{
			float flTPos[3];
			GetClientAbsOrigin(i, flTPos);
			
			float flMaxs[3];
			GetEntPropVector(i, Prop_Send, "m_vecMaxs", flMaxs);
			flTPos[2] += flMaxs[2] / 2;
			
			TR_TraceRayFilter(flPos, flTPos, MASK_SHOT, RayType_EndPoint, AimTargetFilter, iViewer);
			if(TR_DidHit())
			{
				int entity = TR_GetEntityIndex();
				if(entity == i)
				{
					float flDistance = GetVectorDistance(flPos, flTPos);
			
					if(flDistance < flBestDistance)
					{
						flBestDistance = flDistance;
						iBestTarget = i;
					}
				}
			}
		}
	}

	return iBestTarget;
}

stock bool TF2_IsKillable(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged) 
	|| TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) 
	|| TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen)
	|| TF2_IsPlayerInCondition(client, TFCond_Bonked)
	|| GetEntProp(client, Prop_Data, "m_takedamage") != 2)
	{
		return false;
	}
	
	return true;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
    return !(entity == iExclude);
}