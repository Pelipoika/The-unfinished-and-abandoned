#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <utilsext>
#include <dhooks>

#pragma newdecls required;

#define DEG2RAD(%1) ((%1) * FLOAT_PI / 180.0)

Handle g_hHudInfo;
Handle g_hHudShotCounter;

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

//Add Sniper Rifle: Wait for charge
//Auto Airblast
//Auto sticky det
//(NetVar( int*, pBaseWeapon, m_iWeaponState )) = AC_STATE_IDLE;  

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
	
	g_hHudInfo = CreateHudSynchronizer();
	g_hHudShotCounter = CreateHudSynchronizer();
	
	g_hPrimaryAttack = DHookCreate(436, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFWeaponBase_PrimaryAttack);
}

public void OnPluginEnd()
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, "ESPGlow"))
		{
			AcceptEntityInput(index, "ClearParent");
			AcceptEntityInput(index, "Kill");
		}
	}
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
	
	TF2_CreateGlow(client);
	
	SDKHook(client, SDKHook_TraceAttackPost, TraceAttack);
}

public void OnClientDisconnect(int client)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == client)
		{
			AcceptEntityInput(index, "ClearParent");
			AcceptEntityInput(index, "Kill");
		}
	}
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
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
		
		if(!(buttons & IN_ATTACK) && !g_bAutoShoot[client])
			return Plugin_Continue;
		
		int iTarget = FindClosestTarget(client);
		if(iTarget != -1)
		{
			SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "[AIMING AT: %N [%i HP]", iTarget, GetEntProp(iTarget, Prop_Send, "m_iHealth"));
		
			float flPPos[3];
			GetClientEyePosition(client, flPPos);
			
			float vOrigin[3], vNothing[3];
			int iBone = FindBestHitbox(client, iTarget);
			if(iBone == -1)
				return Plugin_Continue;
			
			utils_EntityGetBonePosition(iTarget, iBone, vOrigin, vNothing);
			
			vOrigin[2] += 2.0;
			
			static float vOldOrigin[3];
			static float vOldestOrigin[3];
			float vDeltaOrigin[3];
			
			// Calculate the delta (the change in two vector) origin
			SubtractVectors(vOrigin, vOldestOrigin, vDeltaOrigin);
			vOldestOrigin = vOldOrigin;
			vOldOrigin = vOrigin;
	 
			// Get the latency
	 		float flLatencyBothAvg = GetClientAvgLatency(client, NetFlow_Both);
			
			// Compensate the latency
			vDeltaOrigin[0] *= -((100 - flLatencyBothAvg) * (flLatencyBothAvg * 2));
			vDeltaOrigin[1] *= -((100 - flLatencyBothAvg) * (flLatencyBothAvg * 2));
			vDeltaOrigin[2] *= -((100 - flLatencyBothAvg) * (flLatencyBothAvg * 2));
	 		
			// Apply the prediction
			AddVectors(vOrigin, vDeltaOrigin, vOrigin);
			
			float flAimDir[3];
			MakeVectorFromPoints(flPPos, vOrigin, flAimDir);
			GetVectorAngles(flAimDir, flAimDir);
			ClampAngle(flAimDir);
			
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
				TeleportEntity(client, NULL_VECTOR, flAimDir, NULL_VECTOR);
			}
			else
			{
				FixSilentAimMovement(client, vel, angles, flAimDir);
			}
			
			angles = flAimDir;
			
			bChanged = true;
		}
	}
	
	if(bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}

public Action OnGlowTransmit(int entity, int other)
{
	SetEdictFlags(entity, FL_EDICT_FULLCHECK|FL_EDICT_CHANGED);
	
	int GlowOwner = GetEntPropEnt(entity, Prop_Send, "m_hTarget");
	
	if(GlowOwner == other)
		return Plugin_Handled;

	if(!g_bWallhack[other])
		return Plugin_Handled;
	
	if(GetClientTeam(GlowOwner) == 3)
		SetVariantColor({91, 122, 140, 255});
	else
		SetVariantColor({189, 59, 140, 255});
	
	AcceptEntityInput(entity, "SetGlowColor");
	
	return Plugin_Continue;
}

stock void FixSilentAimMovement(int client, float vel[3], float angles[3], float aimbotAngles[3])
{
	float vecSilent[3];
	vecSilent = vel;
	
	float flSpeed = SquareRoot(vecSilent[0] * vecSilent[0] + vecSilent[1] * vecSilent[1]);
	float angMove[3];
	GetVectorAngles(vecSilent, angMove);
	
	float flYaw = DEG2RAD(aimbotAngles[1] - angles[1] + angMove[1]);
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
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	
	return !(entity == iExclude);
}

stock void ClampAngle(float flAngles[3])
{
	while(flAngles[0] > 89.0)  flAngles[0] -= 360.0;
	while(flAngles[0] < -89.0) flAngles[0] += 360.0;
	while(flAngles[1] > 180.0) flAngles[1] -= 360.0;
	while(flAngles[1] <-180.0) flAngles[1] += 360.0;
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

stock int TF2_CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));

	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "ESPGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);
	
	AcceptEntityInput(ent, "Enable");
	
	//Change name back to old name because we don't need it anymore.
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	SetEdictFlags(ent, FL_EDICT_FULLCHECK|FL_EDICT_CHANGED);
	SDKHook(ent, SDKHook_SetTransmit, OnGlowTransmit);
	
	return ent;
}