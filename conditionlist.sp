#include <sdktools>
#include <tf2_stocks>

#pragma newdecls required

int g_iCondSourceOffs = -1;

int COND_SOURCE_OFFS = 8;
int COND_SOURCE_SIZE = 20;

Handle g_hHudInfo;

#define	MAX_EDICT_BITS			11			// # of bits needed to represent max edicts
#define NUM_ENT_ENTRY_BITS		(MAX_EDICT_BITS + 1)
#define NUM_ENT_ENTRIES			(1 << NUM_ENT_ENTRY_BITS)
#define ENT_ENTRY_MASK			(NUM_ENT_ENTRIES - 1)

bool g_bShowConditions[MAXPLAYERS+1];

ArrayList aConditions;

public Plugin myinfo = 
{
	name = "[TF2] Condition List",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	int offset = FindSendPropInfo("CTFPlayer", "m_Shared");
	if (offset == -1) SetFailState("Cannot find m_Shared on CTFPlayer.");
	g_iCondSourceOffs = offset + COND_SOURCE_OFFS;
	
	g_hHudInfo = CreateHudSynchronizer();
	
	RegConsoleCmd("sm_condlist", Command_CondList, "Toggle condition listing");
	
	aConditions = new ArrayList(PLATFORM_MAX_PATH);
	aConditions.PushString("TF_COND_AIMING");
	aConditions.PushString("TF_COND_ZOOMED");
	aConditions.PushString("TF_COND_DISGUISING");
	aConditions.PushString("TF_COND_DISGUISED");
	aConditions.PushString("TF_COND_STEALTHED");
	aConditions.PushString("TF_COND_INVULNERABLE");
	aConditions.PushString("TF_COND_TELEPORTED");
	aConditions.PushString("TF_COND_TAUNTING");
	aConditions.PushString("TF_COND_INVULNERABLE_WEARINGOFF");
	aConditions.PushString("TF_COND_STEALTHED_BLINK");
	aConditions.PushString("TF_COND_SELECTED_TO_TELEPORT");
	aConditions.PushString("TF_COND_CRITBOOSTED");
	aConditions.PushString("TF_COND_TMPDAMAGEBONUS");
	aConditions.PushString("TF_COND_FEIGN_DEATH");
	aConditions.PushString("TF_COND_PHASE");
	aConditions.PushString("TF_COND_STUNNED");
	aConditions.PushString("TF_COND_OFFENSEBUFF");
	aConditions.PushString("TF_COND_SHIELD_CHARGE");
	aConditions.PushString("TF_COND_DEMO_BUFF");
	aConditions.PushString("TF_COND_ENERGY_BUFF");
	aConditions.PushString("TF_COND_RADIUSHEAL");
	aConditions.PushString("TF_COND_HEALTH_BUFF");
	aConditions.PushString("TF_COND_BURNING");
	aConditions.PushString("TF_COND_HEALTH_OVERHEALED");
	aConditions.PushString("TF_COND_URINE");
	aConditions.PushString("TF_COND_BLEEDING");
	aConditions.PushString("TF_COND_DEFENSEBUFF");
	aConditions.PushString("TF_COND_MAD_MILK");
	aConditions.PushString("TF_COND_MEGAHEAL");
	aConditions.PushString("TF_COND_REGENONDAMAGEBUFF");
	aConditions.PushString("TF_COND_MARKEDFORDEATH");
	aConditions.PushString("TF_COND_NOHEALINGDAMAGEBUFF");
	aConditions.PushString("TF_COND_SPEED_BOOST");
	aConditions.PushString("TF_COND_CRITBOOSTED_PUMPKIN");
	aConditions.PushString("TF_COND_CRITBOOSTED_USER_BUFF");
	aConditions.PushString("TF_COND_CRITBOOSTED_DEMO_CHARGE");
	aConditions.PushString("TF_COND_SODAPOPPER_HYPE");
	aConditions.PushString("TF_COND_CRITBOOSTED_FIRST_BLOOD");
	aConditions.PushString("TF_COND_CRITBOOSTED_BONUS_TIME");
	aConditions.PushString("TF_COND_CRITBOOSTED_CTF_CAPTURE");
	aConditions.PushString("TF_COND_CRITBOOSTED_ON_KILL");
	aConditions.PushString("TF_COND_CANNOT_SWITCH_FROM_MELEE");
	aConditions.PushString("TF_COND_DEFENSEBUFF_NO_CRIT_BLOCK");
	aConditions.PushString("TF_COND_REPROGRAMMED");
	aConditions.PushString("TF_COND_CRITBOOSTED_RAGE_BUFF");
	aConditions.PushString("TF_COND_DEFENSEBUFF_HIGH");
	aConditions.PushString("TF_COND_SNIPERCHARGE_RAGE_BUFF");
	aConditions.PushString("TF_COND_DISGUISE_WEARINGOFF");
	aConditions.PushString("TF_COND_MARKEDFORDEATH_SILENT");
	aConditions.PushString("TF_COND_DISGUISED_AS_DISPENSER");
	aConditions.PushString("TF_COND_SAPPED");
	aConditions.PushString("TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED");
	aConditions.PushString("TF_COND_INVULNERABLE_USER_BUFF");
	aConditions.PushString("TF_COND_HALLOWEEN_BOMB_HEAD");
	aConditions.PushString("TF_COND_HALLOWEEN_THRILLER");
	aConditions.PushString("TF_COND_RADIUSHEAL_ON_DAMAGE");
	aConditions.PushString("TF_COND_CRITBOOSTED_CARD_EFFECT");
	aConditions.PushString("TF_COND_INVULNERABLE_CARD_EFFECT");
	aConditions.PushString("TF_COND_MEDIGUN_UBER_BULLET_RESIST");
	aConditions.PushString("TF_COND_MEDIGUN_UBER_BLAST_RESIST");
	aConditions.PushString("TF_COND_MEDIGUN_UBER_FIRE_RESIST");
	aConditions.PushString("TF_COND_MEDIGUN_SMALL_BULLET_RESIST");
	aConditions.PushString("TF_COND_MEDIGUN_SMALL_BLAST_RESIST");
	aConditions.PushString("TF_COND_MEDIGUN_SMALL_FIRE_RESIST");
	aConditions.PushString("TF_COND_STEALTHED_USER_BUFF");
	aConditions.PushString("TF_COND_MEDIGUN_DEBUFF");
	aConditions.PushString("TF_COND_STEALTHED_USER_BUFF_FADING");
	aConditions.PushString("TF_COND_BULLET_IMMUNE");
	aConditions.PushString("TF_COND_BLAST_IMMUNE");
	aConditions.PushString("TF_COND_FIRE_IMMUNE");
	aConditions.PushString("TF_COND_PREVENT_DEATH");
	aConditions.PushString("TF_COND_MVM_BOT_STUN_RADIOWAVE");
	aConditions.PushString("TF_COND_HALLOWEEN_SPEED_BOOST");
	aConditions.PushString("TF_COND_HALLOWEEN_QUICK_HEAL");
	aConditions.PushString("TF_COND_HALLOWEEN_GIANT");
	aConditions.PushString("TF_COND_HALLOWEEN_TINY");
	aConditions.PushString("TF_COND_HALLOWEEN_IN_HELL");
	aConditions.PushString("TF_COND_HALLOWEEN_GHOST_MODE");
	aConditions.PushString("TF_COND_MINICRITBOOSTED_ON_KILL");
	aConditions.PushString("TF_COND_OBSCURED_SMOKE");
	aConditions.PushString("TF_COND_PARACHUTE_DEPLOYED");
	aConditions.PushString("TF_COND_BLASTJUMPING");
	aConditions.PushString("TF_COND_HALLOWEEN_KART");
	aConditions.PushString("TF_COND_HALLOWEEN_KART_DASH");
	aConditions.PushString("TF_COND_BALLOON_HEAD");
	aConditions.PushString("TF_COND_MELEE_ONLY");
	aConditions.PushString("TF_COND_SWIMMING_CURSE");
	aConditions.PushString("TF_COND_FREEZE_INPUT");
	aConditions.PushString("TF_COND_HALLOWEEN_KART_CAGE");
	aConditions.PushString("TF_COND_DONOTUSE_0");
	aConditions.PushString("TF_COND_RUNE_STRENGTH");
	aConditions.PushString("TF_COND_RUNE_HASTE");
	aConditions.PushString("TF_COND_RUNE_REGEN");
	aConditions.PushString("TF_COND_RUNE_RESIST");
	aConditions.PushString("TF_COND_RUNE_VAMPIRE");
	aConditions.PushString("TF_COND_RUNE_REFLECT");
	aConditions.PushString("TF_COND_RUNE_PRECISION");
	aConditions.PushString("TF_COND_RUNE_AGILITY");
	aConditions.PushString("TF_COND_GRAPPLINGHOOK");
	aConditions.PushString("TF_COND_GRAPPLINGHOOK_SAFEFALL");
	aConditions.PushString("TF_COND_GRAPPLINGHOOK_LATCHED");
	aConditions.PushString("TF_COND_GRAPPLINGHOOK_BLEEDING");
	aConditions.PushString("TF_COND_AFTERBURN_IMMUNE");
	aConditions.PushString("TF_COND_RUNE_KNOCKOUT");
	aConditions.PushString("TF_COND_RUNE_IMBALANCE");
	aConditions.PushString("TF_COND_CRITBOOSTED_RUNE_TEMP");
	aConditions.PushString("TF_COND_PASSTIME_INTERCEPTION");
	aConditions.PushString("TF_COND_SWIMMING_NO_EFFECTS");
	aConditions.PushString("TF_COND_PURGATORY");
	aConditions.PushString("TF_COND_RUNE_KING");
	aConditions.PushString("TF_COND_RUNE_PLAGUE");
	aConditions.PushString("TF_COND_RUNE_SUPERNOVA");
	aConditions.PushString("TF_COND_PLAGUE");
	aConditions.PushString("TF_COND_KING_BUFFED");
	aConditions.PushString("TF_COND_TEAM_GLOWS");
	aConditions.PushString("TF_COND_KNOCKED_INTO_AIR");
	aConditions.PushString("TF_COND_COMPETITIVE_WINNER");
	aConditions.PushString("TF_COND_COMPETITIVE_LOSER");
	aConditions.PushString("TF_COND_HEALING_DEBUFF");
	aConditions.PushString("TF_COND_PASSTIME_PENALTY_DEBUFF");
	//Phew
}

public void OnClientPutInServer(int client)
{
	g_bShowConditions[client] = false;
}

public Action Command_CondList(int client, int args)
{
	if(g_bShowConditions[client])
	{
		g_bShowConditions[client] = false;
		PrintToChat(client, "[ConditionList] Off");
	}
	else
	{
		g_bShowConditions[client] = true;
		PrintToChat(client, "[ConditionList] On");
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client) || !g_bShowConditions[client])
		return Plugin_Continue;
	
	char strConds[2000];
	SetHudTextParams(1.0, 0.05, 0.1, 255, 255, 0, 0, 0, 0.0, 0.0, 0.0);
	
	int iObserved = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && TF2_GetClientTeam(client) == TFTeam_Spectator)
		Format(strConds, sizeof(strConds), "Conditions on %N\n", iObserved);
	else
		iObserved = client;

	for (int cond = 0; cond <= view_as<int>(TFCond_SpawnOutline); ++cond)
	{
		if (!TF2_IsPlayerInCondition(iObserved, view_as<TFCond>(cond)))
			continue;
		
		Address tmp = view_as<Address>(LoadFromAddress(GetEntityAddress(iObserved) + view_as<Address>(g_iCondSourceOffs), NumberType_Int32));
		Address addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (2 * 4));
		int value = LoadFromAddress(addr, NumberType_Int32);
		
		addr = view_as<Address>(view_as<int>(tmp) + (cond * COND_SOURCE_SIZE) + (3 * 4));
		int provider = LoadFromAddress(addr, NumberType_Int32) & ENT_ENTRY_MASK;
		
		//(m_Shared + 2) + 20 * condnum + 8;
		
		char condStr[PLATFORM_MAX_PATH];
		if(cond < aConditions.Length)
		{
			aConditions.GetString(cond, condStr, PLATFORM_MAX_PATH);
		}
		
		Format(strConds, sizeof(strConds), "%s %s (#%d) %.2f", strConds, condStr, cond, value);
		
		if(provider > 0 && provider <= MaxClients)
			Format(strConds, sizeof(strConds), "%s | PROVIDER %N", strConds, provider);
		
		Format(strConds, sizeof(strConds), "%s\n", strConds);
	}
	
	ShowSyncHudText(client, g_hHudInfo, "%s", strConds);
	
	return Plugin_Continue;
}
