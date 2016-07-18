#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required;

#define PLUGIN_VERSION	"1.0"

#define SOUND_SLOW	"replay/enterperformancemode.wav"
#define SOUND_FAST	"replay/exitperformancemode.wav"
#define SOUND_ADD	"misc/halloween/clock_tick.wav"

ConVar cvarTimeScale;
ConVar cvarCheats;

float g_flZedTime;
bool g_bZedTime;
float g_glZedTimeCooldown;
float g_flTimeScaleGoal;

static const float SLOWMO_AMOUNT = 0.4;

public Plugin myinfo =
{
	name = "[TF2] Zed Time",
	author = "Pelipoika",
	description = "KF2",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnPluginStart()
{
	cvarTimeScale = FindConVar("host_timescale");
	cvarCheats = FindConVar("sv_cheats");
	
	int iHooks = 0;
	char strConCommand[128];
	bool bIsCommand;
	int iFlags;
	Handle hSearch = FindFirstConCommand(strConCommand, sizeof(strConCommand), bIsCommand, iFlags);
	do
	{
		if(bIsCommand && iFlags & FCVAR_CHEAT)
		{
			if(StrEqual(strConCommand, "disguise") || StrEqual(strConCommand, "lastdisguise"))
				continue;
				
			RegConsoleCmd(strConCommand, OnCheatCommand);
			iHooks++;
		}
	}
	while(FindNextConCommand(hSearch, strConCommand, sizeof(strConCommand), bIsCommand, iFlags));

	PrintToServer("[Zed Time] Hooked %i cheat commands", iHooks);
	
	HookEvent("player_death", Event_Death);
	HookEvent("mvm_tank_destroyed_by_players", Event_Notable);
	
	RegAdminCmd("sm_slowmo", Command_ToggleSlowmo, ADMFLAG_ROOT);
}

public Action Command_ToggleSlowmo(int client, int args)
{
	g_glZedTimeCooldown = 0.0;
	
	if(g_bZedTime)
		DisableSlowmo();
	else
		EnableSlowmo(client, 100.0);
		
	return Plugin_Handled;
}

public Action OnCheatCommand(int client, int args)
{
	if(client <= 0 || g_bZedTime)
		return Plugin_Continue;

	PrintToConsole(client, "Cheater! %s", args);
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!impulse || !g_bZedTime) //We just want to prevent impulse commands during zedtime
		return Plugin_Continue;

	if(impulse == 201) //Allow sprays
		return Plugin_Continue;

	PrintToConsole(client, "Cheater! %i", impulse);
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_SLOW);
	PrecacheSound(SOUND_FAST);
	PrecacheSound(SOUND_ADD);
	
	g_flZedTime = 0.0;
	g_glZedTimeCooldown = 0.0;
	g_flTimeScaleGoal = 0.0;
	g_bZedTime = false;
}

public void Event_Notable(Event hEvent, char[] name, bool dontBroadcast)
{
	EnableSlowmo(0, 25.0);
}

public void Event_Death(Handle hEvent, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	bool rocket_jump = GetEventBool(hEvent, "rocket_jump");
	int playerpenetratecount = GetEventInt(hEvent, "playerpenetratecount");
	int customkill = GetEventInt(hEvent, "customkill");
	
	if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && attacker != client) 
	{
		float flChance = 0.0;
		
		if(rocket_jump)
		{
			flChance += 15.0;
		}
		else if(playerpenetratecount >= 1)
		{
			flChance += 5.0;
		}
		else if(customkill == TF_CUSTOM_TAUNT_HADOUKEN             || customkill == TF_CUSTOM_TAUNT_HIGH_NOON
			||	customkill == TF_CUSTOM_TAUNT_GRAND_SLAM           || customkill == TF_CUSTOM_TAUNT_FENCING
			||	customkill == TF_CUSTOM_TAUNT_ARROW_STAB           || customkill == TF_CUSTOM_TAUNT_GRENADE
			||	customkill == TF_CUSTOM_TAUNT_BARBARIAN_SWING      || customkill == TF_CUSTOM_TAUNT_UBERSLICE
			||	customkill == TF_CUSTOM_TAUNT_ENGINEER_SMASH       || customkill == TF_CUSTOM_TAUNT_ENGINEER_ARM
			||	customkill == TF_CUSTOM_TAUNT_ARMAGEDDON           || customkill == TF_CUSTOM_TAUNT_UBERSLICE
			||	customkill == TF_CUSTOM_TAUNT_ALLCLASS_GUITAR_RIFF || customkill == TF_CUSTOM_TELEFRAG
			||	customkill == TF_CUSTOM_COMBO_PUNCH)
		{
			flChance += 25.0;
		}
		else
			flChance += 0.1;
			
		EnableSlowmo(attacker, flChance);
	}
}

public void OnGameFrame()
{
	if(g_flTimeScaleGoal != 0.0)
	{
		float flTimeScale = cvarTimeScale.FloatValue;
		
		if(flTimeScale > g_flTimeScaleGoal)
		{			
			SetConVarFloat(cvarTimeScale, flTimeScale - 0.025);
			if(cvarTimeScale.FloatValue <= g_flTimeScaleGoal)
			{
				SetConVarFloat(cvarTimeScale, SLOWMO_AMOUNT);
			}
		}
		else if(flTimeScale < g_flTimeScaleGoal)
		{
			SetConVarFloat(cvarTimeScale, flTimeScale + 0.025);

			if(cvarTimeScale.FloatValue >= g_flTimeScaleGoal)
			{
				SetConVarFloat(cvarTimeScale, 1.0);
				SetConVarInt(cvarCheats, 0);
				UpdateClientCheatValue(0);
	
				g_flTimeScaleGoal = 0.0;
			}
		}
	}
	
	if(g_flZedTime <= GetTickedTime() && g_bZedTime)
	{
		DisableSlowmo();
	}
}

stock void EnableSlowmo(int activator, float ZedChance)
{
	if(g_glZedTimeCooldown <= GetTickedTime() && GetRandomFloat(0.0, 100.0) <= ZedChance)
	{
		if(!g_bZedTime)
		{
			EmitSoundToAll(SOUND_SLOW);
			EmitSoundToAll(SOUND_SLOW);
		}
		else
		{
			EmitSoundToAll(SOUND_ADD);
		}

		SetConVarInt(cvarCheats, 1);
		UpdateClientCheatValue(1);
		
		g_flTimeScaleGoal = SLOWMO_AMOUNT;
		g_bZedTime = true;
		g_flZedTime = GetTickedTime() + 3.0;
		g_glZedTimeCooldown = GetTickedTime() + 10.0;
	}
}

stock void DisableSlowmo()
{
	if(g_bZedTime)
	{
		EmitSoundToAll(SOUND_FAST);
		EmitSoundToAll(SOUND_FAST);
	}
	
	g_flTimeScaleGoal = 1.0;
	g_bZedTime = false;
}

stock void UpdateClientCheatValue(int value)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client))
		{
			SendConVarValue(client, cvarCheats, value ? "1" : "0");
			
			if(value == 1)
			{
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", SLOWMO_AMOUNT);
				SendConVarValue(client, cvarTimeScale, "0.4");
			}
			else
			{
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
				SendConVarValue(client, cvarTimeScale, "1.0");
			}
		}
	}
}