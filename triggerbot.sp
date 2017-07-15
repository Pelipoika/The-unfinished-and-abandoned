#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <dhooks>

#pragma newdecls required;

Handle g_hHudInfo;
Handle g_hHudShotCounter;
Handle g_hHudEnemyAim;
Handle g_hHudRadar[MAXPLAYERS + 1];

bool g_bNoSlowDown[MAXPLAYERS + 1];
bool g_bAllCrits[MAXPLAYERS + 1];
bool g_bNoSpread[MAXPLAYERS + 1];
bool g_bAimbot[MAXPLAYERS + 1];
bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bTeammates[MAXPLAYERS + 1];
bool g_bShotCounter[MAXPLAYERS + 1];
bool g_bBunnyHop[MAXPLAYERS + 1];
bool g_bSpectators[MAXPLAYERS + 1];

int g_iAimType[MAXPLAYERS + 1];
float g_flAimFOV[MAXPLAYERS + 1];

Handle g_hPrimaryAttack;

Handle g_hGetWeaponID;
Handle g_hGetProjectileSpeed;
Handle g_hGetProjectileGravity;
Handle g_hGetMaxClip;

Handle g_hLookupBone;
Handle g_hGetBonePosition;

bool g_bShot[MAXPLAYERS + 1];
int g_iShots[MAXPLAYERS + 1];
int g_iShotsHit[MAXPLAYERS + 1];

#define UMSG_SPAM_DELAY 0.1
float g_flNextTime[MAXPLAYERS + 1];

// Spectator Movement modes
enum {
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES,
};

//Aimbot modes
enum{
	AIM_NEAR = 0,
	AIM_FOV,
	
	NUM_AIM_MODES,
}

//TODO
//Add Wait for charge
//Add Auto Airblast
//Add Auto sticky det
//SendProxy m_iWeaponState = AC_STATE_IDLE;  
//Calculate proper projectile velocity with weapon attributes.
//Simulate projectile path to detect early collisions.
//https://github.com/danielmm8888/TF2Classic/blob/master/src/game/server/player_lagcompensation.cpp#L388
//https://www.unknowncheats.me/forum/1502192-post9.html
//Use "real angles" not "silent aim angles" for aimbot

ConVar g_hPredictionQuality;

public Plugin myinfo = 
{
	name = "[TF2] Badmin",
	author = "Pelipoika",
	description = "",
	version = "Propably like 500 by now",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

/*
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!(GetEntityFlags(client) & FL_ONGROUND))
    {
		if(mouse[0] > 0)
		{
			vel[1] = 450.0;
			buttons |= IN_MOVERIGHT;
		}
 
		else if(mouse[0] < 0)
		{
			vel[1] = -450.0;
			buttons |= IN_MOVELEFT;
		}
	}
}
*/

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks", Command_Trigger, ADMFLAG_ROOT);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	g_hPredictionQuality = CreateConVar("sm_triggerbot_prediction_quality", "1.0", "Projectile Aimbot projectile prediction quality");
	
	g_hHudInfo = CreateHudSynchronizer();
	g_hHudShotCounter = CreateHudSynchronizer();
	g_hHudEnemyAim = CreateHudSynchronizer();
	
	//Ohno
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hHudRadar[i] = CreateHudSynchronizer();
	}
	
	//CTFWeaponBase::PrimaryAttack()
	g_hPrimaryAttack = DHookCreate(437, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFWeaponBase_PrimaryAttack);
	
	//CTFWeaponBaseGun::GetWeaponID()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(372);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns WeaponID
	if ((g_hGetWeaponID = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetWeaponID offset!");
	
	//CTFWeaponBaseGun::GetProjectileSpeed()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(462);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);	//Returns SPEED
	if ((g_hGetProjectileSpeed = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetProjectileSpeed offset!");
	
	//CTFWeaponBaseGun::GetProjectileGravity()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(463);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);	//Returns SPEED
	if ((g_hGetProjectileGravity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetProjectileGravity offset!");
	
	//CTFWeaponBase::GetMaxClip1()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(316);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns iMaxClip
	if ((g_hGetMaxClip = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFWeaponBase::GetMaxClip1 offset!");
	
	//-----------------------------------------------------------------------------
	// Purpose: Returns index number of a given named bone
	// Input  : name of a bone
	// Output :	Bone index number or -1 if bone not found
	//-----------------------------------------------------------------------------
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
}

int g_iPathLaserModelIndex;

public void OnMapStart()
{
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
	g_bNoSlowDown[client] = false;
	g_bAllCrits[client] = false;
	g_bNoSpread[client] = false;
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bSilentAim[client] = false;
	g_bTeammates[client] = false;
	g_bShotCounter[client] = false;
	g_bBunnyHop[client] = false;
	g_bSpectators[client] = false;
	
	g_iAimType[client] = AIM_NEAR;
	g_flAimFOV[client] = 10.0;
	
	g_bShot[client] = false;
	g_iShots[client] = 0;
	g_iShotsHit[client] = 0;
	
	g_flNextTime[client] = 0.0;
	
	SDKHook(client, SDKHook_TraceAttackPost, TraceAttack);
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
	menu.SetTitle("Hacker!");
	menu.AddItem("0", "Aimbot");
	menu.AddItem("1", "Misc");
	menu.AddItem("2", "Visuals");

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
	Format(FOV, sizeof(FOV), "Aim FOV: %.0f", g_flAimFOV[client]);
	menu.AddItem("2", FOV);

	if(g_bAutoShoot[client])
		menu.AddItem("3", "Auto Shoot: On");
	else
		menu.AddItem("3", "Auto Shoot: Off");

	if(g_bNoSpread[client])
		menu.AddItem("3", "No Spread: On");
	else
		menu.AddItem("3", "No Spread: Off");
		
	if(g_bSilentAim[client])
		menu.AddItem("3", "Silent Aim: On");
	else
		menu.AddItem("3", "Silent Aim: Off");
	
	if(g_bTeammates[client])
		menu.AddItem("4", "Aim at teammates: On");
	else
		menu.AddItem("4", "Aim at teammates: Off");
	
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
	
	if(g_bBunnyHop[client])
		menu.AddItem("2", "Bunny Hop: On");
	else
		menu.AddItem("2", "Bunny Hop: Off");
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayVisualsMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuVisualsHandler);
	menu.SetTitle("Visuals - Settings");
	
	if(g_bShotCounter[client])
		menu.AddItem("0", "Shot Counter: On");
	else
		menu.AddItem("0", "Shot Counter: Off");
	
	if(g_bSpectators[client])
		menu.AddItem("1", "Spectator List: On");
	else
		menu.AddItem("1", "Spectator List: Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int MenuVisualsHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{		
			case 0:
			{
				if(!g_bShotCounter[param1])
				{
					int wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Primary);
					if(IsValidEntity(wep))
						DHookEntity(g_hPrimaryAttack, false, wep);	//Abuse the fact that you can't have multiple hooks to the same callback on the same entity.
					
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
				
				g_bShot[param1]     = false;
				g_iShots[param1]    = 0;
				g_iShotsHit[param1] = 0;				
			}
			case 1: g_bSpectators[param1]  = !g_bSpectators[param1];
		}
		
		DisplayVisualsMenuAtItem(param1, GetMenuSelectionPosition());
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

public int MenuAimbotHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{		
			case 0: g_bAimbot[param1]    = !g_bAimbot[param1];
			case 1: 
			{
				if(g_iAimType[param1] == AIM_NEAR)
					g_iAimType[param1] = AIM_FOV;
				else if(g_iAimType[param1] == AIM_FOV)
					g_iAimType[param1] = AIM_NEAR;
			}
			case 2: PrintCenterText(param1, "Hi");	//TODO Make do thing.
			case 3: g_bAutoShoot[param1] = !g_bAutoShoot[param1];
			case 4:
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
			case 5: g_bSilentAim[param1]  = !g_bSilentAim[param1];
			case 6: g_bTeammates[param1]  = !g_bTeammates[param1];
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
			case 1: g_bAllCrits[param1]   = !g_bAllCrits[param1];
			case 2: g_bBunnyHop[param1]   = !g_bBunnyHop[param1];
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
			case 2: DisplayVisualsMenuAtItem(param1);
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
		
		if(GetRandomFloat(1.0, 0.0) > 0.99)
		{
			buttons |= IN_JUMP;
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
	
	if(g_bSpectators[client])
	{
		char strObservers[32 * 64];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Spectator && !IsFakeClient(i))
			{
				int iObserved = GetEntPropEnt(i, Prop_Data, "m_hObserverTarget");
				int iObsMode = GetEntProp(i, Prop_Data, "m_iObserverMode");
				
				if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && iObserved == client)
				{
					Format(strObservers, sizeof(strObservers), "%s%N%s\n", strObservers, i, iObsMode == OBS_MODE_IN_EYE ? " - IN EYE" : "");
				}
			}
		}
		
		SetHudTextParams(-1.0, 1.0, 0.1, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudShotCounter, strObservers);
	}

	if(g_bBunnyHop[client] || (!(GetEntityFlags(client) & FL_FAKECLIENT) && buttons & IN_JUMP))
	{
		if((GetEntityFlags(client) & FL_ONGROUND))
		{
			int nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			SetEntProp(client, Prop_Data, "m_nOldButtons", (nOldButtons &= ~(IN_JUMP|IN_DUCK)));
		}
	}
	
	if(g_bAimbot[client])
	{
		if(g_flNextTime[client] <= GetGameTime())
		{
			Radar(client, angles);
		
			EnemyIsAimingAtYou(client);
			
			g_flNextTime[client] = GetGameTime() + UMSG_SPAM_DELAY;
		}
		
		if(!(buttons & IN_ATTACK) && !g_bAutoShoot[client])
			return Plugin_Continue;
	
		int iAw = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(!IsValidEntity(iAw))
			return Plugin_Continue;

		if(IsPlayerReloading(client))
			return Plugin_Continue;
		
		int iTarget = FindBestTarget(client, angles);
		if(iTarget != -1)
		{
			float myEyePosition[3];
			GetClientEyePosition(client, myEyePosition);
		
			float target_point[3], vNothing[3];
			int iBone = FindBestHitbox(client, angles, iTarget);
			if(iBone == -1)
				return Plugin_Continue;
			
			GetBonePosition(iTarget, iBone, target_point, vNothing);
					
			if(iTarget > 0 && iTarget <= MaxClients)
			{
				SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(client, g_hHudInfo, "%N [%i HP]", iTarget, GetEntProp(iTarget, Prop_Data, "m_iHealth"));
				
				if(IsProjectileWeapon(iAw))
				{
					if(IsExplosiveProjectileWeapon(iAw) && GetEntityFlags(iTarget) & FL_ONGROUND)
					{
						//Aim at feet if on ground.
						GetClientAbsOrigin(iTarget, target_point);
					}
					
					float pred[3]; pred = PredictCorrection(client, iAw, iTarget, myEyePosition, g_hPredictionQuality.IntValue); 
					AddVectors(target_point, pred, target_point);
					
					int iWeaponID = SDKCall(g_hGetWeaponID, iAw);
					float flProjectileGravity = GetProjectileGravity(iAw);
					float flProjectileSpeed   = GetProjectileSpeed(iAw);
					
					PrintCenterText(client, "WeaponID %i\nGravity %f\nSpeed %f", iWeaponID, flProjectileGravity, flProjectileSpeed);
				}
				else
				{
					target_point[2] += 5.0;		
				
					float target_velocity[3];
					GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", target_velocity);
					
					//Predict "localplayer"
					float player_velocity[3];
					GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", player_velocity);
					
					float delta[3];
					
					delta[0] = player_velocity[0] * (1 / 66);
					delta[1] = player_velocity[1] * (1 / 66);
					delta[2] = player_velocity[2] * (1 / 66);
					
					myEyePosition[0] = myEyePosition[0] + delta[0];
					myEyePosition[1] = myEyePosition[1] + delta[1];
					myEyePosition[2] = myEyePosition[2] + delta[2];
					
					//Predict target
					delta[0] = target_velocity[0] * (1 / 66);
					delta[1] = target_velocity[1] * (1 / 66);
					delta[2] = target_velocity[2] * (1 / 66);
					
					target_point[0] = target_point[0] - delta[0];
					target_point[1] = target_point[1] - delta[1];
					target_point[2] = target_point[2] - delta[2];
					
					/*
					#define clamp(a,b,c) ( (a) > (c) ? (c) : ( (a) < (b) ? (b) : (a) ) )
					
					#define TIME_TO_TICKS( dt )		( (int)( 0.5f + (float)(dt) / TICK_INTERVAL ) )
					#define TICKS_TO_TIME( t )		( TICK_INTERVAL *( t ) )
					#define ROUND_TO_TICKS( t )		( TICK_INTERVAL * TIME_TO_TICKS( t ) )
					*/
					
					// correct is the amout of time we have to correct game time
					float correct = 0.0;
					
					// add network latency
					correct += GetClientLatency(client, NetFlow_Outgoing);
					
					// calc number of view interpolation ticks - 1
					int lerpTicks = RoundToFloor(0.5 + GetPlayerLerp(client) / GetTickInterval());
					
					// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
					correct += (GetTickInterval() * lerpTicks);
					
					// check bounds [0,sv_maxunlag]
					float sv_unlag = FindConVar("sv_maxunlag").FloatValue;
					correct = (correct > sv_unlag ? sv_unlag : (correct < 0.0 ? 0.0 : correct));
				
			//		PrintCenterText(client, "correct %f tickcount %i", correct, tickcount);
					
					ScaleVector(target_velocity, correct);
					SubtractVectors(target_point, target_velocity, target_point);
					
					float vecPunch[3];
					GetEntPropVector(client, Prop_Send, "m_vecPunchAngle", vecPunch);
					AddVectors(target_point, vecPunch, target_point);
				}
			}
			else
			{
				SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(client, g_hHudInfo, "[%i / %i HP]", GetEntProp(iTarget, Prop_Data, "m_iHealth"), GetEntProp(iTarget, Prop_Data, "m_iMaxHealth"));
			}
			
			float eye_to_target[3];
			SubtractVectors(target_point, myEyePosition, eye_to_target);
			GetVectorAngles(eye_to_target, eye_to_target);
			
			eye_to_target[0] = AngleNormalize(eye_to_target[0]);
			eye_to_target[1] = AngleNormalize(eye_to_target[1]);
			eye_to_target[2] = 0.0;
			
			if(g_bAutoShoot[client])
			{
				if(IsReadyToFire(iAw))
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

stock float[] PredictCorrection(int iClient, int iWeapon, int iTarget, float vecFrom[3], int iQuality)
{
	if(!IsValidEntity(iWeapon))
		return vecFrom;
		
	float flSpeed = GetProjectileSpeed(iWeapon);
	
	if(flSpeed <= 0.0)
		return vecFrom;
		
	float sv_gravity = GetConVarFloat(FindConVar("sv_gravity")) * PlayerGravityMod(iClient);
	
	float flLag = GetPlayerLerp(iClient);
	
	bool bOnGround = ((GetEntityFlags(iTarget) & FL_ONGROUND) != 0);
	
	float vecWorldGravity[3]; vecWorldGravity[2] = -sv_gravity * (bOnGround ? 0.0 : 1.0) * GetTickInterval() * GetTickInterval();
	float vecProjGravity[3];  vecProjGravity[2]  = sv_gravity  * GetProjectileGravity(iWeapon) * GetTickInterval() * GetTickInterval();
	
	float vecVelocity[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", vecVelocity);
//	vecVelocity = view_as<float>( { -0.000010, 239.999984, -160.999984 } );
	
	float vecProjVelocity[3]; vecProjVelocity = vecProjGravity;
	
	// get the current position
	// this is not important - any point inside the collideable will work.
	float vecStepPos[3]
	GetClientAbsOrigin(iTarget, vecStepPos);
	
	float vecMins[3], vecMaxs[3];
	GetClientMins(iTarget, vecMins);
	GetClientMaxs(iTarget, vecMaxs);
	
	// get velocity for a single tick
	ScaleVector(vecVelocity, GetTickInterval());
	ScaleVector(vecProjVelocity, GetTickInterval());
	
	float vecPredictedPos[3]; vecPredictedPos = vecStepPos;
	
	// get the current arival time
	float vecPredictedProjVel[3]; vecPredictedProjVel = vecProjVelocity; // TODO: rename - this is used for gravity
	
	float subtracted[3];
	SubtractVectors(vecFrom, vecPredictedPos, subtracted);
	
	float flArrivalTime = GetVectorLength(subtracted) / (flSpeed) + flLag + GetTickInterval();
	float vecPredictedVel[3]; vecPredictedVel = vecVelocity;
	
	Handle Trace = null;
	
	int iSteps = 0;
	
	for(float flTravelTime = 0.0; flTravelTime < flArrivalTime; flTravelTime += (GetTickInterval() * iQuality))
	{
		// trace the velocity of the target
		float vecPredicted[3];
		AddVectors(vecPredictedPos, vecPredictedVel, vecPredicted);
		
		Trace = TR_TraceHullFilterEx(vecPredictedPos, vecPredicted, vecMins, vecMaxs, MASK_PLAYERSOLID, AimTargetFilter, iTarget);
		
		if(TR_GetFraction(Trace) != 1.0)
		{
			float vecNormal[3];
			TR_GetPlaneNormal(Trace, vecNormal);
			
			PhysicsClipVelocity(vecPredictedVel, vecNormal, vecPredictedVel, 1.0);
		}
		
		float vecTraceEnd[3];
		TR_GetEndPosition(vecTraceEnd, Trace);
		
		vecPredictedPos = vecTraceEnd;
		
		delete Trace;
		vecPredicted = NULL_VECTOR;
		
		// trace the gravity of the target
		AddVectors(vecPredictedPos, vecWorldGravity, vecPredicted);
		
		Trace = TR_TraceHullFilterEx(vecPredictedPos, vecPredicted, vecMins, vecMaxs, MASK_PLAYERSOLID, AimTargetFilter, iTarget);
		
		// this is important - we predict the world as moving up in order to predict for the projectile moving down
		AddVectors(vecPredictedVel, vecPredictedProjVel, vecPredictedVel);
		
		if(TR_GetFraction(Trace) == 1.0)
		{
			bOnGround = false;
			AddVectors(vecPredictedVel, vecWorldGravity, vecPredictedVel);
		}
		else if(!bOnGround)
		{
			float surfaceFriction = 1.0;
		//	gInts->PhysicsSurfaceProps->GetPhysicsProperties(tr.surface.surfaceProps, NULL, NULL, &surfaceFriction, NULL);
			
			if(PhysicsApplyFriction(vecPredictedVel, vecPredictedVel, surfaceFriction, GetTickInterval()))
			{
				break;
			}
		}
		
		delete Trace;
		
		float temp[3];
		SubtractVectors(vecFrom, vecPredictedPos, temp);
		
		flArrivalTime = GetVectorLength(temp) / (flSpeed) + flLag + GetTickInterval();
		
		// if they are moving away too fast then there is no way we can hit them - bail!!
		if(GetVectorLength(vecPredictedVel) > flSpeed)
		{
		//	PrintToChatAll("Target too fast! id = %d", iTarget);
			break;
		}
		
		iSteps++;
	}
	
//	PrintToServer("Simulation ran for %i steps", iSteps);

//	DrawDebugArrow(vecStepPos, vecPredictedPos, view_as<float>({255, 255, 0, 255}), 0.075);

	float flOut[3];
	SubtractVectors(vecPredictedPos, vecStepPos, flOut);
	
	return flOut;
}

stock float PlayerGravityMod(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Parachute))
		return 0.448;
		
	return 1.0;
}

stock void DrawDebugArrow(float vecFrom[3], float vecTo[3], float color[4], float life = 0.1)
{
	float subtracted[3];
	SubtractVectors(vecTo, vecFrom, subtracted);
	
	float angRotation[3];
	GetVectorAngles(subtracted, angRotation);
	
	float vecForward[3], vecRight[3], vecUp[3];
	GetAngleVectors(angRotation, vecForward, vecRight, vecUp);
	
	TE_SetupBeamPoints(vecFrom, vecTo, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, life, 2.0, 2.0, 5, 0.0, color, 30);
	TE_SendToAllInRange(vecFrom, RangeType_Visibility);

	float multi[3];
	multi[0] = vecRight[0] * 25;
	multi[1] = vecRight[1] * 25;
	multi[2] = vecRight[2] * 25;

	float subtr[3];
	SubtractVectors(vecFrom, multi, subtr);
	
	TE_SetupBeamPoints(vecFrom, subtr, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, life, 2.0, 5.0, 5, 0.0, view_as<float>({255, 0, 0, 255}), 30);
	TE_SendToAllInRange(vecFrom, RangeType_Visibility);
}

void PhysicsClipVelocity(const float input[3], float normal[3], float out[3], float overbounce)
{
	float backoff = GetVectorDotProduct(input, normal) * overbounce;

	for(int i = 0; i < 3; ++i)
	{
		float change = normal[i] * backoff;
		out[i] = input[i] - change;

		if(out[i] > -0.1 && out[i] < 0.1)
			out[i] = 0.0;
	}

	float adjust = GetVectorDotProduct(out, normal);

	if(adjust < 0.0)
	{
		ScaleVector(normal, adjust);
		
		SubtractVectors(out, normal, out);
	//	out -= (normal * adjust);
	}
}

bool PhysicsApplyFriction(float input[3], float out[3], float flSurfaceFriction, float flTickRate)
{
	float sv_friction = GetConVarFloat(FindConVar("sv_friction"));
	float sv_stopspeed = GetConVarFloat(FindConVar("sv_stopspeed"));

	float speed = GetVectorLength(input) / flTickRate;

	if(speed < 0.1)
		return false;

	float drop = 0.0;

	if(flSurfaceFriction != -1.0)
	{
		float friction = sv_friction * flSurfaceFriction;
		float control = (speed < sv_stopspeed) ? sv_stopspeed : speed;
		drop += control * friction * flTickRate;
	}

	float newspeed = speed - drop;

	if(newspeed < 0.0)
		newspeed = 0.0;

	if(newspeed != speed)
	{
		newspeed /= speed;
		
		out[0] = input[0] * newspeed;
		out[1] = input[1] * newspeed;
		out[2] = input[2] * newspeed;
	}

	out[0] -= input[0] * (1.0 - newspeed);
	out[1] -= input[1] * (1.0 - newspeed);
	out[2] -= input[2] * (1.0 - newspeed);
	
	out[0] *= flTickRate;
	out[1] *= flTickRate;
	out[2] *= flTickRate;
	
	return true;
}

bool IsPlayerReloading(int client)
{
	int PlayerWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	if(!IsValidEntity(PlayerWeapon))
		return false;
	
	//Fix for pyro flamethrower aimbot not aiming.	
	if(TF2_GetPlayerClass(client) == TFClass_Pyro && GetPlayerWeaponSlot(client, 0) == PlayerWeapon)
		return false;
	
	//Wrangler doesn't reload
	if(SDKCall(g_hGetWeaponID, PlayerWeapon) == TF_WEAPON_LASER_POINTER)
		return false;
	
	//Melee weapons don't reload
	if (GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) == PlayerWeapon)
	    return false;
	
	int AmmoCur = GetEntProp(PlayerWeapon, Prop_Send, "m_iClip1");
	int AmmoMax = SDKCall(g_hGetMaxClip, PlayerWeapon);
	
	if (AmmoCur == AmmoMax)
	    return false;
	
	if (GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flLastFireTime") > GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flReloadPriorNextFire"))
	    return false;
	
	return true;
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
		
		TR_TraceRayFilter(flMyPos, flTheirPos, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, client);
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

stock int GetMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
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

stock float Max(float one, float two)
{
	if(one > two)
		return one;
	else if(two > one)
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

stock int FindBestHitbox(int client, float playerEyeAngles[3], int target)
{
	int iBestHitBox = LookupBone(target, "bip_spine_2");
	int iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	TFClassType playerClass = TF2_GetPlayerClass(client);
	
	if(iActiveWeapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
	{
		//If they're a sniper and zoomed in or a spy..
		if (((TF2_IsPlayerInCondition(client, TFCond_Zoomed) || SDKCall(g_hGetWeaponID, iActiveWeapon) == TF_WEAPON_COMPOUND_BOW) && playerClass == TFClass_Sniper)
		|| playerClass == TFClass_Spy)
		{
			//Aim at head
			iBestHitBox = LookupBone(target, "bip_head");
		}
	}
	
	if(iBestHitBox != -1 && IsBoneVisible(client, playerEyeAngles, target, iBestHitBox))
	{
		return iBestHitBox;
	}
	else
	{
		iBestHitBox = -1;
		
		for (int i = 0; i < 17; i++)	//Replace with GetNumBones eventually.
		{
			if(IsBoneVisible(client, playerEyeAngles, target, i))
			{
				iBestHitBox = i;
				break;
			}
		}
	}
	
	return iBestHitBox;
}

stock int LookupBone(int iEntity, const char[] szName)
{
	return SDKCall(g_hLookupBone, iEntity, szName);
}

stock void GetBonePosition(int iEntity, int iBone, float origin[3], float angles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, origin, angles);
}

stock bool IsBoneVisible(int player, float playerEyeAngles[3], int target, int bone)
{
	float vecEyePosition[3];
	GetClientEyePosition(player, vecEyePosition);

	float vNothing[3], vOrigin[3];
	GetBonePosition(target, bone, vOrigin, vNothing);
	
	if(g_iAimType[player] == AIM_FOV && target > 0 && target <= MaxClients)
	{
		float vTEyeAngles[3];
		GetClientEyeAngles(target, vTEyeAngles);
		
		float vTargetAngles[3];
		
		// Get the angle needed to aim at the enemy
		SubtractVectors(vecEyePosition, vOrigin, vTargetAngles);
		
		float flFov = angleFOV(playerEyeAngles, vecEyePosition, vOrigin);
		
		return (flFov <= g_flAimFOV[player]) && IsPointVisible(player, target, vecEyePosition, vOrigin);
	}
	
	return IsPointVisible(player, target, vecEyePosition, vOrigin);
}

float angleFOV(float angle[3], float src[3], float dest[3])
{
	float f[3];
	float d[3];
	
	GetAngleVectors(angle, f, NULL_VECTOR, NULL_VECTOR);
	
	SubtractVectors(dest, src, d);
	NormalizeVector(d, d);
	
	return Max(angleBetween(f, d), 0.0);
}

float angleBetween(float f[3], float v[3])
{
	return RadToDeg(ArcCosine(GetVectorDotProduct(f, v)));
}  

stock bool IsPointVisible(int looker, int target, float start[3], float point[3])
{
	TR_TraceRayFilter(start, point, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, looker);
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

stock bool TF2_IsKillable(int entity)
{
	bool bResult = true;

	if(entity > 0 && entity <= MaxClients)
	{
		if(TF2_IsPlayerInCondition(entity, TFCond_Ubercharged) 
		|| TF2_IsPlayerInCondition(entity, TFCond_UberchargedHidden) 
		|| TF2_IsPlayerInCondition(entity, TFCond_UberchargedCanteen)
		|| TF2_IsPlayerInCondition(entity, TFCond_Bonked))
		{
			bResult = false;
		}
	}
	
	if(GetEntProp(entity, Prop_Data, "m_takedamage") != 2)
	{
		bResult = false;
	}
	
	return bResult;
}

char strTargetEntities[][] =
{
	"player",
	"tank_boss",
	"headless_hatman",
	"eyeball_boss",
	"merasmus",
	"tf_zombie",
	"tf_robot_destruction_robot",
	"obj_sentrygun",
	"obj_dispenser",
	"obj_teleporter"
}

stock int FindBestTarget(int client, float playerEyeAngles[3])
{
	float flBestDistance = 99999.0;
	int iBestTarget = -1;
	
	float flPos[3];
	GetClientEyePosition(client, flPos);

	if(g_bTeammates[client])
	{
		int iLowestHP = 999999;
		for (int i = 1; i <= MaxClients; i++)
		{
			if(i == client)
				continue;
			
			if(!IsClientInGame(i))
				continue;
			
			if(!IsPlayerAlive(i))
				continue;
			
			if(GetEntProp(i, Prop_Send, "m_iTeamNum") != GetClientTeam(client))
				continue;
			
			if(!TF2_IsKillable(i))
				continue;
			
			int iBone = FindBestHitbox(client, playerEyeAngles, i);
			if(iBone == -1)
				continue;
			
			if(IsBoneVisible(client, playerEyeAngles, i, iBone))
			{
				int iMaxHealth = GetMaxHealth(i);
				int iHealth = GetEntProp(i, Prop_Data, "m_iHealth");
				
			//	PrintToServer("%N %i / %i", i, iMaxHealth, iHealth);
				
				if(iHealth < iMaxHealth && iHealth < iLowestHP)
				{
					iLowestHP = iHealth;
					iBestTarget = i;
				}
			}
		}
		
		return iBestTarget;
	}

	for (int i = 0; i < ((g_bTeammates[client]) ? 1 : sizeof(strTargetEntities)); i++)
	{
		int iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, strTargetEntities[i])) != -1)
		{
			int iTarget = iEnt;
		
			if(iTarget == client)
				continue;
			
			if(GetEntProp(iTarget, Prop_Send, "m_iTeamNum") == GetClientTeam(client) && !g_bTeammates[client])
				continue;
			
			if(!TF2_IsKillable(iTarget))
				continue;
			
			if(StrEqual(strTargetEntities[i], "player"))
			{
				if(!IsClientInGame(iEnt))
					continue;
				
				if(!IsPlayerAlive(iEnt))
					continue;
				
				int iBone = FindBestHitbox(client, playerEyeAngles, iTarget);
				if(iBone == -1)
					continue;
				
				int iHealer = FindHealer(iTarget);
				if(iHealer != -1)
				{
					iBone = FindBestHitbox(client, playerEyeAngles, iHealer);
					if(IsBoneVisible(client, playerEyeAngles, iHealer, iBone))
					{
						iTarget = iHealer;
					}
				}
				
				if(IsBoneVisible(client, playerEyeAngles, iTarget, iBone))
				{
					float flTheirOrigin[3];
					GetClientAbsOrigin(iTarget, flTheirOrigin);
					
					float flDistance = GetVectorDistance(flPos, flTheirOrigin);
					
					if(flDistance < flBestDistance)
					{
						flBestDistance = flDistance;
						iBestTarget = iTarget;
					}
				}
			}
			else
			{
				int iBone = FindBestHitbox(client, playerEyeAngles, iTarget);
				if(iBone == -1)
					continue;
				
				if(IsBoneVisible(client, playerEyeAngles, iTarget, iBone))
				{
					float flTheirOrigin[3];
					GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", flTheirOrigin);
					
					float flDistance = GetVectorDistance(flPos, flTheirOrigin);
					
					if(flDistance < flBestDistance)
					{
						flBestDistance = flDistance;
						iBestTarget = iTarget;
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

stock bool IsHitScanWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_SMG:                   return true;
		case TF_WEAPON_PISTOL:                return true;
		case TF_WEAPON_MINIGUN:               return true;
		case TF_WEAPON_REVOLVER:              return true;
		case TF_WEAPON_SCATTERGUN:            return true;
		case TF_WEAPON_SNIPERRIFLE:           return true;
		case TF_WEAPON_SHOTGUN_HWG:           return true;
		case TF_WEAPON_SODA_POPPER:           return true;
		case TF_WEAPON_SHOTGUN_PYRO:          return true;
		case TF_WEAPON_PISTOL_SCOUT:          return true;
		case TF_WEAPON_SENTRY_BULLET:         return true;
		case TF_WEAPON_SENTRY_ROCKET:         return true;
		case TF_WEAPON_SENTRY_REVENGE:        return true;
		case TF_WEAPON_SHOTGUN_SOLDIER:       return true;
		case TF_WEAPON_SHOTGUN_PRIMARY:       return true;
		case TF_WEAPON_HANDGUN_SCOUT_SEC:     return true;
		case TF_WEAPON_PEP_BRAWLER_BLASTER:   return true;
		case TF_WEAPON_SNIPERRIFLE_CLASSIC:   return true;
		case TF_WEAPON_HANDGUN_SCOUT_PRIMARY: return true;
	}
	
	return false;
}

stock bool IsProjectileWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
	//	case TF_WEAPON_BAT_WOOD:                return true;	//Crashes server
		case TF_WEAPON_SYRINGEGUN_MEDIC:        return true;
		case TF_WEAPON_ROCKETLAUNCHER:          return true;
		case TF_WEAPON_GRENADELAUNCHER:         return true;
		case TF_WEAPON_PIPEBOMBLAUNCHER:        return true;
		case TF_WEAPON_FLAMETHROWER:            return true;
		case TF_WEAPON_FLAMETHROWER_ROCKET:     return true;
		case TF_WEAPON_GRENADE_DEMOMAN:         return true;
		case TF_WEAPON_SENTRY_ROCKET:           return true;
		case TF_WEAPON_FLAREGUN:                return true;
		case TF_WEAPON_COMPOUND_BOW:            return true;
		case TF_WEAPON_DIRECTHIT:               return true;
		case TF_WEAPON_CROSSBOW:                return true;
		case TF_WEAPON_STICKBOMB:               return true;
		case TF_WEAPON_PARTICLE_CANNON:         return true;
		case TF_WEAPON_DRG_POMSON:              return true;
		case TF_WEAPON_BAT_GIFTWRAP:            return true;
		case TF_WEAPON_GRENADE_ORNAMENT:        return true;
		case TF_WEAPON_RAYGUN_REVENGE:          return true;
		case TF_WEAPON_CLEAVER:                 return true;
		case TF_WEAPON_GRENADE_CLEAVER:         return true;
		case TF_WEAPON_STICKY_BALL_LAUNCHER:    return true;
		case TF_WEAPON_GRENADE_STICKY_BALL:     return true;
		case TF_WEAPON_SHOTGUN_BUILDING_RESCUE: return true;
		case TF_WEAPON_CANNON:                  return true;
		case TF_WEAPON_THROWABLE:               return true;
		case TF_WEAPON_GRENADE_THROWABLE:       return true;
		case TF_WEAPON_SPELLBOOK:               return true;
		case TF_WEAPON_GRAPPLINGHOOK:           return true;
		case TF_WEAPON_PASSTIME_GUN:            return true;
		case TF_WEAPON_JAR:                     return true;
		case TF_WEAPON_JAR_MILK:                return true;
		case TF_WEAPON_RAYGUN:                  return true;
	}
	
	return false;
}

//Bad name, meant for weapons which you can target teammates with
stock bool IsTeammateWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_MEDIGUN:  return true;
		case TF_WEAPON_CROSSBOW: return true;
	}
	
	return false;
}

stock bool IsReadyToFire(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_SNIPERRIFLE, TF_WEAPON_SNIPERRIFLE_DECAP:
		{
			float flDamage = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargedDamage");
			if (flDamage < 10.0)
			{
				return false;
			}
		}
		case TF_WEAPON_SNIPERRIFLE_CLASSIC:
		{
			if(GetEntProp(iWeapon, Prop_Send, "m_bCharging"))
			{
				float flDamage = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargedDamage");
				
				if (flDamage >= 150.0)
				{
					return false;
				}
				
				return true;
			}
		}
		case TF_WEAPON_COMPOUND_BOW:
		{
			float flChargeBeginTime = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeBeginTime");
			
			float flCharge = flChargeBeginTime == 0.0 ? 0.0 : GetGameTime() - flChargeBeginTime;
			
			if(flCharge > 0.0)
			{
				return false;
			}
		}
		case TF_WEAPON_REVOLVER:
		{
			float flLastFireTime = GetGameTime() - GetEntPropFloat(iWeapon, Prop_Send, "m_flLastFireTime");
			
			if(flLastFireTime < 0.95)
			{
				return false;
			}
		}
	}
	
	return true;
}

stock bool IsExplosiveProjectileWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_PIPEBOMBLAUNCHER: return true;
		case TF_WEAPON_GRENADELAUNCHER:  return true;
		case TF_WEAPON_PARTICLE_CANNON:  return true;
		case TF_WEAPON_ROCKETLAUNCHER:   return true;
		case TF_WEAPON_DIRECTHIT:        return true;
		case TF_WEAPON_CANNON:           return true;
		case TF_WEAPON_JAR:              return true;
	}
	
	return false;
}

//Always make sure IsProjectileWeapon is true before calling this.
stock float GetProjectileSpeed(int iWeapon)
{	
	float flProjectileSpeed = SDKCall(g_hGetProjectileSpeed, iWeapon);
	if(flProjectileSpeed == 0.0)
	{
		//Some projectiles speeds are hardcoded so we manually return them here.
		switch(SDKCall(g_hGetWeaponID, iWeapon))
		{
			case TF_WEAPON_ROCKETLAUNCHER:   flProjectileSpeed = 1100.0;
			case TF_WEAPON_DIRECTHIT:        flProjectileSpeed = 1980.0;
			case TF_WEAPON_FLAREGUN:         flProjectileSpeed = 2000.0;
			case TF_WEAPON_RAYGUN_REVENGE:   flProjectileSpeed = 2000.0; //Manmelter
			case TF_WEAPON_FLAMETHROWER:     flProjectileSpeed = 1500.0;
			case TF_WEAPON_SYRINGEGUN_MEDIC: flProjectileSpeed = 990.0;
		}
	}
	
	return flProjectileSpeed;
}

stock float GetProjectileGravity(int iWeapon)
{
	float flProjectileGravity = SDKCall(g_hGetProjectileGravity, iWeapon);
	
	//Wrong.
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_JAR:                     flProjectileGravity = 50.0;
		case TF_WEAPON_CANNON:                  flProjectileGravity = 75.0;
		case TF_WEAPON_FLAREGUN:                flProjectileGravity = 18.5;
		case TF_WEAPON_RAYGUN_REVENGE:          flProjectileGravity = 12.5; //Manmelter
		case TF_WEAPON_CROSSBOW:                flProjectileGravity *= 65.0;
		case TF_WEAPON_COMPOUND_BOW:            flProjectileGravity *= 65.0;
		case TF_WEAPON_GRENADELAUNCHER:         flProjectileGravity = 50.0;
		case TF_WEAPON_SYRINGEGUN_MEDIC:        flProjectileGravity = 15.0;
		case TF_WEAPON_SHOTGUN_BUILDING_RESCUE: flProjectileGravity *= 70.0;
	}
	
	return flProjectileGravity;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "player"))
	{
		if(GetClientTeam(entity) == GetClientTeam(iExclude) && !g_bTeammates[iExclude])
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
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	
	return !(entity == iExclude);
}

public bool WorldOnly(int entity, int contentsMask, any iExclude)
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

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock float GetPlayerLerp(int client)
{
	return GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
}

stock void TE_SendBox(float vMins[3], float vMaxs[3], int color[4])
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
//	TE_SendBeam(vMaxs, vPos1, color);
//	TE_SendBeam(vMaxs, vPos2, color);
	TE_SendBeam(vMaxs, vPos3, color);	//Vertical
//	TE_SendBeam(vPos6, vPos1, color);
//	TE_SendBeam(vPos6, vPos2, color);
	TE_SendBeam(vPos6, vMins, color);	//Vertical
//	TE_SendBeam(vPos4, vMins, color);
//	TE_SendBeam(vPos5, vMins, color);
	TE_SendBeam(vPos5, vPos1, color);	//Vertical
//	TE_SendBeam(vPos5, vPos3, color);
//	TE_SendBeam(vPos4, vPos3, color);
	TE_SendBeam(vPos4, vPos2, color);	//Vertical
}

stock void TE_SendBeam(const float vMins[3], const float vMaxs[3], const int color[4])
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 0, 0.075, 1.0, 1.0, 1, 0.0, color, 0);
	TE_SendToAll();
}
