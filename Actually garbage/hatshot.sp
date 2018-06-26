#include <sdkhooks>
#include <tf2_stocks>
#include <tf2idb>

#pragma newdecls required

Handle g_db;
Handle g_hCanDrop;

public Plugin myinfo = 
{
	name = "[TF2] Hat shots",
	author = "Pelipoika",
	description = "Shooting a player wearing a hat causes them to drop it",
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
	PREPARE_STATEMENT(g_hCanDrop, "SELECT drop_type FROM tf2idb_item WHERE id = ?")

	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			SDKHook(client, SDKHook_TraceAttack, TraceAttack);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttackPost, TraceAttack);
}

public Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) 
	&& victim > 0 && victim <= MaxClients && IsClientInGame(victim)
	&& hitgroup == 1 && TF2_GetPlayerClass(attacker) == TFClass_Sniper && IsPlayerAlive(victim))
	{
		int weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(weapon))
		{
			float flDamage = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");
			if(flDamage >= 0)
			{
				int iHat = TF2IDB_FindPlayerHat(victim);
				if(IsValidEntity(iHat))
				{
					int iItemIndex = GetEntProp(iHat, Prop_Send, "m_iItemDefinitionIndex");
					
				//	PrintToChatAll("CanDrop (%i) %s", iItemIndex, TF2IDB_CanDrop(iItemIndex) ? "true" : "false");
					
					if(TF2IDB_CanDrop(iItemIndex))
					{					
						char strModelPath[PLATFORM_MAX_PATH];
						GetEntPropString(iHat, Prop_Data, "m_ModelName", strModelPath, PLATFORM_MAX_PATH);
					
						float flPos[3], flAng[3];
						GetClientEyePosition(victim, flPos);
						GetClientEyeAngles(victim, flAng);
						
						TF2_RemoveWearable(victim, iHat);
						AcceptEntityInput(iHat, "Kill");
						
						int ent = CreateEntityByName("tf_ammo_pack");
						if (IsValidEntity(ent))
						{
							PrecacheModel(strModelPath);
							DispatchKeyValueVector(ent, "origin", flPos);
							DispatchKeyValueVector(ent, "angles", flAng);
							DispatchKeyValueVector(ent, "basevelocity", view_as<float>{0.0, 30.0, 0.0});
							DispatchKeyValueVector(ent, "velocity", view_as<float>{0.0, 10.0, 0.0});
							DispatchKeyValue(ent, "model", strModelPath);
							DispatchKeyValue(ent, "OnPlayerTouch", "!self,Kill,,0,-1"); 		
							DispatchSpawn(ent);
							
							SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
							if(TF2_GetClientTeam(victim) != TFTeam_Red)
								SetEntProp(ent, Prop_Send, "m_nSkin", GetEntProp(ent, Prop_Send, "m_nSkin") + 1);
							
							char addoutput[64];
							Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::60:1");
							SetVariantString(addoutput);
							
							AcceptEntityInput(ent, "AddOutput");
							AcceptEntityInput(ent, "FireUser1");
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

stock int TF2IDB_FindPlayerHat(int client)
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "tf_wearable")) != -1) 
	{
		if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == client 
		&& TF2IDB_GetItemSlot(GetEntProp(iEnt, Prop_Send, "m_iItemDefinitionIndex")) == TF2ItemSlot_Hat) 
		{
			return iEnt;
		}
	}
	
	return iEnt;
}

stock bool TF2IDB_CanDrop(int iItemDefIndex)
{
	SQL_BindParamInt(g_hCanDrop, 0, iItemDefIndex);
	SQL_Execute(g_hCanDrop);
	
	if(SQL_FetchRow(g_hCanDrop))
	{
		char strDropType[8];
		SQL_FetchString(g_hCanDrop, 0, strDropType, sizeof(strDropType));
		
		if(StrEqual(strDropType, "drop"))
		{
			return true;
		}
	}
	
	return false;
}