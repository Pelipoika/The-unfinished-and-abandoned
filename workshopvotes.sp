#include <SteamWorks>
#include <sdktools>

bool g_bCanChangeMap = true;
int g_iSelectPos[MAXPLAYERS+1];
char g_strSelectGamemode[MAXPLAYERS+1][32];

ArrayList g_hMaps;
Menu g_hGamemodeMenu;

public Plugin myinfo = 
{
	name = "[TF2] Map Workshop Votes",
	author = "Pelipoika",
	description = "Downloads WorkshopMapData",
	version = "1.0",
	url = ""
};

//TODO Add NEW to new maps
 
//SetEntityFlags(iClient, GetEntityFlags(iClient) | FL_FAKECLIENT);
//SetEntityFlags(iClient, GetEntityFlags(iCient) &= ~FL_FAKECLIENT);

public void OnPluginStart()
{
	g_hMaps = CreateArray(64);

	g_hGamemodeMenu = CreateMenu(MenuGamemodeHandler);
	g_hGamemodeMenu.SetTitle("[WorkshopMaps] Select Gamemode\n ");
	g_hGamemodeMenu.AddItem("PL", "Payload");
	g_hGamemodeMenu.AddItem("PLR", "Payload Race");
	g_hGamemodeMenu.AddItem("CP", "Control Point");
	g_hGamemodeMenu.AddItem("AD", "Attack/Defence");
	g_hGamemodeMenu.AddItem("CTF", "Capture the Flag");
	g_hGamemodeMenu.AddItem("ARENA", "Arena");
	g_hGamemodeMenu.AddItem("KOTH", "King of the Hill");
	g_hGamemodeMenu.AddItem("SD", "Special Delivery");
	g_hGamemodeMenu.AddItem("MEDIEVAL", "Medieval");
	g_hGamemodeMenu.AddItem("SPECIALITY", "Speciality");
	g_hGamemodeMenu.AddItem("PASS", "Pass Time");
	g_hGamemodeMenu.AddItem("MANNPOWER", "Mannpower");
	g_hGamemodeMenu.AddItem("MVM", "Mann vs. Machine");
	g_hGamemodeMenu.AddItem("RD", "Robot Destruction");
	g_hGamemodeMenu.ExitButton = true;

	RegAdminCmd("sm_showmaps", Command_ShowMaps, ADMFLAG_BAN);
	RegAdminCmd("sm_installmap", Command_ManualMap, ADMFLAG_BAN);
}
 
public void OnMapStart() 
{
	Workshop_GetMaps();
	
	g_bCanChangeMap = true;
}

stock void Workshop_GetMaps()
{
	Handle hDLPack = CreateDataPack();
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, "http://82.197.11.167:3000/workshopdata");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, 10);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamWorksHTTPComplete);
	SteamWorks_SetHTTPRequestContextValue(hRequest, hDLPack);
	SteamWorks_SendHTTPRequest(hRequest);
}

public OnSteamWorksHTTPComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any hDLPack)
{
	ResetPack(hDLPack);
	CloseHandle(hDLPack);
	
	if (bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		SteamWorks_WriteHTTPResponseBodyToFile(hRequest, "WorkshopData.txt");
		ParseMaps();
	}
	else
	{
		char sError[256];
		FormatEx(sError, sizeof(sError), "SteamWorks error (status code %i). Request successful: %s", _:eStatusCode, bRequestSuccessful ? "True" : "False");
	}
	
	CloseHandle(hRequest);
}

public Action Command_ManualMap(int client, int argc)
{
	char strID[64];
	GetCmdArgString(strID, sizeof(strID));
	
	Workshop_DownloadAndChangeMap(StringToInt(strID));
	PrintToChatAll("[WorkshopMaps] Preparing manually added map %s", strID);
}

public Action Command_ShowMaps(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		g_hGamemodeMenu.Display(client, MENU_TIME_FOREVER);
	}

	return Plugin_Handled;
}

stock void DisplayMapMenu(int client, const char[] gamemode, int page = 0)
{
	Menu manu = new Menu(Menu_Maps);
	manu.SetTitle("%s maps\n ", gamemode);
	
	for(int i = 0; i < g_hMaps.Length; i += 5)
	{
		char strGameMode[32]; 
		g_hMaps.GetString(i + 4, strGameMode, sizeof(strGameMode));

		if(StrEqual(gamemode, strGameMode) || StrEqual(gamemode, ""))
		{
			char display[526], rating[18];
			char strID[32], strRating[32], strMaker[32], strMapname[256]; 
			
			g_hMaps.GetString(i, 	 strID,			sizeof(strID));
			g_hMaps.GetString(i + 1, strRating,		sizeof(strRating));
			g_hMaps.GetString(i + 2, strMaker,		sizeof(strMaker));
			g_hMaps.GetString(i + 3, strMapname,	sizeof(strMapname));
			g_hMaps.GetString(i + 4, strGameMode,	sizeof(strGameMode));
			
			switch(StringToInt(strRating))
			{
				case 0: Format(rating, sizeof(rating), "☆☆☆☆☆");
				case 1: Format(rating, sizeof(rating), "★☆☆☆☆");
				case 2: Format(rating, sizeof(rating), "★★☆☆☆");
				case 3: Format(rating, sizeof(rating), "★★★☆☆");
				case 4: Format(rating, sizeof(rating), "★★★★☆");
				case 5: Format(rating, sizeof(rating), "★★★★★");
			}
			
			Format(display, sizeof(display), "%s\nBy: %s\n%s", strMapname, strMaker, rating);
			manu.AddItem(strID, display);
		}
	}
	
	manu.ExitBackButton = true;
	manu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMapInfoMenu(int client, char[] strID, char[] strRating, char[] strMaker, char[] strMapname, char[] strGamemode)
{
	char display[526], rating[18];
	
	switch(StringToInt(strRating))
	{
		case 0: Format(rating, sizeof(rating), "☆☆☆☆☆");
		case 1: Format(rating, sizeof(rating), "★☆☆☆☆");
		case 2: Format(rating, sizeof(rating), "★★☆☆☆");
		case 3: Format(rating, sizeof(rating), "★★★☆☆");
		case 4: Format(rating, sizeof(rating), "★★★★☆");
		case 5: Format(rating, sizeof(rating), "★★★★★");
	}
	
	Menu menu = CreateMenu(Menu_MapDo);
	Format(display, sizeof(display), "WorkshopMaps\n \nMap: %s\nGamemode: %s\nBy: %s\n%s\n ", strMapname, strGamemode, strMaker, rating);
	menu.SetTitle(display);
	menu.AddItem(strID, "Open map Workshop page");
	Format(display, sizeof(display), "Change level to: %s", strMapname);
	menu.AddItem(strID, display);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuGamemodeHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char strGamemode[32];
		GetMenuItem(menu, param2, strGamemode, sizeof(strGamemode));
		
		DisplayMapMenu(param1, strGamemode);
	}
}

public int Menu_Maps(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(g_bCanChangeMap)
		{
			char strID[64], strRating[64], strMaker[64], strGamemode[64], strMapname[256]; 
			GetMenuItem(menu, param2, strID, sizeof(strID));
			
			FindRating(strID, strRating, sizeof(strRating));
			FindMaker(strID, strMaker, sizeof(strMaker));
			FindMapname(strID, strMapname, sizeof(strMapname));
			FindGamemode(strID, strGamemode, sizeof(strGamemode));

			g_iSelectPos[param1] = GetMenuSelectionPosition();
			
			Format(g_strSelectGamemode[param1], 32, "%s", strGamemode);
			
			DisplayMapInfoMenu(param1, strID, strRating, strMaker, strMapname, strGamemode);
		}
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		g_hGamemodeMenu.Display(param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_MapDo(Handle menu, MenuAction action, int param1, int param2)
{
	char strID[32], strRating[32], strMaker[32], strGamemode[32], strMapname[256]; 

	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, strID, sizeof(strID));
		
		FindRating(strID, strRating, sizeof(strRating));
		FindMaker(strID, strMaker, sizeof(strMaker));
		FindMapname(strID, strMapname, sizeof(strMapname));
		FindGamemode(strID, strGamemode, sizeof(strGamemode));
	
		switch(param2)
		{
			case 0:
			{
				char url[256];
				Format(url, 255, "http://steamcommunity.com/sharedfiles/filedetails/?id=%s", strID);
				
				KeyValues kv = CreateKeyValues("motd");
				kv.SetString("title", "Profile");
				kv.SetNum("type", MOTDPANEL_TYPE_URL);
				kv.SetString("msg", url);
				kv.SetNum("customsvr", 1);
		
				ShowVGUIPanel(param1, "info", kv);
				delete kv;
			}
			case 1:
			{
				Workshop_DownloadAndChangeMap(StringToInt(strID));
				PrintToChatAll("[WorkshopMaps] Preparing map %s rated %s stars by %s", strMapname, strRating, strMaker);
			}
		}

		DisplayMapInfoMenu(param1, strID, strRating, strMaker, strMapname, strGamemode);
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayMapMenu(param1, g_strSelectGamemode[param1], g_iSelectPos[param1]);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

stock void Workshop_DownloadAndChangeMap(int iWorkshopID)
{
	ServerCommand("tf_workshop_map_sync %i", iWorkshopID);
	
	CreateTimer(2.0, Timer_CheckDownload, iWorkshopID, TIMER_FLAG_NO_MAPCHANGE);

	g_bCanChangeMap = false;
}

public Action Timer_CheckDownload(Handle timer, any data)
{
	char strStatus[4098];
	ServerCommandEx(strStatus, sizeof(strStatus), "tf_workshop_map_status");

	if(StrContains(strStatus, "downloading") != -1 || StrContains(strStatus, "refreshing") != -1)
	{
		CreateTimer(1.0, Timer_CheckDownload, data, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChatAll("[WorkshopMaps] Download Finished, Changing map...");
		CreateTimer(3.0, Timer_ChangeMap, data, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ChangeMap(Handle timer, any data)
{
	char map[PLATFORM_MAX_PATH];
	Format(map, PLATFORM_MAX_PATH, "workshop/%i", data);
	ForceChangeLevel(map, "[WorkshopMaps] Map change");
}

stock bool FindRating(char[] id, char[] rating, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 1, rating, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindMaker(char[] id, char[] maker, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 2, maker, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindMapname(char[] id, char[] mapname, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 3, mapname, maxlength);
		
		return true;
	}

	return false;
}

stock bool FindGamemode(char[] id, char[] gamemode, int maxlength)
{
	int i = g_hMaps.FindString(id);
	if(i != -1)
	{
		g_hMaps.GetString(i + 4, gamemode, maxlength);
		
		return true;
	}

	return false;
}

stock void ParseMaps()
{
	g_hMaps.Clear();

	KeyValues kvConfig = new KeyValues("WorkshopData");
	
	if (!FileToKeyValues(kvConfig, "WorkshopData.txt")) 
		SetFailState("Error while parsing the workshop file.");
		
	kvConfig.SetEscapeSequences(true);
	kvConfig.GotoFirstSubKey(true);
	
	int iCount = 0, iBadCount = 0;
	
	do
	{
		char strID[32], strRating[32], strMaker[32], strMapname[256], strGameMode[32]; 
		kvConfig.GetString("id",		strID, 		sizeof(strID));
		kvConfig.GetString("rating",	strRating,	sizeof(strRating));
		kvConfig.GetString("maker",		strMaker,	sizeof(strMaker));
		kvConfig.GetString("mapname",	strMapname,	sizeof(strMapname));
		kvConfig.GetString("gamemode",	strGameMode,sizeof(strGameMode));
		
		if(!StrEqual(strRating, "0"))
		{
			g_hMaps.PushString(strID);
			g_hMaps.PushString(strRating);
			g_hMaps.PushString(strMaker);
			g_hMaps.PushString(strMapname);
			g_hMaps.PushString(strGameMode);
			
			iCount++;
		}
		else
			iBadCount++;
	}
	while (KvGotoNextKey(kvConfig));
	
	PrintToServer("[WorkshopData] Got %i good maps, left out %i bad maps", iCount, iBadCount);
	delete kvConfig;
}