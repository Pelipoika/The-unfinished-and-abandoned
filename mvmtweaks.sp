#include <sdktools>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

bool g_bCanVote[MAXPLAYERS+1];

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

public void OnClientPutInServer(int client)
{
	g_bCanVote[client] = false;
}

public void OnPluginStart()
{
	g_hDifficulty = CreateConVar("sm_mvmtweaks_difficulty", "1", "Auto scale difficulty");
	g_hDifficulty.AddChangeHook(DifficultyScalingChanged);
	
	AddCommandListener(callvote, "callvote");
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("mvm_wave_complete", WaveCompleted);
	HookEvent("mvm_wave_failed", WaveCompleted);
}

void DifficultyScalingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ConVar cvarHealth = FindConVar("tf_populator_health_multiplier");
	ConVar cvarDamage = FindConVar("tf_populator_damage_multiplier");
	
	if(StringToInt(newValue) <= 0)
	{
		cvarHealth.SetFloat(1.0);
		cvarDamage.SetFloat(1.0);
	}
}

public Action callvote(int client, const char[]cmd, int argc)
{
	if(TF2_IsMvM())
	{
		if(!g_bCanVote[client])
		{
			PrintToChat(client, "You can't vote right now");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	//Оба гибусы
	Regex rgx = new Regex("[\xd0\x80-\xd3\xbf]+", PCRE_CASELESS|PCRE_UTF8);
	
	int substrings = 0
	int skip_text = 0;
	
	char buffer[PLATFORM_MAX_PATH];
	
	char out[PLATFORM_MAX_PATH];
	strcopy(out, PLATFORM_MAX_PATH, sArgs);
	
	bool bFound = false;
	
	while((substrings = rgx.Match(sArgs[skip_text])) > 0) // When the first string of input text match with expression pattern.
    {
        // Pick whole string matching with expression pattern.
        if( !rgx.GetSubString(0, buffer, sizeof(buffer)) )
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
	
	if(bFound)
	{
		CPrintToChat(client, "{lightblue}Your message was not sent because it contained banned letters");
		CPrintToChat(client, "%s", out);
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
	
	/*
		// If regex expression pattern include capturing parentheses = /(x)(x)/
		// The matching strings are stored in array, variable substrings contains the number of strings
		for(int index = 1; index < substrings; index++)
		{
			if( !rgx.GetSubString(index, buffer, sizeof(buffer)) )
			{
			    break;
			}
			
			PrintToChat(client, ">> %s", buffer);
			
			ReplaceString(out, PLATFORM_MAX_PATH, buffer, "{red}CANCER{default}");
		}
	*/
}

public Action WaveCompleted(Event event, const char[] name, bool dontBroadcast)
{
	if(TF2_IsMvM())
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && TF2_GetClientTeam(i) != TFTeam_Spectator)
			{
				if(!g_bCanVote[i])
				{
					PrintToChat(i, "You may now vote again.");
					g_bCanVote[i] = true;
				}
			}
		}
	}
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(TF2_IsMvM())
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		int iDefenders = GetTeamClientCount(view_as<int>(TFTeam_Red));
		if(iDefenders > 0 && g_hDifficulty.BoolValue)
		{
			ConVar cvarHealth = FindConVar("tf_populator_health_multiplier");
			ConVar cvarDamage = FindConVar("tf_populator_damage_multiplier");
			
			float flOldValue = cvarHealth.FloatValue;
	
			switch(iDefenders)
			{
				case 1: 
				{
					cvarHealth.SetFloat(0.166);
					cvarDamage.SetFloat(0.166);
				}
				case 2:	
				{
					cvarHealth.SetFloat(0.333);
					cvarDamage.SetFloat(0.333);
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
	
			if(flOldValue < cvarHealth.FloatValue)
			{
				CPrintToChatAll("Increasing difficulty to accommodate current player count %.0f%% -> %.0f%%", flOldValue * 100, cvarHealth.FloatValue * 100);
			}
			else if(flOldValue > cvarHealth.FloatValue)
			{
				CPrintToChatAll("Lowering difficulty to accommodate current player count %.0f%% -> %.0f%%", flOldValue * 100, cvarHealth.FloatValue * 100);
			}
		}
		
	//	TFTeam iTeam = view_as<TFTeam>(event.GetInt("team"));
		TFTeam iOldTeam = view_as<TFTeam>(event.GetInt("oldteam"));
		
		//Don't show joining spectator from blue team or joining blue team
		if(!IsFakeClient(client) && iOldTeam == TFTeam_Spectator && g_bCanVote[client])
		{
			g_bCanVote[client] = false;
			PrintToChat(client, "You vote priviledges have been stripped");
		}
	}
	
	return Plugin_Continue;
}

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}