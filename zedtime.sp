#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required;

#define SOUND_SLOW	"replay/enterperformancemode.wav"
#define SOUND_FAST	"replay/exitperformancemode.wav"
#define SOUND_ADD	"misc/halloween/clock_tick.wav"

ConVar cvarTimeScale;
ConVar cvarCheats;

//Is ZED Time?
bool g_bZedTime;

//ZED Time start time.
float g_flZedTime;

//ZED Time cooldown period.
float g_glZedTimeCooldown;

//ZED Time slowdown amount goal.
float g_flTimeScaleGoal;

//Last time a kill happened.
float g_flLastKillTime;

//Kill stack time tolerance
static const float SLOWMO_KILL_STACK_WINDOW = 0.5;
int g_iKillStack;

//ZED Time slows the world to 20% of its normal speed (i.e. by 5 times).			
static const float SLOWMO_AMOUNT = 0.3;

//ZED Time duration
static const float SLOWMO_DURATION = 5.0;

//ZED Time lerp amount
static const float SLOWMO_CHANGE_AMOUNT = 2.0;


public Plugin myinfo =
{
	name = "[TF2] Zed Time",
	author = "Pelipoika",
	description = "KF2 Slowmo in TF2",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	cvarTimeScale = FindConVar("host_timescale");
	cvarCheats = FindConVar("sv_cheats");
	
	int iHooks = 0;
	char strConCommand[PLATFORM_MAX_PATH];
	bool bIsCommand;
	int iFlags;
	
	AddCommandListener(OnCheatCommand, "addcond");
	AddCommandListener(OnCheatCommand, "removecond");
	
	Handle hSearch = FindFirstConCommand(strConCommand, sizeof(strConCommand), bIsCommand, iFlags);
	do
	{
		if(bIsCommand && (iFlags & FCVAR_CHEAT))
		{
			if(StrEqual(strConCommand, "disguise") || StrEqual(strConCommand, "lastdisguise"))
				continue;
			
			//PrintToServer("%i %s", bIsCommand, strConCommand);
			AddCommandListener(OnCheatCommand, strConCommand);
			iHooks++;
		}
	}
	while(FindNextConCommand(hSearch, strConCommand, sizeof(strConCommand), bIsCommand, iFlags));
	
	PrintToServer("[Zed Time] Hooked %i cheat commands", iHooks);

/*	int flags = GetCommandFlags("tf_mvm_jump_to_wave");
	SetCommandFlags("tf_mvm_jump_to_wave", flags & ~FCVAR_CHEAT);
	RegConsoleCmd("tf_mvm_jump_to_wave", Command_JumpToWave);
	
	flags = GetCommandFlags("tf_mvm_popfile");
	SetCommandFlags("tf_mvm_popfile", flags & ~FCVAR_CHEAT);
	RegConsoleCmd("tf_mvm_popfile", Command_JumpToWave);
	
	flags = GetCommandFlags("ent_create");
	SetCommandFlags("ent_create", flags & ~FCVAR_CHEAT);
	RegConsoleCmd("ent_create", Command_JumpToWave);*/
	
	//HookEvent("player_death", Event_Death);
	//HookEvent("mvm_tank_destroyed_by_players", Event_Notable);
	
	RegAdminCmd("sm_slowmo", Command_ToggleSlowmo, ADMFLAG_ROOT);
}

public Action Command_JumpToWave(int client, int args)
{
	if(client > 0 && !CheckCommandAccess(client, "", ADMFLAG_ROOT, true))
	{
		PrintToChat(client, "You cant use this command");
		return Plugin_Stop;
	}
		
	return Plugin_Continue;
}

public Action Command_ToggleSlowmo(int client, int args)
{
	char time[16];
	GetCmdArgString(time, sizeof(time));
	
	float flCustomTime = StringToFloat(time);
	
	g_glZedTimeCooldown = 0.0;
	
	if(g_bZedTime)
		DisableSlowmo();
	else
		EnableSlowmo(client, 100.0, flCustomTime);
		
	return Plugin_Handled;
}

public Action OnCheatCommand(int client, const char[] command, int argc)
{
	if(client <= 1)
		return Plugin_Continue;
		
	//Allow admins to cheat
	//if(CheckCommandAccess(client, "", ADMFLAG_BAN, true))
		//return Plugin_Continue;
		
	//if(!g_bZedTime)
	//	return Plugin_Continue;
	
	char strArgs[PLATFORM_MAX_PATH];
	GetCmdArgString(strArgs, PLATFORM_MAX_PATH);

	PrintToServer("OnCheatCommand %N %s %s", client, command, strArgs);
	
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
	g_iKillStack = 0;
	g_bZedTime = false;
}

public void Event_Notable(Event hEvent, char[] name, bool dontBroadcast)
{
	EnableSlowmo(0, 5.0);
}

public void Event_Death(Handle hEvent, char[] name, bool dontBroadcast)
{
	int victim   = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
		
	//Suicide
	if(attacker == victim)
		return;
	
	//Attacker is not a player
	if(attacker <= 0 || attacker > MaxClients) 
		return;
	
	bool bVictimWasAI   = IsFakeClient(victim);
	bool bAttackerWasAI = IsFakeClient(attacker);
	
	int customkill = GetEventInt(hEvent, "customkill");
	int damagebits = GetEventInt(hEvent, "damagebits");

	//ZED Time trigger chance this kill
	float flChance = 0.0;
	
	float flDistanceToKill = GetVectorDistance(GetAbsOrigin(attacker), GetAbsOrigin(victim));
	
	if(bVictimWasAI) 
	{
		//PrintToServer("HammerUnitsToMeters %f = %f", flDistanceToKill, HammerUnitsToMeters(flDistanceToKill));
	
		//Was the kill a headshot?
		if((customkill & TF_CUSTOM_HEADSHOT) || (customkill & TF_CUSTOM_HEADSHOT_DECAPITATION)) 
		{
			if(HammerUnitsToMeters(flDistanceToKill) < 25) {
				// - if ZED killed by headshot (distance < 25 meters)		
				flChance = 5.0;
			} else {
				// - if ZED killed by headshot (distance > 25 meters)		
				flChance = 2.5;
			}
		}
		else
		{
			if(HammerUnitsToMeters(flDistanceToKill) < 3) {
				//Player kill AI ZED (distance < 3 meters)		
				flChance = 5.0;
			} else {
				//Player kill AI ZED (distance > 3 meters)		
				flChance = 2.5;
			}
		}
		
		bool bCanStackExplosiveKills = ((GetEngineTime() - g_flLastKillTime) <= SLOWMO_KILL_STACK_WINDOW);
		
		//Keep track and count explosive kills that happen within 0.5 seconds.
		if(damagebits & DMG_BLAST && bCanStackExplosiveKills) 
		{
			g_iKillStack++;
		} 
		else 
		{
			if(g_iKillStack >= 4) {
				flChance = 5.0;
			} else if (g_iKillStack >= 2 && g_iKillStack <= 3) {
				flChance = 3.0;
			}
			
			g_iKillStack = 0;
		}
	}
	
	g_flLastKillTime = GetEngineTime();	
	
	//ZED kill player		
	if(bAttackerWasAI) {
		flChance = 5.0;
	}
	
	//Critical hits increase slowmo chance by 5%
	if(damagebits & DMG_CRIT) {
		flChance += 5.0;
	}

	EnableSlowmo(attacker, flChance);
}

/*
	if(customkill == TF_CUSTOM_TAUNT_HADOUKEN             || customkill == TF_CUSTOM_TAUNT_HIGH_NOON
	|| customkill == TF_CUSTOM_TAUNT_GRAND_SLAM           || customkill == TF_CUSTOM_TAUNT_FENCING
	|| customkill == TF_CUSTOM_TAUNT_ARROW_STAB           || customkill == TF_CUSTOM_TAUNT_GRENADE
	|| customkill == TF_CUSTOM_TAUNT_BARBARIAN_SWING      || customkill == TF_CUSTOM_TAUNT_UBERSLICE
	|| customkill == TF_CUSTOM_TAUNT_ENGINEER_SMASH       || customkill == TF_CUSTOM_TAUNT_ENGINEER_ARM
	|| customkill == TF_CUSTOM_TAUNT_ARMAGEDDON           || customkill == TF_CUSTOM_TAUNT_UBERSLICE
	|| customkill == TF_CUSTOM_TAUNT_ALLCLASS_GUITAR_RIFF || customkill == TF_CUSTOM_TELEFRAG
	|| customkill == TF_CUSTOM_COMBO_PUNCH)
	{
		flChance += 25.0;
	}
*/

const float one_centimeter_in_hu = 1.904;
const float one_meter_in_hu      = 190.4; 

stock float HammerUnitsToMeters(float hu)
{
	return (hu / one_meter_in_hu);
}

public void OnGameFrame()
{
	if(g_flTimeScaleGoal != 0.0)
	{
		float flTimeScale = cvarTimeScale.FloatValue;
		
		if(flTimeScale > g_flTimeScaleGoal)
		{
			flTimeScale -= SLOWMO_CHANGE_AMOUNT * GetGameFrameTime();
		
			SetConVarFloat(cvarTimeScale, flTimeScale);
			
			//PrintToServer("flTimeScale %f", flTimeScale);
			
			if(cvarTimeScale.FloatValue <= g_flTimeScaleGoal)
			{
				SetConVarFloat(cvarTimeScale, SLOWMO_AMOUNT);
			}
		}
		else if(flTimeScale < g_flTimeScaleGoal)
		{
			flTimeScale += SLOWMO_CHANGE_AMOUNT * GetGameFrameTime();
		
			SetConVarFloat(cvarTimeScale, flTimeScale);
			
			if(cvarTimeScale.FloatValue >= g_flTimeScaleGoal)
			{
				SetConVarFloat(cvarTimeScale, 1.0);
				SetConVarInt(cvarCheats, 0);
				UpdateClientCheatValue(0);
	
				g_flTimeScaleGoal = 0.0;
			}
		}
	}
	
	if(g_flZedTime <= GetEngineTime() && g_bZedTime)
	{
		DisableSlowmo();
	}
}

stock void EnableSlowmo(int activator, float ZedChance, float flTimeOverride = 0.0)
{
	if(g_glZedTimeCooldown <= GetEngineTime() && GetRandomFloat(0.0, 100.0) <= ZedChance)
	{
		if(!g_bZedTime)
		{
			EmitSoundToAll(SOUND_SLOW);
			EmitSoundToAll(SOUND_SLOW);
		}
		else
		{
			EmitSoundToAll(SOUND_ADD);
			
			//Triggering ZED time again when it's already on resets the timer.
			g_flZedTime = GetEngineTime() + SLOWMO_DURATION;
		}

		SetConVarInt(cvarCheats, 1);
		UpdateClientCheatValue(1);
		
		//ZED Time now.
		g_bZedTime = true;
		
		//ZED Time slows the world to 20% of its normal speed (i.e. by 5 times).			
		g_flTimeScaleGoal = SLOWMO_AMOUNT;
		
		//ZED Time duration		
		g_flZedTime = GetEngineTime() + ((flTimeOverride > 0.0) ? flTimeOverride : SLOWMO_DURATION);
		
		//Minimum interval between 2 ZED Times		
		g_glZedTimeCooldown = GetEngineTime() + GetRandomFloat(30.0, 120.0);
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

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}