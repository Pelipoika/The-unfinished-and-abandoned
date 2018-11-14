#include <sdktools>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#include <basecomm>

#pragma newdecls required

//bool g_bCanVote[MAXPLAYERS+1];

ArrayList g_aVoteBlockedUsers;
ArrayList g_aSpectateBlockedUsers;

ConVar g_hDifficulty;

// /[\x{0410}-\x{042F}]+/umi

public Plugin myinfo = 
{
	name = "[TF2] MvM Tweaks", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

//Pressing F4    makes you unable to spectate
//Calling a vote makes you unable to spectate
//Leaving the spectator team blocks you from voting
//All of the above is void once a wave is completed/failed or after map change
public void OnPluginStart()
{
	g_hDifficulty = CreateConVar("sm_mvmtweaks_difficulty", "1", "Auto scale difficulty");
	g_hDifficulty.AddChangeHook(DifficultyScalingChanged);
	
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("mvm_wave_complete", WaveCompleted);
	HookEvent("mvm_wave_failed", WaveCompleted);
	
	
	//The real reason communism failed
	RegAdminCmd("sm_endrussians", Bye, ADMFLAG_BAN);
	
	
	RegAdminCmd("sm_specban",            SpecBan, ADMFLAG_BAN);
	RegAdminCmd("sm_blockspec",          SpecBan, ADMFLAG_BAN);
	RegAdminCmd("sm_spectateban",        SpecBan, ADMFLAG_BAN);
	RegAdminCmd("sm_spectorban",         SpecBan, ADMFLAG_BAN);
	
	LoadTranslations("common.phrases");
	
	AddCommandListener(callvote, "callvote");
	AddCommandListener(vote, "vote");
	
	AddCommandListener(pressedf4, "tournament_player_readystate");
	AddCommandListener(jointeam, "jointeam");
	AddCommandListener(jointeam, "spectate");
	
	g_aVoteBlockedUsers     = new ArrayList(PLATFORM_MAX_PATH);
	g_aSpectateBlockedUsers = new ArrayList(PLATFORM_MAX_PATH);
}

public void OnMapStart()
{
	g_aVoteBlockedUsers.Clear();
	g_aSpectateBlockedUsers.Clear();
}

public Action WaveCompleted(Event event, const char[] name, bool dontBroadcast)
{
	g_aVoteBlockedUsers.Clear();
	g_aSpectateBlockedUsers.Clear();
}

public Action SpecBan(int client, int args)
{
	char arg1[32];
	
	/* Get the first argument */
	GetCmdArg(1, arg1, sizeof(arg1));
	
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS, /* Only allow alive players */
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		BlockFromSpectating(target_list[i]);
		LogAction(client, target_list[i], "\"%L\" blocked \"%L\" from spectating", client, target_list[i]);
	}
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "Blocked %t from spectating!", target_name);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "Blocked %s from spectating!", target_name);
	}

	return Plugin_Handled;
}

public Action Bye(int client, int args)
{
	char cl_language[32];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if(IsFakeClient(i))
			continue;
		
		GetClientInfo(i, "cl_language", cl_language, sizeof(cl_language));
		
		if (StrEqual(cl_language, "russian") || StrEqual(cl_language, "polish"))
		{
			ReplyToCommand(client, "\"%N\" is a communist AND HAS BEEN MUTED!", i);
			
			BaseComm_SetClientMute(i, true);
		}
		else
		{
			ReplyToCommand(client, "\"%N\" - \"%s\" is okay i guess", i, cl_language);
		}
	}
	
	return Plugin_Handled;
}

void DifficultyScalingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ConVar cvarHealth = FindConVar("tf_populator_health_multiplier");
	ConVar cvarDamage = FindConVar("tf_populator_damage_multiplier");
	
	if (StringToInt(newValue) <= 0)
	{
		cvarHealth.SetFloat(1.0);
		cvarDamage.SetFloat(1.0);
	}
}

public Action pressedf4(int client, const char[] cmd, int argc)
{
	if (TF2_IsMvM() && IsAllowedToSpectate(client)) {
		BlockFromSpectating(client);
	}
	
	return Plugin_Continue;
}

public Action jointeam(int client, const char[] cmd, int argc)
{
	char buff[PLATFORM_MAX_PATH];
	GetCmdArgString(buff, PLATFORM_MAX_PATH);
	
	//Command or argstream contains specta
	bool bIsAttemptingToSpectate = ((StrContains(buff, "specta", false) != -1) || StrEqual(cmd, "spectate", false));
	
	if (TF2_IsMvM() && bIsAttemptingToSpectate && !IsAllowedToSpectate(client))
	{
		CPrintToChat(client, "You are not allowed to spectate right now.");
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action callvote(int client, const char[] cmd, int argc)
{
	if (TF2_IsMvM())
	{
		BlockFromSpectating(client);
		
		if (!IsAllowedToVote(client))
		{
			CPrintToChat(client, "You are not allowed to start a vote right now.");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action vote(int client, const char[] cmd, int argc)
{
	if (TF2_IsMvM() && !IsAllowedToVote(client)) 
	{
		CPrintToChat(client, "You are not allowed to participate in votes right now.");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock bool IsAllowedToVote(int client)
{
	//Owned
	if (TF2_GetClientTeam(client) == TFTeam_Spectator)
		return false;
	
	if (TF2_GetClientTeam(client) == TFTeam_Blue)
		return false;
	
	char steam64[64];
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	
	for (int i = 0; i < g_aVoteBlockedUsers.Length; i++)
	{
		char aSteam64[64];
		g_aVoteBlockedUsers.GetString(i, aSteam64, sizeof(aSteam64));
		
		if (!StrEqual(aSteam64, steam64))
			continue;
		
		return false;
	}
	
	return true;
}

stock void BlockFromVoting(int client)
{
	char steam64[64];
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	
	g_aVoteBlockedUsers.PushString(steam64);
}

stock bool IsAllowedToSpectate(int client)
{
	char steam64[64];
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	
	for (int i = 0; i < g_aSpectateBlockedUsers.Length; i++)
	{
		char aSteam64[64];
		g_aSpectateBlockedUsers.GetString(i, aSteam64, sizeof(aSteam64));
		
		if (!StrEqual(aSteam64, steam64))
			continue;
		
		return false;
	}
	
	return true;
}

stock void BlockFromSpectating(int client)
{
	char steam64[64];
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	
	g_aSpectateBlockedUsers.PushString(steam64);
	
	//Force them out of spectator team if they are spectating.
	if(TF2_GetClientTeam(client) == TFTeam_Spectator)
	{
		FakeClientCommand(client, "autoteam");
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	//Test string :Оба гибусы
	Regex rgx = new Regex("[\xd0\x80-\xd3\xbf]+", PCRE_CASELESS | PCRE_UTF8);
	
	int skip_text = 0;
	
	char buffer[PLATFORM_MAX_PATH];
	
	char out[PLATFORM_MAX_PATH];
	strcopy(out, PLATFORM_MAX_PATH, sArgs);
	
	bool bFound = false;
	
	while (strlen(sArgs[skip_text]) > 0 && rgx.Match(sArgs[skip_text])) // When the first string of input text match with expression pattern.
	{
		// Pick whole string matching with expression pattern.
		if (!rgx.GetSubString(0, buffer, sizeof(buffer)))
		{
			break;
		}
		
		char replace[64];
		Format(replace, sizeof(replace), "{red}%s{default}", buffer);
		
		ReplaceString(out, PLATFORM_MAX_PATH, buffer, replace);
		
		// We do not want regex to hit the same part of the input text. Skip the first piece of input text in the next cycle.
		skip_text += StrContains(sArgs[skip_text], buffer);
		skip_text += strlen(buffer);
		
		bFound = true;
	}
	
	delete rgx;
	
	if (bFound)
	{
		CPrintToChat(client, "{lightblue}Your message was not sent because it contained banned letters");
		CPrintToChat(client, "%s", out);
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (TF2_IsMvM())
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		int iDefenders = GetTeamClientCount(view_as<int>(TFTeam_Red));
		if (iDefenders > 0 && g_hDifficulty.BoolValue)
		{
			ConVar cvarHealth = FindConVar("tf_populator_health_multiplier");
			ConVar cvarDamage = FindConVar("tf_populator_damage_multiplier");
			
			float flOldValue = cvarHealth.FloatValue;
			
			switch (iDefenders)
			{
				case 1:
				{
					cvarHealth.SetFloat(0.5);
					cvarDamage.SetFloat(0.5);
				}
				case 2:
				{
					cvarHealth.SetFloat(0.5);
					cvarDamage.SetFloat(0.5);
				}
				case 3:
				{
					cvarHealth.SetFloat(0.5);
					cvarDamage.SetFloat(0.5);
				}
				case 4:
				{
					cvarHealth.SetFloat(0.666);
					cvarDamage.SetFloat(0.666);
				}
				case 5:
				{
					cvarHealth.SetFloat(0.833);
					cvarDamage.SetFloat(0.833);
				}
				case 6:
				{
					cvarHealth.SetFloat(1.0);
					cvarDamage.SetFloat(1.0);
				}
				default:
				{
					cvarHealth.SetFloat(1.0);
					cvarDamage.SetFloat(1.0);
				}
			}
			
			if (flOldValue < cvarHealth.FloatValue)
			{
				CPrintToChatAll("Increasing difficulty to accommodate current player count %.0f%% -> %.0f%%", flOldValue * 100, cvarHealth.FloatValue * 100);
			}
			else if (flOldValue > cvarHealth.FloatValue)
			{
				CPrintToChatAll("Lowering difficulty to accommodate current player count %.0f%% -> %.0f%%", flOldValue * 100, cvarHealth.FloatValue * 100);
			}
		}
		
		//	TFTeam iTeam = view_as<TFTeam>(event.GetInt("team"));
		TFTeam iOldTeam = view_as<TFTeam>(event.GetInt("oldteam"));
		
		//Don't show joining spectator from blue team or joining blue team
		if (!IsFakeClient(client) && iOldTeam == TFTeam_Spectator && IsAllowedToVote(client))
		{
			BlockFromVoting(client);
			CPrintToChat(client, "Your vote priviledges have been stripped");
		}
	}
	
	return Plugin_Continue;
}

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
} 