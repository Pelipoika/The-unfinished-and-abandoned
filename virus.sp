#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <morecolors>

#pragma newdecls required;

#define PLUGIN_VERSION	"1.0"
#define MODEL_VIRUS	"models/bots/skeleton_sniper/skeleton_sniper.mdl"

Handle g_hCvarRoundDuration;
Handle g_hRoundTimer = INVALID_HANDLE;
int g_iRoundTime;

bool g_bVirus[MAXPLAYERS + 1];
bool g_bPlaying;

public Plugin myinfo =
{
	name = "[TF2] Virus",
	author = "Pelipoika",
	description = "Stay together, don't let it spread",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnPluginStart()
{
	g_bPlaying = false;

	AddTempEntHook("TFBlood", TempHook);

	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	RegAdminCmd("sm_infected", Command_Infected, ADMFLAG_ROOT);
		
	g_hCvarRoundDuration = CreateConVar("tf2_virus_roundtime", "120", "How long do VIRUS rounds last? (Seconds)", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, false);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			UnInfect(client);
			g_bVirus[client] = false;
			SDKHook(client, SDKHook_StartTouch, StartTouch);
			SDKHook(client, SDKHook_Touch, StartTouch);
		}
	}
	
	AddNormalSoundHook(SkeletonSH);
}

public void OnMapStart()
{
	PrecacheModel(MODEL_VIRUS);
	PrecacheSound("misc/halloween/spell_skeleton_horde_rise.wav");
	PrecacheSound("misc/halloween/skeleton_break.wav");
	
	for (int i = 1; i <= 22; i++)
	{
		char iString[PLATFORM_MAX_PATH];
		
		if (i < 10) 
			Format(iString, sizeof(iString), "misc/halloween/skeletons/skelly_small_0%i.wav", i);
		else 
			Format(iString, sizeof(iString), "misc/halloween/skeletons/skelly_small_%i.wav", i);
			
		PrecacheSound(iString);
	}
	
	g_bPlaying = false;
	
	HookEntityOutput("func_door", "OnClose", DoorClosing);
}

public void OnClientPutInServer(int client)
{
	g_bVirus[client] = false;
	SDKHook(client, SDKHook_StartTouch, StartTouch);
	SDKHook(client, SDKHook_Touch, StartTouch);
}

public Action Command_Infected(int client, int args)
{
	if(g_bPlaying)
	{
		DisableGame();
		CPrintToChatAll("{lime}[VIRUS]{default} Disabling game..");
	}
	else
	{
		CPrintToChatAll("{lime}[VIRUS]{default} Playing for 1 game.");
		EnableGame();
	}
	
	return Plugin_Handled;
}

public Action StartTouch(int client, int other)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && g_bPlaying)
	{
		if(other > 0 && other <= MaxClients && IsClientInGame(other))
		{
			if(!g_bVirus[other] && g_bVirus[client])
			{
				PrintCenterTextAll("%N infected %N", client, other);
				
				SendDeathMessage(client, other);
				
				Infect(other);
			}
		}
		else if(IsValidEntity(other) && g_bVirus[client])
		{
			char classname[64];
			GetEntityClassname(other, classname, sizeof(classname));
			if(StrContains(classname, "obj_") != -1)
			{
				SDKHooks_TakeDamage(other, client, client, 500.0);
			}
		}
	}
}

public Action TempHook(const char[] te_name, const Players[], int numClients, float delay)
{
	int client = TE_ReadNum("entindex");
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && g_bPlaying && g_bVirus[client])
	{
		float m_vecOrigin[3];
		m_vecOrigin[0] = TE_ReadFloat("m_vecOrigin[0]");
		m_vecOrigin[1] = TE_ReadFloat("m_vecOrigin[1]");
		m_vecOrigin[2] = TE_ReadFloat("m_vecOrigin[2]");
		
		switch(GetRandomInt(1, 3))
		{
			case 1: CreateParticle("spell_skeleton_goop_green", m_vecOrigin);
			case 2:	CreateParticle("spell_pumpkin_mirv_goop_red", m_vecOrigin);
			case 3:	CreateParticle("spell_pumpkin_mirv_goop_blue", m_vecOrigin);
		}
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_bPlaying = false;
}

public Action Event_PlayerSpawn(Handle hEvent, char[] name, bool dontBroadcast)
{
	if(!g_bPlaying) return Plugin_Continue;
	
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(g_bVirus[client]) 
		Infect(client);
	else 
		UnInfect(client);
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle hEvent, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int killer = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int deathflags = GetEventInt(hEvent, "death_flags");
	
	if(g_bPlaying && !g_bVirus[client] && killer != client && deathflags != TF_DEATHFLAG_DEADRINGER) 
	{
		EmitSoundToAll("misc/halloween/skeleton_break.wav", client);
		
		g_bVirus[client] = true;
		
		if(GetNumNotInfected() <= 0)
		{
			RequestFrame(DelayDisable);
			CPrintToChatAll("The {lime}VIRUS{default} spred succesfully.. The epidemic wins!");
		}
	}
	
	return Plugin_Continue;
}

public void DelayDisable(any data)
{
	DisableGame();
}

public Action Timer_InfectRandom(Handle timer, any data)
{
	if(g_bPlaying)
	{
		int client = GetRandomPlayer();
		
		CPrintToChatAll("%N is the {lime}VIRUS{default}! You need to {red}SURVIVE for 2 minutes!{default}", client);
		
		g_hRoundTimer = CreateTimer(1.0, Timer_RoundClock, _, TIMER_REPEAT);
		
		Infect(client);
		
		TF2_RespawnPlayer(client);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 30.0);
		
		EmitSoundToAll("misc/halloween/spell_skeleton_horde_rise.wav");
	}
}

public Action Timer_RoundClock(Handle timer, any data)
{
	g_iRoundTime--;
	
	SetHudTextParams(-1.0, 0.0, 1.025, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
	
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			ShowHudText(i, -1, "%i seconds", g_iRoundTime);
	
	if(g_iRoundTime <= 0)
	{
		if(GetNumNotInfected() != 0)
		{
			DisableGame();
			CPrintToChatAll("The {blue}Humans{default} win!");
		}
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(g_bPlaying)
	{
		if (condition == TFCond_Disguised && TF2_GetPlayerClass(client) == TFClass_Spy)
			TF2_RemovePlayerDisguise(client);
		if (condition == TFCond_Cloaked && TF2_GetPlayerClass(client) == TFClass_Spy)
			TF2_RemoveCondition(client, TFCond_Cloaked);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname,"tf_ammo_pack") && g_bPlaying)
    {
        SDKHook(entity, SDKHook_SpawnPost, OnAmmoSpawn);
    }
}

public void OnAmmoSpawn(int entity)
{
    if(IsValidEntity(entity))
        AcceptEntityInput(entity, "Kill");
}  

public void DoorClosing(const char[] output, int caller, int activator, float delay)
{
	if(g_bPlaying)
		AcceptEntityInput(caller, "Open");
}

public Action SkeletonSH(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if (entity > 0 && entity <= MaxClients && IsClientInGame(entity))
	{
		if (!g_bVirus[entity]) return Plugin_Continue;

		if (StrContains(sample, "vo/", false) != -1)
		{
			int num = GetRandomInt(1, 22);
			if (num < 10) 
				Format(sample, sizeof(sample), "misc/halloween/skeletons/skelly_small_0%i.wav", num);
			else 
				Format(sample, sizeof(sample), "misc/halloween/skeletons/skelly_small_%i.wav", num);
				
			EmitSoundToAll(sample, entity, channel, level, flags, volume);
			
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

stock void EnableGame()
{
	if(g_hRoundTimer != INVALID_HANDLE)
	{
		KillTimer(g_hRoundTimer);
		g_hRoundTimer = INVALID_HANDLE;
	}

	g_iRoundTime = GetConVarInt(g_hCvarRoundDuration);
	g_bPlaying = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			UnInfect(i);
			g_bVirus[i] = false;
			SDKHook(i, SDKHook_StartTouch, StartTouch);
			SDKHook(i, SDKHook_Touch, StartTouch);
			
			TF2_ChangeClientTeam(i, TFTeam_Blue);
			TF2_RespawnPlayer(i);
		}
	}
	
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1)
		AcceptEntityInput(ent, "Disable");
	ent = -1;
	while((ent = FindEntityByClassname(ent, "trigger_teleport")) != -1)
		AcceptEntityInput(ent, "Disable");
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_regenerate")) != -1)
		if (IsValidEntity(ent))
			AcceptEntityInput(ent, "Disable");
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
		AcceptEntityInput(ent, "Open");
		
	SetConVarString(FindConVar("mp_humans_must_join_team"), "spectator");	

	CreateTimer(30.0, Timer_InfectRandom, _, TIMER_FLAG_NO_MAPCHANGE);
	CPrintToChatAll("Selecting the {lime}VIRUS{default} in 30 seconds");
}

stock void DisableGame()
{
	g_bPlaying = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			UnInfect(i);
			TF2_RespawnPlayer(i);
		}
	}

	int ent = -1;
	while((ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1)
		AcceptEntityInput(ent, "Enable");

	ent = -1;
	while((ent = FindEntityByClassname(ent, "trigger_teleport")) != -1)
		AcceptEntityInput(ent, "Enable");
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_regenerate")) != -1)
		if (IsValidEntity(ent))
			AcceptEntityInput(ent, "Enable");
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
		AcceptEntityInput(ent, "Close");
		
	SetConVarString(FindConVar("mp_humans_must_join_team"), "any");
		
	if(g_hRoundTimer != INVALID_HANDLE)
	{
		KillTimer(g_hRoundTimer);
		g_hRoundTimer = INVALID_HANDLE;
	}
}

stock void Infect(int client)
{
	CPrintToChat(client, "As a {lime}VIRUS{default} you're supposed to touch the uninfected to infect them!");

	TF2_SetPlayerClass(client, TFClass_Scout, _, false);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
	
	SetModel(client, MODEL_VIRUS);
	
	float flSize = GetRandomFloat(0.75, 1.5);
	char strSize[4];
	FloatToString(flSize, strSize, sizeof(strSize));
	
	SetEntProp(client, Prop_Send, "m_bForcedSkin", 1);
	SetEntProp(client, Prop_Send, "m_nForcedSkin", GetRandomInt(0, 3));
	
	SetVariantString(strSize);
	AcceptEntityInput(client, "SetModelScale");
	
	g_bVirus[client] = true;
	
	ChangeClientTeamAlive(client, TFTeam_Red);

	TF2_RemoveAllWeapons(client);
	TF2_RemoveAllWearables(client);
	
	Handle hWeaponFists = TF2Items_CreateItem(OVERRIDE_ALL);
	TF2Items_SetClassname(hWeaponFists, "tf_weapon_bat_fish");
	TF2Items_SetItemIndex(hWeaponFists, 572);
	TF2Items_SetQuality(hWeaponFists, 13);
	TF2Items_SetAttribute(hWeaponFists, 0, 1, 0.0);
	TF2Items_SetAttribute(hWeaponFists, 1, 5, 2.0);
	TF2Items_SetAttribute(hWeaponFists, 2, 326, 1.5);
	TF2Items_SetNumAttributes(hWeaponFists, 3);
	int iEntity = TF2Items_GiveNamedItem(client, hWeaponFists);
	
	EquipPlayerWeapon(client, iEntity);
	CloseHandle(hWeaponFists);
	
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, 255, 255, 255, 0);
	SetEntProp(iEntity, Prop_Send, "m_fEffects", 16);
	
	SetEntityHealth(client, 130);
	
	if(GetNumNotInfected() <= 3)
	{
		for(int player = 1; player <= MaxClients; player++)
		{
			if(IsClientConnected(client) && IsClientAuthorized(client) && IsClientInGame(player) && !g_bVirus[player])
			{
				SetEntProp(player, Prop_Send, "m_bGlowEnabled", 1);
			}
		}
	}
}

stock void UnInfect(int client)
{
	SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);

	g_bVirus[client] = false;
	
	SetEntProp(client, Prop_Send, "m_bForcedSkin", 0);
	
	SetModel(client, "");
	
	SetVariantString("1.0");
	AcceptEntityInput(client, "SetModelScale");
}

stock int GetRandomPlayer()
{
	int playerarray[MAXPLAYERS+1];
	int playercount;
	
	for(int player = 1; player <= MaxClients; player++)
	{
		if(IsClientInGame(player))
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

stock int GetNumNotInfected()
{
	int playercount;

	for(int player = 1; player <= MaxClients; player++)
	{
		if(IsClientInGame(player) && !g_bVirus[player])
		{
			playercount++;
		}
	}
	
	return playercount;
}

stock void SetModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);		
}

stock void ChangeClientTeamAlive(int client, TFTeam team)
{
	if(IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		TF2_ChangeClientTeam(client, team);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
	}
	else 
		TF2_ChangeClientTeam(client, team);
}  

stock void SendDeathMessage(int attacker, int victim)
{
	Event event = CreateEvent("player_death");
	if (event != INVALID_HANDLE)
	{ 
		event.SetInt("userid", GetClientUserId(victim));
		event.SetInt("attacker", GetClientUserId(attacker));
		event.SetInt("weapon_def_index", 572);
		event.SetString("weapon", "unarmed_combat");
		event.SetString("weapon_logclassname", "unarmed_combat");
		event.Fire(false);
	}
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