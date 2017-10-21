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
	aConditions.PushString("AIMING"); //0
	aConditions.PushString("ZOOMED");
	aConditions.PushString("DISGUISING");
	aConditions.PushString("DISGUISED");
	aConditions.PushString("STEALTHED");
	aConditions.PushString("INVULNERABLE"); //5
	aConditions.PushString("TELEPORTED");
	aConditions.PushString("TAUNTING");
	aConditions.PushString("INVULNERABLE_WEARINGOFF");
	aConditions.PushString("STEALTHED_BLINK");
	aConditions.PushString("SELECTED_TO_TELEPORT"); //10
	aConditions.PushString("CRITBOOSTED");
	aConditions.PushString("TMPDAMAGEBONUS");
	aConditions.PushString("FEIGN_DEATH");
	aConditions.PushString("PHASE");
	aConditions.PushString("STUNNED"); //15
	aConditions.PushString("OFFENSEBUFF");
	aConditions.PushString("SHIELD_CHARGE");
	aConditions.PushString("DEMO_BUFF");
	aConditions.PushString("ENERGY_BUFF");
	aConditions.PushString("RADIUSHEAL"); //20
	aConditions.PushString("HEALTH_BUFF");
	aConditions.PushString("BURNING");
	aConditions.PushString("HEALTH_OVERHEALED");
	aConditions.PushString("URINE");
	aConditions.PushString("BLEEDING");
	aConditions.PushString("DEFENSEBUFF");
	aConditions.PushString("MAD_MILK");
	aConditions.PushString("MEGAHEAL");
	aConditions.PushString("REGENONDAMAGEBUFF");
	aConditions.PushString("MARKEDFORDEATH"); //30
	aConditions.PushString("NOHEALINGDAMAGEBUFF");
	aConditions.PushString("SPEED_BOOST");
	aConditions.PushString("CRITBOOSTED_PUMPKIN");
	aConditions.PushString("CRITBOOSTED_USER_BUFF");
	aConditions.PushString("CRITBOOSTED_DEMO_CHARGE");
	aConditions.PushString("SODAPOPPER_HYPE");
	aConditions.PushString("CRITBOOSTED_FIRST_BLOOD");
	aConditions.PushString("CRITBOOSTED_BONUS_TIME");
	aConditions.PushString("CRITBOOSTED_CTF_CAPTURE");
	aConditions.PushString("CRITBOOSTED_ON_KILL");
	aConditions.PushString("CANNOT_SWITCH_FROM_MELEE");
	aConditions.PushString("DEFENSEBUFF_NO_CRIT_BLOCK");
	aConditions.PushString("REPROGRAMMED");
	aConditions.PushString("CRITBOOSTED_RAGE_BUFF");
	aConditions.PushString("DEFENSEBUFF_HIGH");
	aConditions.PushString("SNIPERCHARGE_RAGE_BUFF");
	aConditions.PushString("DISGUISE_WEARINGOFF");
	aConditions.PushString("MARKEDFORDEATH_SILENT");
	aConditions.PushString("DISGUISED_AS_DISPENSER");
	aConditions.PushString("SAPPED");
	aConditions.PushString("INVULNERABLE_HIDE_UNLESS_DAMAGED");
	aConditions.PushString("INVULNERABLE_USER_BUFF");
	aConditions.PushString("HALLOWEEN_BOMB_HEAD");
	aConditions.PushString("HALLOWEEN_THRILLER");
	aConditions.PushString("RADIUSHEAL_ON_DAMAGE");
	aConditions.PushString("CRITBOOSTED_CARD_EFFECT");
	aConditions.PushString("INVULNERABLE_CARD_EFFECT");
	aConditions.PushString("MEDIGUN_UBER_BULLET_RESIST");
	aConditions.PushString("MEDIGUN_UBER_BLAST_RESIST");
	aConditions.PushString("MEDIGUN_UBER_FIRE_RESIST");
	aConditions.PushString("MEDIGUN_SMALL_BULLET_RESIST");
	aConditions.PushString("MEDIGUN_SMALL_BLAST_RESIST");
	aConditions.PushString("MEDIGUN_SMALL_FIRE_RESIST");
	aConditions.PushString("STEALTHED_USER_BUFF");
	aConditions.PushString("MEDIGUN_DEBUFF");
	aConditions.PushString("STEALTHED_USER_BUFF_FADING");
	aConditions.PushString("BULLET_IMMUNE");
	aConditions.PushString("BLAST_IMMUNE");
	aConditions.PushString("FIRE_IMMUNE");
	aConditions.PushString("PREVENT_DEATH");
	aConditions.PushString("MVM_BOT_STUN_RADIOWAVE");
	aConditions.PushString("HALLOWEEN_SPEED_BOOST");
	aConditions.PushString("HALLOWEEN_QUICK_HEAL");
	aConditions.PushString("HALLOWEEN_GIANT");
	aConditions.PushString("HALLOWEEN_TINY");
	aConditions.PushString("HALLOWEEN_IN_HELL");
	aConditions.PushString("HALLOWEEN_GHOST_MODE");
	aConditions.PushString("MINICRITBOOSTED_ON_KILL");
	aConditions.PushString("OBSCURED_SMOKE");
	aConditions.PushString("PARACHUTE_DEPLOYED");
	aConditions.PushString("BLASTJUMPING");
	aConditions.PushString("HALLOWEEN_KART");
	aConditions.PushString("HALLOWEEN_KART_DASH");
	aConditions.PushString("BALLOON_HEAD");
	aConditions.PushString("MELEE_ONLY");
	aConditions.PushString("SWIMMING_CURSE");
	aConditions.PushString("FREEZE_INPUT");
	aConditions.PushString("HALLOWEEN_KART_CAGE");
	aConditions.PushString("DONOTUSE_0");
	aConditions.PushString("RUNE_STRENGTH");
	aConditions.PushString("RUNE_HASTE");
	aConditions.PushString("RUNE_REGEN");
	aConditions.PushString("RUNE_RESIST");
	aConditions.PushString("RUNE_VAMPIRE");
	aConditions.PushString("RUNE_REFLECT");
	aConditions.PushString("RUNE_PRECISION");
	aConditions.PushString("RUNE_AGILITY");
	aConditions.PushString("GRAPPLINGHOOK");
	aConditions.PushString("GRAPPLINGHOOK_SAFEFALL");
	aConditions.PushString("GRAPPLINGHOOK_LATCHED");
	aConditions.PushString("GRAPPLINGHOOK_BLEEDING");
	aConditions.PushString("AFTERBURN_IMMUNE");
	aConditions.PushString("RUNE_KNOCKOUT");
	aConditions.PushString("RUNE_IMBALANCE");
	aConditions.PushString("CRITBOOSTED_RUNE_TEMP");
	aConditions.PushString("PASSTIME_INTERCEPTION");
	aConditions.PushString("SWIMMING_NO_EFFECTS");
	aConditions.PushString("PURGATORY");
	aConditions.PushString("RUNE_KING");
	aConditions.PushString("RUNE_PLAGUE");
	aConditions.PushString("RUNE_SUPERNOVA");
	aConditions.PushString("PLAGUE");
	aConditions.PushString("KING_BUFFED");
	aConditions.PushString("TEAM_GLOWS");
	aConditions.PushString("KNOCKED_INTO_AIR");
	aConditions.PushString("COMPETITIVE_WINNER");
	aConditions.PushString("COMPETITIVE_LOSER");
	aConditions.PushString("HEALING_DEBUFF");
	aConditions.PushString("PASSTIME_PENALTY_DEBUFF");
	aConditions.PushString("PARACHUTE_DEPLOYED");
	aConditions.PushString("NO_COMBAT_SPEED_BOOST");
	aConditions.PushString("TRANQ_SPY_BOOST");
	aConditions.PushString("TRANQ_MARKED");
	aConditions.PushString("ROCKETPACK");
	aConditions.PushString("ROCKETPACK_PASSENGER");
	aConditions.PushString("STEALTHED_PHASE");
	aConditions.PushString("CLIP_OVERLOAD");
	aConditions.PushString("SPY_CLASS_STEAL");
	aConditions.PushString("GAS");
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
	SetHudTextParams(0.0, 0.3, 0.1, 255, 255, 0, 0, 0, 0.0, 0.0, 0.0);
	
	int iObserved = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && TF2_GetClientTeam(client) == TFTeam_Spectator)
		Format(strConds, sizeof(strConds), "Conditions on %N\n", iObserved);
	else
		iObserved = client;
	
	for (int cond = 0; cond <= aConditions.Length; ++cond)
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
