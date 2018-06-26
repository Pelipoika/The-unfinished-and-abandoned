#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required;

int iTankOffset;

bool g_bDrivingTank[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[TF2] Be the Tank", 
	author = "Pelipoika", 
	description = "tank_boss", 
	version = "1.0", 
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_tank", Command_Tank, ADMFLAG_ROOT);
	RegAdminCmd("sm_leavetank", Command_TankExit, 0);

	if(LookupOffset(iTankOffset, "CTFTankBoss", "m_lastHealthPercentage")) iTankOffset += 48;
}

public void OnClientPutInServer(int client)
{
	g_bDrivingTank[client] = false;
}

public void OnEntityDestroyed(int entity)
{
	if(entity > MaxClients)
	{
		char strName[64];
		GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrContains(strName, "PlayerControlledTankEntity") != -1)
		{
			int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			if(client > 0 && client <= MaxClients && IsClientInGame(client))
			{
				g_bDrivingTank[client] = false;
				
				SetVariantString("0");
				AcceptEntityInput(client, "SetForcedTauntCam");
				
				SetClientViewEntity(client, client);
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
			
			int iTrack = GetEntDataEnt2(entity, iTankOffset);
			if(IsValidEntity(iTrack))
			{
				AcceptEntityInput(iTrack, "KillHierarchy");
			}
		}
	}
}

public Action Command_TankExit(int client, int args)
{
	if(g_bDrivingTank[client])
	{
		SetVariantString("0");
		AcceptEntityInput(client, "SetForcedTauntCam");
		SetClientViewEntity(client, client);
		SetEntityMoveType(client, MOVETYPE_WALK);
		
		g_bDrivingTank[client] = false;
		
		int i = -1;	
		while ((i = FindEntityByClassname(i, "tank_boss")) != -1)
		{
			if(GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == client)
			{
				SDKHooks_TakeDamage(i, i, i, 900000.0);
			}
		}
	}
	
	return Plugin_Handled;	
}

public Action Command_Tank(int client, int args)
{
	if(!g_bDrivingTank[client])
	{
		float flPos[3], flAng[3];
		GetClientAbsOrigin(client, flPos);
		GetClientEyeAngles(client, flAng);
		flAng[1] = 0.0;
		
		float vForward[3], vLeft[3];
		GetAngleVectors(flAng, vForward, NULL_VECTOR, NULL_VECTOR);
		GetAngleVectors(flAng, NULL_VECTOR, vLeft, NULL_VECTOR);
		flPos[0] += (vForward[0] * 200);
		flPos[1] += (vForward[1] * 200);
		flPos[2] += (vForward[2] * 200);
		
		int iTrack = CreateEntityByName("info_target");
		DispatchKeyValueVector(iTrack, "origin", flPos);
		DispatchSpawn(iTrack);
		
		int tank = CreateEntityByName("tank_boss");
		DispatchKeyValue(tank, "targetname", "PlayerControlledTankEntity");
		DispatchKeyValueVector(tank, "origin", flPos);
		DispatchKeyValueVector(tank, "angles", flAng);
		DispatchKeyValue(tank, "ModelScale", "0.5");
		SetEntDataEnt2(tank, iTankOffset, iTrack, true);
		DispatchSpawn(tank);
		
		float flMaxs[3];
		GetEntPropVector(tank, Prop_Data, "m_vecMaxs", flMaxs);
		flMaxs[2] -= 10.0;
		
	/*	int iCamera = CreateEntityByName("info_observer_point");
		DispatchKeyValueVector(iCamera, "origin", flPos);
		DispatchKeyValueVector(iCamera, "angles", flAng);
		DispatchKeyValue(iCamera, "TeamNum", "0");
		DispatchKeyValue(iCamera, "StartDisabled", "0");
		DispatchSpawn(iCamera);
		AcceptEntityInput(iCamera, "Enable");
		
		SetVariantString("!activator");
		AcceptEntityInput(iCamera, "SetParent", tank);*/
		
		SetVariantString("1");
		AcceptEntityInput(client, "SetForcedTauntCam");
		SetClientViewEntity(client, tank);
		SetEntityMoveType(client, MOVETYPE_NONE);

		SetEntPropEnt(tank, Prop_Send, "m_hOwnerEntity", client);
		SetEntProp(tank, Prop_Send, "m_bGlowEnabled", 0);
		SetEntProp(tank, Prop_Data, "m_takedamage", 0);
		
		SDKHook(tank, SDKHook_Think, OnTankThink);
		
		g_bDrivingTank[client] = true;
	}
	
	return Plugin_Handled;	
}

public Action OnTankThink(int tank)
{
	int client = GetEntPropEnt(tank, Prop_Send, "m_hOwnerEntity");
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		float tPos[3], tAng[3];
		GetEntPropVector(tank, Prop_Send, "m_vecOrigin", tPos);
		GetEntPropVector(tank, Prop_Data, "m_angRotation", tAng);
		
		int iTrack = GetEntDataEnt2(tank, iTankOffset);
		if(IsValidEntity(iTrack))
		{
			float vForward[3], vLeft[3];
			GetAngleVectors(tAng, vForward, NULL_VECTOR, NULL_VECTOR);
			GetAngleVectors(tAng, NULL_VECTOR, vLeft, NULL_VECTOR);
			tPos[0] += (vForward[0] * 200);
			tPos[1] += (vForward[1] * 200);
			tPos[2] += (vForward[2] * 200);
		
			int iButtons = GetClientButtons(client);
	
			if(iButtons & IN_MOVELEFT)
			{
				tPos[0] += (vLeft[0] * -45);
				tPos[1] += (vLeft[1] * -45);
				tPos[2] += (vLeft[2] * -45);
			}
			else if(iButtons & IN_MOVERIGHT)
			{
				tPos[0] += (vLeft[0] * 45);
				tPos[1] += (vLeft[1] * 45);
				tPos[2] += (vLeft[2] * 45);
			}

			TeleportEntity(iTrack, tPos, NULL_VECTOR, NULL_VECTOR);
	
			if(iButtons & IN_FORWARD)
			{
				if(iButtons & IN_JUMP)
					SetVariantString("200");
				else
					SetVariantString("100");
			}
			else 
				SetVariantString("0");
				
			AcceptEntityInput(tank, "SetSpeed");
		}
	}
}

stock bool LookupOffset(int &iOffset, const char[] strClass, const char[] strProp)
{
	iOffset = FindSendPropInfo(strClass, strProp);
	if(iOffset <= 0)
	{
		LogMessage("Could not locate offset for %s::%s!", strClass, strProp);
		return false;
	}

	return true;
}