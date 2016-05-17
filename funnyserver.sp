#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2items>

#pragma newdecls required

ConVar g_hFallDamage;
ConVar g_hRocketJumpDamage;
ConVar g_hJuggleGroundBoost;

bool g_bPVEEnabled = false;
bool g_bDirectHit[MAXPLAYERS+1];
int g_iChallenger[MAXPLAYERS+1];

Handle newGrenadeLauncher;

public Plugin myinfo = 
{
	name = "[TF2] Funny server",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	g_hFallDamage = CreateConVar("sm_funserver_falldamage", "0", "Should there be fall damage? 1 - 0");
	g_hRocketJumpDamage = CreateConVar("sm_funserver_rocketjump_damage", "0", "Should there be self rocketjump damage? 1 - 0");
	g_hJuggleGroundBoost = CreateConVar("sm_funserver_groundjuggle_boost", "1.0", "Juggle knockback boost when target on ground");
	
	for(int client = 1; client <= MaxClients; client++) 
	{
		if(IsClientInGame(client)) 
		{
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
		}
	}
	
	AddTempEntHook("World Decal", TempHook);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_start", Event_RoundStart);
	
	RegAdminCmd("sm_duel", Command_Duel, ADMFLAG_ROOT);
	
	if(newGrenadeLauncher != null)
		delete newGrenadeLauncher;
		
	newGrenadeLauncher = TF2Items_CreateItem(PRESERVE_ATTRIBUTES|OVERRIDE_ATTRIBUTES);
	TF2Items_SetAttribute(newGrenadeLauncher, 0, 681, 1.0);
	TF2Items_SetAttribute(newGrenadeLauncher, 1, 127, 2.0);
	TF2Items_SetNumAttributes(newGrenadeLauncher, 2);
}

public void OnClientPutInServer(int client) 
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public void OnMapStart()
{
	PrecacheSound("ui/duel_challenge.wav");
	PrecacheSound("ui/duel_challenge_accepted.wav");
	PrecacheSound("ui/duel_challenge_rejected.wav");
	PrecacheSound("ui/item_dueling_pistols_pickup.wav");
	
	g_bPVEEnabled = false;
}

public Action Command_Duel(int client, int args)
{
	EmitSoundToClient(client, "ui/item_dueling_pistols_pickup.wav");

	Menu menu = new Menu(MenuDuelHandler);
	menu.SetTitle("Duel who\n ");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			char strName[64], strUserID[8];
			
			IntToString(GetClientUserId(i), strUserID, sizeof(strUserID));
			GetClientName(i, strName, sizeof(strName));

			menu.AddItem(strUserID, strName);
		}
	}
	menu.Display(client, 60);
	
	return Plugin_Handled;
}

public int MenuDuelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char infoBuf[64], displayBuf[64];
			menu.GetItem(param2, infoBuf, sizeof(infoBuf), _, displayBuf, sizeof(displayBuf));
			
			int iTarget = GetClientOfUserId(StringToInt(infoBuf));
			Menu ask = new Menu(MenuDuelAskHandler);
			ask.SetTitle("%N wants to duel\n ", param1);
			ask.AddItem("yes",	"Bring It");
			ask.AddItem("no",	"No");
			ask.Display(iTarget, 60);
			
			g_iChallenger[iTarget] = param1;
			
			EmitSoundToClient(iTarget, "ui/duel_challenge.wav");
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int MenuDuelAskHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char infoBuf[64], displayBuf[64];
			menu.GetItem(param2, infoBuf, sizeof(infoBuf), _, displayBuf, sizeof(displayBuf));

			if(StrEqual(infoBuf, "yes"))
			{
				PrintToChatAll("-> %N agrees to duel with %N", param1, g_iChallenger[param1]);
				EmitSoundToClient(param1, "ui/duel_challenge_accepted.wav");
				EmitSoundToClient(g_iChallenger[param1], "ui/duel_challenge_accepted.wav");
				
				g_iChallenger[g_iChallenger[param1]] = param1;
			
				PrintToChatAll("%N VS %N", g_iChallenger[param1], g_iChallenger[g_iChallenger[param1]]);
			}
			else
			{
				PrintToChatAll("-> %N disagrees to duel with %N", param1, g_iChallenger[param1]);
				EmitSoundToClient(param1, "ui/duel_challenge_rejected.wav");
				EmitSoundToClient(g_iChallenger[param1], "ui/duel_challenge_rejected.wav");
			}
		}
		case MenuAction_Cancel:
		{
			PrintToChatAll("-> %N disagrees to duel with %N", param1, g_iChallenger[param1]);
			EmitSoundToClient(param1, "ui/duel_challenge_rejected.wav");
			EmitSoundToClient(g_iChallenger[param1], "ui/duel_challenge_rejected.wav");
		
			delete menu;
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "tf_ammo_pack", true) != -1)
	{
		SDKHook(entity, SDKHook_Spawn, OnAmmoSpawn);
	}
	else if(StrEqual(classname, "tf_projectile_rocket"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnRocketTouch);
	}
}

public void OnRocketTouch(int entity, int other)
{
	if(other > 0 && other <= MaxClients)
	{
		g_bDirectHit[other] = true;
	}
}

public void OnAmmoSpawn(int entity)
{
	if(IsValidEntity(entity) && GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != -1)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int defindex, Handle &item) 
{
	if(StrEqual(classname, "tf_wearable_demoshield") 
	|| StrEqual(classname, "tf_weapon_medigun") 
	|| StrEqual(classname, "tf_weapon_buff_item") 
	|| StrEqual(classname, "tf_weapon_invis")
	|| StrEqual(classname, "tf_weapon_sword")
	|| defindex == 127 || defindex == 444)
	{
		return Plugin_Handled;
	}
	
	if(StrEqual(classname, "tf_weapon_grenadelauncher") || StrEqual(classname, "tf_weapon_cannon"))
	{
		item = newGrenadeLauncher;

		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(killer > 0 && killer <= MaxClients && IsClientConnected(killer) && client != killer)
	{
		int iMaxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, killer);
		int iCurHealth = GetClientHealth(killer);
		
		int iHP = 50;
		if(iCurHealth + iHP > iMaxHealth)
			SetEntProp(killer, Prop_Send, "m_iHealth", iMaxHealth);
		else
			SetEntProp(killer, Prop_Send, "m_iHealth", iCurHealth + iHP);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool bChanged = false;
	
	if(damagetype & DMG_FALL && !g_hFallDamage.BoolValue)
		return Plugin_Handled;

	if(!IsValidEntity(weapon))
		return Plugin_Continue;

	char strClassname[64];
	GetEntityClassname(weapon, strClassname, sizeof(strClassname));

	if(victim != attacker && victim != inflictor)
	{
		TFClassType aClass = TF2_GetPlayerClass(attacker);
		bool bAttackerBlastJumping = TF2_IsPlayerInCondition(attacker, TFCond_BlastJumping);
		bool bVictimBlastJumping = TF2_IsPlayerInCondition(victim, TFCond_BlastJumping);
		bool bIsBodyshot = (damagecustom != TF_CUSTOM_HEADSHOT && damagecustom != TF_CUSTOM_HEADSHOT_DECAPITATION);
		int iWeaponDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		
		switch(aClass)
		{
			case TFClass_Sniper:
			{
				if(StrContains(strClassname, "sniperrifle") != -1 || StrContains(strClassname, "bow") != -1)
				{
					if(bIsBodyshot)
					{
						damage = damage = 0.0;
						bChanged = true;
					}
					else
					{
						if(bVictimBlastJumping && !bIsBodyshot)
						{
							damage = damage * 2.0;
							bChanged = true;
						}
						else
						{
							damage = damage * 0.5;
							bChanged = true;
						}
					}
				}
				else
				{
					damage = damage = 0.0;
					bChanged = true
				}
			}
			case TFClass_Medic:
			{
				if(StrContains(strClassname, "crossbow") == -1)
				{
					damage = 0.0;
					bChanged = true;
				}
			}
			case TFClass_Spy:
			{
				if(StrContains(strClassname, "revolver") != -1 || StrContains(strClassname, "bow") != -1)
				{
					if(bIsBodyshot)
					{
						damage = 0.0;
						bChanged = true;
					}
				}
				else
				{
					damage = 0.0;
					bChanged = true;
				}
			}
			case TFClass_DemoMan, TFClass_Soldier:
			{
				if(StrContains(strClassname, "rocketlauncher") != -1)
				{
					if(!bVictimBlastJumping)
					{
						SetEntProp(victim, Prop_Data, "m_takedamage", 1, 1);
						RequestFrame(ReCheck, victim);
					}
					
					if(!g_bDirectHit[victim] && bVictimBlastJumping)
					{
						g_bDirectHit[victim] = false;
						
						damage = 0.0;
						bChanged = true;
					}
				}
				else if(StrContains(strClassname, "grenadelauncher") != -1)
				{
					if(!bVictimBlastJumping)
					{
						SetEntProp(victim, Prop_Data, "m_takedamage", 1, 1);
						RequestFrame(ReCheck, victim);
					}
				}
				else if(StrContains(strClassname, "shovel") != -1)
				{
					if(iWeaponDefIndex == 416 && damagetype & DMG_CRIT)
					{
						damage = 200.0;
						bChanged = true;
					}
					if(!bAttackerBlastJumping)
					{
						damage = 0.0;
						bChanged = true;
					}
				}
				else
				{
					damage = 0.0;
					bChanged = true;
				}
			}
			default:
			{
				damage = 0.0;
				bChanged = true;
			}
		}
		
		g_bDirectHit[victim] = false;
	}
	else
	{
		damage = 0.1;
		bChanged = true;
	}

	if(!g_hRocketJumpDamage.BoolValue && (victim == attacker || victim == inflictor))
	{
		TF2Attrib_SetByName(attacker, "rocket jump damage reduction", 0.0);
	}
	else
	{
		TF2Attrib_RemoveByName(attacker, "rocket jump damage reduction");
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

public void ReCheck(int client)
{
	float flVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);

	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	
	ScaleVector(flVelocity, g_hJuggleGroundBoost.FloatValue);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, flVelocity);
}

public Action TempHook(const char[] te_name, const Players[], int numClients, float delay)
{
	return Plugin_Stop;
}

//PVE stuff
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, Timer_PVEVote);
}

public Action Timer_PVEVote(Handle timer, any data)
{
	if (!IsVoteInProgress() && !g_bPVEEnabled)
	{
		Menu menu = new Menu(Handle_VoteMenu);
		menu.VoteResultCallback = Handle_VoteResults;
		menu.SetTitle("Enable PVE mode?");
		menu.AddItem("yes", "Yes");
		menu.AddItem("no", "No");
		menu.ExitButton = false;
		menu.DisplayVoteToAll(20);
	}
}

public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		/* This is called after VoteEnd */
		delete menu;
	}
}

public void Handle_VoteResults(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	/* See if there were multiple winners */
	int winner = 0;
	if (num_items > 1 && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES]))
	{
		PrintToChatAll("Handle_VoteResults Get Random Winner");
		winner = GetRandomInt(0, 1);
	}
 
	char strWinnerInfo[64];
	menu.GetItem(item_info[winner][VOTEINFO_ITEM_INDEX], strWinnerInfo, sizeof(strWinnerInfo));
	
	if(StrEqual(strWinnerInfo, "yes"))
	{
		PrintCenterTextAll("PVE Mode will be enabled for this map..");
		
		SetConVarString(FindConVar("mp_humans_must_join_team"), "blue", true); 
		SetConVarInt(FindConVar("mp_friendlyfire"), 1, true); 
		SetConVarInt(FindConVar("tf_avoidteammates"), 0, true); 
		SetConVarInt(FindConVar("tf_spawn_glows_duration"), 0, true); 

		g_bPVEEnabled = true;
		
		for(int client = 1; client <= MaxClients; client++) 
			if(IsClientInGame(client) && TF2_GetClientTeam(client) != TFTeam_Blue)
				TF2_ChangeClientTeam(client, TFTeam_Blue);
	}
	else
	{
		PrintCenterTextAll("PVE Mode will be disabled for this map..");
		
		SetConVarString(FindConVar("mp_humans_must_join_team"), "any", true); 
		SetConVarInt(FindConVar("mp_friendlyfire"), 0, true); 
		SetConVarInt(FindConVar("tf_avoidteammates"), 1, true); 
		SetConVarInt(FindConVar("tf_spawn_glows_duration"), 10, true); 
		
		if(g_bPVEEnabled)
			ServerCommand("mp_scrambleteams");
		
		g_bPVEEnabled = false;
	}
}

public void OnGameFrame()
{
	if(g_bPVEEnabled)
	{
		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
		{
			SetEntProp(ent, Prop_Data, "m_iInitialTeamNum", 2);
			SetEntProp(ent, Prop_Send, "m_iTeamNum", 2);
		}
	}
}
//PVE end
