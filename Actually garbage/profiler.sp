#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

Handle hAdminMenu = INVALID_HANDLE;

int g_iTarget[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[ANY] Profiler",
	author = "Pelipoika",
	description = "Player profiler.",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	AddCommandListener(Command_Kill, "kill");
	AddCommandListener(Command_Kill, "explode");
	
	RegConsoleCmd("sm_profile", Cmd_Profiler, "Opens player profiler");
	RegAdminCmd("sm_jail", Cmd_Jail, ADMFLAG_ROOT, "Jail a player");
}

public Action Cmd_Profiler(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		Menu menu = CreateMenu(MenuProfilerHandler);
		menu.SetTitle("Player profile");
		for(int i = 0; i <= MaxClients; i++)
		{
			if(i > 0 && i <= MaxClients && IsClientInGame(i) && !IsFakeClient(i))
			{
				char info[8], display[32];
				Format(info, sizeof(info), "%i", i);
				Format(display, sizeof(display), "%N", i);
				menu.AddItem(info, display);
			}
		}
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public Action Command_Kill(int client, const char[] command, int  argc) 
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(TF2_IsPlayerInCondition(client, TFCond_HalloweenKartCage))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action Cmd_Jail(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		Menu menu = CreateMenu(MenuJailHandler);
		menu.SetTitle("Jail player");
		AddTargetsToMenu(menu, client, true, true);
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public MenuJailHandler(Handle hMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char idStr[8];
		GetMenuItem(hMenu, option, idStr, sizeof(idStr));
		int target = GetClientOfUserId(StringToInt(idStr));
		
		if(target > 0 && target <= MaxClients && IsClientInGame(target))
		{
			g_iTarget[client] = target;
			
			Menu menu = CreateMenu(MenuHandler_JailTime);
			char title[100];
			Format(title, sizeof(title), "Jail player : %N", target);
			menu.SetTitle(title);		
			menu.AddItem("30.0",	"30 Seconds");
			menu.AddItem("60.0",	"1 Minute");
			menu.AddItem("120.0",	"2 Minutes");
			menu.AddItem("180.0",	"3 Minutes");
			menu.AddItem("240.0",	"4 Minutes");
			menu.AddItem("300.0",	"5 minutes");
			menu.ExitBackButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			PrintToChat(client, "[SM] Player no longer valid");
			Cmd_Jail(client, client);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
	}
}

public MenuHandler_JailTime(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		float jailtime = StringToFloat(info);

		PrintToChat(g_iTarget[param1], "[SM] %N jailed you for %f seconds", param1, jailtime);
		TF2_AddCondition(g_iTarget[param1], TFCond_HalloweenKartCage, jailtime, param1);

		g_iTarget[param1] = -1;
	}
}

public MenuProfilerHandler(Handle hMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char idStr[8];
		GetMenuItem(hMenu, option, idStr, sizeof(idStr));
		int target = StringToInt(idStr);
		
		if(target > 0 && target <= MaxClients && IsClientInGame(target))
		{
			char Steam2[32], Steam3[32], SteamID64[32];
			GetClientAuthId(target, AuthId_Steam2, Steam2, 32);
			GetClientAuthId(target, AuthId_Steam3, Steam3, 32);
			GetClientAuthId(target, AuthId_SteamID64, SteamID64, 32);
			
			Menu menu = CreateMenu(MenuJUSTDOIT);
			menu.SetTitle("Player profiler\n \nSteam2: %s\nSteam3: %s\nSteamID64: %s\n\n\n ", Steam2, Steam3, SteamID64);
			menu.AddItem(SteamID64, "Open Steam Profile");
			menu.ExitBackButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			PrintToChat(client, "[SM] Player no longer valid");
			Cmd_Profiler(client, client);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
	}
}

public MenuJUSTDOIT(Handle hMenu, MenuAction action, int client, int option)
{
	if(action == MenuAction_Select)
	{
		char SteamID64[32], url[256];
		GetMenuItem(hMenu, option, SteamID64, sizeof(SteamID64));
		Format(url, 255, "http://steamcommunity.com/profiles/%s", SteamID64);
		
		PrintToChat(client, "%s", url);
		
		Handle Kv = CreateKeyValues("motd");
		KvSetString(Kv, "title", "Profile");
		KvSetNum(Kv, "type", MOTDPANEL_TYPE_URL);
		KvSetString(Kv, "msg", url);
		KvSetNum(Kv, "customsvr", 1);

		ShowVGUIPanel(client, "info", Kv);
		CloseHandle(Kv);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
	}
}

public OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
	{
		hAdminMenu = INVALID_HANDLE;
	}
}

public void OnAdminMenuReady(Handle hTopMenu)
{
	if(hTopMenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = hTopMenu;
	
	TopMenuObject TopMenuPlayerCommands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);
	if(TopMenuPlayerCommands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hAdminMenu, "Player Profiler", TopMenuObject_Item, AdminMenu_Profiler, TopMenuPlayerCommands, "sm_profile", 0);
		AddToTopMenu(hAdminMenu, "Jail player", TopMenuObject_Item, AdminMenu_Jailer, TopMenuPlayerCommands, "sm_jail", ADMFLAG_ROOT);
	}
}

public AdminMenu_Profiler(Handle topmenu, TopMenuAction:action, TopMenuObject:object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Profile player");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		Cmd_Profiler(param, 0);
	//	DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_Jailer(Handle topmenu, TopMenuAction:action, TopMenuObject:object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Jail player");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		Cmd_Jail(param, 0);
	//	DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}