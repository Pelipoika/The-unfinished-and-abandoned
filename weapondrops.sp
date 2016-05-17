#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <tf2items>
#include <tf2idb>

Handle g_db;
int stringTable;

Handle g_statement_GetItemModel;

public Plugin myinfo = 
{
	name = "[TF2] Weapon pickups",
	author = "Pelipoika",
	description = "",
	version = SOURCEMOD_VERSION,
	url = "http://www.sourcemod.net/"
};
	
public void OnPluginStart()
{
	char error[255];
	g_db = SQLite_UseDatabase("tf2idb", error, sizeof(error));
	if(g_db == INVALID_HANDLE)
		SetFailState(error);
	
	#define PREPARE_STATEMENT(%1,%2) %1 = SQL_PrepareQuery(g_db, %2, error, sizeof(error)); if(%1 == INVALID_HANDLE) SetFailState(error);
	
	PREPARE_STATEMENT(g_statement_GetItemModel, "SELECT model FROM tf2idb_item WHERE model IS NOT '' AND id = ?")
	
	stringTable = FindStringTable("modelprecache");

	AddCommandListener(Listener_Voice, "voicemenu");
	
	HookEvent("player_death", Event_PlayerDeath);

	RegAdminCmd("sm_drop", Command_Drop, 0);
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{		
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		char strClass[256];
		TFClassType class = TF2_GetPlayerClass(client);
		switch(class)
		{
			case TFClass_DemoMan: 	Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='demoman' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Engineer:	Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='engineer' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Heavy:		Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='heavy' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Medic: 	Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='medic' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Pyro: 		Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='pyro'  AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Scout: 	Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='scout' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Sniper:	Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='sniper' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Soldier: 	Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='soldier' AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
			case TFClass_Spy:		Format(strClass, sizeof(strClass), "SELECT a.id FROM tf2idb_item a JOIN tf2idb_class b ON a.id=b.id WHERE b.class='spy'   AND (slot='melee' OR slot='primary' OR slot='secondary') AND has_string_attribute=0");
		}
		
		Handle ItemArray = CreateArray(4);
		ItemArray = TF2IDB_FindItemCustom(strClass);
		
		int index = GetRandomInt(0, GetArraySize(ItemArray));
		char strName[64], strModel[PLATFORM_MAX_PATH];
		
		SQL_BindParamInt(g_statement_GetItemModel, 0, GetArrayCell(ItemArray, index));
		SQL_Execute(g_statement_GetItemModel);
		if(SQL_FetchRow(g_statement_GetItemModel)) 
		{
			SQL_FetchString(g_statement_GetItemModel, 0, strModel, PLATFORM_MAX_PATH);
		}
		
		TF2IDB_GetItemName(GetArrayCell(ItemArray, index), strName, sizeof(strName));
		PrintToChat(client, "You dropped: %s %i %s", strName, GetArrayCell(ItemArray, index), strModel);
		
		DropWeapon(client, GetArrayCell(ItemArray, index), strModel);
		
		delete ItemArray;
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)
{
	if(TF2IDB_GetItemSlot(iItemDefinitionIndex) != TF2ItemSlot_Melee 
	&& TF2IDB_GetItemSlot(iItemDefinitionIndex) != TF2ItemSlot_Hat
	&& TF2IDB_GetItemSlot(iItemDefinitionIndex) != TF2ItemSlot_Head
	&& TF2IDB_GetItemSlot(iItemDefinitionIndex) != TF2ItemSlot_Misc)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action Command_Drop(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		int activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(activeweapon))
		{
			int weaponindex = GetEntProp(activeweapon, Prop_Send, "m_iItemDefinitionIndex");
			
			char strModelPath[PLATFORM_MAX_PATH];
			ReadStringTable(stringTable, GetEntProp(activeweapon, Prop_Send, "m_iWorldModelIndex"), strModelPath, PLATFORM_MAX_PATH);  
			
			DropWeapon(client, weaponindex, strModelPath);
			TF2_SwitchToIdealSlot(client);
		}
	}
	
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrContains(classname, "tf_ammo_pack", true) != -1)
    {
        SDKHook(entity, SDKHook_Touch, PickedLarge);
        SDKHook(entity, SDKHook_Spawn, OnAmmoSpawn);
    }
}

public OnAmmoSpawn(int entity)
{
	if(IsValidEntity(entity) && GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != -1)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public PickedLarge(int entity, int client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		char m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString(entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
	}
}

public Action Listener_Voice(int client, char[] command, int args) 
{
	char arguments[4];
	GetCmdArgString(arguments, sizeof(arguments));
	
	if (StrEqual(arguments, "0 0"))
	{
		int target = GetClientAimTarget(client, false);
		if(IsValidEntity(target))
		{
			char sTargetName[256], sDest[2][30], strClass[TF2IDB_ITEMCLASS_LENGTH];
			GetEntPropString(target, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
			
			if(StrContains(sTargetName, "[TF2]WeaponDrops", true) != -1)
			{
				ExplodeString(sTargetName, ";", sDest, 2, 30);
				TF2IDB_GetItemClass(StringToInt(sDest[1]), strClass, TF2IDB_ITEMCLASS_LENGTH);
				
				float vecTPos[3], vecPPos[3];
				GetEntPropVector(target, Prop_Send, "m_vecOrigin", vecTPos);
				GetClientAbsOrigin(client, vecPPos);
				
				if(GetVectorDistance(vecPPos, vecTPos) <= 200.0)
				{	
					if(StrEqual(strClass, "saxxy"))
						SpawnItem(client, StringToInt(sDest[1]), false);
					else
						SpawnItem(client, StringToInt(sDest[1]), true);
					
					AcceptEntityInput(target, "Kill");

					return Plugin_Handled;
				}
			}
		}
	}

	return Plugin_Continue;
}

stock int GetSlotFromPlayerWeapon(int iClient, int iWeapon)
{
    for (new i = 0; i <= 5; i++)
    {
        if (iWeapon == GetPlayerWeaponSlot(iClient, i))
        {
            return i;
        }
    }
    
    return -1;
}  

stock int SpawnItem(int client, int index, bool forcegen = true)
{
	char hItemClassname[TF2IDB_ITEMCLASS_LENGTH];
	Handle hItem;
	int flags = OVERRIDE_ALL|PRESERVE_ATTRIBUTES;
	
	if(forcegen)
	{
		flags |= FORCE_GENERATION;
	}
	hItem = TF2Items_CreateItem(flags);
	
	TF2Items_SetFlags(hItem, flags);
	TF2IDB_GetItemClass(index, hItemClassname, sizeof(hItemClassname));
	TF2Items_SetClassname(hItem, hItemClassname);
	TF2Items_SetItemIndex(hItem, index);
	
	int minlevel, maxlevel;
	TF2IDB_GetItemLevels(index, minlevel, maxlevel);
	TF2Items_SetLevel(hItem, GetRandomInt(minlevel, maxlevel));
	TF2Items_SetQuality(hItem, (view_as<int>(TF2IDB_GetItemQuality(index))));
	
	int iAIndexes[TF2IDB_MAX_ATTRIBUTES];
	float flAValues[TF2IDB_MAX_ATTRIBUTES];
	TF2IDB_GetItemAttributes(index, iAIndexes, flAValues);
	TF2Items_SetNumAttributes(hItem, sizeof(iAIndexes));
	
	for(int a = 0; a <= TF2IDB_MAX_ATTRIBUTES - 1; a++)
	{
		if(TF2IDB_ItemHasAttribute(index, iAIndexes[a]))
		{
			TF2Items_SetAttribute(hItem, a, iAIndexes[a], flAValues[a]);
		}
	}
	
	int Item = TF2Items_GiveNamedItem(client, hItem);
	delete(hItem);
	
	TF2_RemoveWeaponSlot(client, view_as<int>(TF2IDB_GetItemSlot(index)));
	EquipPlayerWeapon(client, Item);
	
	return Item;
}

stock void DropWeapon(int client, int iItemDefinitionIndex, char[] model)
{
	char strName[64];
	Format(strName, sizeof(strName), "[TF2]WeaponDrops;%i", iItemDefinitionIndex);
	
	float vecPPos[3];
	GetClientEyePosition(client, vecPPos);

	int ent = CreateEntityByName("tf_ammo_pack");
	if (IsValidEntity(ent))
	{
		DispatchKeyValue(ent, "targetname", strName);
		DispatchKeyValueVector(ent, "origin", vecPPos);
		DispatchKeyValueVector(ent, "basevelocity", view_as<float>{0.0, 10.0, 0.0});
		DispatchKeyValueVector(ent, "velocity", view_as<float>{0.0, 10.0, 0.0});
		DispatchKeyValue(ent, "model", model);
		DispatchKeyValue(ent, "OnPlayerTouch", "!self,Kill,,0,-1"); 		
		DispatchSpawn(ent);
		
		SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
		if(TF2_GetClientTeam(client) != TFTeam_Red)
			SetEntProp(ent, Prop_Send, "m_nSkin", GetEntProp(ent, Prop_Send, "m_nSkin") + 1);
		
		char addoutput[64];
		Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::60:1");
		SetVariantString(addoutput);
		
		AcceptEntityInput(ent, "AddOutput");
		AcceptEntityInput(ent, "FireUser1");
	}
}

stock void TF2_SwitchToIdealSlot(int client)
{
	int activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(IsValidEntity(activeweapon))
	{
		int slot = GetSlotFromPlayerWeapon(client, activeweapon);
		if(slot != -1)
		{
			TF2_RemoveWeaponSlot(client, slot);
			
			char classname[64];
			int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			if (primary > MaxClients && IsValidEntity(primary) && GetEntityClassname(primary, classname, sizeof(classname)))
			{
				FakeClientCommandEx(client, "use %s", classname);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", primary);
			}
			else if (melee > MaxClients && IsValidEntity(melee) && GetEntityClassname(melee, classname, sizeof(classname)))
			{
				FakeClientCommandEx(client, "use %s", classname);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee);
			}
		}
	}
}