#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required;

/*
CREATE TABLE `tf2_mapteleports` (
	`ID` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	`LocX` VARCHAR(30) NOT NULL DEFAULT '0',
	`LocY` VARCHAR(30) NOT NULL DEFAULT '0',
	`LocZ` VARCHAR(30) NOT NULL DEFAULT '0',
	`DestX` VARCHAR(30) NOT NULL DEFAULT '0',
	`DestY` VARCHAR(30) NOT NULL DEFAULT '0',
	`DestZ` VARCHAR(30) NOT NULL DEFAULT '0',
	`map` VARCHAR(60) NOT NULL DEFAULT '0',
	PRIMARY KEY (`ID`)
)
COMMENT='Stores the positions and destinations of teleporters on a ma'
COLLATE='utf8_general_ci'
ENGINE=InnoDB
AUTO_INCREMENT=28;
*/

Handle hDatabase = INVALID_HANDLE;
float vecDestination[MAXPLAYERS+1][3];

public Plugin myinfo = 
{
	name = "[TF2] Auto Teleports",
	author = "Pelipoika",
	description = "Auto-Spawns map teleports",
	version = "1.0",
	url = "private"
}

public void OnPluginStart()
{
	SQL_TConnect(OnDatabaseConnect, "default");
	
	RegAdminCmd("sm_placetele", SeedPumpkin, ADMFLAG_ROOT);
	RegAdminCmd("sm_deletetele", DelPumpkin, ADMFLAG_ROOT);
	
	HookEvent("teamplay_round_start", EventRoundStart);
}

public void OnMapStart()
{
	PrecacheModel("models/error.mdl");
}

public void OnDatabaseConnect(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[autoteleports.smx] Database failure: %s", error);
	} 
	else 
	{
		PrintToServer("[autoteleports.smx] Succesfully connected to database");
		hDatabase = hndl;
	}
}

public void OnClientPutInServer(int client)
{
	vecDestination[client][0] = 0.0;
	vecDestination[client][1] = 0.0;
	vecDestination[client][2] = 0.0;
}

public Action SeedPumpkin(int client, int args)
{
	float pos[3];
	GetClientAbsOrigin(client, pos);

	if(vecDestination[client][0] == 0.0
	&& vecDestination[client][1] == 0.0
	&& vecDestination[client][2] == 0.0)
	{
		vecDestination[client][0] = pos[0];
		vecDestination[client][1] = pos[1];
		vecDestination[client][2] = pos[2] + 10.0;
	
		PrintToChat(client, "\x04[\x03MT\x04]\x01 Destination set to %.2f %.2f %.2f, now select a position for the teleporter.", pos[0], pos[1], pos[2]);
	}
	else
	{
		char mapname[150];
		char mapname_esc[150];
		
		GetCurrentMap(mapname, sizeof(mapname));
		SQL_EscapeString(hDatabase, mapname, mapname_esc, sizeof(mapname_esc));

		CreateTriggerMultiple(vecDestination[client], pos, view_as<float>{10.0, 10.0, 100.0}, view_as<float>{-10.0, -10.0, 0.0});
		
		int len = 0;
		char buffer[2048];
		len += Format(buffer[len], sizeof(buffer)-len, "INSERT INTO `tf2_mapteleports` (`locX`, `locY`, `locZ`, `DestX`, `DestY`, `DestZ`, `map`)");
		len += Format(buffer[len], sizeof(buffer)-len, "VALUES ('%f', '%f', '%f', '%f', '%f', '%f', '%s');", pos[0], pos[1], pos[2], vecDestination[client][0], vecDestination[client][1], vecDestination[client][2], mapname_esc);
		SQL_TQuery(hDatabase, SQLErrorCheckCallback, buffer);
		
		PrintToChat(client, "\x04[\x03MT\x04]\x01 Teleporter location added to database!");
		
		vecDestination[client][0] = 0.0;
		vecDestination[client][1] = 0.0;
		vecDestination[client][2] = 0.0;
	}
		
	return Plugin_Handled;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (!StrEqual("", error))
	{
		LogMessage("SQL Error: %s", error);
	}
}

public Action DelPumpkin(int client, int args)
{
	int iEntity;
	float EntLoc[3];
	
	iEntity = GetClientAimTarget(client, false);
	if (iEntity != -1 && iEntity != -2)
	{
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", EntLoc)
		char buffer[255]
		PrintToChat(client, "\x04[\x03MT\x04]\x01 Teleporter location deleted from database!")
		Format(buffer, sizeof(buffer), "DELETE FROM `tf2_mapteleports` WHERE `locX` = '%f' AND `locY` = '%f' AND `locZ` = '%f'", EntLoc[0], EntLoc[1], EntLoc[2])
		SQL_FastQuery(hDatabase, buffer);
	}
	return Plugin_Handled;
}

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{		
	char mapname[50];
	GetCurrentMap(mapname, sizeof(mapname))
	
	PrintCenterTextAll("[MT] Loading teleporters for map %s", mapname);
	
	char buffer[255]
	Format(buffer, sizeof(buffer), "SELECT `locX`, `locY`, `locZ`, `DestX`, `DestY`, `DestZ` FROM tf2_mapteleports WHERE `map` = '%s'", mapname)
	SQL_TQuery(hDatabase, SQL_SpawnPumpkins, buffer);
	
	return Plugin_Continue;
}

public void SQL_SpawnPumpkins(Handle owner, Handle query, const char[] error, any data)
{	
	if (!StrEqual("", error))
	{
		LogError("SQL Error: %s", error);
	}
	else 
	{
		/* Process results here!*/
		while (SQL_FetchRow(query))
		{
			float pos[3];
			pos[0] = SQL_FetchFloat(query, 0);
			pos[1] = SQL_FetchFloat(query, 1);
			pos[2] = SQL_FetchFloat(query, 2);
			
			float dest[3];
			dest[0] = SQL_FetchFloat(query, 3);
			dest[1] = SQL_FetchFloat(query, 4);
			dest[2] = SQL_FetchFloat(query, 5);
			
			CreateTriggerMultiple(dest, pos, view_as<float>{10.0, 10.0, 100.0}, view_as<float>{-10.0, -10.0, 0.0});
		}
	}
}

void CreateTriggerMultiple(float vDest[3], float vPos[3], float vMaxs[3], float vMins[3])
{
	int trigger = CreateEntityByName("trigger_multiple");
	
	char strName[128];
	Format(strName, sizeof(strName), "%f;%f;%f", vDest[0], vDest[1], vDest[2]);
	
	DispatchKeyValue(trigger, "targetname", strName);
	DispatchKeyValue(trigger, "StartDisabled", "0");
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "model", "models/error.mdl");

	DispatchKeyValueVector(trigger, "origin", vPos);
	DispatchSpawn(trigger);
	
//	SetEntityModel(trigger, "models/error.mdl");
	
	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

	AcceptEntityInput(trigger, "Enable");
	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	
	AttachParticle(trigger, "utaunt_souls_purple_base");
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(IsClientInGame(activator))
	{
		char sTargetName[256], sDest[3][30];
		GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		ExplodeString(sTargetName, ";", sDest, 3, 30);
		
		float vDest[3];
		vDest[0] = StringToFloat(sDest[0]);
		vDest[1] = StringToFloat(sDest[1]);
		vDest[2] = StringToFloat(sDest[2]);
		
		TeleportEntity(activator, vDest, NULL_VECTOR, NULL_VECTOR);
	}
}

stock bool AttachParticle(int Ent, char[] particleType)
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEdict(particle)) return false;
	
	float f_pos[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", f_pos);

	TeleportEntity(particle, f_pos, NULL_VECTOR, NULL_VECTOR);

	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	
	return true;
}