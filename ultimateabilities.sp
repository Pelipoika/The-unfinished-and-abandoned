#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2_extras>
#include <tf2attributes>
#include <tf2items>

#pragma newdecls required

#define DMG_SCOUT    100
#define DMG_SOLDIER  100
#define DMG_PYRO     100
#define DMG_DEMO     100
#define DMG_HEAVY    100
#define DMG_ENGINEER 100
#define DMG_MEDIC    100
#define DMG_SNIPER   100
#define DMG_SPY      100

char g_strClassName[][] = {"", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"};
char g_strSoundRobotFallDamage[][] = {"mvm/mvm_fallpain01.wav", "mvm/mvm_fallpain02.wav"};
char g_strSoundRobotFootsteps[][] = 
{
	"mvm/player/footsteps/robostep_01.wav", "mvm/player/footsteps/robostep_02.wav", "mvm/player/footsteps/robostep_03.wav", "mvm/player/footsteps/robostep_04.wav", 
	"mvm/player/footsteps/robostep_05.wav", "mvm/player/footsteps/robostep_06.wav", "mvm/player/footsteps/robostep_07.wav", "mvm/player/footsteps/robostep_08.wav", 
	"mvm/player/footsteps/robostep_09.wav", "mvm/player/footsteps/robostep_10.wav", "mvm/player/footsteps/robostep_11.wav", "mvm/player/footsteps/robostep_12.wav", 
	"mvm/player/footsteps/robostep_13.wav", "mvm/player/footsteps/robostep_14.wav", "mvm/player/footsteps/robostep_15.wav", "mvm/player/footsteps/robostep_16.wav", 
	"mvm/player/footsteps/robostep_17.wav", "mvm/player/footsteps/robostep_18.wav"
};

//General
int g_iDamageDone[MAXPLAYERS+1];
bool g_bAbilityActive[MAXPLAYERS+1];
float g_flAbilityTime[MAXPLAYERS+1];

//Resurrect
float flDeathPos[MAXPLAYERS+1][3];
float flDeathAng[MAXPLAYERS+1][3];

//Deadeye
int g_iTarget[MAXPLAYERS+1];
float g_flLockOnTime[MAXPLAYERS+1];
bool g_bLocked[MAXPLAYERS+1];

//Grapple
bool g_bGrappling[MAXPLAYERS + 1];

Handle g_hHudInfo;

#define MODEL_ENGINEER	"models/bots/engineer/bot_engineer.mdl"
#define MODEL_GRAVITON	"models/empty.mdl"
#define ENGINE_LOOP		"mvm/giant_heavy/giant_heavy_loop.wav"

//mannpower_imbalance_blue
//mannpower_imbalance_red

public Plugin myinfo = 
{
	name = "[TF2] Ultimate Abilities",
	author = "Pelipoika",
	description = "Overwatch style ultimate abilities. They copied us, now we copy them.",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	g_hHudInfo = CreateHudSynchronizer();
	
	AddNormalSoundHook(NormalSoundHook);
}

public void OnMapStart()
{
	PrecacheModel(MODEL_GRAVITON);
	PrecacheModel(MODEL_ENGINEER);
	PrecacheSound(ENGINE_LOOP);
	
	PrecacheSound("misc/cp_harbor_blue_whistle.wav");
	PrecacheSound("misc/cp_harbor_red_whistle.wav");
	PrecacheSound("misc/halloween/duck_pickup_pos_01.wav");
	PrecacheSound("misc/halloween/duck_pickup_neg_01.wav");
	PrecacheSound("replay/cameracontrolmodeentered.wav");
	PrecacheSound("replay/cameracontrolmodeexited.wav");
	PrecacheSound("replay/enterperformancemode.wav");
	PrecacheSound("replay/exitperformancemode.wav");
	PrecacheSound("weapons/medi_shield_deploy.wav");
	PrecacheSound("misc/halloween_eyeball/vortex_eyeball_moved.wav");
	PrecacheSound("weapons/airstrike_fire_01.wav");
	PrecacheSound("weapons/airstrike_fire_02.wav");
	PrecacheSound("weapons/airstrike_fire_03.wav");
	
	for(int i = 0; i < sizeof(g_strSoundRobotFootsteps); i++)	PrecacheSound(g_strSoundRobotFootsteps[i]);
	for(int i = 0; i < sizeof(g_strSoundRobotFallDamage); i++)	PrecacheSound(g_strSoundRobotFallDamage[i]);
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char strCmd[256];
	kv.GetSectionName(strCmd, 256);
	
	int iDmg;
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:		iDmg = DMG_SCOUT;
		case TFClass_Soldier:	iDmg = DMG_SOLDIER;
		case TFClass_Pyro:		iDmg = DMG_PYRO;
		case TFClass_DemoMan:	iDmg = DMG_DEMO;
		case TFClass_Heavy:		iDmg = DMG_HEAVY;
		case TFClass_Engineer:	iDmg = DMG_ENGINEER;
		case TFClass_Medic:		iDmg = DMG_MEDIC;
		case TFClass_Sniper:	iDmg = DMG_SNIPER;
		case TFClass_Spy:		iDmg = DMG_SPY;
	}
	
	if(StrEqual(strCmd, "+use_action_slot_item_server") && client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && g_iDamageDone[client] >= iDmg && !g_bAbilityActive[client])
	{
		MeleeDare(client);

		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier:
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					g_iDamageDone[client] = 0;
					g_flAbilityTime[client] = GetGameTime() + 3.0;
					g_bAbilityActive[client] = true;
					
					SetEntityMoveType(client, MOVETYPE_NONE);
					FireRocket(client);
					Overlay(client, "effects/combine_binocoverlay");
				}
			}
			case TFClass_DemoMan:
			{
				float flStartPos[3], flEyeAng[3], flForw[3];
				GetClientEyePosition(client, flStartPos);
				GetClientEyeAngles(client, flEyeAng);
				
				GetAngleVectors(flEyeAng, flForw, NULL_VECTOR, NULL_VECTOR) 
		
				flStartPos[0] += (flForw[0] * 100.0);
				flStartPos[1] += (flForw[1] * 100.0);
				flStartPos[2] += (flForw[2] * 100.0);
				
				Handle hTrace = TR_TraceRayFilterEx(flStartPos, flEyeAng, MASK_SHOT, RayType_Infinite, AimTargetFilter, client);
				float flHitPos[3];
				TR_GetEndPosition(flHitPos, hTrace);
				
				float flResult[3];
				SubtractVectors(flStartPos, flHitPos, flResult);
				NegateVector(flResult);
				NormalizeVector(flResult, flResult);
				ScaleVector(flResult, 1000.0);
			
				g_iDamageDone[client] = 0;
				g_flAbilityTime[client] = GetGameTime() + 10.0;
				g_bAbilityActive[client] = true;
				
				int bomb = CreateEntityByName("tf_projectile_pipe_remote");	
				DispatchKeyValueVector(bomb, "origin", flStartPos);
				DispatchKeyValueVector(bomb, "basevelocity", flResult);
				DispatchKeyValueVector(bomb, "velocity", flResult);
				DispatchKeyValue(bomb, "ModelScale", "5.0");
				
				if (TF2_GetClientTeam(client) == TFTeam_Red) 
					DispatchKeyValue(bomb, "skin", "0");
				else if (TF2_GetClientTeam(client) == TFTeam_Blue) 
					DispatchKeyValue(bomb, "skin", "1");
			
				SetEntPropEnt(bomb, Prop_Data, "m_hThrower", client);
				SetEntProp(bomb, Prop_Send, "m_iType", 1);
				SetEntPropFloat(bomb, Prop_Data, "m_flDetonateTime", GetGameTime() + 6.0);
				
				DispatchSpawn(bomb);
				
				SetEntityModel(bomb, MODEL_GRAVITON);

				if(TF2_GetClientTeam(client) == TFTeam_Blue)
					Particle_Create(bomb, "spell_fireball_small_blue", _, 1.0, true);
				else
					Particle_Create(bomb, "spell_fireball_small_red", _, 1.0, true);
					
				TeleportEntity(bomb, NULL_VECTOR, NULL_VECTOR, flResult);

				SDKHook(bomb, SDKHook_Think, OnGravitonThink);
			}
			case TFClass_Heavy:
			{
				g_iDamageDone[client] = 0;
				g_flAbilityTime[client] = GetGameTime() + 20.0;
				g_bAbilityActive[client] = true;
			
				int shield = CreateEntityByName("entity_medigun_shield");	
				SetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity", client);  
				SetEntProp(shield, Prop_Send, "m_iTeamNum", GetClientTeam(client));  
				SetEntProp(shield, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));  
				
				if (TF2_GetClientTeam(client) == TFTeam_Red) 
					DispatchKeyValue(shield, "skin", "0");
				else if (TF2_GetClientTeam(client) == TFTeam_Blue) 
					DispatchKeyValue(shield, "skin", "1");
				
				SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 200.0);
				SetEntProp(client, Prop_Send, "m_bRageDraining", 1);
				
				DispatchSpawn(shield);
				
				EmitSoundToClient(client, "weapons/medi_shield_deploy.wav", shield);
				SetEntityModel(shield, "models/props_mvm/mvm_player_shield2.mdl");
			}
			case TFClass_Medic:
			{
				g_iDamageDone[client] = 0;
			
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && !IsPlayerAlive(i) && TF2_GetClientTeam(i) == TF2_GetClientTeam(client))
					{
						TF2_RespawnPlayer(i);
						
						float flTimeImmunity = 3.0;
						
						TF2_AddCondition(i, TFCond_UberchargedCanteen, flTimeImmunity);
						TeleportEntity(i, flDeathPos[i], flDeathAng[i], NULL_VECTOR);
						
						Particle_Create(i, "teleporter_mvm_bot_persist", 0.0, flTimeImmunity);
						
						SetVariantString("randomnum:30");
						AcceptEntityInput(i, "AddContext");

						SetVariantString("TLK_RESURRECTED");
						AcceptEntityInput(i, "SpeakResponseConcept");

						AcceptEntityInput(i, "ClearContext");
					}
				}
			}
			case TFClass_Engineer:
			{
				g_iDamageDone[client] = 0;
				g_flAbilityTime[client] = GetGameTime() + 20.0;
				g_bAbilityActive[client] = true;
				
				SetVariantString(MODEL_ENGINEER);
				AcceptEntityInput(client, "SetCustomModel");
				SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
				
				EmitSoundToAll(ENGINE_LOOP, client, _, _, _, 0.5);
				
				if(TF2_GetClientTeam(client) == TFTeam_Blue)
					EmitSoundToAll("misc/cp_harbor_blue_whistle.wav", client, _, _, _, 0.25);	//LOUD
				else
					EmitSoundToAll("misc/cp_harbor_red_whistle.wav", client, _, _, _, 0.25);
				
				int iPrimary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
				TF2Attrib_SetByName(iPrimary, "fire rate bonus", 0.75);
				int iSecondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
				TF2Attrib_SetByName(iSecondary, "fire rate bonus", 0.75);
				int iMelee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
				TF2Attrib_SetByName(iMelee, "melee attack rate bonus", 0.5);
				TF2Attrib_SetByName(iMelee, "Construction rate increased", 2.0);
				
				Particle_Create(client, "ghost_appearation", 20.0, 2.0);
			}
			case TFClass_Sniper:
			{
				g_flAbilityTime[client] = GetGameTime() + 12.0;
				g_iDamageDone[client] = 0;
				g_bAbilityActive[client] = true;
			
				Handle TF2Item = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
				TF2Items_SetClassname(TF2Item, "tf_weapon_grapplinghook");
				TF2Items_SetItemIndex(TF2Item, 1152);
				TF2Items_SetLevel(TF2Item, 100);
				
				int ItemEntity = TF2Items_GiveNamedItem(client, TF2Item);
				delete TF2Item;

				EquipPlayerWeapon(client, ItemEntity);

				FakeClientCommand(client, "use tf_weapon_grapplinghook");
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", ItemEntity);
			}
			case TFClass_Spy:
			{
				g_iDamageDone[client] = (iDmg / 2);
				g_flAbilityTime[client] = GetGameTime() + 20.0;
				g_bAbilityActive[client] = true;
				
				g_flLockOnTime[client] = GetGameTime() + 1.0;
				g_bLocked[client] = false;
				g_iTarget[client] = -1;
				
				EmitSoundToAll("replay/enterperformancemode.wav", client);
				EmitSoundToClient(client, "replay/cameracontrolmodeentered.wav");
				TF2_SetFOV(client, GetEntProp(client, Prop_Send, "m_iDefaultFOV"), 1.0, 0);
				Overlay(client, "effects/combine_binocoverlay");
			}
		}
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

void OnGravitonThink(int iEnt)
{
	float flPos[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", flPos);
	
	int iClient = GetEntPropEnt(iEnt, Prop_Data, "m_hThrower");
	
	if(GetEntProp(iEnt, Prop_Send, "m_bTouched") == 1)
	{
		if(GetEntProp(iEnt, Prop_Send, "m_bIsLive") == 0)
		{
			EmitSoundToAll("misc/halloween_eyeball/vortex_eyeball_moved.wav", iEnt);
			
			Particle_Create(iEnt, "eyeboss_tp_vortex", _, _, true);
			
			if(TF2_GetClientTeam(iClient) == TFTeam_Blue)
				Particle_Create(iEnt, "eyeboss_vortex_blue", _, _, true);
			else
				Particle_Create(iEnt, "eyeboss_vortex_red", _, _, true);
			
			SetEntProp(iEnt, Prop_Send, "m_bIsLive", 1);
		}
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				float flPlayer[3];
				GetClientAbsOrigin(i, flPlayer);
				
				float flDistance = GetVectorDistance(flPlayer, flPos);
				if(flDistance <= 225.0 && iClient != i && GetClientTeam(i) != GetClientTeam(iClient))
				{
					float flVelocity[3];
					MakeVectorFromPoints(flPlayer, flPos, flVelocity);
					ScaleVector(flVelocity, 3.0);
					
					TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, flVelocity);
					SDKHooks_TakeDamage(i, iClient, iClient, GetRandomFloat(2.0, 5.0), DMG_GENERIC, _, flVelocity, flPos);
				}
			}
		}
		
		float flDetonateTime = GetEntPropFloat(iEnt, Prop_Data, "m_flDetonateTime");
		if(flDetonateTime <= GetGameTime())
		{
			SDKUnhook(iEnt, SDKHook_Think, OnGravitonThink);
	
			AcceptEntityInput(iEnt, "Kill");
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(buttons & IN_SCORE || IsFakeClient(client))
		return Plugin_Continue;	
	
	int iDmg;
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:		iDmg = DMG_SCOUT;
		case TFClass_Soldier:	iDmg = DMG_SOLDIER;
		case TFClass_Pyro:		iDmg = DMG_PYRO;
		case TFClass_DemoMan:	iDmg = DMG_DEMO;
		case TFClass_Heavy:		iDmg = DMG_HEAVY;
		case TFClass_Engineer:	iDmg = DMG_ENGINEER;
		case TFClass_Medic:		iDmg = DMG_MEDIC;
		case TFClass_Sniper:	iDmg = DMG_SNIPER;
		case TFClass_Spy:		iDmg = DMG_SPY;
	}
	
	float flPercentage = g_iDamageDone[client] / float(iDmg) * 100;
		
	if(flPercentage > 100.0) 
		flPercentage = 100.0;
							
	if(g_bAbilityActive[client])
	{
		if(g_flAbilityTime[client] >= (GetGameTime() + 1.0))	//Ability is active
		{
			SetHudTextParams(0.55, -1.0, 0.1, 255, 255, 0, 0, 0, 0.0, 0.0, 0.0);
			ShowHudText(client, -1, "[%.0fs]", g_flAbilityTime[client] - GetGameTime());
		
			switch(TF2_GetPlayerClass(client))
			{
				case TFClass_Sniper:
				{
					int iGrapple = GetPlayerWeaponSlot(client, view_as<int>(TFWeaponSlot_PDA));
					if(IsValidEntity(iGrapple))
					{
						int iProjectile = GetEntPropEnt(iGrapple, Prop_Send, "m_hProjectile");
						if(g_bGrappling[client] && !IsValidEntity(iProjectile))
						{
							EndAbilities(client);
						}
						
						if(GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") == iGrapple)
						{
							g_bGrappling[client] = true;
						
							buttons |= IN_ATTACK;
							return Plugin_Changed;
						}
					}
				}
				case TFClass_Engineer:
				{
					SetEntProp(client, Prop_Data, "m_iAmmo", 200, 4, 3);
				}
				case TFClass_Spy:
				{
					int iTarget = FindTargetInViewCone(client, 1250.0, 20.0);

					if(iTarget != -1 && g_iTarget[client] == iTarget)
					{
						if(g_flLockOnTime[client] <= GetGameTime())
						{
							if(!g_bLocked[client])
							{
								EmitSoundToAll("misc/halloween/duck_pickup_pos_01.wav", client);
								g_bLocked[client] = true;
							}
							
							SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
							ShowHudText(client, -1, "[LOCKED ON: %N]", iTarget);
						}
						else
						{
							SetHudTextParams(0.55, 0.55, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
							ShowHudText(client, -1, "[LOCKING ON: %N]", iTarget);
						}
					}
					else
					{
						g_iTarget[client] = iTarget;
						g_flLockOnTime[client] = GetGameTime() + 1.0;
						
						if(iTarget == -1 && g_bLocked[client])
						{
							EmitSoundToAll("misc/halloween/duck_pickup_neg_01.wav", client);
						
							g_bLocked[client] = false;
						}
					}
				}
			}
		}
		else	//Ability ended, remove ability things
		{
			if(g_bAbilityActive[client])
				EndAbilities(client);
		}
	}
	else
	{
		char strProgressBar[64];
		
		if(flPercentage == 100.0)
		{
			switch(TF2_GetPlayerClass(client))
			{
				case TFClass_Engineer:	Format(strProgressBar, sizeof(strProgressBar), "MOLTEN CORE");
				case TFClass_Medic:		Format(strProgressBar, sizeof(strProgressBar), "RESURRECT");
				case TFClass_Heavy:		Format(strProgressBar, sizeof(strProgressBar), "SHIELD");
				case TFClass_DemoMan:	Format(strProgressBar, sizeof(strProgressBar), "GRAVITON SURGE");
				case TFClass_Spy:		Format(strProgressBar, sizeof(strProgressBar), "DEADEYE");			//TODO: shoots every enemy in his line of sight. The weaker his targets are, the faster he’ll line up a killshot.
				case TFClass_Sniper:	Format(strProgressBar, sizeof(strProgressBar), "GRAPPLING HOOK");
				case TFClass_Soldier:	Format(strProgressBar, sizeof(strProgressBar), "BARRAGE");
				default:				Format(strProgressBar, sizeof(strProgressBar), "Not implemented");
			}
			
			Format(strProgressBar, sizeof(strProgressBar), "%s\n[H]", strProgressBar);
		}
		else
		{
			for(int i = 0; i < flPercentage / 4; i++)
				Format(strProgressBar, sizeof(strProgressBar), "%s|", strProgressBar);
		}
		
		SetHudTextParams(-1.0, 1.0, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudInfo, "%.0f%%\n%s", flPercentage, strProgressBar);
	}
	
	return Plugin_Continue;	
}

void EndAbilities(int client)
{
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Engineer:
		{
			SetVariantString("");
			AcceptEntityInput(client, "SetCustomModel");
			
			StopSound(client, SNDCHAN_AUTO, ENGINE_LOOP);
			
			int iPrimary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			TF2Attrib_SetByName(iPrimary, "fire rate bonus", 1.0);
			
			int iSecondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			TF2Attrib_SetByName(iSecondary, "fire rate bonus", 1.0);
			
			int iMelee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			TF2Attrib_SetByName(iMelee, "melee attack rate bonus", 1.0);
			TF2Attrib_SetByName(iMelee, "Construction rate increased", 1.0);
		}
		case TFClass_Spy:
		{
			TF2_SetFOV(client, GetEntProp(client, Prop_Send, "m_iDefaultFOV"), 1.0, 0);
			
			EmitSoundToClient(client, "replay/cameracontrolmodeexited.wav");
			Overlay(client, "\"\"");
			
			EmitSoundToAll("replay/exitperformancemode.wav", client);
		}
		case TFClass_Soldier:
		{
			int index = -1;
			while ((index = FindEntityByClassname(index, "tf_point_weapon_mimic")) != -1)
				if (GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") == client)
					AcceptEntityInput(index, "Kill");
		
			SetEntityMoveType(client, MOVETYPE_WALK);
			Overlay(client, "\"\"");
		}
		case TFClass_Sniper:
		{
			int iGrapple = GetPlayerWeaponSlot(client, view_as<int>(TFWeaponSlot_PDA));
			if(IsValidEntity(iGrapple))
			{
				int iLastWep = GetEntPropEnt(client, Prop_Data, "m_hLastWeapon");
				if(IsValidEntity(iLastWep))
				{
					char strClass[64];
					GetEntityClassname(iLastWep, strClass, sizeof(strClass));
					FakeClientCommand(client, "use %s", strClass);
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iLastWep);
				}
			
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
				TF2_RemoveWearable(client, iGrapple);
			}
			
			g_bGrappling[client] = false;
		}
	}

	g_bAbilityActive[client] = false;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && g_bAbilityActive[client])
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Spy:
			{
				if(weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
				{
					g_iDamageDone[client] = 0;
					g_flAbilityTime[client] = GetGameTime();
					
					if(g_bLocked[client] && g_iTarget[client] != -1)
					{
						SDKHooks_TakeDamage(g_iTarget[client], client, client, 700.0, DMG_BULLET|DMG_CRIT, weapon);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
    return !(entity == iExclude);
}
 
stock int FindTargetInViewCone(int iViewer, float max_distance = 0.0, float cone_angle = 180.0) // 180.0 could be for backstabs and stuff
{
	float flBestAngle = 180.0;
	int iBestTarget = -1;

	if (iViewer > 0 && iViewer <= MaxClients && IsClientInGame(iViewer) && IsPlayerAlive(iViewer))
	{
		if(max_distance < 0.0)
			max_distance = 0.0;
		if(cone_angle < 0.0)
			cone_angle = 0.0;
		
		float PlayerEyePos[3];
		float PlayerAimAngles[3];
		float PlayerToTargetVec[3];
		
		float OtherPlayerPos[3];
		GetClientEyePosition(iViewer,PlayerEyePos);
		GetClientEyeAngles(iViewer,PlayerAimAngles);
		
		float ThisAngle;
		float playerDistance;
		float PlayerAimVector[3];
		
		GetAngleVectors(PlayerAimAngles, PlayerAimVector, NULL_VECTOR, NULL_VECTOR);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer))
			{
				GetClientEyePosition(i, OtherPlayerPos);
			
				playerDistance = GetVectorDistance(PlayerEyePos, OtherPlayerPos);
				
				if(max_distance > 0.0 && playerDistance > max_distance)
				{
					continue;
				}
				
				SubtractVectors(OtherPlayerPos, PlayerEyePos, PlayerToTargetVec);
				
				ThisAngle = ArcCosine(GetVectorDotProduct(PlayerAimVector,PlayerToTargetVec) / (GetVectorLength(PlayerAimVector) * GetVectorLength(PlayerToTargetVec)));
				ThisAngle = ThisAngle * 360 / 2 / FLOAT_PI;

				if(ThisAngle <= cone_angle)
				{
					if(ThisAngle < flBestAngle)
					{
						iBestTarget = i;
						flBestAngle = ThisAngle;
					}
				}
			}
		}
		
		if(iBestTarget != -1)
		{
			GetClientEyePosition(iBestTarget, OtherPlayerPos);
			
			TR_TraceRayFilter(PlayerEyePos, OtherPlayerPos, MASK_ALL,RayType_EndPoint, AimTargetFilter, iViewer);
			if(TR_DidHit())
			{
				int entity = TR_GetEntityIndex();
				if(entity != iBestTarget)	//iBestTarget is not visible, remove target.
				{
					iBestTarget = -1;
				}
			}
		}
	}
	
	return iBestTarget;
}

public Action NormalSoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	// Robot sounds for the robot team!
	if(entity >= 1 && entity <= MaxClients && IsClientInGame(entity) && g_bAbilityActive[entity] && TF2_GetPlayerClass(entity) == TFClass_Engineer && !TF2_IsPlayerInCondition(entity, TFCond_HalloweenGhostMode))
	{
		TFTeam team = TF2_GetClientTeam(entity);
		TFTeam teamDisguised = view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_nDisguiseTeam"));
		if((team == TFTeam_Blue && teamDisguised != TFTeam_Red) || teamDisguised == TFTeam_Blue)
		{
			TFClassType class = TF2_GetPlayerClass(entity);
			if(class == TFClass_Unknown) return Plugin_Continue;

			if(teamDisguised != TFTeam_Unassigned) 
				class = view_as<TFClassType>(GetEntProp(entity, Prop_Send, "m_nDisguiseClass"));

			// Hook footstep sounds
			if(StrContains(sample, "player/footsteps/", false) != -1 && !TF2_IsPlayerInCondition(entity, TFCond_Cloaked))
			{
				if(class != TFClass_Medic) EmitSoundToAll(g_strSoundRobotFootsteps[GetRandomInt(0, sizeof(g_strSoundRobotFootsteps)-1)], entity, _, _, _, 0.13, GetRandomInt(95, 100));
				return Plugin_Stop;
			}

			// Hook falldamage sounds
			if(strcmp(sample, "player/pl_fallpain.wav") == 0)
			{
				volume = 1.0;
				strcopy(sample, sizeof(sample), g_strSoundRobotFallDamage[GetRandomInt(0, sizeof(g_strSoundRobotFallDamage)-1)]);
				return Plugin_Changed;
			}

			// Hook voice lines
			if(StrContains(sample, "vo/", false) != -1 && StrContains(sample, "vo/announcer", false) == -1)
			{
				char strClassMvM[20];
				if(GetEntProp(entity, Prop_Send, "m_bIsMiniBoss") == 1 && class != TFClass_Sniper && class != TFClass_Engineer && class != TFClass_Medic && class != TFClass_Spy)
				{
					// Lookup miniboss sounds
					ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/mght/", false);
					Format(strClassMvM, sizeof(strClassMvM), "%s_mvm_m", g_strClassName[view_as<int>(class)]);
				}
				else
				{
					ReplaceString(sample, sizeof(sample), "vo/", "vo/mvm/norm/", false);
					Format(strClassMvM, sizeof(strClassMvM), "%s_mvm", g_strClassName[view_as<int>(class)]);
				}
				
				ReplaceString(sample, sizeof(sample), ".wav", ".mp3", false); // shouldn't need this anymore
				ReplaceString(sample, sizeof(sample), g_strClassName[view_as<int>(class)], strClassMvM);
				
				char strFileSound[PLATFORM_MAX_PATH];
				Format(strFileSound, sizeof(strFileSound), "sound/%s", sample);
				if(FileExists(strFileSound, true))
				{
					PrecacheSound(sample);
					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients)
	{
		GetClientAbsOrigin(client, flDeathPos[client]);
		GetClientEyeAngles(client, flDeathAng[client]);
		
		if(g_bAbilityActive[client])
			EndAbilities(client);
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
//	int iHealth = event.GetInt("health");
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamageAmount = event.GetInt("damageamount");
	
	if(iAttacker > 0 && iAttacker <= MaxClients && iAttacker != iVictim && !g_bAbilityActive[iAttacker])
	{
		g_iDamageDone[iAttacker] += iDamageAmount;
		
	//	PrintCenterText(iAttacker, "iVictim %N\niHealth %i\niAttacker %N\niDamageAmount %i\nTotal Damage Done: %i", iVictim, iHealth, iAttacker, iDamageAmount, g_iDamageDone[iAttacker]);
	}
}

int CreateLauncher(int client, float flPos[3], float flAng[3])
{
	int ent = CreateEntityByName("tf_point_weapon_mimic");
	DispatchKeyValueVector(ent, "origin", flPos);
	DispatchKeyValueVector(ent, "angles", flAng);
	DispatchKeyValue(ent, "ModelOverride", "models/weapons/w_models/w_rocket_airstrike/w_rocket_airstrike.mdl");
	DispatchKeyValue(ent, "WeaponType", "0");
	DispatchKeyValue(ent, "SpeedMin", "600");
	DispatchKeyValue(ent, "SpeedMax", "1100");
	DispatchKeyValue(ent, "Damage", "50");
	DispatchKeyValue(ent, "SplashRadius", "100");
	DispatchKeyValue(ent, "SpreadAngle", "5");
	DispatchSpawn(ent);
	
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	CreateTimer(0.2, Timer_FireRocket, EntIndexToEntRef(ent), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client);
	
	SetVariantString("OnUser1 !self:ClearParent::2.95:1");
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser1");
	
	SetVariantString("OnUser2 !self:Kill::10.0:1");
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser2");
	
	return ent;
}

void FireRocket(int client)
{
	float flPos[3], flAng[3], vLeft[3];
	GetClientEyeAngles(client, flAng);

	GetClientEyePosition(client, flPos);
	flPos[2] -= 15.0;
	GetAngleVectors(flAng, NULL_VECTOR, vLeft, NULL_VECTOR);
	flPos[0] += (vLeft[0] * -45);
	flPos[1] += (vLeft[1] * -45);
	flPos[2] += (vLeft[2] * -45);
	CreateLauncher(client, flPos, flAng);
	
	GetClientEyePosition(client, flPos);
	GetAngleVectors(flAng, NULL_VECTOR, vLeft, NULL_VECTOR);
	flPos[0] += (vLeft[0] * 45);
	flPos[1] += (vLeft[1] * 45);
	flPos[2] += (vLeft[2] * 45);
	CreateLauncher(client, flPos, flAng);
} 

public Action Timer_FireRocket(Handle timer, int iRef)
{
	int ent = EntRefToEntIndex(iRef);
	if(ent != INVALID_ENT_REFERENCE)
	{
		int client = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		
		float flAng[3];
		GetClientEyeAngles(client, flAng);
		DispatchKeyValueVector(ent, "angles", flAng);
		
		switch(GetRandomInt(1, 3))
		{
			case 1: EmitSoundToAll("weapons/airstrike_fire_01.wav", ent);
			case 2: EmitSoundToAll("weapons/airstrike_fire_02.wav", ent);
			case 3: EmitSoundToAll("weapons/airstrike_fire_03.wav", ent);
		}
		
		AcceptEntityInput(ent, "FireOnce");
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

stock void CreateParticle(char[] particle, float pos[3])
{
	int tblidx = FindStringTable("ParticleEffectNames");
	char tmp[256];
	int count = GetStringTableNumStrings(tblidx);
	int stridx = INVALID_STRING_INDEX;
	for(int i = 0; i < count; i++)
    {
        ReadStringTable(tblidx, i, tmp, sizeof(tmp));
        if(StrEqual(tmp, particle, false))
        {
            stridx = i;
            break;
        }
    }

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", pos[0]);
	TE_WriteFloat("m_vecOrigin[1]", pos[1]);
	TE_WriteFloat("m_vecOrigin[2]", pos[2]);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", -1);
	TE_WriteNum("m_iAttachType", 2);
	TE_SendToAll();
}

stock int Particle_Create(int iEntity, const char[] strParticleEffect, float flOffsetZ = 0.0, float flTimeExpire = 0.0, bool bParent = false)
{
	int iParticle = CreateEntityByName("info_particle_system");
	
	if(iParticle > MaxClients && IsValidEntity(iParticle))
	{
		float flPos[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPos);
		flPos[2] += flOffsetZ;
		
		TeleportEntity(iParticle, flPos, NULL_VECTOR, NULL_VECTOR);
		
		DispatchKeyValue(iParticle, "effect_name", strParticleEffect);
		DispatchSpawn(iParticle);
	
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "start");
		
		if(bParent)
		{
			SetVariantString("!activator");
			AcceptEntityInput(iParticle, "SetParent", iEntity);
		}
		
		if(flTimeExpire > 0.0)
		{
			char addoutput[64];
			Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::%f:1", flTimeExpire);
			SetVariantString(addoutput);
			AcceptEntityInput(iParticle, "AddOutput");
			AcceptEntityInput(iParticle, "FireUser1");
		}
		
		return iParticle;
	}
	
	return 0;
}

stock void Overlay(int client, char[] overlay) 
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
	ClientCommand(client, "r_screenoverlay %s", overlay);
}

stock void MeleeDare(int client)
{
	SetVariantString("weaponmode:melee");
	AcceptEntityInput(client, "AddContext");
	
	SetVariantString("crosshair_enemy:Yes");
	AcceptEntityInput(client, "AddContext");
	
	SetVariantString("TLK_PLAYER_BATTLECRY");
	AcceptEntityInput(client, "SpeakResponseConcept");
	    
	AcceptEntityInput(client, "ClearContext");
}