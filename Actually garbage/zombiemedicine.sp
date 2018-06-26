#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2idb>
#include <tf2items>
#include <morecolors>

#pragma newdecls required;

#include <bonemerge_test>

#define PLUGIN_VERSION	"1.0"

//http://pastebin.com/b586ka0c

static int g_iPlayerMarker[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... }; 

bool g_bPlayerPressedReload[MAXPLAYERS+1];
bool g_bPlayerPressedMouse2[MAXPLAYERS+1];
bool g_bMedic[MAXPLAYERS + 1];
bool g_bIsArena;

float g_flHealTime[MAXPLAYERS+1];
float g_flHealTick[MAXPLAYERS+1];

int g_iUber[MAXPLAYERS+1];
int g_iPlayerTime[MAXPLAYERS+1];

Handle newItem;
Handle newWatch;

public void OnConfigsExecuted() 
{
	if(newItem != INVALID_HANDLE) 
	{
		CloseHandle(newItem);
		newItem = INVALID_HANDLE;
	}
	
	if(newWatch != INVALID_HANDLE) 
	{
		CloseHandle(newWatch);
		newWatch = INVALID_HANDLE;
	}
	
	newItem = TF2Items_CreateItem(PRESERVE_ATTRIBUTES|OVERRIDE_ATTRIBUTES);
	TF2Items_SetAttribute(newItem, 0, 517, 350.0);
	TF2Items_SetAttribute(newItem, 1, 7, 0.8);
	TF2Items_SetAttribute(newItem, 2, 479, 0.5);	
	TF2Items_SetAttribute(newItem, 3, 473, 1.0);
	TF2Items_SetAttribute(newItem, 4, 144, 2.0);
	TF2Items_SetNumAttributes(newItem, 5);
	
	newWatch = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);
	TF2Items_SetNumAttributes(newWatch, 0);
}

public Plugin myinfo =
{
	name = "[TF2] Medics Zombies",
	author = "Pelipoika",
	description = "Tommygun san~",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnPluginStart()
{
//	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("revive_player_complete", Event_ReviveComplete);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);

	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPutInServer(client);
			
			if(TF2_GetPlayerClass(client) == TFClass_Medic)
				g_bMedic[client] = true;
		}
	}
}

public void OnMapStart()
{
	char strMap[64];
	GetCurrentMap(strMap, sizeof(strMap));
	g_bIsArena = (strncmp(strMap, "arena_", 6) == 0);
	
	PrecacheSound("weapons/explode3.wav");
	PrecacheSound("weapons/cguard/charging.wav");
	PrecacheSound("buttons/button17.wav");
	PrecacheSound(")items/powerup_pickup_base.wav");
	PrecacheSound(")items/powerup_pickup_regeneration.wav");
	PrecacheSound(")items/powerup_pickup_regeneration.wav");
	PrecacheSound(")items/powerup_pickup_agility.wav");
	PrecacheSound(")items/powerup_pickup_precision.wav");
	PrecacheSound(")items/powerup_pickup_warlock.wav");
	PrecacheSound(")items/powerup_pickup_crits.wav");
	PrecacheSound("weapons/vaccinator_toggle.wav");
}

public void OnClientPutInServer(int client)
{
	g_bPlayerPressedReload[client] = false;
	g_bPlayerPressedMouse2[client] = false;
	g_bMedic[client] = false;
	g_iUber[client] = 1;
	g_iPlayerTime[client] = 0;
	g_iPlayerMarker[client] = INVALID_ENT_REFERENCE;
	g_flHealTime[client] = GetGameTime();
	g_flHealTick[client] = GetGameTime();
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(g_bIsArena)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i)) 
			{
				g_bMedic[i]	= false;
				if(TF2_GetPlayerClass(i) == TFClass_Medic)
				{
					TF2_SetPlayerClass(i, TFClass_Scout);	
					TF2_RegeneratePlayer(i);			
					OnClientPutInServer(i);
					SetEntityHealth(i, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, i));
				}
			}
		}
	
		int bMedic, rMedic;
		bMedic = GetRandomBlue();
		rMedic = GetRandomRed();
		
		if(bMedic != -1)
		{
			g_bMedic[bMedic] = true;
			
			CPrintToChatAll("{blue}%N{default} is the {blue}Medic{default}", bMedic);
			
			TF2_SetPlayerClass(bMedic, TFClass_Medic, false, false);
			TF2_RegeneratePlayer(bMedic);
			
			SetEntProp(bMedic, Prop_Send, "m_bGlowEnabled", 1);
			
		//	Attachable_RemoveAll(bMedic);
		//	Attachable_CreateAttachable(bMedic, bMedic, "models/workshop/player/items/medic/hw2013_second_opinion/hw2013_second_opinion.mdl");
		}
		if(rMedic != -1)
		{
			g_bMedic[rMedic] = true;
			
			CPrintToChatAll("{red}%N{default} is the {red}Medic{default}", rMedic);

			TF2_SetPlayerClass(rMedic, TFClass_Medic, false, false);
			TF2_RegeneratePlayer(rMedic);
			
			SetEntProp(rMedic, Prop_Send, "m_bGlowEnabled", 1);
			
		//	Attachable_RemoveAll(rMedic);
		//	Attachable_CreateAttachable(rMedic, rMedic, "models/workshop/player/items/medic/hw2013_second_opinion/hw2013_second_opinion.mdl");
		}
	}
}

public Action Event_PlayerSpawn(Handle hEvent, char[] name, bool dontBroadcast)
{
	if(g_bIsArena)
	{
		int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
		int ent = EntRefToEntIndex(g_iPlayerMarker[client]);
		if (ent && ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "Kill");
		}
		
		g_iPlayerMarker[client] = INVALID_ENT_REFERENCE;
	
	//	Attachable_RemoveAll(client);
		
		switch(TF2_GetPlayerClass(client))
		{
		/*	case TFClass_Scout:		Attachable_CreateAttachable(client, client, "models/player/items/scout/scout_zombie.mdl");
			case TFClass_Soldier:	Attachable_CreateAttachable(client, client, "models/player/items/soldier/soldier_zombie.mdl");
			case TFClass_DemoMan:	Attachable_CreateAttachable(client, client, "models/player/items/demo/demo_zombie.mdl");
			case TFClass_Medic:		Attachable_CreateAttachable(client, client, "models/player/items/medic/medic_zombie.mdl");
			case TFClass_Pyro:		Attachable_CreateAttachable(client, client, "models/player/items/pyro/pyro_zombie.mdl");
			case TFClass_Spy:		Attachable_CreateAttachable(client, client, "models/player/items/spy/spy_zombie.mdl");*/
			case TFClass_Engineer:	
			{	
			//	Attachable_CreateAttachable(client, client, "models/player/items/engineer/engineer_zombie.mdl");
				
				int secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_PDA);
				if (IsValidEntity(secondary))
				{
					TF2Attrib_SetByName(secondary, "engy dispenser radius increased", 2.0);
					SetEntProp(secondary, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
					SetEntProp(secondary, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
					SetEntProp(secondary, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
					SetEntProp(secondary, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
				}
			}
			case TFClass_Sniper:	Attachable_CreateAttachable(client, client, "models/player/items/sniper/sniper_zombie.mdl");
			case TFClass_Heavy:		
			{
			//	Attachable_CreateAttachable(client, client, "models/player/items/heavy/heavy_zombie.mdl");
				TF2Attrib_SetByName(client, "move speed bonus", 1.1);
			}
		}
		
	//	SetEntProp(client, Prop_Send, "m_bForcedSkin", 1);
	//	SetEntProp(client, Prop_Send, "m_nForcedSkin", 5);
	}
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontbroadcast) 
{
	if(g_bIsArena)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int iFlags = GetEventInt(event, "death_flags");
		
		if(iFlags & TF_DEATHFLAG_DEADRINGER) 
			return;
	
		if(TF2_GetPlayerClass(client) != TFClass_Medic)
			spawnReviveMarker(client);
			
		g_iPlayerTime[client] = 0;
		g_bMedic[client] = false;
		
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
		
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client);
		
		TF2Attrib_RemoveByName(client, "move speed bonus");
		
		int weapon = -1;
		weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if(IsValidEntity(weapon))
		{
			TF2Attrib_RemoveAll(weapon);
			TF2Attrib_ClearCache(weapon);
		}
		weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if(IsValidEntity(weapon))
		{
			TF2Attrib_RemoveAll(weapon);
			TF2Attrib_ClearCache(weapon);
		}
		weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if(IsValidEntity(weapon))
		{
			TF2Attrib_RemoveAll(weapon);
			TF2Attrib_ClearCache(weapon);
		}
		TF2Attrib_RemoveAll(client);
		TF2Attrib_ClearCache(client);
	}
}

public Action Event_ReviveComplete(Handle event, const char[] name, bool dontbroadcast)
{
	if(g_bIsArena)
	{
		int medic = GetEventInt(event, "entindex");
		
		SetEntityHealth(medic, GetClientHealth(medic) + 20);
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon)
{
	if(g_bIsArena && IsPlayerAlive(client) && TF2_GetPlayerClass(client) == TFClass_Medic && g_bMedic[client])
	{
		SetHudTextParams(0.0, 0.25, 0.1, 150, 150, 0, 150, 0, 0.0, 0.0, 0.0);
	
		switch(g_iUber[client])
		{
			case 1:	ShowHudText(client, -1, "Press R (Reload) to cycle through special ubers\nRANDOM UPGRADE | Give a random Upgrade to patient\nCost: -30%% uber");
			case 2:	ShowHudText(client, -1, "Press R (Reload) to cycle through special ubers\nTIMEBOMB | Make your patient go nuclear\nCost: -60%% uber");
			case 3:	ShowHudText(client, -1, "Press R (Reload) to cycle through special ubers\nPANIC | 5 second speed boost\nCost: -10%% uber");
			case 4:	ShowHudText(client, -1, "Press R (Reload) to cycle through special ubers\nMEDICATING MELODY | Area of Effect heal\nCost: -60%% uber");
			case 5:	ShowHudText(client, -1, "Press R (Reload) to cycle through special ubers\nZOMBIE TIER UPGRADE| Upgrades the patient to their next tier\nCost: -70%% uber");
			case 6:	ShowHudText(client, -1, "Press R (Reload) to cycle through special ubers\nSUPER UBER | Crits, Knockback resist, Uber and Speed Boost 8 Seconds\nCost: -100%% uber");
		}
		
		float flPos[3];
		GetClientAbsOrigin(client, flPos);
		
		if(g_flHealTime[client] >= GetGameTime())
		{
			if(g_flHealTick[client] <= GetGameTime())
			{
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && i != client && GetClientTeam(i) == GetClientTeam(client))
					{
						float fliPos[3];
						GetClientAbsOrigin(i, fliPos);
						
						if(GetVectorDistance(flPos, fliPos) <= 450.0)
						{
							int iHealth = GetClientHealth(i);
							int iMaxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, i);
							int amount = 75;
							
							if(iHealth + 75 > iMaxHealth)
								amount = iMaxHealth - iHealth;

							TF2_AddCondition(i, TFCond_InHealRadius, 1.25, client);
							TF2_AddCondition(i, TFCond_Healing, 1.25, client);
							
							Event event = CreateEvent("player_healed");
							if (event != INVALID_HANDLE)
							{ 
								event.SetInt("patient", GetClientUserId(i));
								event.SetInt("healer", GetClientUserId(client));
								event.SetInt("amount", amount);
								event.Fire(false);
							}
							
							SetEntityHealth(i, GetClientHealth(i) + amount);
						}
					}
				}
				
				g_flHealTick[client] = GetGameTime() + 1.0;
			}
		}		
		
		int weaponIndex = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	//	SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", 1.0); 		
		
		if(iButtons & IN_ATTACK2)
		{
			int patient = GetEntPropEnt(weaponIndex, Prop_Send, "m_hHealingTarget");
			if(!g_bPlayerPressedMouse2[client])
			{
				g_bPlayerPressedMouse2[client] = true;
			
				float flUber = GetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel"); 
			
				switch(g_iUber[client])
				{
					case 1:
					{
						if(patient > 0 && patient <= MaxClients && IsClientInGame(patient) && IsPlayerAlive(patient) && flUber >= 0.3)
						{
							int melee = GetPlayerWeaponSlot(patient, TFWeaponSlot_Melee);
							if(IsValidEntity(melee))
							{
								switch(GetRandomInt(1, 3))
								{
									case 1: 
									{
										Address pDmg = TF2Attrib_GetByName(melee, "damage bonus");
										float flDamage = 1.0;
										if(pDmg != Address_Null)
											flDamage = TF2Attrib_GetValue(pDmg);
											
										if(flDamage < 1.2)
										{
											TF2Attrib_SetByName(melee, "damage bonus", flDamage + 0.1);
											SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.3); 
											
											CPrintToChatEx(client, client, "{teamcolor}You{default} gave {teamcolor}%N{default} a {arcana}10%% Damage Boost{default}!", patient);
											CPrintToChatEx(patient, patient, "{teamcolor}%N{default} gave you a {arcana}10%% Damage Boost{default}!", client);
											
											EmitSoundToAll(")items/powerup_pickup_warlock.wav", patient);
											EmitSoundToAll(")items/powerup_pickup_warlock.wav", client);
											
											CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}RANDOM UPGRADE{default} on {teamcolor}%N{default}!", client, patient);
										}
									}
									case 2:
									{
										Address pFireRate = TF2Attrib_GetByName(melee, "fire rate bonus");
										float flFireRate = 1.0;
										if(pFireRate != Address_Null)
											flFireRate = TF2Attrib_GetValue(pFireRate);
											
										if(flFireRate > 0.8)
										{
											TF2Attrib_SetByName(melee, "fire rate bonus", flFireRate - 0.1);
											SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.3); 
											
											CPrintToChatEx(client, client, "{teamcolor}You{default} gave {teamcolor}%N{default} a {arcana}10%% FIRE RATE BONUS{default}!", patient);
											CPrintToChatEx(patient, patient, "{teamcolor}%N{default} gave you a {arcana}10%% FIRE RATE BONUS{default}!", client);
											
											EmitSoundToAll(")items/powerup_pickup_warlock.wav", patient);
											EmitSoundToAll(")items/powerup_pickup_warlock.wav", client);
											
											CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}RANDOM UPGRADE{default} on {teamcolor}%N{default}!", client, patient);
										}
									}
									case 3:
									{
										Address pMeleeResist = TF2Attrib_GetByName(patient, "max health additive bonus");
										float flHealthBonus = 0.0;
										if(pMeleeResist != Address_Null)
											flHealthBonus = TF2Attrib_GetValue(pMeleeResist);
											
										if(flHealthBonus < 40.0)
										{
											TF2Attrib_SetByName(patient, "max health additive bonus", flHealthBonus + 20.0);
											SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.3); 
											
											CPrintToChatEx(client, client, "{teamcolor}You{default} gave {teamcolor}%N{default} a {arcana}+20 MAX HEALTH{default}!", patient);
											CPrintToChatEx(patient, patient, "{teamcolor}%N{default} gave you a {arcana}+20 MAX HEALTH{default}!", client);
											
											EmitSoundToAll(")items/powerup_pickup_warlock.wav", patient);
											EmitSoundToAll(")items/powerup_pickup_warlock.wav", client);
											
											CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}RANDOM UPGRADE{default} on {teamcolor}%N{default}!", client, patient);
										}
									}
								}
							}
						}
					}
					case 2:
					{
						if(patient > 0 && patient <= MaxClients && IsClientInGame(patient) && IsPlayerAlive(patient) && flUber >= 0.6 && g_iPlayerTime[patient] == 0)
						{
							CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}TIMEBOMB{default} on {teamcolor}%N{default}!", client, patient);
												
							EmitSoundToAll(")items/powerup_pickup_precision.wav", patient);
							EmitSoundToAll(")items/powerup_pickup_precision.wav", client);
							
							SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.6); 
							
							g_iPlayerTime[patient] = 10;
							CreateTimer(1.0, Timer_Timebomb, GetClientUserId(patient), TIMER_REPEAT);		
						}
					}
					case 3:
					{
						if(flUber >= 0.1)
						{
							if(!TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly))
							{
								SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.1); 
								
								CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}PANIC{default}!", client);
								
								EmitSoundToAll(")items/powerup_pickup_agility.wav", client);
								
								TF2_AddCondition(client, TFCond_SpeedBuffAlly, 5.0);
							}
						}
					}
					case 4:
					{
						if(flUber >= 0.6)
						{
							if(g_flHealTime[client] <= GetGameTime())
							{
								SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.6); 
								
								g_flHealTime[client] = GetGameTime() + 10.0;
								g_flHealTick[client] = GetGameTime() + 1.0;
								
								EmitSoundToAll(")items/powerup_pickup_regeneration.wav", client);
								
								CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}MEDICATING MELODY{default}!", client);
							}
						}
					}
					case 5:
					{
						if(patient > 0 && patient <= MaxClients && IsClientInGame(patient) && IsPlayerAlive(patient) && flUber >= 0.7)
						{
						//	SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 0.7); 
							
							EmitSoundToAll(")items/powerup_pickup_base.wav", patient);
							EmitSoundToAll(")items/powerup_pickup_base.wav", client);
							
							CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}ZOMBIE TIER UPGRADE{default} on {teamcolor}%N{default}! {fullred}It does nothing.", client, patient);
						}
					}
					case 6:
					{
						if(patient > 0 && patient <= MaxClients && IsClientInGame(patient) && IsPlayerAlive(patient) && flUber >= 1.0)
						{
							if(!TF2_IsPlayerInCondition(client, TFCond_Ubercharged) && !TF2_IsPlayerInCondition(client, TFCond_CritOnWin)
							&& !TF2_IsPlayerInCondition(client, TFCond_MegaHeal) && !TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly))
							{
								SetEntPropFloat(weaponIndex, Prop_Send, "m_flChargeLevel", flUber - 1.0); 
	
								EmitSoundToAll(")items/powerup_pickup_crits.wav", patient);
								EmitSoundToAll(")items/powerup_pickup_crits.wav", client);
								
								TF2_AddCondition(patient, TFCond_Ubercharged, 8.0);
								TF2_AddCondition(patient, TFCond_CritOnWin, 8.0);
								TF2_AddCondition(patient, TFCond_MegaHeal, 8.0);
								TF2_AddCondition(patient, TFCond_SpeedBuffAlly, 8.0);
								
								CPrintToChatAllEx(client, "{teamcolor}%N{default} has used {arcana}SUPER UBER{default} on {teamcolor}%N{default}!", client, patient);
							}
						}
					}
				}
			}
		
			iButtons &= ~IN_ATTACK2;
		}
		else if (!(iButtons & IN_ATTACK2) && g_bPlayerPressedMouse2[client])
		{
			g_bPlayerPressedMouse2[client] = false;
		}
		
		if(iButtons & IN_RELOAD && !g_bPlayerPressedReload[client])
		{
			if(g_iUber[client] < 6)
				g_iUber[client]++;
			else
				g_iUber[client] = 1;
			
			EmitSoundToClient(client, "weapons/vaccinator_toggle.wav");
			
			g_bPlayerPressedReload[client] = true;
		}
		else if (!(iButtons & IN_RELOAD) && g_bPlayerPressedReload[client])
		{
			g_bPlayerPressedReload[client] = false;
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Timebomb(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(client >= 1 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		g_iPlayerTime[client]--;
		
		if(g_iPlayerTime[client] > 0)
		{
			int iColor;
			if(g_iPlayerTime[client] > 1)
			{
				iColor = RoundToFloor(g_iPlayerTime[client] * (128.0 / 10));
				EmitSoundToAll("buttons/button17.wav", client);
			}
			else
			{
				EmitSoundToAll("weapons/cguard/charging.wav", client);
			}
			
			SetEntityRenderMode(client, RENDER_TRANSCOLOR);
			SetEntityRenderColor(client, 255, 128, iColor, 255);

			float flPos[3];
			GetClientAbsOrigin(client, flPos);
			flPos[2] += 10.0;
			
			return Plugin_Continue;
		}
		else
		{
			float flPos[3], flPos1[3];
			GetClientAbsOrigin(client, flPos1);
			GetClientEyePosition(client, flPos);
			
			CreateParticle("fluidSmokeExpl_ring", flPos);			
			EmitSoundToAll("weapons/explode3.wav", client);
			
			CreateParticle("bomibomicon_ring", flPos1);
			
			SetEntityRenderMode(client, RENDER_TRANSCOLOR);
			SetEntityRenderColor(client);
			
			int iTeam = GetClientTeam(client);
			
			int iPlayerDamage;
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != iTeam || client == i)
				{
					if(!TF2_IsPlayerInCondition(i, TFCond_Ubercharged))
					{
						float flPos2[3];
						GetClientAbsOrigin(i, flPos2);
						
						if(GetVectorDistance(flPos1, flPos2) <= 600.0)
						{
							int iDamage = 180;
							iPlayerDamage += iDamage; 

							if(GetClientHealth(i) - iDamage <= 0)
							{
								flPos2[2] + 40.0;
								CreateParticle("ExplosionCore_Wall", flPos2);
							}

							SDKHooks_TakeDamage(i, 0, client, float(iDamage), DMG_PREVENT_PHYSICS_FORCE|DMG_CRUSH|DMG_ALWAYSGIB);
						}
					}
				}
			}
			
			PrintToChatAll("%N damage: %i", client, iPlayerDamage);
		}
	}

	return Plugin_Stop;
}

public Action Timer_RemoveWeapons(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if(TF2_GetPlayerClass(client) != TFClass_Medic)
		{
			int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			if(IsValidEntity(weapon))
				AcceptEntityInput(weapon, "Kill");
				
			weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if(IsValidEntity(weapon))
				AcceptEntityInput(weapon, "Kill");
				
			weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			if(IsValidEntity(weapon))
				SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(g_bIsArena)
	{
		if(victim > 0 && victim <= MaxClients && IsClientInGame(victim) && IsPlayerAlive(victim))
		{
			if (damagecustom == TF_CUSTOM_BACKSTAB)
			{
				TF2_StunPlayer(victim, 3.0, 0.0, TF_STUNFLAGS_BIGBONK|TF_STUNFLAG_NOSOUNDOREFFECT, attacker);
				
				damagetype &= ~DMG_CRIT;
				damage = 100.0;
				
				SetNextAttack(weapon, 5.0);
				
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)	//Medics can only carry mediguns
{
	if(g_bIsArena)
	{
		if(g_bMedic[client])
		{
			if(TF2IDB_GetItemSlot(iItemDefinitionIndex) == TF2ItemSlot_Primary)
				return Plugin_Handled;
				
			if(TF2IDB_GetItemSlot(iItemDefinitionIndex) == TF2ItemSlot_Melee && (GetTeamClientCount(3) + GetTeamClientCount(2)) > 4)
				return Plugin_Handled;
				
			if(TF2IDB_GetItemSlot(iItemDefinitionIndex) == TF2ItemSlot_Secondary)
			{
				hItem = newItem;
				return Plugin_Changed;
			}
		}
		else
		{
			if(TF2IDB_GetItemSlot(iItemDefinitionIndex) == TF2ItemSlot_Primary || TF2IDB_GetItemSlot(iItemDefinitionIndex) == TF2ItemSlot_Secondary)
				return Plugin_Handled;
		
			if(StrEqual(classname, "tf_weapon_invis"))
			{
				hItem = newWatch;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

stock int GetRandomBlue()
{
	int playerarray[MAXPLAYERS+1];
	int playercount;
	
	for(int player = 1; player <= MaxClients; player++)
	{
		if(IsClientInGame(player) && TF2_GetClientTeam(player) == TFTeam_Blue && !IsFakeClient(player))
		{
			playerarray[playercount] = player;
			playercount++;
		}
	}
	
	if(playercount)
	{
		int target = playerarray[GetRandomInt(0, playercount-1)];
		return target;
	}
	
	return -1;
}

stock int GetRandomRed()
{
	int playerarray[MAXPLAYERS+1];
	int playercount;
	
	for(int player = 1; player <= MaxClients; player++)
	{
		if(IsClientInGame(player) && TF2_GetClientTeam(player) == TFTeam_Red && !IsFakeClient(player))
		{
			playerarray[playercount] = player;
			playercount++;
		}
	}
	
	if(playercount)
	{
		int target = playerarray[GetRandomInt(0, playercount-1)];
		return target;
	}
	
	return -1;
}

stock void SetModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);		
}

stock void TF2_RemoveAllWearables(int client)
{
	int wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable*")) != -1)
	{
		if (IsValidEntity(wearable))
		{
			int player = GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity");
			if (client == player)
			{
				TF2_RemoveWearable(client, wearable);
			}
		}
	}
	
	while ((wearable = FindEntityByClassname(wearable, "vgui_screen")) != -1)
	{
		if (IsValidEntity(wearable))
		{
			int player = GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity");
			if (client == player)
			{
				AcceptEntityInput(wearable, "Kill");
			}
		}
	}

	while ((wearable = FindEntityByClassname(wearable, "tf_powerup_bottle")) != -1)
	{
		if (IsValidEntity(wearable))
		{
			int player = GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity");
			if (client == player)
			{
				TF2_RemoveWearable(client, wearable);
			}
		}
	}

	while ((wearable = FindEntityByClassname(wearable, "tf_weapon_spellbook")) != -1)
	{
		if (IsValidEntity(wearable))
		{
			int player = GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity");
			if (client == player)
			{
				TF2_RemoveWearable(client, wearable);
			}
		}
	}
}

stock void SetNextAttack(int weapon, float duration = 0.0)
{
	if (!IsValidEntity(weapon)) return;
	
	float next = GetGameTime() + duration;
	
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", next);
//	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", next);
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
    
	for(int i = 1; i <= GetMaxClients(); i++)
	{
		if(!IsValidEntity(i)) continue;
		if(!IsClientInGame(i)) continue;
		TE_Start("TFParticleEffect");
		TE_WriteFloat("m_vecOrigin[0]", pos[0]);
		TE_WriteFloat("m_vecOrigin[1]", pos[1]);
		TE_WriteFloat("m_vecOrigin[2]", pos[2]);
		TE_WriteNum("m_iParticleSystemIndex", stridx);
		TE_WriteNum("entindex", -1);
		TE_WriteNum("m_iAttachType", 5);	//Dont associate with any entity
		TE_SendToClient(i, 0.0);
	}
}

public void spawnReviveMarker(int client) 
{
	float flPos[3], flAng[3];
	GetClientAbsOrigin(client, flPos);
	GetClientAbsAngles(client, flAng);
	
	int reviveMarker = CreateEntityByName("entity_revive_marker");
	if (IsValidEntity(reviveMarker)) 
	{
		DispatchKeyValueVector(reviveMarker, "origin", flPos);
		DispatchKeyValueVector(reviveMarker, "angles", flAng);
		DispatchKeyValue(reviveMarker, "max_health", "30");
		
		SetEntPropEnt(reviveMarker, Prop_Send, "m_hOwner", client);
		SetEntProp(reviveMarker, Prop_Data, "m_nSolidType", 0);
		SetEntProp(reviveMarker, Prop_Data, "m_usSolidFlags", 0);
		SetEntProp(reviveMarker, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(reviveMarker, Prop_Send, "m_iTeamNum", GetClientTeam(client));
		SetEntProp(reviveMarker, Prop_Send, "m_bSimulatedEveryTick", 1);
		SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin") + 4, reviveMarker);
		SetEntProp(reviveMarker, Prop_Send, "m_nBody", (view_as<int>TF2_GetPlayerClass(client)) - 1);
		SetEntProp(reviveMarker, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));
		if(TF2_GetClientTeam(client) == TFTeam_Blue)
			SetEntityRenderColor(reviveMarker, 0, 0, 255); // make the BLU Revive Marker distinguishable from the red one
			
		DispatchSpawn(reviveMarker);
		
		g_iPlayerMarker[client] = EntIndexToEntRef(reviveMarker);
		
		char sBuffer[PLATFORM_MAX_PATH];
		GetEntPropString(reviveMarker, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));

		int ent = CreateEntityByName("obj_dispenser");
		if (ent != -1)
		{
			DispatchKeyValue(ent, "targetname", "zombiemedESP");
			DispatchSpawn(ent);
			
			SetEntityModel(ent, sBuffer);

			SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
			SetEntityRenderColor(ent, 0, 0, 0, 0);
			
			SetEntProp(ent, Prop_Send, "m_bGlowEnabled", 1);
			SetEntProp(ent, Prop_Send, "m_bDisabled", 1);
			SetEntProp(ent, Prop_Data, "m_takedamage", 0);
			SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
			SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
			SetEntProp(ent, Prop_Send, "m_nBody", (view_as<int>TF2_GetPlayerClass(client)) - 1);
			SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	
			int iFlags = GetEntProp(ent, Prop_Send, "m_fEffects");
			SetEntProp(ent, Prop_Send, "m_fEffects", iFlags | (1 << 0));
	
			SetVariantString("!activator");
			AcceptEntityInput(ent, "SetParent", reviveMarker);
			
			SDKHook(ent, SDKHook_SetTransmit, Hook_ReviveTransmit);
		}
	}
}

public Action Hook_ReviveTransmit(int ent, int other)
{
	if(other > 0 && other <= MaxClients && IsClientInGame(other))
	{
		if(g_bMedic[other] && GetEntProp(ent, Prop_Send, "m_iTeamNum") == GetClientTeam(other))
		{
			return Plugin_Continue;
		}
	}

	return Plugin_Handled;
}