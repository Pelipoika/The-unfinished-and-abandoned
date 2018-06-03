#include <sdktools>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#include <basecomm>

#pragma newdecls required

//bool g_bCanVote[MAXPLAYERS+1];

ArrayList g_aVoteBlockedUsers;

ConVar g_hDifficulty;

// /[\x{0410}-\x{042F}]+/umi

char g_sPermaBannedFromVoting[][] = 
{
	"76561198389562175", 
};

public Plugin myinfo = 
{
	name = "[TF2] MvM Tweaks", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	g_hDifficulty = CreateConVar("sm_mvmtweaks_difficulty", "1", "Auto scale difficulty");
	g_hDifficulty.AddChangeHook(DifficultyScalingChanged);
	
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("mvm_wave_complete", WaveCompleted);
	HookEvent("mvm_wave_failed", WaveCompleted);
	
	RegAdminCmd("sm_endrussians", Bye, ADMFLAG_BAN);
	
	AddCommandListener(callvote, "callvote");
	AddCommandListener(vote, "vote");
	
	g_aVoteBlockedUsers = new ArrayList();
}

public void OnMapStart()
{
	g_aVoteBlockedUsers.Clear();
}

public Action Bye(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		QueryClientConVar(i, "cl_language", ConvarQueryResult, client);
	}
	
	return Plugin_Handled;
}

public void ConvarQueryResult(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	int iIssuer = value;
	
	if (StrEqual(cvarValue, "russian")
	 || StrEqual(cvarValue, "polish"))
	{
		CPrintToChat(iIssuer, "%N, is a {red}communist AND HAS BEEN {fullred}MUTED!", client);
		BaseComm_SetClientMute(client, true);
	}
	else
	{
		CPrintToChat(iIssuer, "%N - {lime}%s{default}, is a {lime}okay i guess", client, cvarValue);
	}
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

public Action callvote(int client, const char[] cmd, int argc)
{
	if (TF2_IsMvM() && !IsAllowedToVote(client)) {
		PrintToChat(client, "You can't vote right now");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


public Action vote(int client, const char[] cmd, int argc)
{
	if (TF2_IsMvM() && !IsAllowedToVote(client)) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock bool IsAllowedToVote(int client)
{
	//Owned
	if (TF2_GetClientTeam(client) == TFTeam_Spectator)
		return false;
		
	char steam64[64];
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	
	for (int i = 0; i < sizeof(g_sPermaBannedFromVoting); i++)
	{
		if (!StrEqual(g_sPermaBannedFromVoting[i], steam64))
			continue;
		
		return false;
	}
	
	for (int i = 0; i <= g_aVoteBlockedUsers.Length; i++)
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

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	//Оба гибусы
	Regex rgx = new Regex("[\xd0\x80-\xd3\xbf]+", PCRE_CASELESS | PCRE_UTF8);
	
	int skip_text = 0;
	
	char buffer[PLATFORM_MAX_PATH];
	
	char out[PLATFORM_MAX_PATH];
	strcopy(out, PLATFORM_MAX_PATH, sArgs);
	
	bool bFound = false;
	
	while ((rgx.Match(sArgs[skip_text])) > 0) // When the first string of input text match with expression pattern.
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

public Action WaveCompleted(Event event, const char[] name, bool dontBroadcast)
{
	g_aVoteBlockedUsers.Clear();
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
			PrintToChat(client, "Your vote priviledges have been stripped");
		}
	}
	
	return Plugin_Continue;
}

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
} 