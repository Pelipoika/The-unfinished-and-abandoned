#include <sdktools>
//#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

#define NONE 
#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)

#define HIDEHUD_BITCOUNT			12

public Plugin myinfo = 
{
	name = "[TF2] Hud Manager",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_hud", Command_Hud);
}

public Action Command_Hud(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		DisplayHUDMenuAtItem(client);
	}
}

stock void DisplayHUDMenuAtItem(int client, int iItem = 0)
{
	Menu g_hMenuHUD = new Menu(MenuHUDHandler);
	g_hMenuHUD.SetTitle("HUD Manager : Select which elements to Display / Hide\n ");
	g_hMenuHUD.AddItem("0",  IsFlagSet(client, HIDEHUD_WEAPONSELECTION)   ? "✅ WEAPONSELECTION"   : "WEAPONSELECTION");
	g_hMenuHUD.AddItem("1",  IsFlagSet(client, HIDEHUD_FLASHLIGHT)        ? "✅ FLASHLIGHT"        : "FLASHLIGHT");
	g_hMenuHUD.AddItem("2",  IsFlagSet(client, HIDEHUD_ALL)               ? "✅ ALL"               : "ALL");
	g_hMenuHUD.AddItem("3",  IsFlagSet(client, HIDEHUD_HEALTH)            ? "✅ HEALTH"            : "HEALTH");
	g_hMenuHUD.AddItem("4",  IsFlagSet(client, HIDEHUD_PLAYERDEAD)        ? "✅ PLAYERDEAD"        : "PLAYERDEAD");
	g_hMenuHUD.AddItem("5",  IsFlagSet(client, HIDEHUD_NEEDSUIT)          ? "✅ NEEDSUIT"          : "NEEDSUIT");
	g_hMenuHUD.AddItem("6",  IsFlagSet(client, HIDEHUD_MISCSTATUS)        ? "✅ MISCSTATUS"        : "MISCSTATUS");
	g_hMenuHUD.AddItem("7",  IsFlagSet(client, HIDEHUD_CHAT)              ? "✅ CHAT"              : "CHAT");
	g_hMenuHUD.AddItem("8",  IsFlagSet(client, HIDEHUD_CROSSHAIR)         ? "✅ CROSSHAIR"         : "CROSSHAIR");
	g_hMenuHUD.AddItem("9",  IsFlagSet(client, HIDEHUD_VEHICLE_CROSSHAIR) ? "✅ VEHICLE_CROSSHAIR" : "VEHICLE_CROSSHAIR");
	g_hMenuHUD.AddItem("10", IsFlagSet(client, HIDEHUD_INVEHICLE)         ? "✅ INVEHICLE"         : "INVEHICLE");
	g_hMenuHUD.AddItem("11", IsFlagSet(client, HIDEHUD_BONUS_PROGRESS)    ? "✅ BONUS_PROGRESS"    : "BONUS_PROGRESS");
	g_hMenuHUD.DisplayAt(client, iItem, MENU_TIME_FOREVER);
}

stock bool IsFlagSet(int client, int iFlag)
{
	int HideHUD = GetEntProp(client, Prop_Send, "m_iHideHUD");
	
	if(HideHUD & iFlag)
		return true;
		
	return false;
}

public int MenuHUDHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		int HideHUD = GetEntProp(param1, Prop_Send, "m_iHideHUD");
	
		switch (param2)
		{
			case 0:  HideHUD ^= HIDEHUD_WEAPONSELECTION;
			case 1:  HideHUD ^= HIDEHUD_FLASHLIGHT;
			case 2:  HideHUD ^= HIDEHUD_ALL;
			case 3:  HideHUD ^= HIDEHUD_HEALTH;
			case 4:  HideHUD ^= HIDEHUD_PLAYERDEAD;
			case 5:  HideHUD ^= HIDEHUD_NEEDSUIT;
			case 6:  HideHUD ^= HIDEHUD_MISCSTATUS;
			case 7:  HideHUD ^= HIDEHUD_CHAT;
			case 8:  HideHUD ^= HIDEHUD_CROSSHAIR;
			case 9:  HideHUD ^= HIDEHUD_VEHICLE_CROSSHAIR;
			case 10: HideHUD ^= HIDEHUD_INVEHICLE;
			case 11: HideHUD ^= HIDEHUD_BONUS_PROGRESS;
		}
		
		SetEntProp(param1, Prop_Send, "m_iHideHUD", HideHUD);

		DisplayHUDMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}
