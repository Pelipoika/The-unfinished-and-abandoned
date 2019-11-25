#include <sdktools>
#include <sdkhooks>
#include <tf2items>

#pragma newdecls required

Handle g_hSdkEquipWearable;

bool g_bApply[MAXPLAYERS + 1];
char g_strClientModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

char g_strModels[][] = 
{
	{ "models/bots/headless_hatman.mdl" }, 
	{ "models/bots/skeleton_sniper/skeleton_sniper.mdl" }, 
	{ "models/bots/skeleton_sniper_boss/skeleton_sniper_boss.mdl" }, 
	{ "models/bots/merasmus/merasmus.mdl" }, 
	{ "models/bots/demo/bot_demo.mdl" }, 
	{ "models/bots/demo/bot_sentry_buster.mdl" }, 
	{ "models/bots/engineer/bot_engineer.mdl" }, 
	{ "models/bots/heavy/bot_heavy.mdl" }, 
	{ "models/bots/medic/bot_medic.mdl" }, 
	{ "models/bots/pyro/bot_pyro.mdl" }, 
	{ "models/bots/scout/bot_scout.mdl" }, 
	{ "models/bots/sniper/bot_sniper.mdl" }, 
	{ "models/bots/soldier/bot_soldier.mdl" }, 
	{ "models/bots/spy/bot_spy.mdl" }, 
	{ "models/player/demo.mdl" }, 
	{ "models/player/engineer.mdl" }, 
	{ "models/player/heavy.mdl" }, 
	{ "models/player/medic.mdl" }, 
	{ "models/player/pyro.mdl" }, 
	{ "models/player/scout.mdl" }, 
	{ "models/player/sniper.mdl" }, 
	{ "models/player/soldier.mdl" }, 
	{ "models/player/spy.mdl" }, 
	{ "models/player/items/taunts/yeti/yeti.mdl" }, 
	//	{""},
}

public Plugin myinfo = 
{
	name = "[TF2] Player model randomizer", 
	author = "Pelipoika", 
	description = "", 
	version = "1.0", 
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	HookEvent("player_changeclass", Event_PlayerChangeClass, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_InvApp, EventHookMode_Post);
	
	Handle hConf = LoadGameConfigFile("tf2items.randomizer");
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable"))PrintToServer("[PlayerModelRandomizer] Failed to set EquipWearable from conf!");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();
	
	delete hConf;
	
	RegAdminCmd("sm_bonemerge", BoneM, ADMFLAG_ROOT, "lollllllllll");
}

public Action BoneM(int client, int argc)
{
	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	GetCmdArgString(g_strClientModel[client], PLATFORM_MAX_PATH);
	
	ApplyModel(client, g_strClientModel[client]);
	
	return Plugin_Handled;
}

public void Event_InvApp(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!StrEqual(g_strClientModel[client], "") && g_bApply[client])
	{
		Handle hItem = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
		TF2Items_SetClassname(hItem, "tf_wearable");
		TF2Items_SetItemIndex(hItem, 30601);
		TF2Items_SetQuality(hItem, 6);
		TF2Items_SetLevel(hItem, 1);
		
		int iItem = TF2Items_GiveNamedItem(client, hItem);
		
		delete(hItem);
		
		SDKCall(g_hSdkEquipWearable, client, iItem);
		
		SetEntProp(client, Prop_Send, "m_nRenderFX", 6);
		SetEntProp(iItem, Prop_Data, "m_nModelIndexOverrides", PrecacheModel(g_strClientModel[client]));
		SetEntProp(iItem, Prop_Send, "m_bValidatedAttachedEntity", 1);
	}
}

public void Event_PlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int iModel = GetRandomInt(0, sizeof(g_strModels) - 1);
	Format(g_strClientModel[client], PLATFORM_MAX_PATH, "%s", g_strModels[iModel]);
	
	char strModel[PLATFORM_MAX_PATH];
	Format(strModel, PLATFORM_MAX_PATH, "%s", g_strModels[iModel]);
	
	ApplyModel(client, strModel);
}

public void ApplyModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	
	g_bApply[client] = true;
} 