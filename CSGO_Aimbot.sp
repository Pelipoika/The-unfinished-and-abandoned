#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required;

Handle g_hHudRadar[MAXPLAYERS + 1];

bool g_bAimbot[MAXPLAYERS + 1];
bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bBunnyHop[MAXPLAYERS + 1];
bool g_bHeadshots[MAXPLAYERS + 1];

#define UMSG_SPAM_DELAY 0.1
float g_flNextTime[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] Aimbot",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

Handle g_hLookupBone;
Handle g_hGetBonePosition;

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks", Command_Trigger, ADMFLAG_BAN);

	for (int i = 1; i <= MaxClients; i++)
	{	
		if(IsClientInGame(i)) 
		{ 
			OnClientPutInServer(i); 
		}
		
		g_hHudRadar[i] = CreateHudSynchronizer();
	}
	
	//-----------------------------------------------------------------------------
	// Purpose: Returns index number of a given named bone
	// Input  : name of a bone
	// Output : Bone index number or -1 if bone not found
	//-----------------------------------------------------------------------------
	//int CBaseAnimating::LookupBone( const char *szName )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x57\x8B\xF9\x83\xBF\x9C\x04\x00\x00\x00\x75\x2A\xA1\x2A\x2A\x2A\x2A\x8B\x30\x8B\x07\xFF\x50\x18\x8B\x0D\x2A\x2A\x2A\x2A\x50\xFF\x56\x04\x85\xC0\x74\x2A\x8B\xCF\xE8\x2A\x2A\x2A\x2A\x8B\x8F\x9C\x04\x00\x00\x85\xC9\x0F\x84\x2A\x2A\x2A\x2A", 63);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
	
	//void CBaseAnimating::GetBonePosition ( int iBone, Vector &origin, QAngle &angles )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xE4\xF8\x83\xEC\x30\x56\x57\x8B\xF9\x83\xBF\x9C\x04\x00\x00\x00\x75\x2A\xA1\x2A\x2A\x2A\x2A\x8B\x30\x8B\x07\xFF\x50\x18\x8B\x0D\x2A\x2A\x2A\x2A\x50\xFF\x56\x04\x85\xC0\x74\x2A\x8B\xCF\xE8\x2A\x2A\x2A\x2A\x8B\x87\x9C\x04\x00\x00", 61);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
}

public void OnClientPutInServer(int client)
{
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bSilentAim[client] = false;
	
	g_bBunnyHop[client] = false;
	g_bHeadshots[client] = false;

	g_flNextTime[client] = 0.0;
}

public Action Command_Trigger(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		DisplayHackMenuAtItem(client);
	}

	return Plugin_Handled;
}

stock void DisplayHackMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuLegitnessHandler);
	menu.SetTitle("LMAOBOX CS:GO");
	menu.AddItem("0", "Aimbot");
	menu.AddItem("1", "Misc");

	menu.ExitButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayAimbotMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuAimbotHandler);
	menu.SetTitle("Aimbot - Settings");
	
	if(g_bAimbot[client])
		menu.AddItem("0", "Aimbot: On");
	else
		menu.AddItem("0", "Aimbot: Off");
	
	if(g_bAutoShoot[client])
		menu.AddItem("1", "Auto Shoot: On");
	else
		menu.AddItem("1", "Auto Shoot: Off");

	if(g_bSilentAim[client])
		menu.AddItem("2", "Silent Aim: On");
	else
		menu.AddItem("2", "Silent Aim: Off");
		
	if(g_bHeadshots[client])
		menu.AddItem("3", "Headshots only: On");
	else
		menu.AddItem("3", "Headshots only: Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMiscMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuMiscHandler);
	menu.SetTitle("Misc - Settings");
	
	if(g_bBunnyHop[client])
		menu.AddItem("2", "Bunny Hop: On");
	else
		menu.AddItem("2", "Bunny Hop: Off");
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int MenuAimbotHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{		
			case 0: 
			{
				g_bAimbot[param1] = !g_bAimbot[param1];
				
				if(!g_bAimbot[param1])
				{
					SetEntProp(param1, Prop_Data, "m_bLagCompensation", true);
					SetEntProp(param1, Prop_Data, "m_bPredictWeapons", true);
				}
			}
			case 1: g_bAutoShoot[param1]  = !g_bAutoShoot[param1];
			case 2: g_bSilentAim[param1]  = !g_bSilentAim[param1];
			case 3: g_bHeadshots[param1]  = !g_bHeadshots[param1];
		}
		
		DisplayAimbotMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuMiscHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: g_bBunnyHop[param1] = !g_bBunnyHop[param1];
		}
		
		DisplayMiscMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuLegitnessHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: DisplayAimbotMenuAtItem(param1);
			case 1: DisplayMiscMenuAtItem(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client) || !IsPlayerAlive(client)) 
		return Plugin_Continue;	
	
//	PrintCenterText(client, "%f %f %f", angles[0], angles[1], angles[2]);
	
	bool bChanged = false;
	
	if(g_bBunnyHop[client])
	{
		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			int nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			SetEntProp(client, Prop_Data, "m_nOldButtons", (nOldButtons &= ~(IN_JUMP|IN_DUCK)));
		}
	}
	
	if(g_bAimbot[client])
	{
		if(g_flNextTime[client] <= GetGameTime())
		{
			SetEntProp(client, Prop_Data, "m_bLagCompensation", false);
			SetEntProp(client, Prop_Data, "m_bPredictWeapons", false);
		
			Radar(client, angles);
			
			g_flNextTime[client] = GetGameTime() + UMSG_SPAM_DELAY;
		}
		
		int iAw = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(!IsValidEntity(iAw))
			return Plugin_Continue;
	
		if(IsPlayerReloading(client) || (!(buttons & IN_ATTACK) && !g_bAutoShoot[client]))
			return Plugin_Continue;

		float target_point[3]; target_point = SelectBestTargetPos(client, angles);
		if (FloatCompare(target_point[2], 0.0) == 0)
			return Plugin_Continue;
		
		if(g_bAutoShoot[client])
		{
			if(IsPlayerReloading(client))
				buttons &= ~IN_ATTACK;
			else
				buttons |= IN_ATTACK;
		}
		
		float eye_to_target[3];
		SubtractVectors(target_point, GetEyePosition(client), eye_to_target);
		GetVectorAngles(eye_to_target, eye_to_target);
		
		eye_to_target[0] = AngleNormalize(eye_to_target[0]);
		eye_to_target[1] = AngleNormalize(eye_to_target[1]);
		eye_to_target[2] = 0.0;
		
		SetEntPropFloat(iAw, Prop_Send, "m_fAccuracyPenalty", 0.0);
		
		float vPunch[3]; vPunch = GetAimPunchAngle(client);
		ScaleVector(vPunch, -2.0);
		
		AddVectors(eye_to_target, vPunch, eye_to_target);
		
		if(!g_bSilentAim[client]) {
			TeleportEntity(client, NULL_VECTOR, eye_to_target, NULL_VECTOR);
		}
		else {
			FixSilentAimMovement(client, vel, angles, eye_to_target);
		}
		
		angles = eye_to_target;
		bChanged = true;
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

float[] SelectBestTargetPos(int client, const float realAngles[3])
{
	float flMyPos[3]; flMyPos = GetAbsOrigin(client);

	float flTargetPos[3];
	float flClosestDistance = 999999999999999.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if (GetEntProp(i, Prop_Send, "m_bGunGameImmunity"))
			continue;
		
		if(GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		int iBone = LookupBone(i, "ValveBiped.Bip01_Head");
		if(iBone < 0)
			continue;
			
		float vecHead[3], vecBad[3];
		GetBonePosition(i, iBone, vecHead, vecBad);
		
		if(!IsPointVisible(client, i, GetEyePosition(client), vecHead))
			continue;
			
		float flEnemyPos[3]; flEnemyPos = GetAbsOrigin(i);
			
		float flDistance = GetVectorDistance(flEnemyPos, flMyPos, true)
		if(flDistance < flClosestDistance)
		{
			flClosestDistance = flDistance;
			flTargetPos = vecHead;
		}
	}
	
	return flTargetPos;
}

bool IsPlayerReloading(int client)
{
	int PlayerWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	if(!IsValidEntity(PlayerWeapon))
		return false;
	
	//Out of ammo?
	if(GetEntProp(PlayerWeapon, Prop_Data, "m_iClip1") == 0)
		return true;
	
	//Reloading?
	if(GetEntProp(PlayerWeapon, Prop_Data, "m_bInReload"))
		return true;
	
	//Ready to fire?
	if(GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flNextPrimaryAttack") <= GetGameTime())
		return false;
	
	return true;
}

stock void Radar(int client, float playerAngles[3])
{
	float flMyPos[3];
	GetClientAbsOrigin(client, flMyPos);
	
	float screenx, screeny;
	float vecGrenDelta[3];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		float flEnemyPos[3];
		GetClientAbsOrigin(i, flEnemyPos);
		
		flEnemyPos[2] = flMyPos[2]; //We only care about 2D
		
		vecGrenDelta = GetDeltaVector(client, i);
		NormalizeVector(vecGrenDelta, vecGrenDelta);
		GetEnemyPosToScreen(client, playerAngles, vecGrenDelta, screenx, screeny, GetVectorDistance(flMyPos, flEnemyPos) * 0.25);
		
		SetHudTextParams(screenx, screeny, UMSG_SPAM_DELAY + 0.5, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudRadar[i], "⬤");
	}
}

stock void GetEnemyPosToScreen(int client, float playerAngles[3], float vecDelta[3], float& xpos, float& ypos, float flRadius)
{
	if(flRadius > 400.0)
		flRadius = 400.0;

	float vecforward[3], right[3], up[3] = { 0.0, 0.0, 1.0 };
	GetAngleVectors(playerAngles, vecforward, NULL_VECTOR, NULL_VECTOR );
	vecforward[2] = 0.0;

	NormalizeVector(vecforward, vecforward);
	GetVectorCrossProduct(up, vecforward, right);

	float front = GetVectorDotProduct(vecDelta, vecforward);
	float side  = GetVectorDotProduct(vecDelta, right);

	xpos = flRadius * -front;
	ypos = flRadius * -side;
	
	float flRotation = (ArcTangent2(xpos, ypos) + FLOAT_PI) * (180.0 / FLOAT_PI);
	
	float yawRadians = -flRotation * FLOAT_PI / 180.0; // Convert back to radians
	
	// Rotate it around the circle
	xpos = (500 + (flRadius * Cosine(yawRadians))) / 1000.0; // divide by 1000 to make it fit with HudTextParams
	ypos = (500 - (flRadius * Sine(yawRadians)))   / 1000.0;
}

stock float[] GetDeltaVector(const int client, const int target)
{
	float vec[3];

	float vecPlayer[3];	
	GetClientAbsOrigin(client, vecPlayer);
	
	float vecPos[3];	
	GetClientAbsOrigin(target, vecPos);
	
	SubtractVectors(vecPlayer, vecPos, vec);
	return vec;
}

stock void FixSilentAimMovement(int client, float vel[3], float angles[3], float aimbotAngles[3])
{
	float vecSilent[3];
	vecSilent = vel;
	
	float flSpeed = SquareRoot(vecSilent[0] * vecSilent[0] + vecSilent[1] * vecSilent[1]);
	float angMove[3];
	GetVectorAngles(vecSilent, angMove);
	
	float flYaw = DegToRad(aimbotAngles[1] - angles[1] + angMove[1]);
	vel[0] = Cosine( flYaw ) * flSpeed;
	vel[1] = Sine( flYaw ) * flSpeed;
}

stock bool IsPointVisible(int looker, int target, float start[3], float point[3])
{
	TR_TraceRayFilter(start, point, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, looker);
	if(!TR_DidHit() || TR_GetEntityIndex() == target)
	{
		return true;
	}
	
	return false;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "player"))
	{
		return false;
	}
	
	return !(entity == iExclude);
}

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock int LookupBone(int iEntity, const char[] szName)
{
	return SDKCall(g_hLookupBone, iEntity, szName);
}

stock void GetBonePosition(int iEntity, int iBone, float origin[3], float angles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, origin, angles);
}

stock float[] GetViewPunchAngle(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_viewPunchAngle", v);
	return v;
}

stock float[] GetAimPunchAngle(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_aimPunchAngle", v);
	return v;
}

stock float[] GetAbsVelocity(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", v);
	return v;
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] GetEyePosition(int client)
{
	float v[3];
	GetClientEyePosition(client, v);
	return v;
}

stock float[] GetEyeAngles(int client)
{
	float v[3];
	GetClientEyeAngles(client, v);
	return v;
}

stock int GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}