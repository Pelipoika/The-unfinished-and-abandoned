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
		
		switch(cond)
		{
			case 0: Format(strConds, sizeof(strConds), "%s%d | SLOWED %.2f", strConds, cond, value);
			case 1: Format(strConds, sizeof(strConds), "%s%d | ZOOMED %.2f", strConds, cond, value);
			case 2: Format(strConds, sizeof(strConds), "%s%d | DISGUISING %.2f", strConds, cond, value);
			case 3: Format(strConds, sizeof(strConds), "%s%d | DISGUISED %.2f", strConds, cond, value);
			case 4: Format(strConds, sizeof(strConds), "%s%d | CLOAKED %.2f", strConds, cond, value);
			case 5: Format(strConds, sizeof(strConds), "%s%d | UBERCHARGED %.2f", strConds, cond, value);
			case 6: Format(strConds, sizeof(strConds), "%s%d | TELEPORTED %.2f", strConds, cond, value);
			case 7: Format(strConds, sizeof(strConds), "%s%d | TAUNTING %.2f", strConds, cond, value);
			case 8: Format(strConds, sizeof(strConds), "%s%d | UBERCHARGE FADING %.2f", strConds, cond, value);
			case 10: Format(strConds, sizeof(strConds), "%s%d | TELEPORTING %.2f", strConds, cond, value);
			case 11: Format(strConds, sizeof(strConds), "%s%d | KRITZKRIEGED %.2f", strConds, cond, value);
			case 15: Format(strConds, sizeof(strConds), "%s%d | STUNNED %.2f", strConds, cond, value);
			case 16: Format(strConds, sizeof(strConds), "%s%d | BUFF BANNER %.2f", strConds, cond, value);
			case 21: Format(strConds, sizeof(strConds), "%s%d | HEALED %.2f", strConds, cond, value);
			case 22: Format(strConds, sizeof(strConds), "%s%d | ON FIRE %.2f", strConds, cond, value);
			case 23: Format(strConds, sizeof(strConds), "%s%d | OVERHEALED %.2f", strConds, cond, value);
			case 24: Format(strConds, sizeof(strConds), "%s%d | JARATED %.2f", strConds, cond, value);
			case 25: Format(strConds, sizeof(strConds), "%s%d | BLEEDING %.2f", strConds, cond, value);
			case 28: Format(strConds, sizeof(strConds), "%s%d | MEGAHEAL %.2f", strConds, cond, value);
			case 29: Format(strConds, sizeof(strConds), "%s%d | CONCHEROR %.2f", strConds, cond, value);
			case 32: Format(strConds, sizeof(strConds), "%s%d | WHIPPED %.2f", strConds, cond, value);
			case 42: Format(strConds, sizeof(strConds), "%s%d | DEFENCE BUFF NO CRIT BLOCK %.2f", strConds, cond, value);
			case 48: Format(strConds, sizeof(strConds), "%s%d | MARKED FOR DEATH %.2f", strConds, cond, value);
			case 50: Format(strConds, sizeof(strConds), "%s%d | SAPPED %.2f", strConds, cond, value);
			case 51: Format(strConds, sizeof(strConds), "%s%d | UBERCHARGED HIDDEN %.2f", strConds, cond, value);
			case 71: Format(strConds, sizeof(strConds), "%s%d | RADIOWAVE %.2f", strConds, cond, value);
			case 81: Format(strConds, sizeof(strConds), "%s%d | BLAST JUMPING %.2f", strConds, cond, value);
			default: Format(strConds, sizeof(strConds), "%s%d %.2f", strConds, cond, value);
		}
		
		if(provider > 0 && provider <= MaxClients)
			Format(strConds, sizeof(strConds), "%s | PROVIDER %N", strConds, provider);
		
		Format(strConds, sizeof(strConds), "%s\n", strConds);
	}
	
	ShowSyncHudText(client, g_hHudInfo, "%s", strConds);
	
	return Plugin_Continue;
}
