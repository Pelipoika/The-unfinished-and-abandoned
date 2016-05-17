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

Handle cvarTimeScale;
Handle cvarCheats;

bool g_bExplosiveJumping[MAXPLAYERS+1];

float g_flZedTime;
bool g_bZedTime;
float g_glZedTimeCooldown;

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
	
	HookEvent("player_death", Event_Death);
	
	RegAdminCmd("sm_slowmo", Command_ToggleSlowmo, ADMFLAG_ROOT);
}

public Action Command_ToggleSlowmo(int client, int args)
{
/*	if(g_bZedTime)
		DisableSlowmo();
	else
		EnableSlowmo(client, 100.0);*/
	int target = GetClientAimTarget(client, false);
	if(target > 0)
		SetClientViewEntity(client, target);
	else
		SetClientViewEntity(client, client);
		
	return Plugin_Handled;
}

public Action Timer_ShowTrades(Handle timer, any client)
{
	if(g_flZedTime <= GetTickedTime() && g_bZedTime)
	{
		DisableSlowmo();
	}
}

public void OnClientPutInServer(int client)
{
	g_bExplosiveJumping[client] = false;	
}

public void OnMapStart()
{
	PrecacheSound(SOUND_SLOW);
	PrecacheSound(SOUND_FAST);
	PrecacheSound(SOUND_ADD);
	
	CreateTimer(0.1, Timer_ShowTrades, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	g_flZedTime = GetTickedTime() - 10.0;
	g_glZedTimeCooldown = GetTickedTime() - 10.0;
	DisableSlowmo();
}

public Action Event_Death(Handle hEvent, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	bool rocket_jump = GetEventBool(hEvent, "rocket_jump");
	int playerpenetratecount = GetEventInt(hEvent, "playerpenetratecount");
	int customkill = GetEventInt(hEvent, "customkill");
	
	if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && attacker != client) 
	{
		if(rocket_jump)
		{
			EnableSlowmo(attacker, 25.0);
		}
		else if(playerpenetratecount >= 1)
		{
			EnableSlowmo(attacker, 50.0);
		}
		else if(customkill == TF_CUSTOM_TAUNT_HADOUKEN || customkill == TF_CUSTOM_TAUNT_HIGH_NOON
			||	customkill == TF_CUSTOM_TAUNT_GRAND_SLAM || customkill == TF_CUSTOM_TAUNT_FENCING
			||	customkill == TF_CUSTOM_TAUNT_ARROW_STAB || customkill == TF_CUSTOM_TAUNT_GRENADE
			||	customkill == TF_CUSTOM_TAUNT_BARBARIAN_SWING || customkill == TF_CUSTOM_TAUNT_UBERSLICE
			||	customkill == TF_CUSTOM_TAUNT_ENGINEER_SMASH || customkill == TF_CUSTOM_TAUNT_ENGINEER_ARM
			||	customkill == TF_CUSTOM_TAUNT_ARMAGEDDON || customkill == TF_CUSTOM_TAUNT_UBERSLICE
			||	customkill == TF_CUSTOM_TAUNT_ALLCLASS_GUITAR_RIFF || customkill == TF_CUSTOM_TELEFRAG
			||	customkill == TF_CUSTOM_COMBO_PUNCH)
		{
			EnableSlowmo(attacker, 50.0);
		}
		else
			EnableSlowmo(attacker, 1.5);
	}

	return Plugin_Continue;
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
//			EmitSoundToAll(SOUND_ADD);
//			PrintCenterTextAll("%N extended zed-time (+3 Seconds)", activator);
		}

		int flags2 = GetConVarFlags(cvarCheats);
		flags2 &= ~FCVAR_CHEAT
		SetConVarFlags(cvarCheats, flags2);
		
		int flags = GetConVarFlags(cvarTimeScale);
		flags &= ~FCVAR_CHEAT
		SetConVarFlags(cvarTimeScale, flags);
	
		SetConVarFloat(cvarTimeScale, SLOWMO_AMOUNT);
		SetConVarInt(cvarCheats, 1);
		UpdateClientCheatValue(1);	
		
		g_bZedTime = true;
		g_flZedTime = GetTickedTime() + 3.0;
	}
}

stock void DisableSlowmo()
{
	EmitSoundToAll(SOUND_FAST);
	EmitSoundToAll(SOUND_FAST);
	
	int flags2 = GetConVarFlags(cvarCheats);
	flags2 |= FCVAR_CHEAT
	SetConVarFlags(cvarCheats, flags2);
	
	int flags = GetConVarFlags(cvarTimeScale);
	flags |= FCVAR_CHEAT
	SetConVarFlags(cvarTimeScale, flags);
	
	SetConVarFloat(cvarTimeScale, 1.0);
	SetConVarInt(cvarCheats, 0);
	UpdateClientCheatValue(0);
	
	g_glZedTimeCooldown = GetTickedTime() + 10.0;
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
			//	SetVariantInt(0);z
			//	AcceptEntityInput(client, "SetHudVisibility");
			}
			else
			{
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
				SendConVarValue(client, cvarTimeScale, "1.0");
			//	SetVariantInt(1);
			//	AcceptEntityInput(client, "SetHudVisibility");
			}
		}
	}
}

stock void SetEveryonesViewEntity(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			SetClientViewEntity(i, client);
		}
	}
}