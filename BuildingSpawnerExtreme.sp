#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

Handle g_hMainMenu = INVALID_HANDLE;
Handle g_hSentryMenu = INVALID_HANDLE;
Handle g_hDispenserMenu = INVALID_HANDLE;
Handle g_hTeleporterMenu = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "[TF2] BuildingSpawnerExtreme",
	author = "Pelipoika",
	description = "Now just stop trying to mess with my contraptions!",
	version = "3.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_sbuildex", BuildMenuCMD, ADMFLAG_ROOT);
	
	g_hMainMenu = CreateMenu(MenuMainHandler);
	SetMenuTitle(g_hMainMenu, "Building Spawner Extreme");
	AddMenuItem(g_hMainMenu, "1", "Sentries");
	AddMenuItem(g_hMainMenu, "2", "Dispensers");
	AddMenuItem(g_hMainMenu, "3", "Teleporters");

	g_hSentryMenu = CreateMenu(MenuSentryHandler);
	SetMenuTitle(g_hSentryMenu, "Sentries");
	AddMenuItem(g_hSentryMenu, "1", "Sentry Level 1");
	AddMenuItem(g_hSentryMenu, "2", "Sentry Level 2");
	AddMenuItem(g_hSentryMenu, "3", "Sentry Level 3");
	AddMenuItem(g_hSentryMenu, "4", "Mini Sentry Level 1");
	AddMenuItem(g_hSentryMenu, "5", "Mini Sentry Level 2");
	AddMenuItem(g_hSentryMenu, "6", "Mini Sentry Level 3");
	AddMenuItem(g_hSentryMenu, "7", "Disposable Sentry Level 1");
	AddMenuItem(g_hSentryMenu, "8", "Disposable Sentry Level 2");
	AddMenuItem(g_hSentryMenu, "9", "Disposable Sentry Level 3");
	SetMenuExitBackButton(g_hSentryMenu, true); 
	
	g_hDispenserMenu = CreateMenu(MenuDispenserHandler);
	SetMenuTitle(g_hDispenserMenu, "Dispensers");
	AddMenuItem(g_hDispenserMenu, "1", "Dispenser Level 1");
	AddMenuItem(g_hDispenserMenu, "2", "Dispenser Level 2");
	AddMenuItem(g_hDispenserMenu, "3", "Dispenser Level 3");
	SetMenuExitBackButton(g_hDispenserMenu, true); 
	
	g_hTeleporterMenu = CreateMenu(MenuTeleportHandler);
	SetMenuTitle(g_hTeleporterMenu, "Teleporters");
	AddMenuItem(g_hTeleporterMenu, "1", "Teleporter Entrance Level 1");
	AddMenuItem(g_hTeleporterMenu, "2", "Teleporter Entrance Level 2");
	AddMenuItem(g_hTeleporterMenu, "3", "Teleporter Entrance Level 3");
	AddMenuItem(g_hTeleporterMenu, "4", "Teleporter Exit Level 1");
	AddMenuItem(g_hTeleporterMenu, "5", "Teleporter Exit Level 2");
	AddMenuItem(g_hTeleporterMenu, "6", "Teleporter Exit Level 3");
	SetMenuExitBackButton(g_hTeleporterMenu, true); 
}

public int MenuMainHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		switch (param2)
		{
			case 0:	DisplayMenuSafely(g_hSentryMenu, param1);
			case 1: DisplayMenuSafely(g_hDispenserMenu, param1);
			case 2: DisplayMenuSafely(g_hTeleporterMenu, param1);
		}
	}
}

public int MenuSentryHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		float flAng[3];
		GetClientEyeAngles(param1, flAng);
		flAng[0] = 0.0;
		
		float flSpawn[3];
		if(!GetAimPos(param1, flSpawn))
		{
			PrintToChat(param1, "[SM] Could not find spawn point.");
			return;
		}

		switch (param2)
		{
			case 0:	SpawnSentry(param1, flSpawn, flAng, "0", false);
			case 1: SpawnSentry(param1, flSpawn, flAng, "1", false);
			case 2: SpawnSentry(param1, flSpawn, flAng, "2", false);
			
			case 3:	SpawnSentry(param1, flSpawn, flAng, "0", true);
			case 4: SpawnSentry(param1, flSpawn, flAng, "1", true);
			case 5: SpawnSentry(param1, flSpawn, flAng, "2", true);
			
			case 6:	SpawnSentry(param1, flSpawn, flAng, "0", false, true);
			case 7: SpawnSentry(param1, flSpawn, flAng, "1", false, true);
			case 8: SpawnSentry(param1, flSpawn, flAng, "2", false, true);
		}
		
		DisplayMenuSafely(g_hSentryMenu, param1);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        DisplayMenuSafely(g_hMainMenu, param1);
    }
}

public int MenuDispenserHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		float flAng[3];
		GetClientEyeAngles(param1, flAng);
		flAng[0] = 0.0;
		
		float flSpawn[3];
		if(!GetAimPos(param1, flSpawn))
		{
			PrintToChat(param1, "[SM] Could not find spawn point.");
			return;
		}

		switch (param2)
		{
			case 0:	SpawnDispenser(param1, flSpawn, flAng, "0");
			case 1: SpawnDispenser(param1, flSpawn, flAng, "1");
			case 2: SpawnDispenser(param1, flSpawn, flAng, "2");
		}
		
		DisplayMenuSafely(g_hDispenserMenu, param1);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        DisplayMenuSafely(g_hMainMenu, param1);
    }
}

public int MenuTeleportHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		float flAng[3];
		GetClientEyeAngles(param1, flAng);
		flAng[0] = 0.0;
		
		float flSpawn[3];
		if(!GetAimPos(param1, flSpawn))
		{
			PrintToChat(param1, "[SM] Could not find spawn point.");
			return;
		}

		switch (param2)
		{
			case 0:	SpawnTeleporter(param1, flSpawn, flAng, "0", TFObjectMode_Entrance);
			case 1: SpawnTeleporter(param1, flSpawn, flAng, "1", TFObjectMode_Entrance);
			case 2: SpawnTeleporter(param1, flSpawn, flAng, "2", TFObjectMode_Entrance);
			
			case 3:	SpawnTeleporter(param1, flSpawn, flAng, "0", TFObjectMode_Exit);
			case 4: SpawnTeleporter(param1, flSpawn, flAng, "1", TFObjectMode_Exit);
			case 5: SpawnTeleporter(param1, flSpawn, flAng, "2", TFObjectMode_Exit);
		}
		
		DisplayMenuSafely(g_hTeleporterMenu, param1);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        DisplayMenuSafely(g_hMainMenu, param1);
    }
}

public Action BuildMenuCMD(int client, int args)
{
	if (IsValidClient(client))
		DisplayMenuSafely(g_hMainMenu, client);
		
	return Plugin_Handled;
}

stock void SpawnSentry(int builder, float Position[3], float Angle[3], char[] level = "0", bool mini = false, bool disposable = false, char[] flags = "4")
{
	static const float m_vecMinsMini[3] = {-15.0, -15.0, 0.0}, m_vecMaxsMini[3] = {15.0, 15.0, 49.5};
	static const float m_vecMinsDisp[3] = {-13.0, -13.0, 0.0}, m_vecMaxsDisp[3] = {13.0, 13.0, 42.9};
	
	int sentry = CreateEntityByName("obj_sentrygun");
	
	AcceptEntityInput(sentry, "SetBuilder", builder);
	
	DispatchKeyValueVector(sentry, "origin", Position);
	DispatchKeyValueVector(sentry, "angles", Angle);
	DispatchKeyValue(sentry, "defaultupgrade", level);
	DispatchKeyValue(sentry, "spawnflags", flags);
	SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
	
	if(mini || disposable)
	{
		SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
		SetEntProp(sentry, Prop_Send, "m_nSkin", StringToInt(level) == 0 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
	}
	
	if(mini)
	{
		DispatchSpawn(sentry);
		
		SetVariantInt(100);
		AcceptEntityInput(sentry, "SetHealth");
		
		SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.75);
		SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsMini);
		SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsMini);
	}
	else if(disposable)
	{
		SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
		DispatchSpawn(sentry);
		
		SetVariantInt(100);
		AcceptEntityInput(sentry, "SetHealth");
		
		SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.60);
		SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsDisp);
		SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsDisp);
	}
	else
	{
		SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
		DispatchSpawn(sentry);
	}
}

stock void SpawnDispenser(int builder, float Position[3], float Angle[3], char[] level = "0", char[] flags = "4")
{
	int dispenser = CreateEntityByName("obj_dispenser");
	
	DispatchKeyValueVector(dispenser, "origin", Position);
	DispatchKeyValueVector(dispenser, "angles", Angle);
	DispatchKeyValue(dispenser, "defaultupgrade", level);
	DispatchKeyValue(dispenser, "spawnflags", flags);
	SetEntProp(dispenser, Prop_Send, "m_bBuilding", 1);
	DispatchSpawn(dispenser);

	SetVariantInt(GetClientTeam(builder));
	AcceptEntityInput(dispenser, "SetTeam");
	SetEntProp(dispenser, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
	
	ActivateEntity(dispenser);
	
	AcceptEntityInput(dispenser, "SetBuilder", builder);
}

stock void SpawnTeleporter(int builder, float Position[3], float Angle[3], char[] level = "0", TFObjectMode mode, char[] flags = "4")
{
	int teleporter = CreateEntityByName("obj_teleporter");
	
	DispatchKeyValueVector(teleporter, "origin", Position);
	DispatchKeyValueVector(teleporter, "angles", Angle);
	DispatchKeyValue(teleporter, "defaultupgrade", level);
	DispatchKeyValue(teleporter, "spawnflags", flags);
	
	SetEntProp(teleporter, Prop_Send, "m_bBuilding", 1);
	SetEntProp(teleporter, Prop_Data, "m_iTeleportType", mode);
	SetEntProp(teleporter, Prop_Send, "m_iObjectMode", mode);
	SetEntProp(teleporter, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
	DispatchSpawn(teleporter);
	
	AcceptEntityInput(teleporter, "SetBuilder", builder);
	
	SetVariantInt(GetClientTeam(builder));
	AcceptEntityInput(teleporter, "SetTeam");
}

stock void DisplayMenuSafely(Handle menu, int client)
{
	if(IsValidClient(client))
	{
		if(menu == INVALID_HANDLE)
		{
			PrintToConsole(client, "ERROR: Unable to open Menu.");
		}
		else
		{
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
	}
}

public void OnMapEnd()
{
	delete g_hMainMenu;
	delete g_hSentryMenu;
	delete g_hDispenserMenu;
	delete g_hTeleporterMenu;
}

stock bool GetAimPos(int client, float vecPos[3])
{
	float StartOrigin[3], Angles[3];
	GetClientEyeAngles(client, Angles);
	GetClientEyePosition(client, StartOrigin);

	Handle TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_ALL, RayType_Infinite, ExcludeFilter, client);
	if (TR_DidHit(TraceRay))
	{
		TR_GetEndPosition(vecPos, TraceRay);
	}
	
	delete TraceRay;
	
	return true;
}

public bool ExcludeFilter(int entityhit, int mask, any entity)
{
	if (entityhit > MaxClients && entityhit != entity)
	{
		return true;
	}
	
	return false;
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	return IsClientInGame(client);
}