#include <sdktools>
#include <tf2_stocks>
#include <tf2attributes>

#pragma newdecls required

enum MissionType
{
	NOMISSION         = 0,
	UNKNOWN           = 1,
	DESTROY_SENTRIES  = 2,
	SNIPER            = 3,
	SPY               = 4,
	ENGINEER          = 5,
	REPROGRAMMED      = 6,
};

public Plugin myinfo = 
{
	name = "[TF2] Buster",
	author = "Pelipoika",
	description = "!",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

int g_iOffsetSBTarget;

Handle g_hSetMission;

bool g_bIsBuster[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_bust", Command_Bust, ADMFLAG_ROOT, "Send a sentry buster after someone/something");
	
//	if(LookupOffset(g_iOffsetSBTarget, "CTFPlayer", "m_iPlayerSkinOverride")) g_iOffsetSBTarget += GameConfGetOffset(hConf, "m_hSBTarget");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x80\x7D\x0C\x00\x56\x8B\xF1", 10);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//MissionType
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//StartIdleSount?
	if((g_hSetMission = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Signature Call for CTFBot::SetMission!");
	
	int m_iPlayerSkinOverride = FindSendPropInfo("CTFPlayer", "m_iPlayerSkinOverride");
	int m_hSBTarget = (2407 * 4) - m_iPlayerSkinOverride;
	
	g_iOffsetSBTarget = m_iPlayerSkinOverride + m_hSBTarget;
	
	HookEvent("player_death", Event_BusterDeath, EventHookMode_PostNoCopy);
	HookEvent("post_inventory_application", Event_BusterSpawn);
	
	PrintToServer("m_iPlayerSkinOverride = %i\nm_hSBTarget = %i + %i = %i", m_iPlayerSkinOverride, m_iPlayerSkinOverride, m_hSBTarget, m_iPlayerSkinOverride + m_hSBTarget);	//m_iPlayerSkinOverride = 9048
}

public void OnMapStart()
{
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_intro.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_explode.wav");
	PrecacheSound(")mvm/sentrybuster/mvm_sentrybuster_spin.wav");
	
	PrecacheModel("models/bots/demo/bot_sentry_buster.mdl");
	
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_01.wav"); 
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_02.wav"); 
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_03.wav"); 
	PrecacheSound("^mvm/sentrybuster/mvm_sentrybuster_step_04.wav");
}

public Action Command_Bust(int client, int argc)
{
	int iClients = 0;
	int iBuildings = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			iClients++;
		}
	}
	
	int iBuilding = -1;
	while((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
	{
		iBuildings++;
	}
	
	if(iClients < 32 && iBuildings > 0)
	{
		ServerCommand("tf_bot_add 1 demoman expert \"Sentry Buster\"");
	}
	
	return Plugin_Handled;
}

public void Event_BusterSpawn(Event hEvent, char[] name, bool dontBroadcast)
{
	int buster = GetClientOfUserId(hEvent.GetInt("userid"));
	
	char strName[MAX_NAME_LENGTH];
	GetClientName(buster, strName, MAX_NAME_LENGTH);
	if(StrContains(strName, "Sentry Buster") != -1 && IsFakeClient(buster))
	{
		CreateTimer(0.5, Timer_DoBuster, hEvent.GetInt("userid"));
	}
}

public Action Timer_DoBuster(Handle timer, int userid)
{
	int buster = GetClientOfUserId(userid);
	if(buster != 0)
	{
		g_bIsBuster[buster] = true;
		
		TF2_BustTarget(buster, FindEntityByClassname(-1, "obj_*"));
	}
}

public void Event_BusterDeath(Event hEvent, char[] name, bool dontBroadcast)
{
	int buster = GetClientOfUserId(hEvent.GetInt("userid"));
	if(g_bIsBuster[buster])
	{
		RequestFrame(DeBuster, hEvent.GetInt("userid"));
	}
}

public void DeBuster(int userid)
{
	int buster = GetClientOfUserId(userid);
	if(buster != 0)
	{
		g_bIsBuster[buster] = false;
		
		SetEntDataEnt2(buster, g_iOffsetSBTarget, -1, true);
		SDKCall(g_hSetMission, buster, NOMISSION, true);
		SetEntDataEnt2(buster, g_iOffsetSBTarget, -1, true);
	
		ServerCommand("tf_bot_kick \"%N\"", buster);
	}
}

stock int TF2_BustTarget(int buster, int target)
{
	/*
	T_TFBot_SentryBuster
	{
		Class Demoman
		Name "Sentry Buster"
		Skill Expert
		Health 2500
		Item "The Ullapool Caber"
		WeaponRestrictions MeleeOnly
		ClassIcon sentry_buster
		Attributes MiniBoss
		CharacterAttributes
		{
			"move speed bonus" 2
			"damage force reduction" 0.5
			"airblast vulnerability multiplier" 0.5
			"override footstep sound set" 7
			"cannot be backstabbed" 1
		}
	}
	*/
	
	TF2_RemovePlayerDisguise(buster);
	TF2_SetPlayerClass(buster, TFClass_DemoMan, false, false);
	TF2_RemoveAllWeapons(buster);
	
	TF2Attrib_SetByName(buster, "max health additive bonus", 2325.0);
	SetEntityHealth(buster, 2500);
	
	TF2Attrib_SetByName(buster, "move speed bonus", 2.0);
	TF2Attrib_SetByName(buster, "damage force reduction", 0.5);
	TF2Attrib_SetByName(buster, "airblast vulnerability multiplier", 0.5);
	TF2Attrib_SetByName(buster, "override footstep sound set", 7.0);
	TF2Attrib_SetByName(buster, "cannot be backstabbed", 1.0);
	
	int weapon = CreateEntityByName("tf_weapon_stickbomb");
	SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", 307);
	SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 25);
	SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 6);
	SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);	
	DispatchSpawn(weapon);
	EquipPlayerWeapon(buster, weapon);
	
	SetVariantString("models/bots/demo/bot_sentry_buster.mdl");
	AcceptEntityInput(buster, "SetCustomModel");
	
	SetEntProp(buster, Prop_Send, "m_bUseClassAnimations", 1);
	SetEntProp(buster, Prop_Send, "m_bIsMiniBoss", 1);
	SetEntProp(buster, Prop_Send, "m_nBotSkill", 3);
	
	SetEntDataEnt2(buster, g_iOffsetSBTarget, target, true);
	SDKCall(g_hSetMission, buster, DESTROY_SENTRIES, true);
	SetEntDataEnt2(buster, g_iOffsetSBTarget, target, true);
	
	g_bIsBuster[buster] = true;
}

stock bool LookupOffset(int &iOffset, const char[] strClass, const char[] strProp)
{
	iOffset = FindSendPropInfo(strClass, strProp);
	if(iOffset <= 0)
	{
		LogMessage("Could not locate offset for %s::%s!", strClass, strProp);
		return false;
	}

	return true;
}