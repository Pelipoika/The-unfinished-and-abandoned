#pragma semicolon 1

#include <tf2>
#include <tf2_stocks>
#include <sourcemod>
#include <sdkhooks>
#include <tf2items>
//#include <tf2wearables>
#include <clientprefs>
#include <tf2attributes>
#include <morecolors>

#pragma newdecls required

#define SOUND_FLAP	"misc/vs/flap.mp3"
#define SOUND_JUMP	"misc/vs/jump.mp3"
#define SOUND_VMISS	"misc/vs/vmiss.mp3"

bool Vampire[MAXPLAYERS+1];
bool Slayer[MAXPLAYERS+1];
bool Jumped[MAXPLAYERS+1];
bool g_bStunned[MAXPLAYERS+1];
bool g_bClientPreference[MAXPLAYERS+1];  

//Handle g_hGameConf;
Handle g_hForceStalemate;
Handle g_hClientCookie = null;

//Special DSP

public Plugin myinfo =
{
	name = "[TF2] Vampire Slayer",
	author = "Pelipoika",
	description = "Suck it saigns.de",
	version = "1.0",
	url = "http://forums.alliedmods.net"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("teamplay_round_start", Event_RoundStart);
	
	g_hClientCookie = RegClientCookie("VSMenu", "VampireSlayerMenu", CookieAccess_Private);
	
	AddCommandListener(Listener_Build, "build");
	AddCommandListener(Listener_Say, "say");
	AddCommandListener(Listener_Say, "say_team");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			SDKHook(client, SDKHook_OnTakeDamageAlive, TakeDamage);
		}
	}
	
	Handle hConfig = LoadGameConfigFile("getweaponid"); 
	if (hConfig == INVALID_HANDLE) SetFailState("Couldn't find plugin gamedata!"); 
	
	hConfig = LoadGameConfigFile("getweaponid");
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "ForceStalemate");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hForceStalemate = EndPrepSDKCall();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, TakeDamage);
}

public void OnClientCookiesCached(int client)
{
    char sValue[8];
    GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
    
    g_bClientPreference[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public void OnMapStart()
{
	PrecacheSound(SOUND_FLAP);
	PrecacheSound(SOUND_JUMP);
	PrecacheSound(SOUND_VMISS);

	HookEntityOutput("func_door", "OnClose", DoorClosing);

//	AddFileToDownloadsTable("materials/correction/night.raw");
//	AddFileToDownloadsTable("sound/misc/vs/flap.mp3");
//	AddFileToDownloadsTable("sound/misc/vs/jump.mp3");
//	AddFileToDownloadsTable("sound/misc/vs/vmiss.mp3");
	
/*	SetLightStyle(0, "i");
	DispatchKeyValue(0, "skyname", "sky_nightfall_01");

	int ent = FindEntityByClassname(-1, "env_fog_controller");
	if (ent != -1) 
	{
		DispatchKeyValue(ent, "fogenable", "1");
		DispatchKeyValue(ent, "fogblend", "0");
		DispatchKeyValue(ent, "fogcolor", "16 18 20");
		DispatchKeyValueFloat(ent, "fogstart", -2682.0);
		DispatchKeyValueFloat(ent, "fogend", 3000.0);
	}
	
	AcceptEntityInput(ent, "TurnOn");
	
	int sc = -1, proxy = -1, scape = -1;
	float org[3];
	char target[32];

	// Find all soundscape proxies and determine if they're inside or outside
	while ((sc = FindEntityByClassname(sc, "env_soundscape_proxy")) != -1) 
	{
		proxy = GetEntDataEnt2(sc, FindDataMapOffs(sc, "m_hProxySoundscape"));
		
		if (proxy != -1) 
		{
			GetEntPropString(proxy, Prop_Data, "m_iName", target, sizeof(target));
			
			if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1) ||
				(StrContains(target, "outside", false) != -1) || (StrContains(target, "outdoor", false) != -1)) 
				{
				// Create new soundscape using loaded attributes
				scape = CreateEntityByName("env_soundscape");

				if (IsValidEntity(scape)) 
				{
					GetEntPropVector(sc, Prop_Data, "m_vecOrigin", org);
					TeleportEntity(scape, org, NULL_VECTOR, NULL_VECTOR);
					
					DispatchKeyValueFloat(scape, "radius", GetEntDataFloat(sc, FindDataMapOffs(sc, "m_flRadius")));
					
					if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1)) 
					{
						DispatchKeyValue(scape, "soundscape", "Halloween.Inside");
						DispatchKeyValue(scape, "targetname", "Halloween.Inside");
					} 
					else if ((StrContains(target, "outside", false) != -1) || (StrContains(target, "outdoor", false) != -1)) 
					{
						DispatchKeyValue(scape, "soundscape", "Halloween.Outside");
						DispatchKeyValue(scape, "targetname", "Halloween.Outside");
					}
					
					DispatchSpawn(scape);
				}
			}
		}
		
		AcceptEntityInput(sc, "Kill");
	}

	// Do the same to normal soundscapes
	while ((sc = FindEntityByClassname(sc, "env_soundscape")) != -1) 
	{
		GetEntPropString(sc, Prop_Data, "m_iName", target, sizeof(target));
		
		if (!StrEqual(target, "Halloween.Inside") && !StrEqual(target, "Halloween.Outside")) 
		{
			scape = CreateEntityByName("env_soundscape");
		
			if (IsValidEntity(scape)) 
			{
				GetEntPropVector(sc, Prop_Data, "m_vecOrigin", org);
				TeleportEntity(scape, org, NULL_VECTOR, NULL_VECTOR);
				
				DispatchKeyValueFloat(scape, "radius", GetEntDataFloat(sc, FindDataMapOffs(sc, "m_flRadius")));
				
				if ((StrContains(target, "inside", false) != -1) || (StrContains(target, "indoor", false) != -1)) 
				{
					DispatchKeyValue(scape, "soundscape", "Halloween.Inside");
					DispatchKeyValue(scape, "targetname", "Halloween.Inside");
				} 
				else 
				{	
					DispatchKeyValue(scape, "soundscape", "Halloween.Outside");
					DispatchKeyValue(scape, "targetname", "Halloween.Outside");
				}
				
				DispatchSpawn(scape);
			}
			AcceptEntityInput(sc, "Kill");
		}
	}*/
	
	ServerCommand("sm_cvar tf_forced_holiday 2");
	ServerCommand("sm_cvar tf_playergib 2");
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_bClientPreference[client])
	{
		Panel g_hMainMenu = CreatePanel();
		g_hMainMenu.SetTitle("Vampire Slayer - How to play \n \n");
		g_hMainMenu.DrawItem("Close");
		g_hMainMenu.DrawItem("Close & Never show this again \n \n");
		g_hMainMenu.DrawText("Slayer (BLU)");
		g_hMainMenu.DrawText("Stun a Vampire with a gun");
		g_hMainMenu.DrawText("and use a melee weapon to kill it");
		g_hMainMenu.DrawText("- Stunned vampires will resurrect after a few seconds \n \n");
		g_hMainMenu.DrawText("Vampire (RED)");
		g_hMainMenu.DrawText("Use your melee weapon to kill a slayer");
		g_hMainMenu.DrawText("- Press 'duck' 'forward' and 'jump' together to make a long jump");
		g_hMainMenu.Send(client, MenuMainHandler, MENU_TIME_FOREVER);
		delete g_hMainMenu;
	}
	
	if(GetClientTeam(client) == view_as<int>TFTeam_Red)
	{
		TF2Attrib_SetByName(client, "afterburn immunity", 1.0);
		TF2Attrib_SetByName(client, "health regen", 6.0);
		TF2Attrib_SetByName(client, "cancel falling damage", 1.0);
		
		int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if(IsValidEntity(melee))
		{
			TF2Attrib_SetByName(melee, "melee attack rate bonus", 0.8);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee);  
		}
		
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);
		
		Vampire[client] = true;
		Slayer[client] = false;
		
	/*	TFClassType class = TF2_GetPlayerClass(client);	//Zombie souls
		switch(class)
		{
			case TFClass_Scout:		TF2_PlayerGiveWearable(client, 5617, 6, 69, -1);
			case TFClass_Soldier:	TF2_PlayerGiveWearable(client, 5618, 6, 69, -1);
			case TFClass_DemoMan:	TF2_PlayerGiveWearable(client, 5620, 6, 69, -1);
			case TFClass_Medic:		TF2_PlayerGiveWearable(client, 5622, 6, 69, -1);
			case TFClass_Pyro:		TF2_PlayerGiveWearable(client, 5624, 6, 69, -1);
			case TFClass_Spy:		TF2_PlayerGiveWearable(client, 5623, 6, 69, -1);
			case TFClass_Engineer:	TF2_PlayerGiveWearable(client, 5621, 6, 69, -1);
			case TFClass_Sniper:	TF2_PlayerGiveWearable(client, 5625, 6, 69, -1);
			case TFClass_Heavy:		TF2_PlayerGiveWearable(client, 5619, 6, 69, -1);
		}*/
	}
	else if(GetClientTeam(client) == view_as<int>TFTeam_Blue)	//Slayers
	{
		TF2Attrib_SetByName(client, "afterburn immunity", 0.0);
		TF2Attrib_SetByName(client, "health regen", 0.0);
		TF2Attrib_SetByName(client, "cancel falling damage", 0.0);
		
		int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if(IsValidEntity(melee))
		{
			TF2Attrib_SetByName(melee, "melee attack rate bonus", 1.0);
		}

		Slayer[client] = true;
		Vampire[client] = false;
	}

	g_bStunned[client] = false;
}

public int MenuMainHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		switch (param2)
		{
		case 1: {SetClientCookie(param1, g_hClientCookie, "1"); g_bClientPreference[param1] = false;}			
			case 2: SetClientCookie(param1, g_hClientCookie, "0");
		}
		
		OnClientCookiesCached(param1);
		
		if(menu != null)
		{
			delete menu;
		}
		
		PrintToChat(param1, "Type 'vs' in chat to open this menu again");
	}
}

public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client && IsClientInGame(client)) 
	{
		SetEntProp(client, Prop_Send, "m_skybox3d.fog.enable", 1);
		SetEntProp(client, Prop_Send, "m_skybox3d.fog.colorPrimary", 16 | 18 << 8 | 20 << 16);
		SetEntProp(client, Prop_Send, "m_skybox3d.fog.colorSecondary", 255 | 255 << 8 | 255 << 16);
		SetEntProp(client, Prop_Send, "m_skybox3d.fog.blend", 0);
		SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.start", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.end", 4500.0);
		SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.maxdensity", 1.0);
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon) 
{
	if (IsPlayerAlive(iClient) && Vampire[iClient] && !TF2_IsPlayerInCondition(iClient, TFCond_Dazed))
	{
		if(iButtons & IN_JUMP && iButtons & IN_FORWARD && iButtons & IN_DUCK && GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != -1)
		{
			float ClientEyeAngle[3];
			float Velocity[3];
			float Pos[3];
			
			GetClientEyeAngles(iClient, ClientEyeAngle);
			GetClientAbsOrigin(iClient, Pos);

			float EyeAngleZero = ClientEyeAngle[0];
			ClientEyeAngle[0] = -30.0;
			GetAngleVectors(ClientEyeAngle, Velocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(Velocity, 600.0);
			ClientEyeAngle[0] = EyeAngleZero;
			
			EmitAmbientSound(SOUND_FLAP, Pos);
			TeleportEntity(iClient, NULL_VECTOR, ClientEyeAngle, Velocity); //Toss 'em
			
			Jumped[iClient] = true;
		}
		else if(iButtons & IN_JUMP && GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != -1 && !Jumped[iClient])
		{
			float fVelocity[3];
			float Pos[3];
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
			GetClientAbsOrigin(iClient, Pos);

			fVelocity[2] = 600.0;
			EmitAmbientSound(SOUND_JUMP, Pos);
			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fVelocity);
			
			Jumped[iClient] = true;
		}
		
		if(!(iButtons & IN_JUMP) && GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != -1)
		{
			Jumped[iClient] = false;
		}
	}
	return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if(IsValidClient(client) && Vampire[client])
	{
		EmitSoundToAll(SOUND_VMISS, client);
	}
	
	return Plugin_Continue;
}

public void TF2_OnConditionRemoved(int client, TFCond cond) 
{
	if(Vampire[client] && g_bStunned[client] && cond == TFCond_Dazed)
	{
		if(IsPlayerAlive(client))
			CPrintToChatAll("Player {red}%N{default} resurrected", client);
	//	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		g_bStunned[client] = false;
	}
}

public Action TakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(IsValidClient(victim) && IsValidClient(attacker) && Vampire[victim])
	{
		if(damage >= GetClientHealth(victim))
		{
			if(damagetype & DMG_CLUB && g_bStunned[victim])
			{
				damage = 420.0;
				return Plugin_Changed;
			}
			else
			{
				damage = 0.0;
				TF2_StunPlayer(victim, 4.0, _, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT);
				g_bStunned[victim] = true;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue; 
}

public Action Listener_Build(int client, char[] cmd, int args)
{
	if (args < 1) return Plugin_Continue;
	if (TF2_GetPlayerClass(client) != TFClass_Engineer) return Plugin_Continue;

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	int building = StringToInt(arg1);
	if (building == view_as<int>TFObject_Dispenser) 
	{
		CPrintToChat(client, "{green}Dispensers are not available in Vampire Slayer");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Listener_Say(int client, const char[] command, int argc)
{
	if(!client || client > MaxClients || !IsClientInGame(client)) return Plugin_Continue;
	
	char strChat[100];
	GetCmdArgString(strChat, sizeof(strChat));
	
	int iStart;
	if(strChat[iStart] == '"') iStart++;
	if(strChat[iStart] == '!') iStart++;
	
	int iLength = strlen(strChat[iStart]);
	if(strChat[iLength + iStart - 1] == '"')
	{
		strChat[iLength-- + iStart - 1] = '\0';
	}	
	
	if(StrContains(strChat[iStart], "vs", false) != -1 && iLength <= 2)
	{
		SetClientCookie(client, g_hClientCookie, "1");
		OnClientCookiesCached(client);
		
		Panel g_hMainMenu = CreatePanel();
		g_hMainMenu.SetTitle("Vampire Slayer - How to play \n \n");
		g_hMainMenu.DrawItem("Close");
		g_hMainMenu.DrawItem("Close & Never show this again \n \n");
		g_hMainMenu.DrawText("Slayer (BLU)");
		g_hMainMenu.DrawText("Stun a Vampire with a gun");
		g_hMainMenu.DrawText("and use a melee weapon to kill it");
		g_hMainMenu.DrawText("- Stunned vampires will resurrect after a few seconds \n \n");
		g_hMainMenu.DrawText("Vampire (RED)");
		g_hMainMenu.DrawText("Use your melee weapon to kill a slayer");
		g_hMainMenu.DrawText("- Press 'duck' 'forward' and 'jump' together to make a long jump");
		g_hMainMenu.Send(client, MenuMainHandler, MENU_TIME_FOREVER);
		delete g_hMainMenu;
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void DoorClosing(const char[] output, int caller, int activator, float delay)
{
	AcceptEntityInput(caller, "Open");
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
//	SDKCall(g_hForceStalemate, 1, false, false);

	int ent = -1;	//Disable health kits
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
	{
		if (IsValidEntity(ent))
		{
			AcceptEntityInput(ent, "Disable");
		}
	}
	
	int ammo = -1;	//Disble ammo kits
	while ((ammo = FindEntityByClassname(ammo, "item_ammopack_*")) != -1)
	{
		if (IsValidEntity(ammo))
		{
			AcceptEntityInput(ammo, "Disable");
		}
	}
	
	int regen = -1;	//Disable resupply lockers
	while ((regen = FindEntityByClassname(regen, "func_regenerate")) != -1)
	{
		if (IsValidEntity(regen))
		{
			AcceptEntityInput(regen, "Disable");
		}
	}

	int sun = -1;
	while ((sun = FindEntityByClassname(sun, "env_sun")) != -1) 
	{
		AcceptEntityInput(sun, "Kill");
	}
	
	int prop = -1;
	while ((prop = FindEntityByClassname(prop, "prop_dynamic")) != -1) 
	{
		char model[128];
		
		GetEntPropString(prop, Prop_Data, "m_ModelName", model, sizeof(model));
		
		if (StrEqual(model, "models/props_skybox/sunnoon.mdl")) 
		{
			AcceptEntityInput(prop, "Kill");
		}
	}
	
	int color = -1;
	while ((color = FindEntityByClassname(color, "color_correction")) != -1) 
	{
		AcceptEntityInput(color, "Kill");
	}
	
	int mapCCEntity1 = CreateEntityByName("color_correction");
	
	if (IsValidEntity(mapCCEntity1)) 
	{
		DispatchKeyValue(mapCCEntity1, "maxweight", "1.0");
		DispatchKeyValue(mapCCEntity1, "maxfalloff", "-1");
		DispatchKeyValue(mapCCEntity1, "minfalloff", "-1");
		DispatchKeyValue(mapCCEntity1, "filename", "scripts/night.raw");
		
		DispatchSpawn(mapCCEntity1);
		ActivateEntity(mapCCEntity1);
		AcceptEntityInput(mapCCEntity1, "Enable");
	}
	
	int spawnblock = -1;
	while((spawnblock = FindEntityByClassname(spawnblock, "func_respawnroomvisualizer")) != -1)
	{
		AcceptEntityInput(spawnblock, "Kill");
	}
	
/*	int String:targets[6][25] = {"team_control_point_master","team_control_point","trigger_capture_area","item_teamflag","func_capturezone","func_respawnroomvisualizer"};

	ent = -1;
	for (int i = 0; i < 5; i++)
	{
		ent = MaxClients+1;
		while((ent = FindEntityByClassname(ent, targets[i])) != -1)
		{
			AcceptEntityInput(ent, "Disable");
			AcceptEntityInput(ent, "Kill");
		}
	}*/
	
	int iDoor = -1;
	while ((iDoor = FindEntityByClassname(iDoor, "func_door")) != -1)
	{
		AcceptEntityInput(iDoor, "Open");
	}
}

stock int TF2_PlayerGiveWearable(int iClient, int iItemIndex, int iQuality = 9, int iLevel = 0, int iPaintColor = -1) 
{
	char szBuffer[64];
	Handle hItem = TF2Items_CreateItem(OVERRIDE_ALL || FORCE_GENERATION);
	TF2Items_SetClassname(hItem, "tf_wearable");
	TF2Items_SetItemIndex(hItem, 0);
	TF2Items_SetQuality(hItem, iQuality);
	TF2Items_SetLevel(hItem, iLevel);
	TF2Items_SetNumAttributes(hItem, 0);
	
	if (iPaintColor != -1) 
	{
		IntToString(iPaintColor, szBuffer, sizeof(szBuffer));
		float flPaintColor = StringToFloat(szBuffer);
		TF2Items_SetNumAttributes(hItem, TF2Items_GetNumAttributes(hItem) + 2);
		TF2Items_SetAttribute(hItem, TF2Items_GetNumAttributes(hItem) - 2, 261, flPaintColor);
		TF2Items_SetAttribute(hItem, TF2Items_GetNumAttributes(hItem) - 1, 142, flPaintColor);
	}

	int iEntity = TF2Items_GiveNamedItem(iClient, hItem);
	SetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex", iItemIndex);
	TF2_EquipPlayerWearable(iClient, iEntity);
	delete hItem;
	
	return iEntity;
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	return IsClientInGame(client);
}