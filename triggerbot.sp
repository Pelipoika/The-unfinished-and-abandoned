#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <utilsext>
#include <dhooks>

#pragma newdecls required;

Handle g_hHudInfo;
Handle g_hHudShotCounter;
Handle g_hHudEnemyAim;
Handle g_hHudRadar[MAXPLAYERS + 1];

bool g_bZoomedOnly[MAXPLAYERS + 1];
bool g_bIgnoreDeadRinger[MAXPLAYERS + 1];
bool g_bIgnoreCloaked[MAXPLAYERS + 1];
bool g_bIgnoreDisguised[MAXPLAYERS + 1];
bool g_bAutoBackstab[MAXPLAYERS + 1];
bool g_bWaitForCharge[MAXPLAYERS + 1];
bool g_bNoSlowDown[MAXPLAYERS + 1];
bool g_bAllCrits[MAXPLAYERS + 1];
bool g_bAutoStrafe[MAXPLAYERS + 1];
bool g_bBhop[MAXPLAYERS + 1];
bool g_bNoSpread[MAXPLAYERS + 1];
bool g_bAimbot[MAXPLAYERS + 1];
bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bShotCounter[MAXPLAYERS + 1];
bool g_bWallhack[MAXPLAYERS + 1];

Handle g_hPrimaryAttack;

bool g_bShot[MAXPLAYERS + 1];
int g_iShots[MAXPLAYERS + 1];
int g_iShotsHit[MAXPLAYERS + 1];

#define UMSG_SPAM_DELAY 0.1
float g_flNextTime[MAXPLAYERS + 1];

ConVar g_hAddition;

//Add Sniper Rifle: Wait for charge
//Auto Airblast
//Auto sticky det
//(NetVar( int*, pBaseWeapon, m_iWeaponState )) = AC_STATE_IDLE;  
//Healer priority

public Plugin myinfo = 
{
	name = "[TF2] Badmin",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks", Command_Trigger, ADMFLAG_BAN);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	g_hAddition = CreateConVar("sm_triggerbot_extra", "100", "Bye", FCVAR_PROTECTED);
	
	g_hHudInfo = CreateHudSynchronizer();
	g_hHudShotCounter = CreateHudSynchronizer();
	g_hHudEnemyAim = CreateHudSynchronizer();
	
	//Ohno
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hHudRadar[i] = CreateHudSynchronizer();
	}
	
	g_hPrimaryAttack = DHookCreate(437, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFWeaponBase_PrimaryAttack);
}

public void OnClientPutInServer(int client)
{
	g_bZoomedOnly[client] = false;
	g_bIgnoreDeadRinger[client] = true;
	g_bIgnoreCloaked[client] = true;
	g_bIgnoreDisguised[client] = false;
	g_bAutoBackstab[client] = false;
	g_bWaitForCharge[client] = false;
	g_bNoSlowDown[client] = false;
	g_bAllCrits[client] = false;
	g_bAutoStrafe[client] = false;
	g_bBhop[client] = false;
	g_bNoSpread[client] = false;
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bSilentAim[client] = false;
	g_bShotCounter[client] = false;
	g_bWallhack[client] = false;
	
	g_bShot[client] = false;
	g_iShots[client] = 0;
	g_iShotsHit[client] = 0;
	
	g_flNextTime[client] = 0.0;
	
	SDKHook(client, SDKHook_TraceAttackPost, TraceAttack);
}

public Action Command_Trigger(int client, int args)
{
	if(IsValidClient(client))
	{
		DisplayHackMenuAtItem(client);
	}

	return Plugin_Handled;
}

stock void DisplayHackMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuLegitnessHandler);
	menu.SetTitle("Hacker!");
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

	if(g_bNoSpread[client])
		menu.AddItem("2", "No Spread: On");
	else
		menu.AddItem("2", "No Spread: Off");
		
	if(g_bSilentAim[client])
		menu.AddItem("3", "Silent Aim: On");
	else
		menu.AddItem("3", "Silent Aim: Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMiscMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuMiscHandler);
	menu.SetTitle("Misc - Settings");
	
	if(g_bNoSlowDown[client])
		menu.AddItem("0", "No Slowdown: On");
	else
		menu.AddItem("0", "No Slowdown: Off");
	
	if(g_bAllCrits[client])
		menu.AddItem("1", "Critical Hits: On");
	else
		menu.AddItem("1", "Critical Hits: Off");
	
	if(g_bShotCounter[client])
		menu.AddItem("2", "Shot Counter: On");
	else
		menu.AddItem("2", "Shot Counter: Off");
	
	if(g_bWallhack[client])
		menu.AddItem("3", "Wallhack: On");
	else
		menu.AddItem("3", "Wallhack: Off");
	
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
			case 0: g_bAimbot[param1] = !g_bAimbot[param1];
			case 1: g_bAutoShoot[param1] = !g_bAutoShoot[param1];
			case 2:
			{
				g_bNoSpread[param1] = !g_bNoSpread[param1];
			
				for (int w = 0; w <= view_as<int>(TFWeaponSlot_Secondary); w++)
				{
					int iEntity = GetPlayerWeaponSlot(param1, w);
				
					if(IsValidEntity(iEntity))
					{
						if(g_bNoSpread[param1])
							TF2Attrib_SetByName(iEntity, "weapon spread bonus", 0.0);
						else
							TF2Attrib_RemoveByName(iEntity, "weapon spread bonus");
					}
				}
			}
			case 3: g_bSilentAim[param1] = !g_bSilentAim[param1];
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
			case 0: g_bNoSlowDown[param1] = !g_bNoSlowDown[param1];
			case 1: g_bAllCrits[param1] = !g_bAllCrits[param1];
			case 2: 
			{
				if(!g_bShotCounter[param1])
				{			
					int wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Primary);
					if(IsValidEntity(wep))
						DHookEntity(g_hPrimaryAttack, false, wep);
					
					wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Secondary);
					if(IsValidEntity(wep))
						DHookEntity(g_hPrimaryAttack, false, wep);
						
					g_bShotCounter[param1] = true;
				}
				else
				{
					int wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Primary);
					if(IsValidEntity(wep))
						DHookRemoveHookID(DHookEntity(g_hPrimaryAttack, false, wep));
					
					wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Secondary);
					if(IsValidEntity(wep))
						DHookRemoveHookID(DHookEntity(g_hPrimaryAttack, false, wep));
					
					g_bShotCounter[param1] = false;
				}
				
				g_bShot[param1] = false;
				g_iShots[param1] = 0;
				g_iShotsHit[param1] = 0;				
			}
			case 3: g_bWallhack[param1] = !g_bWallhack[param1];
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

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if(g_bAllCrits[client])
	{
		result = true;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public MRESReturn CTFWeaponBase_PrimaryAttack(int pThis, Handle hReturn, Handle hParams)
{
	int iWeapon = pThis;
	int iShooter = GetEntPropEnt(iWeapon, Prop_Data, "m_hOwnerEntity");
	
//	PrintToChatAll("CTFWeaponBase_PrimaryAttack %N is firing their weapon %i", iShooter, iWeapon);
	
	g_bShot[iShooter] = true;
	g_iShots[iShooter]++;
	
	RequestFrame(DidHit, GetClientUserId(iShooter));
	
	return MRES_Ignored;
}

public void TraceAttack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
	{
		RequestFrame(TraceAttackDelay, GetClientUserId(attacker));
	}
}

public void TraceAttackDelay(int userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0)
	{
		if(g_bShot[client])
		{
			g_bShot[client] = false;
		}
	}
}

public void DidHit(int userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0)
	{
		if(!g_bShot[client])
			g_iShotsHit[client]++;
			
	//	PrintToChatAll("%N DidHit? %s", client, !g_bShot[client] ? "Yes" : "No");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
/*	if(IsFakeClient(client))
	{
		vel[0] = 500.0;
		
		if(GetRandomFloat(1.0, 0.0) > 0.005)
		{
			buttons |= IN_JUMP
		}
	}*/

	if(IsFakeClient(client) || !IsPlayerAlive(client)) 
		return Plugin_Continue;	
	
	bool bChanged = false;
	
	if(g_bShotCounter[client])
	{
		SetHudTextParams(-1.0, 0.75, 0.1, 255, 0, 255, 0, 0, 0.0, 0.0, 0.0);
		
		int iShots = g_iShots[client];
		int iHits = g_iShotsHit[client];
		float flHitPerc = (float(iHits) / float(iShots)) * 100;
		
		ShowSyncHudText(client, g_hHudShotCounter, "Shots hit %i/%i [%.0f%%]", iHits, iShots, flHitPerc);
	}
	
	if(g_bAimbot[client])
	{
		float frametime = GetTickInterval();
		if(frametime < (1.0 * 10.0 ^ -5.0))
			return Plugin_Continue;
		
		if(g_flNextTime[client] <= GetGameTime())
		{
			Radar(client);
		
			EnemyIsAimingAtYou(client);
			
			g_flNextTime[client] = GetGameTime() + UMSG_SPAM_DELAY;
		}
			
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle",    view_as<float>({0.0, 0.0, 0.0}));
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", view_as<float>({0.0, 0.0, 0.0}));
		
		if(!(buttons & IN_ATTACK) && !g_bAutoShoot[client])
			return Plugin_Continue;
		
		int iTarget = FindClosestTarget(client);
		
		if(iTarget != -1)
		{
			int iHealer = FindHealer(iTarget);
			if (iHealer != -1)
				iTarget = iHealer;
		
			SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "[AIMING AT: %N [%i HP]", iTarget, GetEntProp(iTarget, Prop_Send, "m_iHealth"));
		
			float myEyePosition[3];
			GetClientEyePosition(client, myEyePosition);
			
			float target_point[3], vNothing[3];
			int iBone = FindBestHitbox(client, iTarget);
			if(iBone == -1)
				return Plugin_Continue;
			
			utils_EntityGetBonePosition(iTarget, iBone, target_point, vNothing);
			
			target_point[2] += 2.0;
			
			float target_velocity[3];
			GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", target_velocity);
			
			float delta[3];
			
			float flLatency = GetClientAvgLatency(client, NetFlow_Both);
			float flLeadTime = -(flLatency) * g_hAddition.FloatValue;	//Still don't know how to properly predict serverside
			
			delta[0] += (flLeadTime * target_velocity[0]);
			delta[1] += (flLeadTime * target_velocity[1]);
			delta[2] += (flLeadTime * target_velocity[2]);
			
			float scale = GetVectorLength(delta);
			NormalizeVector(delta, delta);
			
			float m_vecTargetVelocity[3];
			m_vecTargetVelocity[0] = (scale * delta[0]) + target_velocity[0];
			m_vecTargetVelocity[1] = (scale * delta[1]) + target_velocity[1];
			m_vecTargetVelocity[2] = (scale * delta[2]) + target_velocity[2];
			
			target_point[0] += frametime * m_vecTargetVelocity[0];
			target_point[1] += frametime * m_vecTargetVelocity[1];
			target_point[2] += frametime * m_vecTargetVelocity[2];
			
			float eye_to_target[3];
			SubtractVectors(target_point, myEyePosition, eye_to_target);
			GetVectorAngles(eye_to_target, eye_to_target);
			
			eye_to_target[0] = AngleNormalize(eye_to_target[0]);
			eye_to_target[1] = AngleNormalize(eye_to_target[1]);
			eye_to_target[2] = 0.0;
			
			if(g_bAutoShoot[client])
			{
				int iWeapon = GetPlayerWeaponSlot(client, 0);
				
				if(IsValidEntity(iWeapon))
				{
					//Sniperrifle
					if(HasEntProp(iWeapon, Prop_Send, "m_flChargedDamage"))
					{
						float flDamage = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargedDamage");
						if (flDamage >= 150.0)
						{
							buttons |= IN_ATTACK;
						}
					}
					else //Ambassador
					{
						float flLastFireTime = GetGameTime() - GetEntPropFloat(iWeapon, Prop_Send, "m_flLastFireTime");
						if(flLastFireTime >= 0.95)
						{
							buttons |= IN_ATTACK;
						}
					}
				}
				
				buttons |= IN_ATTACK;
			}
			
			if(!g_bSilentAim[client])
			{
				TeleportEntity(client, NULL_VECTOR, eye_to_target, NULL_VECTOR);
			}
			else
			{
				FixSilentAimMovement(client, vel, angles, eye_to_target);
			}
			
			angles = eye_to_target;
			
			bChanged = true;
		}
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

stock void EnemyIsAimingAtYou(int client)
{
	float flMyPos[3];
	GetClientEyePosition(client, flMyPos);
	
	float flMaxAngle = 999.0;
	float flAimingPercent;
	
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
		
		float flTheirPos[3];
		GetClientEyePosition(i, flTheirPos);
		
		TR_TraceRayFilter(flMyPos, flTheirPos, MASK_SHOT, RayType_EndPoint, AimTargetFilter, client);
		if(TR_DidHit())
		{
			int entity = TR_GetEntityIndex();
			if(entity == i)
			{
				float vDistance[3];
				SubtractVectors(flMyPos, flTheirPos, vDistance);
				NormalizeVector(vDistance, vDistance);
				
				float flTheirEyeAng[3];
				GetClientEyeAngles(i, flTheirEyeAng);
				
				float vForward[3];
				GetAngleVectors(flTheirEyeAng, vForward, NULL_VECTOR, NULL_VECTOR);
				
				float flAngle = RadToDeg(ArcCosine(GetVectorDotProduct(vForward, vDistance)));
				
				if(flMaxAngle > flAngle && flAngle <= 60)
				{
					flMaxAngle = flAngle;
					flAimingPercent = 100 - (flMaxAngle * (100 / 60));
				}
			}
		}
	}
	
	if(flMaxAngle != 999)
	{
		char cPlayerAim[120];
		
		if(flAimingPercent >= 85.0)
		{
			SetHudTextParams(-1.0, 0.0, UMSG_SPAM_DELAY + 0.5, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
			Format(cPlayerAim, sizeof(cPlayerAim), "Enemy is AIMING at YOU %.0f%%", flAimingPercent);
		}
		else
		{
			SetHudTextParams(-1.0, 0.0, UMSG_SPAM_DELAY + 0.5, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
			Format(cPlayerAim, sizeof(cPlayerAim), "Enemy can SEE YOU %.0f%%", flAimingPercent);
		}
		
		ShowSyncHudText(client, g_hHudEnemyAim, cPlayerAim);
	}
}

stock void Radar(int client)
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
		
		if(GetClientTeam(i) != 2 || GetClientTeam(i) != 3)
			continue;
		
		float flEnemyPos[3];
		GetClientAbsOrigin(i, flEnemyPos);
		
		vecGrenDelta = GetDeltaVector(client, i);
		NormalizeVector(vecGrenDelta, vecGrenDelta);
		GetEnemyPosToScreen(client, vecGrenDelta, screenx, screeny, GetVectorDistance(flMyPos, flEnemyPos) * 0.25);
		
		SetHudTextParams(screenx, screeny, UMSG_SPAM_DELAY + 0.5, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudRadar[i], "⬤");
	}
	
	SetHudTextParams(-0.7, -0.7, UMSG_SPAM_DELAY + 0.5, 255, 255, 0, 0, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hHudRadar[client], "⬤");
}

stock void GetEnemyPosToScreen(int client, float vecDelta[3], float& xpos, float& ypos, float flRadius)
{
	if(flRadius > 290.0)
		flRadius = 290.0;

	float playerAngles[3]; 
	GetClientEyeAngles(client, playerAngles);

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
	xpos = (290 + (flRadius * Cosine(yawRadians))) / 1000.0; // divide by 1000 to make it fit with HudTextParams
	ypos = (290 - (flRadius * Sine(yawRadians)))   / 1000.0;
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

stock float Min(float one, float two)
{
	if(one < two)
		return one;
	else if(two < one)
		return two;
		
	return two;
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

stock int FindBestHitbox(int client, int target)
{
	int iNumBones = utils_EntityGetNumBones(target);
	if(iNumBones < 17)
		return -1;

	int iBestHitBox = utils_EntityLookupBone(target, "bip_spine_2");
	int iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	if(TF2_GetPlayerClass(client) == TFClass_Spy
	|| TF2_GetPlayerClass(client) == TFClass_Sniper)
	{
		if(iActiveWeapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
		{
			iBestHitBox = utils_EntityLookupBone(target, "bip_head");
		}
	}
	
	if(iBestHitBox != -1 && IsBoneVisible(client, target, iBestHitBox))
	{
		return iBestHitBox;
	}
	else
	{
		iBestHitBox = -1;
		
	/*	for (int i = 0; i < 17; i++)
		{
			if(IsBoneVisible(client, target, i))
			{
				iBestHitBox = i;
				break;
			}
		}*/
	}
	
	return iBestHitBox;
}

stock bool IsBoneVisible(int looker, int target, int bone)
{
	float vecEyePosition[3];
	GetClientEyePosition(looker, vecEyePosition);

	float vNothing[3], vOrigin[3];
	utils_EntityGetBonePosition(target, bone, vOrigin, vNothing);
	
	TR_TraceRayFilter(vecEyePosition, vOrigin, MASK_SHOT, RayType_EndPoint, AimTargetFilter, looker);
	if(TR_DidHit() && TR_GetEntityIndex() == target)
	{
		return true;
	}
	
	return false;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(condition == TFCond_Slowed && g_bNoSlowDown[client])
	{
		TF2_RemoveCondition(client, TFCond_Slowed);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
	}
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

stock int FindClosestTarget(int iViewer)
{
	float flPos[3];
	GetClientEyePosition(iViewer, flPos);
	
	float flBestDistance = 99999.0;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer) && TF2_IsKillable(i))
		{
			int iBone = FindBestHitbox(iViewer, i);
			if(iBone != -1)
			{
				float vOrigin[3], vNothing[3];
				utils_EntityGetBonePosition(i, iBone, vOrigin, vNothing);
				
				TR_TraceRayFilter(flPos, vOrigin, MASK_SHOT, RayType_EndPoint, AimTargetFilter, iViewer);
				if(TR_DidHit())
				{
					int entity = TR_GetEntityIndex();
					if(entity == i)
					{
						float flDistance = GetVectorDistance(flPos, vOrigin);
				
						if(flDistance < flBestDistance)
						{
							flBestDistance = flDistance;
							iBestTarget = i;
						}
					}
				}
			}
		}
	}

	return iBestTarget;
}

stock int FindHealer(int client)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_weapon_medigun")) != -1)
	{
		int hTarget = GetEntPropEnt(index, Prop_Send, "m_hHealingTarget");
		int hHealer = GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity");
		
		if(client == hTarget)
		{
			return hHealer;
		}
	}
	
	return -1;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "player"))
	{
		if(GetClientTeam(entity) == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "entity_medigun_shield"))
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
	
	return !(entity == iExclude);
}

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock void TE_FireBullets(float vecOrigin[3], float vecAngles0, float vecAngles1, int iWeaponID, int iMode, int iSeed, int iPlayer, float flSpread, bool bCritical = false)
{
	TE_Start("Fire Bullets");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteFloat("m_vecAngles[0]", vecAngles0);
	TE_WriteFloat("m_vecAngles[1]", vecAngles1);
	TE_WriteNum("m_iWeaponID", iWeaponID);
	TE_WriteNum("m_iMode", iMode);
	TE_WriteNum("m_iSeed", iSeed);
	TE_WriteNum("m_iPlayer", iPlayer);
	TE_WriteFloat("m_flSpread", flSpread);
	TE_WriteNum("m_bCritical", bCritical);
	TE_SendToAll();
}
