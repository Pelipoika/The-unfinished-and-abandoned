#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <morecolors>
#include <tf2attributes>
#include <steamworks>
#include <dhooks>

#pragma newdecls required

enum ParticleAttachment
{
	PATTACH_ABSORIGIN = 0,			// Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,		// Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,			// Create at a custom origin, but don't follow
	PATTACH_POINT,					// Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW,			// Create on attachment point, and update to follow the entity
	PATTACH_WORLDORIGIN,			// Used for control points that don't attach to an entity
	PATTACH_ROOTBONE_FOLLOW,		// Create at the root bone of the entity, and update to follow
	MAX_PATTACH_TYPES,
};

enum AttributeType
{
	NONE                    = 0,
	REMOVEONDEATH           = (1 << 0),
	AGGRESSIVE              = (1 << 1),
	SUPPRESSFIRE            = (1 << 3),
	DISABLEDODGE            = (1 << 4),
	BECOMESPECTATORONDEATH  = (1 << 5),
	RETAINBUILDINGS         = (1 << 7),
	SPAWNWITHFULLCHARGE     = (1 << 8),
	ALWAYSCRIT              = (1 << 9),
	IGNOREENEMIES           = (1 << 10),
	HOLDFIREUNTILFULLRELOAD = (1 << 11),
	ALWAYSFIREWEAPON        = (1 << 13),
	TELEPORTTOHINT          = (1 << 14),
	MINIBOSS                = (1 << 15),
	USEBOSSHEALTHBAR        = (1 << 16),
	IGNOREFLAG              = (1 << 17),
	AUTOJUMP                = (1 << 18),
	AIRCHARGEONLY           = (1 << 19),
	VACCINATORBULLETS       = (1 << 20),
	VACCINATORBLAST         = (1 << 21),
	VACCINATORFIRE          = (1 << 22),
	BULLETIMMUNE            = (1 << 23),
	BLASTIMMUNE             = (1 << 24),
	FIREIMMUNE              = (1 << 25),
	PARACHUTE               = (1 << 26),
	PROJECTILESHIELD        = (1 << 27),
};

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

enum WeaponRestriction
{
	UNRESTRICTED  = 0,
	MELEEONLY     = (1 << 0),
	PRIMARYONLY   = (1 << 1),
	SECONDARYONLY = (1 << 2),
};

#define BUSTER_SND_LOOP			"mvm/sentrybuster/mvm_sentrybuster_loop.wav"
#define GIANTSCOUT_SND_LOOP		"mvm/giant_scout/giant_scout_loop.wav"
#define GIANTSOLDIER_SND_LOOP	"mvm/giant_soldier/giant_soldier_loop.wav"
#define GIANTPYRO_SND_LOOP		"mvm/giant_pyro/giant_pyro_loop.wav"
#define GIANTDEMOMAN_SND_LOOP	"mvm/giant_demoman/giant_demoman_loop.wav"
#define GIANTHEAVY_SND_LOOP		")mvm/giant_heavy/giant_heavy_loop.wav"
#define BOMB_UPGRADE			"#*mvm/mvm_warning.wav"
#define SOUND_DEPLOY_SMALL		"mvm/mvm_deploy_small.wav"
#define SOUND_DEPLOY_GIANT		"mvm/mvm_deploy_giant.wav"
#define SOUND_TELEPORT_DELIVER	")mvm/mvm_tele_deliver.wav"

Handle g_hHudInfo;

//SDKCalls
Handle g_hSdkEquipWearable;
Handle g_hSDKLeaveSquad;
Handle g_hSDKDispatchParticleEffect;
Handle g_hSDKPlaySpecificSequence;
Handle g_hSDKSetMission;
Handle g_hSDKGetMaxClip;
Handle g_hSDKPickup;
Handle g_hSDKRemoveObject;

//DHooks
Handle g_hIsValidTarget;
Handle g_hCTFPlayerShouldGib;

//Offsets
int g_iOffsetWeaponRestrictions;
int g_iOffsetBotAttribs;
int g_iOffsetAutoJumpMin;
int g_iOffsetAutoJumpMax;
int g_iOffsetMissionBot;
int g_iOffsetSupportLimited;

int g_iCondSourceOffs = -1;
int COND_SOURCE_OFFS = 8;
int COND_SOURCE_SIZE = 20;

//Players bot & player data
int g_iPlayersBot[MAXPLAYERS+1];
int g_iPlayerAttributes[MAXPLAYERS+1];
float g_flAutoJumpMin[MAXPLAYERS+1];
float g_flAutoJumpMax[MAXPLAYERS+1];
float g_flNextJumpTime[MAXPLAYERS+1];
float g_flControlEndTime[MAXPLAYERS+1];
float g_flCooldownEndTime[MAXPLAYERS+1];
bool g_bControllingBot[MAXPLAYERS+1];
bool g_bReloadingBarrage[MAXPLAYERS+1];
bool g_bSkipInventory[MAXPLAYERS+1];
bool g_bCanPlayAsBot[MAXPLAYERS+1];
bool g_bRandomlyChooseBot[MAXPLAYERS+1];
bool g_bBlockRagdoll;	//Stolen from Stop that Tank

//Controlled bot data
bool g_bIsControlled[MAXPLAYERS+1];
int g_iController[MAXPLAYERS+1];

//Bot data
bool g_bIsSentryBuster[MAXPLAYERS+1];
bool g_bIsGateBot[MAXPLAYERS+1];
bool g_bDeploying[MAXPLAYERS+1];
float g_flSpawnTime[MAXPLAYERS+1];

//Is map Mannhattan
bool g_bIsMannhattan = false;

//Bomb data
bool g_bHasBomb[MAXPLAYERS+1];
int g_iFlagCarrierUpgradeLevel[MAXPLAYERS+1];
float g_flBombDeployTime[MAXPLAYERS+1];
float g_flNextBombUpgradeTime[MAXPLAYERS+1];

//TODO:
//Add cvars
//Copy primary ammo
//Spawn leave timer still runs while stunned in spawn
//Start upgarding bomb after exiting spawn
//+map  workshop/601600702

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[TF2] MvM Bot Control",
	author = "Pelipoika",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("bot-control");
	
	//This call is used to equip items on clients
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//tf_wearable
	if ((g_hSdkEquipWearable = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFBot::EquipWearable offset!"); 

	//This call will force a medicbot to ignore its previous patient
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFBot::LeaveSquad");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hSDKLeaveSquad = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFBot::LeaveSquad signature!"); 

	//This call is used to set the deploy animation on the robots with the bomb
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//Sequence name
	if ((g_hSDKPlaySpecificSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFPlayer::PlaySpecificSequence signature!");

	//This call is used to remove an objects owner
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//CBaseObject
	if ((g_hSDKRemoveObject = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed To create SDKCall for CTFPlayer::RemoveObject signature");

	//This call is used to make sentry busters behave nicely
	StartPrepSDKCall(SDKCall_Player); 
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFBot::SetMission");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//MissionType
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//StartSound
	if ((g_hSDKSetMission = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFBot::SetMission signature!"); 

	//This call will play a particle effect
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "DispatchParticleEffect");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszParticleName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//iAttachType
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//pEntity
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszAttachmentName
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//bResetAllParticlesOnEntity 
	if ((g_hSDKDispatchParticleEffect = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for DispatchParticleEffect signature!");

	//This call gets the maximum clip 1 of a weapon
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBase::GetMaxClip1");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Clip
	if ((g_hSDKGetMaxClip = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFWeaponBase::GetMaxClip1 offset!");
	
	//This call forces a player to pickup the intel
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CCaptureFlag::PickUp");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);	//CCaptureFlag
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//silent pickup? or maybe it doesnt exist im not sure.
	if ((g_hSDKPickup = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CCaptureFlag::PickUp offset!");

	if(LookupOffset(g_iOffsetWeaponRestrictions, "CTFPlayer", "m_iPlayerSkinOverride"))	g_iOffsetWeaponRestrictions += GameConfGetOffset(hConf, "m_nWeaponRestrict");
	if(LookupOffset(g_iOffsetBotAttribs,         "CTFPlayer", "m_iPlayerSkinOverride"))	g_iOffsetBotAttribs += GameConfGetOffset(hConf, "m_nBotAttrs");	
	if(LookupOffset(g_iOffsetAutoJumpMin,        "CTFPlayer", "m_iPlayerSkinOverride"))	g_iOffsetAutoJumpMin += GameConfGetOffset(hConf, "m_flAutoJumpMin");
	if(LookupOffset(g_iOffsetAutoJumpMax,        "CTFPlayer", "m_iPlayerSkinOverride"))	g_iOffsetAutoJumpMax += GameConfGetOffset(hConf, "m_flAutoJumpMax");
	if(LookupOffset(g_iOffsetMissionBot,         "CTFPlayer", "m_nCurrency"))			g_iOffsetMissionBot -= GameConfGetOffset(hConf, "m_bMissionBot");
	if(LookupOffset(g_iOffsetSupportLimited,     "CTFPlayer", "m_nCurrency"))			g_iOffsetSupportLimited -= GameConfGetOffset(hConf, "m_bSupportLimited");

	int iOffset = GameConfGetOffset(hConf, "CTFPlayer::ShouldGib");
	if(iOffset == -1) SetFailState("Failed to get offset of CTFBot::ShouldGib");
	g_hCTFPlayerShouldGib = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CTFPlayer_ShouldGib);
	DHookAddParam(g_hCTFPlayerShouldGib, HookParamType_ObjectPtr, -1, DHookPass_ByRef);
	
	iOffset = GameConfGetOffset(hConf, "CTFPlayer::IsValidObserverTarget");	
	if(iOffset == -1) SetFailState("Failed to get offset of CTFPlayer::IsValidObserverTarget");
	g_hIsValidTarget = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, IsValidTarget);
	DHookAddParam(g_hIsValidTarget, HookParamType_CBaseEntity);
	
	//Credits to Psychonic
	int offset = FindSendPropInfo("CTFPlayer", "m_Shared");
	if (offset == -1) SetFailState("Cannot find m_Shared on CTFPlayer.");
	g_iCondSourceOffs = offset + COND_SOURCE_OFFS;
	
	delete hConf;
	
	g_hHudInfo = CreateHudSynchronizer();
	
	SteamWorks_SetGameDescription(":: Bot Control ::");

	AddCommandListener(Listener_Voice,      "voicemenu");
	AddCommandListener(Listener_Jointeam,   "jointeam");
	AddCommandListener(Listener_Block,      "autoteam");
	AddCommandListener(Listener_Block,      "kill");
	AddCommandListener(Listener_Block,      "explode");
	AddCommandListener(Listener_Build,      "build");
	AddCommandListener(Listener_ChoseHuman, "tournament_player_readystate");

	HookEvent("teamplay_flag_event",  Event_FlagEvent);
	HookEvent("player_death",         Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn",         Event_PlayerSpawn);
	HookEvent("player_team",          Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_builtobject",   Event_BuildObject);
	HookEvent("teamplay_round_start", Event_ResetBots);
	HookEvent("mvm_wave_complete",    Event_ResetBots);
	HookEvent("player_sapped_object", Event_SappedObject);

	RegConsoleCmd("sm_joinblue",   Command_ToggleRandomPicker);
	RegConsoleCmd("sm_joinblu",    Command_ToggleRandomPicker);
	RegConsoleCmd("sm_joinbrobot", Command_ToggleRandomPicker);
	RegConsoleCmd("sm_robot",      Command_ToggleRandomPicker);
	RegConsoleCmd("sm_randombot",  Command_ToggleRandomPicker);

	for(int client = 1; client <= MaxClients; client++)
		if(IsClientInGame(client))
			OnClientPutInServer(client);
}

/*
public void TF2_OnWaitingForPlayersEnd()
{
	if(!TF2_IsMvM())
		SetFailState("[Bot Control] Disabling for non mvm map");
}*/

public Action Command_ToggleRandomPicker(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		int iRobotCount = 0;
	
		for(int i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && !IsFakeClient(i))
				if(TF2_GetClientTeam(i) == TFTeam_Blue || TF2_GetClientTeam(i) == TFTeam_Spectator)
					iRobotCount++;
		
		if(iRobotCount < 4 || CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT, true))
		{
			if(!g_bRandomlyChooseBot[client])
			{
				if(TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetClientTeam(client) != TFTeam_Blue)
					TF2_ChangeClientTeam(client, TFTeam_Spectator);
				
				CPrintToChat(client, "{arcana}We will now automatically choose a bot for you when one is available! Type !randombot again to stop playing as random bots");
				g_bRandomlyChooseBot[client] = true;
			}
			else
			{
				CPrintToChat(client, "{arcana}Random bot choosing is now {red}OFF");
				g_bRandomlyChooseBot[client] = false;
			}
		}
		else
			CPrintToChat(client, "{red}Robots are full.");
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	char strMap[32];
	GetCurrentMap(strMap, sizeof(strMap));
	if (StrEqual(strMap, "mvm_mannhattan"))
		g_bIsMannhattan = true;

	PrecacheSound(SOUND_DEPLOY_SMALL);
	PrecacheSound(SOUND_DEPLOY_GIANT);
	PrecacheSound(BOMB_UPGRADE);
	PrecacheSound(BUSTER_SND_LOOP);
	PrecacheSound(SOUND_TELEPORT_DELIVER);
}

public void OnClientPutInServer(int client)
{
	g_iPlayersBot[client] = -1;
	g_bControllingBot[client] = false;	
	g_bIsControlled[client] = false;
	g_iController[client] = -1;
	g_bIsGateBot[client] = false;
	g_bIsSentryBuster[client] = false;
	g_bSkipInventory[client] = false;
	g_bCanPlayAsBot[client] = true;
	
	g_flCooldownEndTime[client] = -1.0;
	g_flControlEndTime[client] = -1.0;
	g_flSpawnTime[client] = -1.0;
	
	g_flNextJumpTime[client] = 0.0;
	g_flAutoJumpMin[client] = 0.0;
	g_flAutoJumpMax[client] = 0.0;
	g_bReloadingBarrage[client] = false;
	g_iPlayerAttributes[client] = 0;
	
	g_iFlagCarrierUpgradeLevel[client] = 0;
	g_flNextBombUpgradeTime[client] = -1.0;
	g_bHasBomb[client] = false;
	g_bDeploying[client] = false;
	g_flBombDeployTime[client] = -1.0;
	
	DHookEntity(g_hCTFPlayerShouldGib, true, client);
	DHookEntity(g_hIsValidTarget, true, client);
	
	SDKHook(client, SDKHook_SetTransmit, Hook_SpyTransmit);
}

public MRESReturn IsValidTarget(int pThis, Handle hReturn, Handle hParams)
{
	if(GameRules_GetProp("m_bPlayingMannVsMachine") && !DHookIsNullParam(hParams, 1))
	{
		int iTarget = DHookGetParam(hParams, 1);
		if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(pThis) && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && !IsFakeClient(pThis))
		{
			if(g_bIsControlled[iTarget])
			{
				DHookSetReturn(hReturn, false);			
				return MRES_Supercede;
			}
		}
	}

	return MRES_Ignored;
}

public MRESReturn CTFPlayer_ShouldGib(int pThis, Handle hReturn, Handle hParams)
{
	if(GameRules_GetProp("m_bPlayingMannVsMachine") && !DHookIsNullParam(hParams, 1) && TF2_GetClientTeam(pThis) == TFTeam_Blue)
	{
		bool is_miniboss = view_as<bool>(GetEntProp(pThis, Prop_Send, "m_bIsMiniBoss"));
		float m_flModelScale = GetEntPropFloat(pThis, Prop_Send, "m_flModelScale");
		
		if(is_miniboss || m_flModelScale > 1.0)
		{
			DHookSetReturn(hReturn, true);
			return MRES_Supercede;
		}
		
		bool is_engie  = (TF2_GetPlayerClass(pThis) == TFClass_Engineer);
		bool is_medic  = (TF2_GetPlayerClass(pThis) == TFClass_Medic);
		bool is_sniper = (TF2_GetPlayerClass(pThis) == TFClass_Sniper);
		bool is_spy    = (TF2_GetPlayerClass(pThis) == TFClass_Spy);
		
		if (is_engie || is_medic || is_sniper || is_spy) {
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public void OnClientDisconnect(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		TF2_RestoreBot(client);
		g_bRandomlyChooseBot[client] = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "tf_wearable"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnWearableSpawnPost);
	}
	else if(StrEqual(classname, "item_currencypack_custom"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnCurrencySpawnPost);
	}
	else if(StrEqual(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnSpawnStartTouch);
		SDKHook(entity, SDKHook_EndTouch, OnSpawnEndTouch);
	}
	else if(StrEqual(classname, "func_capturezone"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnHatchStartTouch);
		SDKHook(entity, SDKHook_EndTouch, OnHatchEndTouch);
	}
	else if(StrEqual(classname, "item_teamflag"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnFlagTouch);
	}
	else if(g_bBlockRagdoll && StrEqual(classname, "tf_ragdoll"))
	{
		AcceptEntityInput(entity, "Kill");
		g_bBlockRagdoll = false;
	}
	else if(StrEqual(classname, "obj_teleporter"))
	{
		SDKHook(entity, SDKHook_SetTransmit, Hook_TeleporterTransmit);
		SDKHook(entity, SDKHook_OnTakeDamage, Hook_TeleporterTakeDamage);
	}
	
	if(g_bIsMannhattan)
	{
		if(StrEqual(classname, "trigger_multiple") || StrEqual(classname, "filter_multi") 
		|| StrEqual(classname, "trigger_timer_door"))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
		}
	}
}

public void OnSpawnPost(int trigger)
{
	char strName[64];
	GetEntPropString(trigger, Prop_Data, "m_iName", strName, 64);
	
	if(StrEqual(strName, "gate1_door_alarm") || StrEqual(strName, "gate2_door_alarm") 
	|| StrEqual(strName, "gate1_door_trigger") || StrEqual(strName, "gate2_door_trigger"))
	{
		SetEntPropEnt(trigger, Prop_Data, "m_hFilter", -1);
		SDKHook(trigger, SDKHook_StartTouch, OnTriggerTouch);
		SDKHook(trigger, SDKHook_Touch, OnTriggerTouch);
		PrintToServer("-> Hooked %s", strName);
	}
	else if(StrEqual(strName, "filter_blue_bombhat"))
	{
		AcceptEntityInput(trigger, "Kill");
		PrintToServer("-> Killed %s", strName);
	}
}

public Action Event_SappedObject(Event event, const char[] name, bool dontBroadcast)
{
	int spy = GetClientOfUserId(event.GetInt("userid"));
	TFObjectType iObject = view_as<TFObjectType>(event.GetInt("object"));
	int iSapper = event.GetInt("sapperid");
	
	if(iObject == TFObject_Teleporter && spy > 0 && spy <= MaxClients && IsClientInGame(spy) && TF2_GetClientTeam(spy) == TFTeam_Blue)
	{
		AcceptEntityInput(iSapper, "Kill");
	}
}

public Action OnFlagTouch(int iEntity, int iOther)
{
	if(iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && !IsFakeClient(iOther) && IsPlayerAlive(iOther) 
	&& g_bControllingBot[iOther] && !g_bIsGateBot[iOther] && !g_bIsSentryBuster[iOther] && !g_bHasBomb[iOther] && TF2Attrib_GetByName(iOther, "cannot pick up intelligence") == Address_Null)
	{
	//	TF2_PickupFlag(iOther, iEntity);
	}
}

public Action OnHatchStartTouch(int iEntity, int client)
{
	if(client > 0 && client <= MaxClients && !IsFakeClient(client) && !g_bDeploying[client] && g_bHasBomb[client])
	{
		if(TF2_IsPlayerInCondition(client, TFCond_Charging)) TF2_RemoveCondition(client, TFCond_Charging);
		if(TF2_IsPlayerInCondition(client, TFCond_Taunting)) TF2_RemoveCondition(client, TFCond_Taunting);

		if(TF2_IsGiant(client))
			EmitSoundToAll(SOUND_DEPLOY_GIANT);
		else
			EmitSoundToAll(SOUND_DEPLOY_SMALL);
		
		BroadcastSoundToTeam(TFTeam_Spectator, "Announcer.MVM_Bomb_Alert_Deploying");
		
		SDKCall(g_hSDKPlaySpecificSequence, client, "primary_deploybomb");			
		RequestFrame(DisableAnim, GetClientUserId(client));	

		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		g_flBombDeployTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_deploying_bomb_time")) + 0.5;
		g_bDeploying[client] = true;
	}
}

public void DisableAnim(int userid)
{
	static int iCount = 0;

	int client = GetClientOfUserId(userid)
	if(client > 0)
	{
		if(iCount > 6)
		{
			float vecClientPos[3], vecTargetPos[3];
			GetClientAbsOrigin(client, vecClientPos);
			
			int i = -1;	
			while ((i = FindEntityByClassname(i, "func_breakable")) != -1)
			{
				char strName[32];
				GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName));
				
				if(StrEqual(strName, "cap_hatch_glasswindow"))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecTargetPos);
					
					float v[3], ang[3];
					SubtractVectors(vecTargetPos, vecClientPos, v);
					NormalizeVector(v, v);
					GetVectorAngles(v, ang);
					
					ang[0] = 0.0;
					
					SetVariantString("1");
					AcceptEntityInput(client, "SetCustomModelRotates");
					
					SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
					
					char strVec[16];
					Format(strVec, sizeof(strVec), "0 %f 0", ang[1]);
					
					SetVariantString(strVec);
					AcceptEntityInput(client, "SetCustomModelRotation");
					
					break;
				}
			}

			iCount = 0;
		}
		else
		{
			SDKCall(g_hSDKPlaySpecificSequence, client, "primary_deploybomb");			
			RequestFrame(DisableAnim, userid);
			iCount++;
		}
	}
}

public Action OnHatchEndTouch(int iEntity, int client)
{
	if(client > 0 && client <= MaxClients && !IsFakeClient(client) && g_bHasBomb[client])
	{
		SetVariantString("1");
		AcceptEntityInput(client, "SetCustomModelRotates");
		
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		g_flBombDeployTime[client] = -1.0;
		g_bDeploying[client] = false;
	}
}

public Action OnSpawnStartTouch(int iEntity, int iOther)
{
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");

	if(iTeam == view_as<int>(TFTeam_Blue) && iOther > 0 && iOther <= MaxClients && GetClientTeam(iOther) == iTeam && !IsFakeClient(iOther))
	{
		if(!TF2_IsPlayerInCondition(iOther, TFCond_UberchargedHidden))
		{	
			TF2_AddCondition(iOther, TFCond_UberchargedHidden);
			TF2_AddCondition(iOther, TFCond_Ubercharged);
			TF2_AddCondition(iOther, TFCond_UberchargeFading);
			
			g_flControlEndTime[iOther] = GetGameTime() + 35.0;
		}
	}
}

public Action OnSpawnEndTouch(int iEntity, int iOther)
{
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum");

	if(iTeam == view_as<int>(TFTeam_Blue) && iOther > 0 && iOther <= MaxClients && GetClientTeam(iOther) == iTeam && !IsFakeClient(iOther))
	{
		TF2_RemoveCondition(iOther, TFCond_UberchargedHidden);
		TF2_RemoveCondition(iOther, TFCond_Ubercharged);
		TF2_RemoveCondition(iOther, TFCond_UberchargeFading);
		TF2_AddCondition(iOther, TFCond_UberchargedHidden, 1.0);
		TF2_AddCondition(iOther, TFCond_Ubercharged, 1.0);
		TF2_AddCondition(iOther, TFCond_UberchargeFading, 1.0);
	}
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	if(cond == view_as<TFCond>(114))
	{
		TF2_RemoveCondition(client, view_as<TFCond>(114));
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if(cond == TFCond_UberchargedHidden)
	{
		g_flControlEndTime[client] = -1.0;
	}
}

public void OnWearableSpawnPost(int iWearable)
{
	RequestFrame(OnWearableSpawnPostPost, EntIndexToEntRef(iWearable));
}

public void OnWearableSpawnPostPost(int iRef)
{
	int iWearable = EntRefToEntIndex(iRef);
	if(iWearable != INVALID_ENT_REFERENCE)
	{
		int iDefIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");

		switch(iDefIndex)
		{
			case 1057, 1058, 1059, 1060, 1061, 1062, 1063, 1064, 1065:
			{
				int iOwner = GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity");
				if(iOwner > 0 && iOwner <= MaxClients)
				{			
					g_bIsGateBot[iOwner] = true;
				}
			}
		}
	}
}

public void OnCurrencySpawnPost(int iCurrency)
{
	int iOwner = GetEntPropEnt(iCurrency, Prop_Send, "m_hOwnerEntity");	//The bot who dropped the money
	if(iOwner > 0 && iOwner <= MaxClients && g_bIsControlled[iOwner])
	{
		int iController = GetClientOfUserId(g_iController[iOwner]);	//The bot's controller player
		int iBot = GetClientOfUserId(g_iPlayersBot[iController]);	//The bot of the controller
		
		if(iBot > 0 && IsFakeClient(iBot) && iController > 0 && iBot == iOwner && g_bControllingBot[iController])
		{
			float flPos[3];
			GetClientAbsOrigin(iController, flPos);
			flPos[2] += 32.0;
			
			TeleportEntity(iCurrency, flPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action OnTriggerTouch(int iEntity, int iOther)
{
	if(iOther > 0 && iOther <= MaxClients && IsPlayerAlive(iOther) && !g_bIsGateBot[iOther])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
		return Plugin_Continue;
	
	if(g_bControllingBot[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 100.0);
		SetEntProp(client, Prop_Send, "m_nNumHealers", 0);	//All your medics are belong to me!
		
		int iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(iActiveWeapon))
		{
			if(TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) && buttons & IN_ATTACK)
			{
				SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.25);
			}

			if(g_iPlayerAttributes[client] & view_as<int>(AUTOJUMP))
			{
				if(g_flNextJumpTime[client] <= GetGameTime())
				{
					g_flNextJumpTime[client] = GetGameTime() + GetRandomFloat(g_flAutoJumpMin[client], g_flAutoJumpMax[client]);
					
					buttons |= IN_JUMP;
					SDKCall(g_hSDKDispatchParticleEffect, "rocketjump_smoke", PATTACH_POINT_FOLLOW, client, "foot_L", 0);
					SDKCall(g_hSDKDispatchParticleEffect, "rocketjump_smoke", PATTACH_POINT_FOLLOW, client, "foot_R", 0);
					
					return Plugin_Changed;
				}
				
				if(TF2_GetPlayerClass(client) == TFClass_DemoMan && g_iPlayerAttributes[client] & view_as<int>(AIRCHARGEONLY))
				{
					if(GetEntProp(client, Prop_Send, "m_bJumping"))
					{
						float flVelocity[3];
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
						
						if(flVelocity[2] <= 0.0)
						{
							buttons |= IN_ATTACK2;
						}
					}
				}
			}
			
			if(g_iPlayerAttributes[client] & view_as<int>(HOLDFIREUNTILFULLRELOAD))
			{
				int iClip1 = GetEntProp(iActiveWeapon, Prop_Send, "m_iClip1");
				
				if(iClip1 <= 0)
				{
					g_bReloadingBarrage[client] = true;
					
					SetHudTextParams(-1.0, -0.65, 0.75, 255, 0, 0, 255, 0, 0.0, 0.0, 0.0);
					ShowHudText(client, -1, "RELOADING BARRAGE!");
				}
				else if(g_bReloadingBarrage[client])
				{
					int iMaxClip1 = SDKCall(g_hSDKGetMaxClip, iActiveWeapon);
					
					if(iClip1 < iMaxClip1 && buttons & IN_ATTACK)
					{
						SetHudTextParams(-1.0, -0.65, 0.25, 255, 0, 0, 255, 0, 0.0, 0.0, 0.0);
						ShowHudText(client, -1, "CANNOT FIRE UNTIL FULLY RELOADED! LET GO OF LEFT MOUSE BUTTON");

						SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.1);
					}
					
					if(iClip1 >= iMaxClip1)
					{
						SetHudTextParams(-1.0, -0.65, 1.75, 100, 255, 100, 255, 0, 0.0, 0.0, 0.0);
						ShowHudText(client, -1, "READY TO FIRE!");
					
						g_bReloadingBarrage[client] = false;
					}
				}
			}
		}
	
		int iBot = GetClientOfUserId(g_iPlayersBot[client]);
		if(iBot > 0 && IsFakeClient(iBot))
		{
			SetHudTextParams(1.0, 0.0, 0.1, 88, 133, 162, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "Playing as %N", iBot);
			
			if(TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden))
			{
				if(g_flControlEndTime[client] <= GetGameTime())
				{
					CPrintToChat(client, "{red}You have lost control of {blue}%N{red} and received a 30 second cooldown from playing as a robot for staying in spawn too long", iBot);
					
					g_bControllingBot[client] = false;
					g_bRandomlyChooseBot[client] = false;
					
					TF2_ChangeClientTeam(client, TFTeam_Spectator);
					TF2_RestoreBot(client);
					
					g_flCooldownEndTime[client] = GetGameTime() + 30.0;
					
					return Plugin_Continue;
				}
				else if(g_flControlEndTime[client] > GetGameTime())
				{
					float flTimeLeft = g_flControlEndTime[client] - GetGameTime();
					
					if(flTimeLeft <= 15.0)
					{
						SetHudTextParams(-1.0, -0.8, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
						ShowSyncHudText(client, g_hHudInfo, "You have %.0f seconds to leave spawn or you will lose control of your bot", flTimeLeft);
					}
				}
			}
			
			if(g_bIsSentryBuster[client] && GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1)
			{
				float flPos[3], flAng[3];
				GetClientAbsOrigin(client, flPos);
				GetClientEyeAngles(client, flAng);
			
				// Disable the use of the sentry buster's caber
				int iMelee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
				if(iMelee > MaxClients) 
					SetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack", 999999.0);

				if(buttons & IN_ATTACK || TF2_IsPlayerInCondition(client, TFCond_Taunting))
				{
					TF2_DetonateBuster(client);					
					TF2_ClearBot(client);
					TF2_ChangeClientTeam(client, TFTeam_Spectator);
				}
				
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientTeam(i) != GetClientTeam(client) && i != client && GetEntProp(i, Prop_Send, "m_bCarryingObject"))
					{
						float iPos[3];
						GetClientAbsOrigin(i, iPos);
						
						float flDistance = GetVectorDistance(flPos, iPos);
						
						if(flDistance <= 100.0)
						{
							TF2_DetonateBuster(client);							
							TF2_ClearBot(client);
							TF2_ChangeClientTeam(client, TFTeam_Spectator);
						}
					}
				}
			}
			else
				SetEntProp(iBot, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iHealth"));
		}
		
		if(g_bHasBomb[client])
		{
			if(g_bDeploying[client])
			{
				if(g_flBombDeployTime[client] <= GetGameTime())
				{
					if(iBot > 0 && IsFakeClient(iBot))
						CPrintToChatAll("{blue}%N{default} playing as {blue}%N{default} deployed the {unique}BOMB{default} with {red}%i HP!", client, iBot, GetEntProp(client, Prop_Send, "m_iHealth"));
					else
						CPrintToChatAll("{blue}%N{default} deployed the {unique}BOMB{default} with {red}%i HP!", client, GetEntProp(client, Prop_Send, "m_iHealth"));
					
					g_bBlockRagdoll = true;
					g_bHasBomb[client] = false;
					g_bDeploying[client] = false;
					
					TF2_RobotsWin();
					
					g_flCooldownEndTime[client] = GetGameTime() + 10.0;
					
					BroadcastSoundToTeam(TFTeam_Spectator, "Announcer.MVM_Robots_Planted");
				}
				
				buttons &= ~IN_JUMP;
				buttons &= ~IN_ATTACK;
				buttons &= ~IN_ATTACK2;
				buttons &= ~IN_ATTACK3;
			
				vel[0] = 0.0;
				vel[1] = 0.0;
				vel[2] = 0.0;
				
				return Plugin_Changed;
			}
		
			if(!TF2_IsPlayerInCondition(client, TFCond_Taunting) && !TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) && !g_bDeploying[client])
			{
				buttons &= ~IN_JUMP;
			
				if(g_iFlagCarrierUpgradeLevel[client] > 0)
				{
					float pPos[3];
					GetClientAbsOrigin(client, pPos);
					
					for(int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && GetClientTeam(i) == GetClientTeam(client) && i != client && g_iFlagCarrierUpgradeLevel[client] >= 1)
						{
							float iPos[3];
							GetClientAbsOrigin(i, iPos);
							
							float flDistance = GetVectorDistance(pPos, iPos);
							
							if(flDistance <= 450.0)
							{
								TF2_AddCondition(i, TFCond_DefenseBuffNoCritBlock, 0.125);
							}
						}
					}
				}
			
				if(g_flNextBombUpgradeTime[client] <= GetGameTime() && g_iFlagCarrierUpgradeLevel[client] < 3 && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)	//Time to upgrade
				{
					FakeClientCommand(client, "taunt");
					
					if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
					{
						g_iFlagCarrierUpgradeLevel[client]++;
						
						switch(g_iFlagCarrierUpgradeLevel[client])
						{
							case 1: 
							{
								g_flNextBombUpgradeTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_2nd_upgrade")); 
								TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, TFCondDuration_Infinite);
								
								SDKCall(g_hSDKDispatchParticleEffect, "mvm_levelup1", PATTACH_POINT_FOLLOW, client, "head", 0);
							}
							case 2: 
							{
								g_flNextBombUpgradeTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_3rd_upgrade"));
								
								Address pRegen = TF2Attrib_GetByName(client, "health regen");
								float flRegen = 0.0;
								if(pRegen != Address_Null)
									flRegen = TF2Attrib_GetValue(pRegen);
								
								TF2Attrib_SetByName(client, "health regen", flRegen + 45.0);
								SDKCall(g_hSDKDispatchParticleEffect, "mvm_levelup2", PATTACH_POINT_FOLLOW, client, "head", 0);
							}
							case 3: 
							{
								TF2_AddCondition(client, TFCond_CritOnWin, TFCondDuration_Infinite);
								SDKCall(g_hSDKDispatchParticleEffect, "mvm_levelup3", PATTACH_POINT_FOLLOW, client, "head", 0);
							}
						}
						
						UpdateBombHud(GetClientUserId(client));
						EmitSoundToAll(BOMB_UPGRADE, SOUND_FROM_WORLD, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_NOFLAGS, 0.500, SNDPITCH_NORMAL);
					}
				}
			}
		}
	}
	else
	{
		if(g_bRandomlyChooseBot[client] && TF2_GetClientTeam(client) == TFTeam_Spectator && !g_bControllingBot[client] && g_bCanPlayAsBot[client] && g_flCooldownEndTime[client] <= GetGameTime())
		{
			int iPlayerarray[MAXPLAYERS+1];
			int iPlayercount;
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsFakeClient(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue && !g_bIsControlled[i])
				{
					if(!TF2_IsPlayerInCondition(i, TFCond_MVMBotRadiowave) && !TF2_IsPlayerInCondition(i, TFCond_Taunting))
					{
						if(GetEntProp(i, Prop_Data, "m_takedamage") != 0)
						{
							float flSpawnedAgo = GetGameTime() - g_flSpawnTime[i];
							if(flSpawnedAgo >= 1.5) //Allow the bots some time to spawn
							{
								iPlayerarray[iPlayercount] = i;
								iPlayercount++;
							}
						}
					}
				}
			}
			
			if(iPlayercount)
			{
				int target = iPlayerarray[GetRandomInt(0, iPlayercount-1)];
				
				TF2_MirrorPlayer(target, client);
				CPrintToChatAll("{blue}%N{default} was auto-assigned to play as {blue}%N", client, target);
			}
		}
		
		int iObserved = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
		if(TF2_ObservedIsValidClient(client))
		{
			SetHudTextParams(1.0, 0.0, 0.1, 126, 126, 126, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "Call for MEDIC! to play as %N", iObserved);
		}
		else if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && IsFakeClient(iObserved))
		{
			char strReason[PLATFORM_MAX_PATH];
			TF2_ObservedIsNotValidReason(client, strReason, PLATFORM_MAX_PATH);
			Format(strReason, PLATFORM_MAX_PATH, "Cannot play as %N beacause %s", iObserved, strReason);
		
			if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 4 || GetEntProp(client, Prop_Send, "m_iObserverMode") == 5)
			{
				SetHudTextParams(1.0, 0.0, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(client, g_hHudInfo, "%s", strReason);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_FlagEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int eventtype = event.GetInt("eventtype");
	
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && eventtype != TF_FLAGEVENT_DEFENDED)
	{
		if(eventtype == TF_FLAGEVENT_PICKEDUP)
		{		
			g_bHasBomb[client] = true;
			
			if(!IsFakeClient(client))
			{
				if(TF2_IsGiant(client))	//Giants have max flag level and cant receive buffs
				{
					g_iFlagCarrierUpgradeLevel[client] = 4;
					g_flNextBombUpgradeTime[client] = GetGameTime();
				}
				else if(g_iFlagCarrierUpgradeLevel[client] == 0)	//Start upgrading from the beginning
				{
					g_flNextBombUpgradeTime[client] = GetGameTime() + GetConVarFloat(FindConVar("tf_mvm_bot_flag_carrier_interval_to_1st_upgrade")); 
				}
				else if(!TF2_IsGiant(client))	//Add existing buffs
				{
					if(g_iFlagCarrierUpgradeLevel[client] >= 1) TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, TFCondDuration_Infinite);
					if(g_iFlagCarrierUpgradeLevel[client] == 3) TF2_AddCondition(client, TFCond_CritOnWin, TFCondDuration_Infinite);
				}
				
				RequestFrame(UpdateBombHud, GetClientUserId(client));
			}
		}
		else
		{
			if(!IsFakeClient(client))
			{
				TF2_RemoveCondition(client, TFCond_DefenseBuffNoCritBlock);
				TF2_RemoveCondition(client, TFCond_CritOnWin);
				
				Address pRegen = TF2Attrib_GetByName(client, "health regen");
				float flRegen = 0.0;
				if(pRegen != Address_Null)
				{
					flRegen = TF2Attrib_GetValue(pRegen);
					
					if(flRegen > 45.0)
					{
						TF2Attrib_SetValue(pRegen, flRegen - 45.0);
						TF2Attrib_ClearCache(client);
					}
					else
					{
						TF2Attrib_RemoveByName(client, "health regen");
					}
				}
			}
			
			g_bHasBomb[client] = false;
			g_iFlagCarrierUpgradeLevel[client] = 0;
			g_flNextBombUpgradeTime[client] = GetGameTime();
		}
	}
}

public void UpdateBombHud(int userid)
{
	int client = GetClientOfUserId(userid)
	if(client > 0)
	{
		int iResource = FindEntityByClassname(-1, "tf_objective_resource");
		SetEntProp(iResource, Prop_Send, "m_nFlagCarrierUpgradeLevel", g_iFlagCarrierUpgradeLevel[client]);
		SetEntPropFloat(iResource, Prop_Send, "m_flMvMBaseBombUpgradeTime", GetGameTime());
		SetEntPropFloat(iResource, Prop_Send, "m_flMvMNextBombUpgradeTime", g_flNextBombUpgradeTime[client]);	
	}
}

public Action Event_ResetBots(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(!IsFakeClient(client))
			{
				if(g_bControllingBot[client])
				{
					TF2_ClearBot(client, true);
					TF2_ChangeClientTeam(client, TFTeam_Spectator);
				}
			}
			
			OnClientPutInServer(client);
		}
	}
}

float flLastTeleSoundTime;

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		g_flSpawnTime[client] = GetGameTime();
	
		if(!IsFakeClient(client))
		{
			if(g_bSkipInventory[client])
			{
				TF2_RestoreBot(client);
				TF2_ChangeClientTeam(client, TFTeam_Spectator);

				g_bSkipInventory[client] = false;
			}
		}
		
		if(TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetPlayerClass(client) != TFClass_Spy && IsFakeClient(client))
		{
			int iBotAttrs = GetEntData(client, g_iOffsetBotAttribs);
			if(!(iBotAttrs & view_as<int>(TELEPORTTOHINT)))
			{	
				int iTele = TF2_FindTeleNearestToBombHole();
				if(IsValidEntity(iTele))
				{
					float flPos[3];
					GetEntPropVector(iTele, Prop_Send, "m_vecOrigin", flPos);
					
					flPos[2] += 15.0;
					//Bots need to be teleported to player teleporters
					//Players need to be teleported to all teleporters
					
					TF2_RemoveCondition(client, TFCond_UberchargedHidden);
					TF2_AddCondition(client, TFCond_UberchargedCanteen, 5.0);
					TF2_AddCondition(client, TFCond_UberchargeFading, 5.0);
				
					int iBuilder = EntRefToEntIndex(GetEntPropEnt(iTele, Prop_Send, "m_hBuilder"));
					if(iBuilder > 0 && iBuilder <= MaxClients && IsClientInGame(iBuilder) && IsFakeClient(client) && !IsFakeClient(iBuilder))
					{
						TeleportEntity(client, flPos, NULL_VECTOR, NULL_VECTOR);
						
						//Anti ear rape
						float flSpawnedAgo = GetGameTime() - flLastTeleSoundTime;
						if(flSpawnedAgo >= 0.5)
						{
							EmitSoundToAll(SOUND_TELEPORT_DELIVER, iTele, SNDCHAN_STATIC, 150, _, 1.0);
						}
						
						flLastTeleSoundTime = GetGameTime();
					}
				}
			}
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	SetEntProp(client, Prop_Send, "m_bUseBossHealthBar", 0);
	g_bIsGateBot[client] = false;
	TF2_StopSounds(client);
	
	if(!IsFakeClient(client) && g_bControllingBot[client])
	{
		int iBot = GetClientOfUserId(g_iPlayersBot[client]);
		
		if(iBot > 0 && IsFakeClient(iBot))
		{
			if(g_bIsSentryBuster[client])
			{
				TF2_DetonateBuster(client);
				TF2_ClearBot(client);
				TF2_ChangeClientTeam(client, TFTeam_Spectator);
			}
			else
			{
				TF2_KillBot(client);
			}
		}
	}
	
	if(IsFakeClient(client) && g_bIsControlled[client])
	{
		dontBroadcast = true;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam iTeam = view_as<TFTeam>(event.GetInt("team"));
	TFTeam iOldTeam = view_as<TFTeam>(event.GetInt("oldteam"));
	
	if(iTeam == TFTeam_Spectator)
	{
		if(g_bControllingBot[client])
		{
			TF2_RestoreBot(client);

			OnClientPutInServer(client);
			
			g_flCooldownEndTime[client] = GetGameTime() + 10.0;
		}
	}
	
	//Don't show joining spectator from blue team or joining blue team
	if(!IsFakeClient(client) && iOldTeam == TFTeam_Blue || iTeam == TFTeam_Blue)
	{
		event.SetInt("silent", 1);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_BuildObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsFakeClient(client) && g_bControllingBot[client] && TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		TFObjectType TFObject = view_as<TFObjectType>(event.GetInt("object"));
		int iEnt = event.GetInt("index");
		
		if(TFObject == TFObject_Teleporter)
		{
			SetEntProp(iEnt, Prop_Send, "m_iUpgradeMetalRequired", -5000);
			
			int iHealth = GetEntProp(iEnt, Prop_Send, "m_iMaxHealth") * GetConVarInt(FindConVar("tf_bot_engineer_building_health_multiplier"));
			
			SetEntProp(iEnt, Prop_Data, "m_iMaxHealth", iHealth);
			SetVariantInt(iHealth);
			AcceptEntityInput(iEnt, "SetHealth");
			
			SDKHook(iEnt, SDKHook_GetMaxHealth, OnObjectThink);
		}
		else
		{
			DispatchKeyValue(iEnt, "defaultupgrade", "2");
		}
	}
	
	return Plugin_Continue;
}

public Action OnObjectThink(int iEnt)
{
	TFObjectType TFObject = TF2_GetObjectType(iEnt);
	float flPercentageConstructed = GetEntPropFloat(iEnt, Prop_Send, "m_flPercentageConstructed");
	
	if(flPercentageConstructed == 1.0)
	{
		if(TFObject == TFObject_Teleporter)
		{
			AddParticle(iEnt, "teleporter_mvm_bot_persist");
			SDKUnhook(iEnt, SDKHook_GetMaxHealth, OnObjectThink);
		}
	}
}

public Action Listener_ChoseHuman(int client, char[] command, int args)
{
	if(IsClientInGame(client) && g_bCanPlayAsBot[client] && IsPlayerAlive(client))
	{
		if(TF2_GetClientTeam(client) == TFTeam_Red)
		{
			char strArg1[8];
			GetCmdArg(1, strArg1, sizeof(strArg1));

			if(StringToInt(strArg1) == 1)
				g_bCanPlayAsBot[client] = false;
		}
	}
	
	return Plugin_Continue;
}

public Action Listener_Build(int client, char[] command, int args)
{
	if(IsClientInGame(client) && g_bControllingBot[client] && IsPlayerAlive(client))
	{
		if(TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetPlayerClass(client) == TFClass_Engineer)
		{
			char strArg1[8], strArg2[8];
			GetCmdArg(1, strArg1, sizeof(strArg1));
			GetCmdArg(2, strArg2, sizeof(strArg2));
			
			TFObjectType objType = view_as<TFObjectType>(StringToInt(strArg1));
			int iCount = TF2_GetObjectCount(client, objType);
			
			if(iCount >= 1)
				return Plugin_Handled;
			
			if(objType == TFObject_Teleporter && StringToInt(strArg2) == 0)
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock int TF2_GetObjectCount(int client, TFObjectType type)
{
	int iObject = -1, iCount = 0;
	while ((iObject = FindEntityByClassname(iObject, "obj_*")) != -1)
	{
		TFObjectType iObjType = TF2_GetObjectType(iObject);
		if(iObjType == type)
		{
			iCount++;
		}
	}
	
	return iCount;
}

public Action Listener_Jointeam(int client, char[] command, int args)
{
	int iRobotCount = 0;
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i))
			if(TF2_GetClientTeam(i) == TFTeam_Blue || TF2_GetClientTeam(i) == TFTeam_Spectator)
				iRobotCount++;
				
	if(iRobotCount < 4 || CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT, true))
	{
		if(TF2_GetClientTeam(client) != TFTeam_Spectator)
		{
			if(!g_bCanPlayAsBot[client])
			{
				CPrintToChat(client, "{red}You pressed F4 and now have to stay for this wave");
				return Plugin_Handled;
			}
			else if(TF2_GetClientTeam(client) == TFTeam_Blue && g_bControllingBot[client])
			{
				TF2_RestoreBot(client);
				
				g_flCooldownEndTime[client] = GetGameTime() + 10.0;
			}
		}
	}
	else
	{
		PrintCenterText(client, "Joining Spectators would unbalance the teams!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Listener_Block(int client, char[] command, int args) 
{
	if(IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Blue && TF2_GetClientTeam(client) != TFTeam_Spectator)
	{
		TF2_ChangeClientTeam(client, TFTeam_Spectator);
		TF2_RestoreBot(client);
		
		g_flCooldownEndTime[client] = GetGameTime() + 10.0;
	}
	
	return Plugin_Continue;
}

public Action Listener_Voice(int client, char[] command, int args) 
{
	if(IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Spectator && TF2_ObservedIsValidClient(client) && !g_bControllingBot[client] && g_bCanPlayAsBot[client])
	{
		char arguments[4];
		GetCmdArgString(arguments, sizeof(arguments));
		
		if (StrEqual(arguments, "0 0"))
		{
			if(g_flCooldownEndTime[client] <= GetGameTime())
			{
				int iObserved = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				
				TF2_MirrorPlayer(iObserved, client);
				
				CPrintToChatAll("{blue}%N{default} is now playing as {blue}%N", client, iObserved);
			}
			else
			{
				float flTimeLeft = g_flCooldownEndTime[client] - GetGameTime();
				
				CPrintToChat(client, "{red}Cannot play as a bot for %.0f more seconds", flTimeLeft);
			}
		}
	}

	return Plugin_Continue;
}

public Action Hook_TeleporterTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker) && TF2_GetClientTeam(attacker) == TFTeam_Blue)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Hook_TeleporterTransmit(int entity, int other)
{
	//Bots don't go after teleportes to destroy them so neither should player bots.
	TFTeam iTeam = view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
	
	if(other > 0 && other <= MaxClients && IsClientInGame(other) && !IsFakeClient(other))
	{
		if(iTeam == TFTeam_Red && TF2_GetClientTeam(other) == TFTeam_Blue)
		{
			return Plugin_Handled;	//Don't Transmit
		}
	}

	return Plugin_Continue;	//Transmit
}

public Action Hook_SpyTransmit(int entity, int other)
{
	//Bots don't know where players are when they are disguised so neither should player bots.
	if(other > 0 && other <= MaxClients && IsClientInGame(other) && entity != other && !IsFakeClient(entity))
	{
		if(TF2_GetPlayerClass(entity) == TFClass_Spy && TF2_GetClientTeam(other) == TFTeam_Blue)
		{
			if(TF2_IsPlayerInCondition(entity, TFCond_Disguised) || TF2_IsPlayerInCondition(entity, TFCond_Cloaked))
			{
				if(!TF2_IsPlayerInCondition(entity, TFCond_Jarated) && !TF2_IsPlayerInCondition(entity, TFCond_OnFire) && !TF2_IsPlayerInCondition(entity, TFCond_Milked))
				{
					return Plugin_Handled;	//Don't Transmit
				}
			}
		}
	}

	return Plugin_Continue;	//Transmit
}

stock void TF2_RestoreBot(int client)
{
	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	if(iBot > 0 && IsFakeClient(iBot))
	{
		if(g_bHasBomb[client])
		{
			int iBomb = TF2_DropBomb(client);
			if(IsValidEntity(iBomb))
				TF2_PickupFlag(iBot, iBomb);
		}
		
		if(TF2_GetPlayerClass(iBot) == TFClass_Engineer)
		{
			TF2_TakeOverBuildings(client, iBot);
		}
		
		if(g_bIsSentryBuster[client])
			TF2_DetonateBuster(client);
	
		float flPos[3], flAng[3], flVelocity[3];
		GetClientAbsOrigin(client, flPos);
		GetClientEyeAngles(client, flAng);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
	
		SetEntityMoveType(iBot, MOVETYPE_WALK);
		TeleportEntity(iBot, flPos, flAng, flVelocity);
		
		OnClientPutInServer(iBot);
	}

	TF2_ClearBot(client);
}

stock void TF2_ClearBot(int client, bool bKill = false)
{
	TF2_SetFakeClient(client, false);
	TF2_StopSounds(client);
	TF2_DropBomb(client);
	
	if(bKill)
	{
		TF2_KillBot(client);
	}
	
	SetEntProp(client, Prop_Send, "m_bIsABot", 0);
	SetEntProp(client, Prop_Send, "m_nBotSkill", 0);
	SetEntProp(client, Prop_Send, "m_bIsMiniBoss", 0);
	
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	TF2Attrib_RemoveAll(client);
	TF2Attrib_ClearCache(client);
	
	OnClientPutInServer(client);
}

stock void TF2_KillBot(int client)
{
	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	if(iBot > 0 && IsFakeClient(iBot))
	{
		SetEntityMoveType(iBot, MOVETYPE_WALK);
		
		TF2_RemoveAllConditions(iBot);
		
		SDKHooks_TakeDamage(iBot, iBot, iBot, 99999999.0);
		
		SetEntProp(iBot, Prop_Send, "m_bUseBossHealthBar", 0);
		SetEntProp(iBot, Prop_Send, "m_bIsMiniBoss", 0);
		
		g_bIsControlled[iBot] = false;
		g_iController[iBot] = -1;
		
		OnClientPutInServer(iBot);
	}
}

stock void TF2_MirrorPlayer(int iTarget, int client)
{
	float flPos[3], flAng[3];
	GetClientAbsOrigin(iTarget, flPos);
	GetClientEyeAngles(iTarget, flAng);
	flAng[2] = 0.0;

	//Set up player
	TF2_SetFakeClient(client, true);
	TF2_ChangeClientTeam(client, TF2_GetClientTeam(iTarget));
	TF2_RespawnPlayer(client);
	TF2_SetPlayerClass(client, TF2_GetPlayerClass(iTarget));
	TF2_RegeneratePlayer(client);
	TF2_RespawnPlayer(client);
	TF2_RemoveAllWeapons(client);
	TF2_RemoveAllWearables(client);
	TF2Attrib_RemoveAll(client);
	TF2Attrib_ClearCache(client);
	TF2_MirrorItems(iTarget, client);
	
	//Set HP
	SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(iTarget, Prop_Send, "m_iHealth"));
	
	//Set Model
	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	SetVariantString(strModel);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

	//Set ModelScale
	char strScale[8];
	FloatToString(GetEntPropFloat(iTarget, Prop_Send, "m_flModelScale"), strScale, sizeof(strScale));
	SetVariantString(strScale);
	AcceptEntityInput(client, "SetModelScale");
	
	//Is target sentry buster?
	if(StrContains(strModel, "bot_sentry_buster.mdl") != -1)
	{
		SDKCall(g_hSDKSetMission, iTarget, NOMISSION, 0);
		g_bIsSentryBuster[client] = true;
		TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
	}
	
	//Get & Set some props
	SetEntPropFloat(client, Prop_Send, "m_flRageMeter",	GetEntPropFloat(iTarget, Prop_Send, "m_flRageMeter"));
	SetEntProp(client, Prop_Send, "m_bRageDraining",	GetEntProp(iTarget, Prop_Send, "m_bRageDraining"));
	SetEntProp(client, Prop_Send, "m_bIsABot",			GetEntProp(iTarget, Prop_Send, "m_bIsABot"));
	SetEntProp(client, Prop_Send, "m_nBotSkill",		GetEntProp(iTarget, Prop_Send, "m_nBotSkill"));
	SetEntProp(client, Prop_Send, "m_bIsMiniBoss",		GetEntProp(iTarget, Prop_Send, "m_bIsMiniBoss"));
	
	//Med bot fix
	if(GetEntProp(iTarget, Prop_Send, "m_nNumHealers") > 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue && TF2_GetPlayerClass(i) == TFClass_Medic)
			{
				int iMedigun = GetPlayerWeaponSlot(i, view_as<int>(TFWeaponSlot_Secondary));
				
				if(IsValidEntity(iMedigun))
				{
					int iHealTarget = GetEntPropEnt(iMedigun, Prop_Send, "m_hHealingTarget");
					
					if(iHealTarget == iTarget)
					{
						SDKCall(g_hSDKLeaveSquad, i);
					}
				}
			}
		}
	}
	SDKCall(g_hSDKLeaveSquad, iTarget);
	
	if(g_bHasBomb[iTarget])
	{
		//Copy bomb carrier upgrade level
		int iResource = FindEntityByClassname(-1, "tf_objective_resource");
		g_iFlagCarrierUpgradeLevel[client] = GetEntProp(iResource, Prop_Send, "m_nFlagCarrierUpgradeLevel");
		g_flNextBombUpgradeTime[client] = GetEntPropFloat(iResource, Prop_Send, "m_flMvMNextBombUpgradeTime");	
	
		PrintToConsole(client, "Bomb index = %i", EntRefToEntIndex(GetEntPropEnt(client, Prop_Send, "m_hItem")));
	
		TF2_SetFakeClient(client, false);
		int iBomb = TF2_DropBomb(iTarget);
		if(IsValidEntity(iBomb))
			TF2_PickupFlag(client, iBomb);
			
		g_bHasBomb[iTarget] = false;
		g_bHasBomb[client] = true;
	}
	
	//Set gatebot on player if target is gatebot
	if(g_bIsGateBot[iTarget])
	{
		TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
		g_bIsGateBot[client] = true;
	}
	
	//Engineers cant carry buildings		
	if(TF2_GetPlayerClass(iTarget) == TFClass_Engineer)		
	{		
		TF2_TakeOverBuildings(iTarget, client);		
		TF2Attrib_SetByName(client, "cannot pick up buildings", 1.0);		
	}
	
	if(TF2_GetPlayerClass(iTarget) == TFClass_Sniper)
	{
		//Unzooms the sniper so the laser wont bug out
		TF2_AddCondition(iTarget, TFCond_Taunting, 5.0);
	}
	
	//Copy medigun data
	if(TF2_GetPlayerClass(iTarget) == TFClass_Medic)
	{
		int tMedigun = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Secondary));
		int pMedigun = GetPlayerWeaponSlot(client, view_as<int>(TFWeaponSlot_Secondary));
		
		if(IsValidEntity(tMedigun) && IsValidEntity(pMedigun))
		{
			SetEntPropFloat(pMedigun, Prop_Send, "m_flChargeLevel",	GetEntPropFloat(tMedigun, Prop_Send, "m_flChargeLevel"));	
			SetEntPropEnt(pMedigun, Prop_Send, "m_hHealingTarget",	GetEntPropEnt(tMedigun, Prop_Send, "m_hHealingTarget"));
			SetEntProp(pMedigun, Prop_Send, "m_nChargeResistType",	GetEntProp(tMedigun, Prop_Send, "m_nChargeResistType"));	
			SetEntProp(pMedigun, Prop_Send, "m_bAttacking",			GetEntProp(tMedigun, Prop_Send, "m_bAttacking"));	
			SetEntProp(pMedigun, Prop_Send, "m_bHealing",			GetEntProp(tMedigun, Prop_Send, "m_bHealing"));	
			SetEntProp(pMedigun, Prop_Send, "m_bChargeRelease",		GetEntProp(tMedigun, Prop_Send, "m_bChargeRelease"));	
		}
	}
	if(TF2_GetPlayerClass(iTarget) == TFClass_Spy)
	{
		int iDisguiseClass	= GetEntProp(iTarget, Prop_Send, "m_nDisguiseClass");
		int iDisguiseTarget = GetEntProp(iTarget, Prop_Send, "m_iDisguiseTargetIndex");

		if(iDisguiseTarget > 0 && iDisguiseTarget <= MaxClients && IsClientInGame(iDisguiseTarget) && iDisguiseClass > 0)	
			TF2_DisguisePlayer(client, TFTeam_Red, view_as<TFClassType>(iDisguiseClass), iDisguiseTarget);
		else if(iDisguiseClass > 0)
			TF2_DisguisePlayer(client, TFTeam_Red, view_as<TFClassType>(iDisguiseClass));		
	}
	
	//Start the engines
	if(TF2_IsGiant(iTarget))
	{
		if(g_bIsSentryBuster[client]) 
		{
			EmitSoundToAll(BUSTER_SND_LOOP, client, SNDCHAN_STATIC, SNDLEVEL_TRAIN, _, 1.0);
		}
		else
		{	
			switch(TF2_GetPlayerClass(iTarget))
			{
				case TFClass_Scout:		EmitSoundToAll(GIANTSCOUT_SND_LOOP,	  client, SNDCHAN_STATIC, SNDLEVEL_SCREAMING, _, 0.3);
				case TFClass_Soldier:	EmitSoundToAll(GIANTSOLDIER_SND_LOOP, client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.7);
				case TFClass_DemoMan:	EmitSoundToAll(GIANTDEMOMAN_SND_LOOP, client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.7);
				case TFClass_Heavy:		EmitSoundToAll(GIANTHEAVY_SND_LOOP,	  client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.8);
				case TFClass_Pyro:		EmitSoundToAll(GIANTPYRO_SND_LOOP,	  client, SNDCHAN_STATIC, SNDLEVEL_MINIBIKE, _, 0.8);
			}
		}
	}
	
	float flJumpMin = GetEntDataFloat(iTarget, g_iOffsetAutoJumpMin);
	float flJumpMax = GetEntDataFloat(iTarget, g_iOffsetAutoJumpMax);
	int iBotAttrs = GetEntData(iTarget, g_iOffsetBotAttribs);
	
	g_flAutoJumpMin[client] = flJumpMin;
	g_flAutoJumpMax[client] = flJumpMax;
	g_iPlayerAttributes[client] = iBotAttrs;

	if(iBotAttrs & view_as<int>(IGNOREFLAG))	TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
	if(iBotAttrs & view_as<int>(ALWAYSCRIT))	TF2_AddCondition(client, TFCond_CritOnFlagCapture);
	if(iBotAttrs & view_as<int>(BULLETIMMUNE))	TF2_AddCondition(client, TFCond_BulletImmune);
	if(iBotAttrs & view_as<int>(BLASTIMMUNE))	TF2_AddCondition(client, TFCond_BlastImmune);
	if(iBotAttrs & view_as<int>(FIREIMMUNE))	TF2_AddCondition(client, TFCond_FireImmune);
	
//	SetEntData(client, g_iOffsetBotAttribs, iBotAttrs, true);	//It does stuff, trust me.
	SetEntData(client, g_iOffsetMissionBot, 1, _, true);		//Makes player death not decrement wave bot count
	SetEntData(client, g_iOffsetSupportLimited, 0, _, true);	//Makes player death not decrement wave bot count
	
	//Fix some bugs...	
	TF2_RemoveCondition(iTarget, TFCond_Zoomed);		
	TF2_RemoveCondition(iTarget, TFCond_Slowed);
	
	//Mirror conditions
	for (int cond = 0; cond <= view_as<int>(TFCond_SpawnOutline); ++cond)
	{
		if(cond == 5 || cond == 9 || cond == 51)
			continue;
		
		if (!TF2_IsPlayerInCondition(iTarget, view_as<TFCond>(cond)))
			continue;
		
		Address tmp = view_as<Address>(LoadFromAddress(GetEntityAddress(iTarget) + view_as<Address>(g_iCondSourceOffs), NumberType_Int32));
		Address addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (2 * 4));
		int value = LoadFromAddress(addr, NumberType_Int32);
		
		//Only mirror conditions that don't last "forever"
		if(value > 0.0)
		{
			TF2_AddCondition(client, view_as<TFCond>(cond), view_as<float>(value));
		}
	}
	
	//Teleport player to bots position and teleport bot away from anyones view
	float flVelocity[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", flVelocity);
	
	SetEntityMoveType(iTarget, MOVETYPE_NONE);
	TeleportEntity(client, flPos, flAng, flVelocity);
	TeleportEntity(iTarget, view_as<float>({0.0, 0.0, 9999.0}), NULL_VECTOR, NULL_VECTOR);

	g_iPlayersBot[client] = GetClientUserId(iTarget);
	g_bControllingBot[client] = true;
	g_bIsControlled[iTarget] = true;
	g_iController[iTarget] = GetClientUserId(client);
	g_bSkipInventory[client] = true;
}

stock void TF2_MirrorItems(int iTarget, int client)
{
	int iAttribList[16];
	float flAttribValues[16];
	Address aAttr;
	
	int iWeaponRestriction = GetEntData(iTarget, g_iOffsetWeaponRestrictions);

	if(iWeaponRestriction == view_as<int>(UNRESTRICTED))
	{
		for (int w = 0; w <= view_as<int>(TFWeaponSlot_PDA); w++)
		{
			int iEntity = GetPlayerWeaponSlot(iTarget, w);
		
			if(IsValidEntity(iEntity))
			{
				char strClass[64];
				GetEntityClassname(iEntity, strClass, sizeof(strClass));
				
				int iDefIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			
				int iCount = TF2Attrib_ListDefIndices(iEntity, iAttribList);
				if (iCount > 0)
				{
					for (int i = 0; i < iCount; i++)
					{
						aAttr = TF2Attrib_GetByDefIndex(iEntity, iAttribList[i]);
						flAttribValues[i] = TF2Attrib_GetValue(aAttr);
					}
				}
				
				GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, GetEntPropEnt(iTarget, Prop_Data, "m_hActiveWeapon") == iEntity ? true : false);
			}
		}
	}
	else
	{
		int iEntity = -1;
		
		switch(iWeaponRestriction)
		{
			case PRIMARYONLY:	iEntity = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Primary));
			case SECONDARYONLY:	iEntity = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Secondary));
			case MELEEONLY:		iEntity = GetPlayerWeaponSlot(iTarget, view_as<int>(TFWeaponSlot_Melee));
		}

		if(IsValidEntity(iEntity))
		{
			char strClass[64];
			GetEntityClassname(iEntity, strClass, sizeof(strClass));
			
			int iDefIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
		
			int iCount = TF2Attrib_ListDefIndices(iEntity, iAttribList);
			if (iCount > 0)
			{
				for (int i = 0; i < iCount; i++)
				{
					aAttr = TF2Attrib_GetByDefIndex(iEntity, iAttribList[i]);
					flAttribValues[i] = TF2Attrib_GetValue(aAttr);
				}
			}
			
			GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, true);
		}
	}

	//Mirror wearables
	int iWearable = -1;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if(!GetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable") && GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == iTarget)
		{
			char strClass[64];
			GetEntityClassname(iWearable, strClass, sizeof(strClass));
			
			int iDefIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
		
			int iCount = TF2Attrib_ListDefIndices(iWearable, iAttribList);
			if (iCount > 0)
			{
				for (int i = 0; i < iCount; i++)
				{
					aAttr = TF2Attrib_GetByDefIndex(iWearable, iAttribList[i]);
					flAttribValues[i] = TF2Attrib_GetValue(aAttr);
				}
			}
			
			GiveItem(client, iDefIndex, strClass, iCount, iAttribList, flAttribValues, false);
		}
	}

	//Mirror player attributes
	int iCount = TF2Attrib_ListDefIndices(iTarget, iAttribList);
	if (iCount > 0)
	{
		for (int i = 0; i < iCount; i++)
		{
			aAttr = TF2Attrib_GetByDefIndex(iTarget, iAttribList[i]);
			flAttribValues[i] = TF2Attrib_GetValue(aAttr);

			TF2Attrib_SetByDefIndex(client, iAttribList[i], flAttribValues[i]);
		}
	}
}

stock void TF2_RemoveAllWearables(int client)
{
	int wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable*")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			TF2_RemoveWearable(client, wearable);
	
	while ((wearable = FindEntityByClassname(wearable, "vgui_screen")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			AcceptEntityInput(wearable, "Kill");

	while ((wearable = FindEntityByClassname(wearable, "tf_powerup_bottle")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			TF2_RemoveWearable(client, wearable);

	while ((wearable = FindEntityByClassname(wearable, "tf_weapon_spellbook")) != -1)
		if (client == GetEntPropEnt(wearable, Prop_Data, "m_hOwnerEntity"))
			TF2_RemoveWearable(client, wearable);
}

stock void TF2_SetObserved(int client, int iObserved, int iObserveMode = -1)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iObserved);
	
	if(iObserveMode != -1)
		SetEntProp(client, Prop_Send, "m_iObserverMode", iObserveMode);
}

stock bool TF2_IsGiant(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_bIsMiniBoss"));
}

stock bool TF2_HasGateBotItem(int client)
{
	int wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable")) != -1)
	{
		int iDefIndex = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex");
		
		switch(iDefIndex)
		{
			case 1057, 1058, 1059, 1060, 1061, 1062, 1063, 1064, 1065:
			{
				int iOwner = GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity");
				
				if(iOwner == client)
					return true;
			}
		}
	}
	
	return false;
}

stock int TF2_DropBomb(int client)
{
	int iBomb = EntRefToEntIndex(GetEntPropEnt(client, Prop_Send, "m_hItem"));
	
	if(iBomb != INVALID_ENT_REFERENCE && GetEntPropEnt(iBomb, Prop_Send, "moveparent") == client)
	{
		AcceptEntityInput(iBomb, "ForceDrop");
	}

/*	int iBomb = -1;
	while ((iBomb = FindEntityByClassname(iBomb, "item_teamflag")) != -1)
	{
		if(GetEntPropEnt(iBomb, Prop_Send, "moveparent") == client)
		{
			AcceptEntityInput(iBomb, "ForceDrop");
			PrintToServer("%N was forced to drop their bomb", client);
			break;
		}
	}*/
	
	return iBomb;
}

stock void TF2_RobotsWin()
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "logic_relay")) != -1)
	{
		char strName[32];
		GetEntPropString(iEnt, Prop_Data, "m_iName", strName, sizeof(strName));
		
		if(StrEqual(strName, "boss_deploy_relay", false))
		{
			AcceptEntityInput(iEnt, "Trigger");
		}
	}
}

stock void TF2_StopSounds(int client)
{
	StopSound(client, SNDCHAN_STATIC, GIANTSCOUT_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTSOLDIER_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTPYRO_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTDEMOMAN_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, GIANTHEAVY_SND_LOOP);
	StopSound(client, SNDCHAN_STATIC, BUSTER_SND_LOOP);
}

stock void TF2_SetFakeClient(int client, bool bOn)
{
	int iEFlags = GetEntityFlags(client);

	if(bOn)
		SetEntityFlags(client, iEFlags | FL_FAKECLIENT);
	else
		SetEntityFlags(client, iEFlags &~ FL_FAKECLIENT);
}

stock void TF2_RemoveAllConditions(int client)
{
	for (int cond = 0; cond <= view_as<int>(TFCond_RuneAgility); ++cond)
		TF2_RemoveCondition(client, view_as<TFCond>(cond));
}

stock bool TF2_ObservedIsValidClient(int observer)
{
	if(GetEntProp(observer, Prop_Send, "m_iObserverMode") == 4 || GetEntProp(observer, Prop_Send, "m_iObserverMode") == 5)
	{
		int iObserved = GetEntPropEnt(observer, Prop_Send, "m_hObserverTarget");
	
		if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && IsFakeClient(iObserved) && IsPlayerAlive(iObserved) && !g_bIsControlled[iObserved])
		{
			if(!TF2_IsPlayerInCondition(iObserved, TFCond_MVMBotRadiowave) && !TF2_IsPlayerInCondition(iObserved, TFCond_Taunting))
			{
				if(GetEntProp(iObserved, Prop_Data, "m_takedamage") != 0)
				{
					float flSpawnedAgo = GetGameTime() - g_flSpawnTime[iObserved];
					if(flSpawnedAgo >= 1.5)
					{
						return true;
					}
				}
			}
		}
	}
	
	return false;
}

stock void TF2_ObservedIsNotValidReason(int observer, char[] strBuffer, int iMaxLenght)
{
	if(GetEntProp(observer, Prop_Send, "m_iObserverMode") == 4 || GetEntProp(observer, Prop_Send, "m_iObserverMode") == 5)
	{
		int iObserved = GetEntPropEnt(observer, Prop_Send, "m_hObserverTarget");
		
		if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && IsFakeClient(iObserved))
		{
			if(!IsPlayerAlive(iObserved))										Format(strBuffer, iMaxLenght, "this bot is dead");
			else if(g_bIsControlled[iObserved])									Format(strBuffer, iMaxLenght, "this bot is controlled by someone else");
			else if(TF2_IsPlayerInCondition(iObserved, TFCond_MVMBotRadiowave))	Format(strBuffer, iMaxLenght, "this bot is stunned");
			else if(TF2_IsPlayerInCondition(iObserved, TFCond_Taunting))		Format(strBuffer, iMaxLenght, "this bot is taunting");
			else if(GetEntProp(iObserved, Prop_Data, "m_takedamage") == 0)		Format(strBuffer, iMaxLenght, "this bot is about to explode");
			else
			{
				float flSpawnedAgo = GetGameTime() - g_flSpawnTime[iObserved];
				if(flSpawnedAgo >= 1.5)	Format(strBuffer, iMaxLenght, "this bot is not ready yet");
			}
		}
	}
}

stock int TF2_FindNearestHint(int client, const char[] strHint = "bot_hint_engineer_nest")
{
	//bot_hint_teleporter_exit
	//bot_hint_engineer_nest
	//bot_hint_sentrygun
	
	float flBestDistance = 999999.0;

	float flOrigin[3];
	GetClientAbsOrigin(client, flOrigin);

	int iBestEntity = -1;

	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, strHint)) != -1)
	{
		float flPos[3];
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", flPos);
		
		float flDistance = GetVectorDistance(flOrigin, flPos);
		if(flDistance <= flBestDistance)
		{
			flBestDistance = flDistance;
			iBestEntity = iEnt;
		}
	}
	
	return iBestEntity;
}

stock void TF2_DetonateBuster(int client)
{
	if(g_bRandomlyChooseBot[client])
		g_flCooldownEndTime[client] = GetGameTime() + 5.0;

	int iBot = GetClientOfUserId(g_iPlayersBot[client]);
	
	if(iBot > 0 && IsFakeClient(iBot))
	{
		TF2_StopSounds(client);
	
		float flPos[3], flAng[3], flVelocity[3];
		GetClientAbsOrigin(client, flPos);
		GetClientEyeAngles(client, flAng);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
	
		SetEntityMoveType(iBot, MOVETYPE_WALK);
		TeleportEntity(iBot, flPos, flAng, flVelocity);
		
		SDKCall(g_hSDKSetMission, iBot, DESTROY_SENTRIES, 1);	
		
		SetEntProp(iBot, Prop_Send, "m_iHealth", 1);
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iBot);
	}
}

stock int TF2_FindTeleNearestToBombHole()
{
	int iHole = -1;	
	while ((iHole = FindEntityByClassname(iHole, "func_breakable")) != -1)
	{
		char strName[32];
		GetEntPropString(iHole, Prop_Data, "m_iName", strName, sizeof(strName));
		
		if(StrEqual(strName, "cap_hatch_glasswindow"))
			break;
	}

	int iBestEntity = -1;

	if(IsValidEntity(iHole))
	{
		float flOrigin[3];
		GetEntPropVector(iHole, Prop_Send, "m_vecOrigin", flOrigin);
		
		float flBestDistance = 999999.0;
		
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "obj_teleporter")) != -1)
		{
			if(GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Blue)
			&& !GetEntProp(iEnt, Prop_Send, "m_bHasSapper") && !GetEntProp(iEnt, Prop_Send, "m_bBuilding") 
			&& !GetEntProp(iEnt, Prop_Send, "m_bPlacing") && !GetEntProp(iEnt, Prop_Send, "m_bDisabled"))
			{
				float flPos[3];
				GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", flPos);
				
				float flDistance = GetVectorDistance(flOrigin, flPos);
				if(flDistance <= flBestDistance)
				{
					flBestDistance = flDistance;
					iBestEntity = iEnt;
				}
			}
		}
	}
	
	return iBestEntity;
}

stock void TF2_TakeOverBuildings(int client, int newClient)
{
	int obj = -1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
	{
		if(IsValidBuilding(obj))
		{
			int iBuilder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
			if(iBuilder == client)
			{
				DispatchKeyValue(obj, "SolidToPlayer", "0");
				SetBuilder(obj, newClient);
			}
		}
	}
}

stock void SetBuilder(int obj, int client)
{
	int iBuilder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");

	if(iBuilder > 0 && iBuilder <= MaxClients && IsClientInGame(iBuilder))
		SDKCall(g_hSDKRemoveObject, iBuilder, obj);
	
	SetEntPropEnt(obj, Prop_Send, "m_hBuilder", -1);
	AcceptEntityInput(obj, "SetBuilder", client);
	SetEntPropEnt(obj, Prop_Send, "m_hBuilder", client);
}

stock bool IsValidBuilding(int iBuilding)
{
	if (IsValidEntity(iBuilding))
	{
		if (GetEntProp(iBuilding, Prop_Send, "m_bPlacing") == 0
		 && GetEntProp(iBuilding, Prop_Send, "m_bCarried") == 0)
			return true;
	}
	
	return false;
}

stock void TF2_PickupFlag(int iClient, int iFlag)
{
	SDKCall(g_hSDKPickup, iFlag, iClient, true);	
}

stock void BroadcastSoundToTeam(TFTeam team, const char[] strSound)
{
	//PrintToChatAll("Broadcasting %s..", strSound);
	switch(team)
	{
		case TFTeam_Red, TFTeam_Blue: 
		{
			for(int i = 1; i <= MaxClients; i++) 
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == team) 
				{
					ClientCommand(i, "playgamesound %s", strSound);
				}
			}
		}
		default: 
		{
			for(int i = 1; i <= MaxClients; i++) 
			{
				if(IsClientInGame(i) && !IsFakeClient(i)) 
				{
					ClientCommand(i, "playgamesound %s", strSound);
				}
			}
		}
	}
}

public void GiveItem(int client, int DefIndex, char[] ItemClass, int iAttribCount, int iAttribList[16], float flAttribValues[16], bool bSetActive)
{
	Handle TF2Item;
	if (StrEqual(ItemClass, "saxxy", false) || StrEqual(ItemClass, "tf_weapon_shotgun", false))
		TF2Item = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES);
	else
		TF2Item = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	
	bool IsWeapon = StrContains(ItemClass, "tf_weapon") != -1;
	
	TF2Items_SetClassname(TF2Item, ItemClass);
	TF2Items_SetItemIndex(TF2Item, DefIndex);
	TF2Items_SetLevel(TF2Item, 100);

	if (iAttribCount > 0)
	{
		for (int i = 0; i < iAttribCount; i++)
		{
			if(i < 15)
			{
				TF2Items_SetAttribute(TF2Item, i, iAttribList[i], flAttribValues[i]);
			}
		}
	}
	
	TF2Items_SetNumAttributes(TF2Item, iAttribCount);
	
	int ItemEntity = TF2Items_GiveNamedItem(client, TF2Item);
	delete TF2Item;

	if(IsValidEntity(ItemEntity))
	{
		if(StrEqual(ItemClass, "tf_weapon_builder") || StrEqual(ItemClass, "tf_weapon_sapper"))
		{
			if(TF2_GetPlayerClass(client) == TFClass_Spy)
			{
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
				
				SetEntProp(ItemEntity, Prop_Send, "m_iObjectType", 3);
				SetEntProp(ItemEntity, Prop_Data, "m_iSubType", 3);
			}
			else
			{
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);	//Dispenser
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);	//Teleporter
				SetEntProp(ItemEntity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);	//Sentry
			}
		}
	
		if (!IsWeapon)
			SDKCall(g_hSdkEquipWearable, client, ItemEntity);		
		else
			EquipPlayerWeapon(client, ItemEntity);
			
		if(bSetActive && IsWeapon)
		{
			FakeClientCommand(client, "use %s", ItemClass);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", ItemEntity);
		}
		
		PrintToConsole(client, "Index %i | iDefIndex %i | ItemClass %s", ItemEntity, DefIndex, ItemClass);
	}
	else
	{
		LogError("Unable to GIVE item '%d' for %N. Skipping...", DefIndex, client);
		return;
	}
}

stock void Annotate(float flPos[3], int client, char[] strMsg, int iOffset = 0)
{
	Event event = CreateEvent("show_annotation");
	if (event != INVALID_HANDLE)
	{
		event.SetFloat("worldPosX", flPos[0]);
		event.SetFloat("worldPosY", flPos[1]);
		event.SetFloat("worldPosZ", flPos[2]);
		event.SetFloat("lifetime", 8.0);
		event.SetInt("id", client + 8750 + iOffset);
		event.SetString("text", strMsg);
		event.SetString("play_sound", "vo/null.wav");
		event.SetString("show_effect", "1");
		event.SetString("show_distance", "1");
		event.SetInt("visibilityBitfield", 1 << client);
		event.Fire(false);
	}
}

stock void AddParticle(int iBuilding, const char[] strParticle)
{
	float flPos[3];
	GetEntPropVector(iBuilding, Prop_Send, "m_vecOrigin", flPos);

	int iParticle = CreateEntityByName("info_particle_system");
	DispatchKeyValueVector(iParticle, "origin", flPos);
	DispatchKeyValue(iParticle, "effect_name", strParticle); 
	DispatchSpawn(iParticle); 
	
	SetVariantString("!activator"); 
	AcceptEntityInput(iParticle, "SetParent", iBuilding); 
	ActivateEntity(iParticle); 
	
	AcceptEntityInput(iParticle, "start"); 
}

stock bool TF2_IsMvM()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

bool LookupOffset(int &iOffset, const char[] strClass, const char[] strProp)
{
	iOffset = FindSendPropInfo(strClass, strProp);
	if(iOffset <= 0)
	{
		LogMessage("Could not locate offset for %s::%s!", strClass, strProp);
		return false;
	}

	return true;
}