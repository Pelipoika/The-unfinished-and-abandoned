#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required;

#define Address(%1) view_as<Address>(%1)
#define int(%1) view_as<int>(%1)

bool g_bAimbot[MAXPLAYERS + 1];

enum 
{
	AIM_NEAR = 0,
	AIM_FOV,
	
	NUM_AIM_MODES,
};

int g_iAimType[MAXPLAYERS + 1];
float g_flAimFOV[MAXPLAYERS + 1];

bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bMedicPriority[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bBunnyHop[MAXPLAYERS + 1];
bool g_bHeadshots[MAXPLAYERS + 1];
bool g_bAutoBackstab[MAXPLAYERS + 1];
bool g_bForceFOV[MAXPLAYERS + 1];

int g_iAntiAimType[MAXPLAYERS + 1];


public Plugin myinfo = 
{
	name = "[TF2] Aimbot V2",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

Handle g_hLookupBone;
Handle g_hGetBonePosition;
Handle g_hGetWeaponID;
Handle g_hGetDamageType;
Handle g_hCanFireCriticalShot;


int g_iOffsetStudioHdr;

//TODO

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks2", Command_Trigger, ADMFLAG_BAN);

	for (int i = 1; i <= MaxClients; i++) {	
		OnClientPutInServer(i); 
	}

	//int CBaseAnimating::LookupBone( const char *szName )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x8B\xF1\x80\xBE\x41\x03\x00\x00\x00\x75\x2A\x83\xBE\x6C\x04\x00\x00\x00\x75\x2A\xE8\x2A\x2A\x2A\x2A\x85\xC0\x74\x2A\x8B\xCE\xE8\x2A\x2A\x2A\x2A\x8B\x86\x6C\x04\x00\x00\x85\xC0\x74\x2A\x83\x38\x00\x74\x2A\xFF\x75\x08\x50\xE8\x2A\x2A\x2A\x2A\x83\xC4\x08\x5E", 68);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
	
	//void CBaseAnimating::GetBonePosition ( int iBone, Vector &origin, QAngle &angles )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x30\x56\x8B\xF1\x80\xBE\x41\x03\x00\x00\x00", 16);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
	
	//CTFWeaponBase::GetWeaponID()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(372);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns WeaponID
	if ((g_hGetWeaponID = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetWeaponID offset!");
	
	//CTFWeaponBase::GetDamageType()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(127);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns int
	if ((g_hGetDamageType = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetDamageType offset!");
	
	//CTFWeaponBase::CanFireCriticalShot()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(428);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);	//bHeadshot
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hCanFireCriticalShot = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CanFireCriticalShot offset!");
	
	g_iOffsetStudioHdr = FindSendPropInfo("CBaseAnimating", "m_flFadeScale") + 28;
	PrintToServer("g_iOffsetStudioHdr %i", g_iOffsetStudioHdr);
}

public void OnClientPutInServer(int client)
{
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bMedicPriority[client] = false;
	g_bSilentAim[client] = false;
	g_bAutoBackstab[client] = false;
	g_bForceFOV[client] = false;

	g_iAntiAimType[client] = 0;
	
	g_iAimType[client] = AIM_NEAR;
	g_flAimFOV[client] = 10.0;
	
	g_bBunnyHop[client] = false;
	g_bHeadshots[client] = false;
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
	menu.SetTitle("LMAOBOX TF2");
	menu.AddItem("0", "Aimbot");
	menu.AddItem("1", "Misc");
	menu.AddItem("2", "Confused Boyes");

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
	
	if(g_iAimType[client] == AIM_NEAR)
		menu.AddItem("1", "Aim Type: Closest");
	else if(g_iAimType[client] == AIM_FOV)
		menu.AddItem("1", "Aim Type: FOV");
		
	char FOV[64];
	Format(FOV, sizeof(FOV), "Aim FOV: %.2f", g_flAimFOV[client]);
	menu.AddItem("2", FOV);
	
	if(g_bAutoShoot[client])
		menu.AddItem("3", "Auto Shoot: On");
	else
		menu.AddItem("3", "Auto Shoot: Off");

	if(g_bSilentAim[client])
		menu.AddItem("4", "Silent Aim: On");
	else
		menu.AddItem("4", "Silent Aim: Off");
		
	if(g_bHeadshots[client])
		menu.AddItem("5", "Headshots only: On");
	else
		menu.AddItem("5", "Headshots only: Off");
	
	if(g_bMedicPriority[client])
		menu.AddItem("6", "Prioritize healers: On");
	else
		menu.AddItem("6", "Prioritize healers: Off");
	
	if(g_bAutoBackstab[client])
		menu.AddItem("7", "Auto Backstab (Ignores Settings): On");
	else
		menu.AddItem("7", "Auto Backstab (Ignores Settings): Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMiscMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuMiscHandler);
	menu.SetTitle("Misc - Settings");
	
	if(g_bBunnyHop[client])
		menu.AddItem("0", "Bunny Hop: On");
	else
		menu.AddItem("0", "Bunny Hop: Off");
		
	if(g_bForceFOV[client])
		menu.AddItem("1", "Force FOV: On");
	else
		menu.AddItem("1", "Force FOV: Off");
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplaySpinbotMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuSpinHandler);
	menu.SetTitle("Spinbot - Settings");
	
	switch(g_iAntiAimType[client])
	{
		case 0: menu.AddItem("0", "Type: OFF");
		case 1: menu.AddItem("1", "Type: Scared");
	}
	
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
				
				SendItemInfo(param1, "Aimbot master switch\nDoesn't affect auto backstab");
			}
			case 1: 
			{
				if     (g_iAimType[param1] == AIM_NEAR) g_iAimType[param1] = AIM_FOV;
				else if(g_iAimType[param1] == AIM_FOV)  g_iAimType[param1] = AIM_NEAR;
				
				SendItemInfo(param1, "Aimbot aim type\nNEAR = Closest enemy\nFOV = Closest enemy to crosshair in \"Aim FOV\" area");
			}
			case 2: {SendItemInfo(param1, "You will be able to change \"Aim FOV\" sometime in the future.");}
			case 3: 
			{
				g_bAutoShoot[param1] = !g_bAutoShoot[param1];
				
				SendItemInfo(param1, "Aimbot will automatically shoot on target found");
			}
			case 4: 
			{
				g_bSilentAim[param1] = !g_bSilentAim[param1];
				
				SendItemInfo(param1, "Aimbot will not change your viewangles");
			}
			case 5: 
			{
				g_bHeadshots[param1] = !g_bHeadshots[param1];
				
				SendItemInfo(param1, "Aimbot will only target head");
			}
			case 6:
			{
				g_bMedicPriority[param1] = !g_bMedicPriority[param1];
				SendItemInfo(param1, "When choosing a target, the aimbot will shoot target their medics before the target itself.");
			}
			case 7: 
			{
				g_bAutoBackstab[param1] = !g_bAutoBackstab[param1];
				
				//Turning on auto backstab turns on silent aim
				if(g_bAutoBackstab[param1])
				{
					g_bSilentAim[param1] = true;
				}
				
				SendItemInfo(param1, "Automatically backstab enemy if possible.");
			}	
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
			case 1: 
			{
				g_bForceFOV[param1] = !g_bForceFOV[param1];
				
				SendItemInfo(param1, "Force FOV to always be your fov_desired");
			}
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

public int MenuSpinHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(++g_iAntiAimType[param1] >= 2)
			g_iAntiAimType[param1] = 0;
		
		DisplaySpinbotMenuAtItem(param1, GetMenuSelectionPosition());
		
		SendItemInfo(param1, "Anti-aim, or \"AA\" is a type of hack mostly used in source games.\nIts purpose is to make aimbots harder to headshot you.");
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
			case 2: DisplaySpinbotMenuAtItem(param1);
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
	
	int iAw = GetActiveWeapon(client);
	if(!IsValidEntity(iAw))
		return Plugin_Continue;
	
	bool bChanged = false;
	
	float oldAngle[3]; oldAngle = angles;
	float oldForward  = vel[0];
	float oldSideMove = vel[1];
	
	if(g_bBunnyHop[client] && buttons & IN_JUMP)
	{
		if(GetEntityFlags(client) & FL_ONGROUND )
		{
			int nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			SetEntProp(client, Prop_Data, "m_nOldButtons", (nOldButtons &= ~(IN_JUMP|IN_DUCK)));
		}
	}
	
	if(g_iAntiAimType[client] != 0)
	{
		//Don't antiaim when user is trying to do something.
		if(!(buttons & IN_ATTACK) && !(buttons & IN_ATTACK2))
		{
			bool bFoundWall = DoAntiAim(client, angles[1]);
			
			angles[0] = (cmdnum % 2 == 0) ? (89.0) : (-89.0);
			
			//Backwards if no wall
			if (!bFoundWall) {
				angles[1] -= 180.0;
			}
		}
	}
	
	if(g_bAimbot[client]) {
		bChanged = DoAimbot(client, buttons, oldAngle, angles, vel[0], vel[1], oldForward, oldSideMove);
	}
	
	if(g_bForceFOV[client]) {
		//-1 or we can't headshot.
		SetEntProp(client, Prop_Send, "m_iFOV",      GetEntProp(client, Prop_Send, "m_iDefaultFOV") - 1);
		SetEntProp(client, Prop_Send, "m_iFOVStart", GetEntProp(client, Prop_Send, "m_iDefaultFOV") - 1);
	}
	
	if(g_bAutoBackstab[client])
	{
		bool bIsHoldingKnife = (GetWeaponID(iAw) == TF_WEAPON_KNIFE);
		if(!bIsHoldingKnife)
			return Plugin_Continue;
		
		SetEntProp(client, Prop_Data, "m_bLagCompensation", false);
		SetEntProp(client, Prop_Data, "m_bPredictWeapons", false);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i))	
				continue;
				
			if(!IsPlayerAlive(i))
				continue;
			
			if(GetClientTeam(i) != GetEnemyTeam(client))
				continue;
			
			if(GetVectorDistance(GetAbsOrigin(client), GetAbsOrigin(i)) > 90.0)
				continue;
			
			bool IsBehindAPotentiallyBackStabbableTarget = IsPotentiallyBackStabbableTarget(client, i);
			if(IsBehindAPotentiallyBackStabbableTarget)
			{
				float vecToTarget[3];
				SubtractVectors(GetPlayerCenterOfMass(i), GetEyePosition(client), vecToTarget);
			
				SnapEyeAngles(client, vecToTarget, angles);
				
				buttons |= IN_ATTACK;
				bChanged = true;
				break;
			}
		}
		
		//PrintToServer("fov %f maxDistance %f index %i", fov, maxDistance, index);
	}
	
	//if(g_bSilentAim[client]) {
	FixSilentAimMovement(client, oldAngle, angles, vel[0], vel[1], oldForward, oldSideMove);
	bChanged = true;
	//}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

stock bool DoAimbot(int client, int &buttons, const float vOldAngles[3], float vViewAngles[3], 
					float &flForwardMove, float &flSideMove, float &fOldForward, float &fOldSidemove)
{
	SetEntProp(client, Prop_Data, "m_bLagCompensation", false);
	SetEntProp(client, Prop_Data, "m_bPredictWeapons", false);
	
	if(!(buttons & IN_ATTACK))
	{
		if(IsPlayerReloading(client) || !g_bAutoShoot[client])
			return false;
	}
	
	int iTarget = INVALID_ENT_REFERENCE;
	float target_point[3]; target_point = SelectBestTargetPos(client, vOldAngles, iTarget);		
	if (iTarget == INVALID_ENT_REFERENCE)
		return false;
	
	//PrintToChatAll("%f %f %f", target_point[0], target_point[1], target_point[2]);
	
	if(g_bAutoShoot[client] && (!(buttons & IN_ATTACK)))
	{
		if(IsPlayerReloading(client)) {
			buttons &= ~IN_ATTACK;
		} else {
			buttons |= IN_ATTACK;
		}
	}
	
	float target_point_adjusted[3];
	
	if(fOldForward != 0 || fOldSidemove != 0)
	{
		//Extrapolate target_point if we are moving.
		SubtractVectors(VelocityExtrapolate(iTarget, target_point), 
						VelocityExtrapolate(client, GetEyePosition(client)), 
						target_point_adjusted);
	}
	else
	{
		SubtractVectors(target_point, GetEyePosition(client), target_point_adjusted);
	}
	
	SnapEyeAngles(client, target_point_adjusted, vViewAngles);
	
	return true;
}

stock int GetEnemyTeam(int ent)
{
	int enemy_team = GetClientTeam(ent);
	switch(enemy_team)
	{
		case 2:  enemy_team = 3;
		case 3: enemy_team = 2;
	}
	
	return enemy_team;
}

stock bool DoAntiAim(int client, float &angle)
{
	float position[3]; position = GetEyePosition(client); 
	
	float closest_distance = 100.0;
	
	//float radius = 25.3;
	float radius = 40.0;
	float step = FLOAT_PI * 2.0 / 16;
	
	for (float a = 0.0; a < (FLOAT_PI * 2.0); a += step)
	{
		float location[3];
		location[0] = radius * Cosine(a) + position[0];
		location[1] = radius * Sine(a)   + position[1];
		location[2] = position[2];
		
		Handle trace = TR_TraceRayFilterEx(position, location, CONTENTS_SOLID, RayType_EndPoint, AimTargetFilter, client);
		
		if (TR_DidHit(trace))
		{
			float posEnd[3];
			TR_GetEndPosition(posEnd, trace);
			
			float distance = GetVectorDistance(position, posEnd);
			
			if (distance < closest_distance)
			{
				closest_distance = distance;
				angle = RadToDeg(a);
			}
		}
		delete trace;
	}
 
	return closest_distance < 25.0;
}

float[] VelocityExtrapolate(int client, float eyepos[3])
{
	float absVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", absVel);
	
	float v[3];
	
	v[0] = eyepos[0] + (absVel[0] * GetTickInterval());
	v[1] = eyepos[1] + (absVel[1] * GetTickInterval());
	v[2] = eyepos[2] + (absVel[2] * GetTickInterval());
	
	return v;
}

float[] SelectBestTargetPos(int client, const float oldAngles[3], int &iBestEnemy)
{
	float flMyPos[3]; flMyPos = GetEyePosition(client);

	float flTargetPos[3];
	float flClosestDistance = 8192.0;

	//FOV aim stuff
	float nearest;
	float fov = g_flAimFOV[client];
	////////////////

	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsKilllablePlayer(client, i))
			continue;
		
		float vVisiblePos[3]; 
		
		bool bFoundMedic = false;
		
		//Before we check the target itself, check their medics.
		if(g_bMedicPriority[client])
		{
			for (int h = 0; h < GetEntProp(i, Prop_Send, "m_nNumHealers"); h++)
			{
				int iHealerIndex = GetHealerByIndex(i, h);
				
				//Not a player
				if(iHealerIndex > MaxClients)
					continue;
				
				//Not ubered and stuff
				if(!IsKilllablePlayer(client, iHealerIndex))
					continue;
				
				//Visibile anywhere?
				if(!GetBestHitBox(client, iHealerIndex, vVisiblePos))
					continue;
				
				//PrintToServer("[%.2f] \"%N\" <- healed by visible player \"%N\" [%i]", GetGameTime(), i, iHealerIndex, iHealerIndex);
				
				//Found medic to target.
				bFoundMedic = true;
				break;
			}
		}
		
		//No medics found for target.
		if(!bFoundMedic) 
		{
			//Target isnt visible either :/
			if(!GetBestHitBox(client, i, vVisiblePos))
				continue;
		}
		
		if(g_iAimType[client] == AIM_FOV)
		{
			nearest = GetFov(oldAngles, CalcAngle(GetEyePosition(client), GetEyePosition(i)));
		
			if (nearest > fov)
				continue;
				
			float distance = GetDistance(GetAbsOrigin(client), GetAbsOrigin(i));
			
			if (FloatAbs(fov - nearest) < 5)
			{
				if (distance < flClosestDistance)
				{
					fov = nearest;
					flClosestDistance = distance;
					flTargetPos = vVisiblePos;
					
					iBestEnemy = i;
				}
			}
			else if (nearest < fov)
			{
				fov = nearest;
				flClosestDistance = distance;
				flTargetPos = vVisiblePos;
				
				iBestEnemy = i;
			}
		}
		else
		{
			float flDistance = GetVectorDistance(flMyPos, vVisiblePos);
			if(flDistance < flClosestDistance)
			{
				flClosestDistance = flDistance;
				
				flTargetPos = vVisiblePos;
				
				iBestEnemy = i;
			}
		}
	}
	
	return flTargetPos;
}

stock bool IsKilllablePlayer(int client, int target)
{
	if(!IsPlayerAlive(target))
		return false;
	
	if(GetEntProp(target, Prop_Send, "m_lifeState") != 0)
		return false;
	
	if(GetClientTeam(target) != GetEnemyTeam(client))
		return false;
		
		
	if(TF2_IsPlayerInCondition(target, TFCond_Ubercharged)        || TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) 
	|| TF2_IsPlayerInCondition(target, TFCond_UberchargedCanteen) || TF2_IsPlayerInCondition(target, TFCond_Bonked)) {
		return false;
	}
	
	if(GetEntProp(target, Prop_Data, "m_takedamage") != 2)
		return false;
	
	return true;
}

stock bool CanFireCriticalShot(int client, bool bIsHeadshot)
{
/*	// can only fire a crit shot if this is a headshot
	if (!bIsHeadshot)
		return false;
	
	// no crits if they're not zoomed
	if (GetEntProp(client, Prop_Send, "m_iFOV") >= GetEntProp(client, Prop_Send, "m_iDefaultFOV")) {
		return false;
	}
	
	//TF_WEAPON_SNIPERRIFLE_NO_CRIT_AFTER_ZOOM_TIME 0.2
	// no crits for 0.2 seconds after starting to zoom
	if ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_flFOVTime")) < 0.2) {
		return false;
	}
	
	return true;*/
	
	return SDKCall(g_hCanFireCriticalShot, GetActiveWeapon(client), bIsHeadshot);
}

bool IsPlayerReloading(int client)
{
	if(GetEntProp(client, Prop_Send, "m_bFeignDeathReady"))
		return true;

	int PlayerWeapon = GetActiveWeapon(client);
	
	if(!IsValidEntity(PlayerWeapon))
		return true;
	
	bool bReloading = true;
	
	//float flReloadPriorNextFire = GetGameTime() - GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flReloadPriorNextFire");
	float flNextPrimaryAttack   = GetGameTime() - GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flNextPrimaryAttack");
	
	bool m_bInReload = !!GetEntProp(PlayerWeapon, Prop_Data, "m_bInReload");
	
	//PrintCenterText(client, "flReloadPriorNextFire %f\nflNextPrimaryAttack %f", flReloadPriorNextFire, flNextPrimaryAttack);
	
	//Can fire?
	if(flNextPrimaryAttack > 0)
		bReloading = false;
	
	//Has ammo and is not reloading
	if(GetEntProp(PlayerWeapon, Prop_Send, "m_iClip1") <= 0 && m_bInReload)
		bReloading = true;
	
	//If shooting head only, only shoot if can headshot.
	if(g_bHeadshots[client]) {
		//DMG_AIRBOAT == DMG_USE_HITLOCATIONS or w/e it's called
		bReloading = !(GetDamageType(PlayerWeapon) & DMG_AIRBOAT && CanFireCriticalShot(client, true));
	}
	
	return bReloading;
}

/*char hitgroup[][] =
{
	{"HITGROUP_GENERIC"},
	{"HITGROUP_HEAD"},
	{"HITGROUP_CHEST"},
	{"HITGROUP_STOMACH"},
	{"HITGROUP_LEFTARM"},
	{"HITGROUP_RIGHTARM"},
	{"HITGROUP_LEFTLEG"},
	{"HITGROUP_RIGHTLEG"}
};*/

enum //hitgroup_t
{
	HITGROUP_GENERIC,
	HITGROUP_HEAD,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
	
	NUM_HITGROUPS
};

int g_iHitBoxOrderHeadshot[] = 
{
	HITGROUP_HEAD,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_GENERIC,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
}

int g_iHitBoxOrderBullet[] = 
{
	HITGROUP_STOMACH,
	HITGROUP_CHEST,
	HITGROUP_GENERIC,
	HITGROUP_HEAD,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
}

/*
	struct mstudiohitboxset_t
	{
		DECLARE_BYTESWAP_DATADESC();
		int					sznameindex;
		inline char * const	pszName( void ) const { return ((char *)this) + sznameindex; }
		int					numhitboxes;
		int					hitboxindex;
		inline mstudiobbox_t *pHitbox( int i ) const { return (mstudiobbox_t *)(((byte *)this) + hitboxindex) + i; };
	};
	
	// intersection boxes
	struct mstudiobbox_t
	{
		DECLARE_BYTESWAP_DATADESC();
		int					bone;
		int					group;				// intersection group
		Vector				bbmin;				// bounding box
		Vector				bbmax;	
		int					szhitboxnameindex;	// offset to the name of the hitbox.
		int					unused[8];
	
		const char* pszHitboxName()
		{
			if( szhitboxnameindex == 0 )
				return "";
	
			return ((const char*)this) + szhitboxnameindex;
		}
	
		mstudiobbox_t() {}
	
	private:
		// No copy constructors allowed
		mstudiobbox_t(const mstudiobbox_t& vOther);
	};


	mstudiohitboxset_t *set = pStudioHdr->pHitboxSet( m_nHitboxSet );
	if ( !set )
		return;
	
	for ( int i = 0; i < set->numhitboxes; i++ )
	{
		mstudiobbox_t *pbox = set->pHitbox( i );
	
		GetBonePosition( pbox->bone, position, angles );
	}
*/

stock bool GetBestHitBox(int client, int entity, float vBestOut[3])
{
	Address pStudioHdr = Address(Dereference(Address(GetEntData(entity, g_iOffsetStudioHdr))));
	if(pStudioHdr == Address_Null)
		return false;
	
	int m_nHitboxSet = GetEntProp(entity, Prop_Send, "m_nHitboxSet");
	if(m_nHitboxSet != 0)
		return false;
	
	Address pHitBoxSet = pStudioHdr + Address(ReadInt(pStudioHdr + Address(0xB0)));
	if(pHitBoxSet == Address_Null)
		return false;
	
	int iNumHitboxes = ReadInt(pHitBoxSet + Address(0x4));
	
	//Into the abyss.
	pHitBoxSet += Address(0xC);
	
	//Check if any hitbox is visible in an order
	//that makes sense for our active weapon
	bool bShouldHeadshot = (GetDamageType(GetActiveWeapon(client)) & DMG_AIRBOAT && CanFireCriticalShot(client, true));
	
	//Loop all hitgroups
	for (int i = 0; i < NUM_HITGROUPS; i++)
	{
		//Match hitgroup to order we want to check
		int hitGroup = (bShouldHeadshot ? (g_iHitBoxOrderHeadshot[i]) : (g_iHitBoxOrderBullet[i]));
	
		//User wants headshots only, don't check for any other hitbox than head.
		if(g_bHeadshots[client] && hitGroup != HITGROUP_HEAD)
			continue;
	
		for (int iHitBox = 0; iHitBox < iNumHitboxes; iHitBox++)
		{
			//mstudiobbox_t 
			Address pbox = Address(pHitBoxSet + Address(iHitBox * 68));
			if(pbox == Address_Null)
				continue;
			
			int iBone  = ReadInt(pbox);
			int iGroup = ReadInt(pbox + Address(0x4));
			
			if(iGroup != hitGroup)
				continue;
			
			float vBonePosition[3], vBoneAngles[3];
			GetBonePosition(entity, iBone, vBonePosition, vBoneAngles);
						
			//TODO
			//If doing headshot only, perform multipoint checking on head hitbox.
			//Is center visible?
			bool bVisible = false;
						
			if(g_bHeadshots[client] && iGroup == HITGROUP_HEAD)
			{
				float vMins[3]; vMins = ExtractVectorFromAddress(pbox + Address(0x8)); 
				float vMaxs[3]; vMaxs = ExtractVectorFromAddress(pbox + Address(0x14)); 
			
				//Hitbox Size
				float vSize[3];
				vSize[0] = FloatAbs(vMaxs[0]) + FloatAbs(vMins[0]);
				vSize[1] = FloatAbs(vMaxs[1]) + FloatAbs(vMins[1]);
				vSize[2] = FloatAbs(vMaxs[2]) + FloatAbs(vMins[2]);
				
				//Hitbox Origin
				float vCenter[3]; 
				AddVectors(vMins, vMaxs, vCenter);
				ScaleVector(vCenter, 0.5);
				
				//Angle vectors
				float vForward[3], vLeft[3], vUp[3];
				GetAngleVectors(vBoneAngles, vForward, vLeft, vUp);
				
				//Center bone pos to hitbox
				vBonePosition[0] += vLeft[2] * vCenter[2];
				vBonePosition[1] += vLeft[0] * vCenter[0];
				vBonePosition[2] -= vLeft[2] * vCenter[1];
				
				//const float flScalar = 1.0;
				
				//ScaleVector(vMaxs, flScalar);
				//ScaleVector(vMins, flScalar);
				
				//MOVE TO TOP CENTER OF HEAD
				//vBonePosition[1] -= vLeft[2] * (vSize[2] / 2.0);
				
				//PrintToServer("vMaxs %f %f %f", vSize[0], vSize[1], vSize[2]);
		/*		bVisible = (IsPointVisible(client, entity, GetEyePosition(client), vBonePosition, hitGroup));
				if(bVisible)
				{
				 	vBestOut = vBonePosition;
					return true;
				}
				
				for (int x = 1; x <= 4; x++)
				{
					//Left then right
					if(x <= 2) vBonePosition[1] -= vUp[1] * (vMaxs[1] * 2); //MOVE TO LEFT SIDE OF HEAD
					else       vBonePosition[1] += vUp[1] * (vMaxs[1] * 2); //MOVE TO RIGHT SIDE OF HEAD
					
					switch(x)
					{
						case 1: vBonePosition[0] += vForward[0] * (vMaxs[0] * 2); //MOVE TO BACK LEFT CORNER OF HEAD
						case 2: vBonePosition[0] -= vForward[0] * (vMaxs[0] * 2); //MOVE TO FRONT LEFT CORNER OF HEAD
						case 3: vBonePosition[0] += vForward[0] * (vMaxs[0] * 2); //MOVE TO BACK RIGHT CORNER OF HEAD
						case 4: vBonePosition[0] -= vForward[0] * (vMaxs[0] * 2); //MOVE TO FRONT RIGHT CORNER OF HEAD
					}
					
					bVisible = (IsPointVisible(client, entity, GetEyePosition(client), vBonePosition, hitGroup));
					if(bVisible)
					{
						PrintToServer("VISIBLE MULTIPOINT %i ON TOP OF HEAD!", x);
						
					 	vBestOut = vBonePosition;
				
						return true;
					}
				}
				
				//HERE WE GO AGAIN
				
				//Reset for accurate results.
				//GetBonePosition(entity, iBone, vBonePosition, vBoneAngles);
				
				//GO BOTTOM OF HEAD
				//vBonePosition[0] += vLeft[0] * (vMins[0] / 2);
				//vBonePosition[1] += vLeft[1] * (vMins[1] / 2);
				//vBonePosition[2] += vLeft[2] * (vMins[2] / 2);*/
			}
			
			bVisible = (IsPointVisible(client, entity, GetEyePosition(client), vBonePosition, hitGroup));
			
			
			if(bVisible)
			{
				//Since we traverse the hitboxes in an ideal order, 
				//we may break/return on the first visible hitbox.
				vBestOut = vBonePosition;
				
				return true;
			}
		}
	}
	
	return false;
}

stock void FixSilentAimMovement(int client, const float vOldAngles[3],    float vViewAngles[3], float &flForwardMove, float &flSideMove,      float fOldForward, float fOldSidemove)
{
	float deltaView;
	float f1;
	float f2;
	
	if (vOldAngles[1] < 0.0)
		f1 = 360.0 + vOldAngles[1];
	else
		f1 = vOldAngles[1];
	
	if (vViewAngles[1] < 0.0)
		f2 = 360.0 + vViewAngles[1];
	else
		f2 = vViewAngles[1];
	
	if (f2 < f1)
		deltaView = FloatAbs(f2 - f1);
	else
		deltaView = 360.0 - FloatAbs(f1 - f2);
		
	deltaView = 360.0 - deltaView;
	
	flForwardMove = Cosine(DegToRad(deltaView)) * fOldForward + Cosine(DegToRad(deltaView + 90.0)) * fOldSidemove;
	flSideMove    =   Sine(DegToRad(deltaView)) * fOldForward +   Sine(DegToRad(deltaView + 90.0)) * fOldSidemove;
}

stock bool IsPointVisible(int looker, int target, float start[3], float point[3], int expectedHitGroup)
{
	TR_TraceRayFilter(start, point, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, looker);
	
	int hitGroup = TR_GetHitGroup();
	int hitEnt   = TR_GetEntityIndex();
	
	//PrintToServer("hitEnt %i; got %i expected %i == %s", hitEnt, hitGroup, expectedHitGroup, hitGroup == expectedHitGroup ? "YES" : "NO"); 
	
	if(!TR_DidHit() || hitEnt == target)
	{
		//Ignore hitgroup expectance if not headshot only.
		if(g_bHeadshots[looker] && hitGroup == expectedHitGroup) {
			return true;
		} else {
			return true;
		}
	}
	
	return false;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "entity_medigun_shield"))
	{
		if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	
	return !(entity == iExclude);
}

stock void SnapEyeAngles(int client, float target_point[3], float cmdAngles[3])
{
	float eye_to_target[3];
	GetVectorAngles(target_point, eye_to_target);
	
	eye_to_target[0] = AngleNormalize(eye_to_target[0]);
	eye_to_target[1] = AngleNormalize(eye_to_target[1]);
	eye_to_target[2] = 0.0;

	cmdAngles = eye_to_target;

	if(!g_bSilentAim[client]) {
		TeleportEntity(client, NULL_VECTOR, eye_to_target, NULL_VECTOR);
	}
}

stock float[] GetPlayerCenterOfMass(int client)
{
	float v[3]; v = GetAbsOrigin(client);
	
	float vecMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", vecMaxs);
	
	v[2] += (vecMaxs[2] / 2);
	
	return v;
}

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock int LookupBone   (int iEntity, const char[] szName) { return SDKCall(g_hLookupBone, iEntity, szName); }
stock int GetDamageType(int iWeapon)                      { return SDKCall(g_hGetDamageType, iWeapon);      }
stock int GetWeaponID  (int iWeapon)                      { return SDKCall(g_hGetWeaponID, iWeapon);        }

stock void GetBonePosition(int iEntity, int iBone, float origin[3], float angles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, origin, angles);
}

stock bool IsPotentiallyBackStabbableTarget(int client, int victim)
{
	float wsc_spy_to_victim[3];
	SubtractVectors(GetPlayerCenterOfMass(victim), VelocityExtrapolate(client, GetPlayerCenterOfMass(client)), wsc_spy_to_victim);
	NormalizeVector(wsc_spy_to_victim, wsc_spy_to_victim);
	wsc_spy_to_victim[2] = 0.0;

	float eye_victim[3];
	GetAngleVectors(GetEyeAngles(victim), eye_victim, NULL_VECTOR, NULL_VECTOR);
	eye_victim[2] = 0.0;
	NormalizeVector(eye_victim, eye_victim);

	return (GetVectorDotProduct(wsc_spy_to_victim, eye_victim) > 0.0);
}

stock float GetFov(const float viewAngle[3], const float aimAngle[3])
{
	float ang[3], aim[3];
	
	GetAngleVectors(viewAngle, aim, NULL_VECTOR, NULL_VECTOR);
	GetAngleVectors(aimAngle,  ang, NULL_VECTOR, NULL_VECTOR);

	return RadToDeg(ArcCosine(GetVectorDotProduct(aim, ang) / GetVectorLength(aim, true)));
}

stock float[] CalcAngle(float src[3], float dst[3])
{
	float angles[3];
	float delta[3];
	SubtractVectors(dst, src, delta);

	GetVectorAngles(delta, angles);

	return angles;
}

stock float GetDistance(float src[3], float dst[3])
{
	return SquareRoot(Pow(src[0] - dst[0], 2.0) + Pow(src[1] - dst[1], 2.0) + Pow(src[2] - dst[2], 2.0));
}

stock int GetHealerByIndex(int client, int index)
{
	int m_aHealers = FindSendPropInfo("CTFPlayer", "m_nNumHealers") + 12;
	
	Address m_Shared = GetEntityAddress(client) + Address(m_aHealers);
	Address aHealers = Address(ReadInt(m_Shared));

	return ReadInt(Transpose(aHealers, (index * 0x24))) & 0xFFF;
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

stock float[] GetAbsAngles(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", v);
	
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

stock float[] ExtractVectorFromAddress(Address address)
{
	float v[3];
	
	v[0] = view_as<float>(ReadInt(address + Address(0x0)));
	v[1] = view_as<float>(ReadInt(address + Address(0x4)));
	v[2] = view_as<float>(ReadInt(address + Address(0x8)));
	
	return v;
}

stock Address Transpose(Address pAddr, int iOffset)		
{
	return Address(int(pAddr) + iOffset);		
}

stock int Dereference(Address pAddr, int iOffset = 0)		
{
	if(pAddr == Address_Null)		
	{
		return -1;
	}
	
	return ReadInt(Transpose(pAddr, iOffset));
} 

stock int ReadInt(Address pAddr)
{
	if(pAddr == Address_Null)
	{
		return -1;
	}
	
	return LoadFromAddress(pAddr, NumberType_Int32);
}

stock void SendItemInfo(int client, const char[] text)
{
	Handle hBuffer = StartMessageOne("KeyHintText", client);
	BfWriteByte(hBuffer, 1);
	BfWriteString(hBuffer, text);
	EndMessage();
}