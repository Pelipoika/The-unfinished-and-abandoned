#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

//Menus
Menu g_hMenuMain;

TFTeam g_iTeam[MAXPLAYERS + 1];
TFClassType g_iClass[MAXPLAYERS + 1];
int g_iWeaponSlot[MAXPLAYERS + 1];
int g_iTarget[MAXPLAYERS + 1];

//http://steamcommunity.com/sharedfiles/filedetails/?id=519629553
//goto action point
//despawn
//taunt
//cloak
//uncloak
//disguise
//build sentry at nearest sentry hint
//->attack sentry at next action point

public Plugin myinfo = 
{
	name = "[TF2] Bot Tools",
	author = "Pelipoika",
	description = "Tools for easier developement with bots",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	g_hMenuMain = new Menu(MenuMainHandler);
	g_hMenuMain.SetTitle("Bot Settings\n ");
	g_hMenuMain.AddItem("0", "Spawn Bots");
	g_hMenuMain.AddItem("1", "Command Bots");

	RegAdminCmd("sm_bottools", Command_BotTools, ADMFLAG_ROOT, "Open the Bot Tools menu");
	
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	g_iTeam[client] = TFTeam_Blue;
	g_iClass[client] = TFClass_Scout;
	g_iTarget[client] = -1;
	g_iWeaponSlot[client] = TFWeaponSlot_Primary;
}

public Action Command_BotTools(int client, int argc)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		g_hMenuMain.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

//Main menu
public int MenuMainHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayBotSpawnMenuAtItem(param1);
			case 1: DisplayBotCommandMenuAtItem(param1);
		}
	}
}

//Bot Spawn menu
stock void DisplayBotSpawnMenuAtItem(int client, int iItem = 0)
{
	char strSpawn[64], strClass[64];
	Format(strSpawn, sizeof(strSpawn), " Spawn %s %s", g_iTeam[client] == TFTeam_Red ? "Red" : "Blue", TF2_GetClassName(g_iClass[client]));
	Format(strClass, sizeof(strClass), "Class: %s", TF2_GetClassName(g_iClass[client]));

	Menu hMenuSpawn = new Menu(MenuSpawnHandler);
	hMenuSpawn.SetTitle("Spawn Bots\n ");
	hMenuSpawn.AddItem("0", g_iTeam[client] == TFTeam_Red ? "Team: Red" : "Team: Blue");
	hMenuSpawn.AddItem("1", strClass);
	hMenuSpawn.AddItem("2", strSpawn);
	hMenuSpawn.ExitBackButton = true;
	hMenuSpawn.DisplayAt(client, iItem, MENU_TIME_FOREVER);
}

public int MenuSpawnHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: 
			{
				g_iTeam[param1] == TFTeam_Red ? (g_iTeam[param1] = TFTeam_Blue) : (g_iTeam[param1] = TFTeam_Red);
				
				DisplayBotSpawnMenuAtItem(param1);
			}
			case 1:
			{
				Menu hMenuClass = new Menu(MenuClassHandler);
				hMenuClass.SetTitle("Select Class\n ");
				hMenuClass.AddItem("0", "Scout");
				hMenuClass.AddItem("1", "Soldier");
				hMenuClass.AddItem("2", "Pyro");
				hMenuClass.AddItem("3", "Demo");
				hMenuClass.AddItem("4", "Heavy");
				hMenuClass.AddItem("5", "Engineer");
				hMenuClass.AddItem("6", "Medic");
				hMenuClass.AddItem("7", "Sniper");
				hMenuClass.AddItem("8", "Spy");
				hMenuClass.ExitBackButton = true;
				hMenuClass.Display(param1, MENU_TIME_FOREVER);
			}
			case 2:
			{
				ServerCommand("bot -team %s -class %s -name \"%s %s\"", g_iTeam[param1] == TFTeam_Red ? "red" : "blue", TF2_GetClassName(g_iClass[param1]), g_iTeam[param1] == TFTeam_Red ? "Red" : "Blue", TF2_GetClassName(g_iClass[param1]));
				
				DisplayBotSpawnMenuAtItem(param1);
			}
		}
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		g_hMenuMain.Display(param1, MENU_TIME_FOREVER);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuClassHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: g_iClass[param1] = TFClass_Scout;
			case 1: g_iClass[param1] = TFClass_Soldier;
			case 2: g_iClass[param1] = TFClass_Pyro;
			case 3: g_iClass[param1] = TFClass_DemoMan;
			case 4: g_iClass[param1] = TFClass_Heavy;
			case 5: g_iClass[param1] = TFClass_Engineer;
			case 6: g_iClass[param1] = TFClass_Medic;
			case 7: g_iClass[param1] = TFClass_Sniper;
			case 8: g_iClass[param1] = TFClass_Spy;
		}

		DisplayBotSpawnMenuAtItem(param1);
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayBotSpawnMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock char TF2_GetClassName(TFClassType class)
{
	char strClass[32];
	
	switch(class)
	{
		case TFClass_Scout:		Format(strClass, sizeof(strClass), "Scout");
		case TFClass_Sniper:	Format(strClass, sizeof(strClass), "Sniper");
		case TFClass_Soldier:	Format(strClass, sizeof(strClass), "Soldier");
		case TFClass_DemoMan:	Format(strClass, sizeof(strClass), "Demoman");
		case TFClass_Medic:		Format(strClass, sizeof(strClass), "Medic");
		case TFClass_Heavy:		Format(strClass, sizeof(strClass), "Heavy");
		case TFClass_Pyro:		Format(strClass, sizeof(strClass), "Pyro");
		case TFClass_Spy:		Format(strClass, sizeof(strClass), "Spy");
		case TFClass_Engineer:	Format(strClass, sizeof(strClass), "Engineer");
	}
	
	return strClass;
}

//Bot Command menu
stock void DisplayBotCommandMenuAtItem(int client, int iItem = 0)
{
	Menu hMenuCommands = new Menu(MenuCommandHandler);
	
	char strName[64];
	int iTarget = g_iTarget[client];
	if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
	{
		Format(strName, sizeof(strName), "Target: %N", iTarget);
	}
	else
	{
		Format(strName, sizeof(strName), "Target: Everyone");
	}
	
	char strTitle[64];
	Format(strTitle, sizeof(strTitle), "Bot Commands\n - %s", strName);
	
	hMenuCommands.SetTitle(strTitle);
	hMenuCommands.AddItem("0", "Pick target");
	hMenuCommands.AddItem("1", "Teleport to me");
	hMenuCommands.AddItem("2", "Look where i'm looking");
	hMenuCommands.AddItem("3", "Switch weapon");
	hMenuCommands.AddItem("4", FindConVar("bot_forceattack").BoolValue ? "Primary Attack: On" : "Primary Attack: Off");
	hMenuCommands.AddItem("5", FindConVar("bot_forceattack2").BoolValue ? "Secondary Attack: On" : "Secondary Attack: Off");
	hMenuCommands.AddItem("6", "Bot Refill");
	hMenuCommands.AddItem("7", "Build Sentry");
	hMenuCommands.AddItem("8", "Build Dispenser");
	hMenuCommands.ExitBackButton = true;
	hMenuCommands.DisplayAt(client, iItem, MENU_TIME_FOREVER);
}

public int MenuCommandHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				int iTarget = GetClientAimTarget(param1);
				if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
				{
					PrintToChat(param1, "Target set to: %N", iTarget);
					g_iTarget[param1] = iTarget;
				}
				else if(g_iTarget[param1] != -1)
				{
					PrintToChat(param1, "Target set to: EVERYONE");
					g_iTarget[param1] = -1;
				}
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 1:
			{
				float flPos[3], flAng[3];
				GetClientAbsOrigin(param1, flPos);
				GetClientAbsAngles(param1, flAng);
				
				int iTarget = g_iTarget[param1]
				
				if(iTarget == -1)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && IsFakeClient(i))
						{
							TeleportEntity(i, flPos, flAng, NULL_VECTOR);
						}
					}
				}
				else
				{
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
					{
						TeleportEntity(iTarget, flPos, flAng, NULL_VECTOR);
					}
				}
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 2:
			{
				float flAng[3];
				GetClientEyeAngles(param1, flAng);
				
				int iTarget = g_iTarget[param1]
				
				if(iTarget == -1)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && IsFakeClient(i))
						{
							TeleportEntity(i, NULL_VECTOR, flAng, NULL_VECTOR);
						}
					}
				}
				else
				{
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
					{
						TeleportEntity(iTarget, NULL_VECTOR, flAng, NULL_VECTOR);
					}
				}
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 3:
			{
				Menu hMenuWeapon = new Menu(MenuWeaponHandler);
				hMenuWeapon.SetTitle("Switch Weapon To:\n ");
				hMenuWeapon.AddItem("0", "Primary");
				hMenuWeapon.AddItem("1", "Secondary");
				hMenuWeapon.AddItem("2", "Melee");
				hMenuWeapon.AddItem("3", "Grenade");
				hMenuWeapon.AddItem("4", "Building");
				hMenuWeapon.AddItem("5", "PDA");
				hMenuWeapon.AddItem("6", "Item1");
				hMenuWeapon.AddItem("7", "Item2");
				hMenuWeapon.ExitBackButton = true;
				hMenuWeapon.Display(param1, MENU_TIME_FOREVER);
			}
			case 4:
			{
				bool bOn = FindConVar("bot_forceattack").BoolValue;
				if(bOn)
					FindConVar("bot_forceattack").BoolValue = false;
				else
					FindConVar("bot_forceattack").BoolValue = true;
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 5:
			{
				bool bOn = FindConVar("bot_forceattack2").BoolValue;
				if(bOn)
					FindConVar("bot_forceattack2").BoolValue = false;
				else
					FindConVar("bot_forceattack2").BoolValue = true;
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 6:
			{
				ServerCommand("bot_refill");
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 7:
			{
				int iTarget = g_iTarget[param1];
				
				if(iTarget == -1)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && IsFakeClient(i))
						{
							FakeClientCommand(i, "destroy 2");
							FakeClientCommand(i, "build 2");
							FindConVar("bot_forceattack").BoolValue = true;
						}
					}
				}
				else
				{
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
					{
						FakeClientCommand(iTarget, "destroy 2");
						FakeClientCommand(iTarget, "build 2");
						FindConVar("bot_forceattack").BoolValue = true;
					}
				}
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
			case 8:
			{
				int iTarget = g_iTarget[param1];
				
				if(iTarget == -1)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && IsFakeClient(i))
						{
							FakeClientCommand(i, "destroy 0");
							FakeClientCommand(i, "build 0");
							FindConVar("bot_forceattack").BoolValue = true;
						}
					}
				}
				else
				{
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
					{
						FakeClientCommand(iTarget, "destroy 0");
						FakeClientCommand(iTarget, "build 0");
						FindConVar("bot_forceattack").BoolValue = true;
					}
				}
				
				DisplayBotCommandMenuAtItem(param1, GetMenuSelectionPosition());
			}
		}
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		g_hMenuMain.Display(param1, MENU_TIME_FOREVER);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuWeaponHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: g_iWeaponSlot[param1] = TFWeaponSlot_Primary;
			case 1: g_iWeaponSlot[param1] = TFWeaponSlot_Secondary;
			case 2: g_iWeaponSlot[param1] = TFWeaponSlot_Melee;
			case 3: g_iWeaponSlot[param1] = TFWeaponSlot_Grenade;
			case 4: g_iWeaponSlot[param1] = TFWeaponSlot_Building;
			case 5: g_iWeaponSlot[param1] = TFWeaponSlot_PDA;
			case 6: g_iWeaponSlot[param1] = TFWeaponSlot_Item1;
			case 7: g_iWeaponSlot[param1] = TFWeaponSlot_Item2;
		}
		
		int iTarget = g_iTarget[param1]
		if(iTarget == -1)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsFakeClient(i))
				{
					TF2_EquipWeaponSlot(i, g_iWeaponSlot[param1]);
				}
			}
		}
		else
		{
			if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsFakeClient(iTarget))
			{
				TF2_EquipWeaponSlot(iTarget, g_iWeaponSlot[param1]);
			}
		}
		
		DisplayBotCommandMenuAtItem(param1);
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayBotCommandMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock void TF2_EquipWeaponSlot(int client, int iSlot = TFWeaponSlot_Primary)
{
	int iWeapon = GetPlayerWeaponSlot(client, iSlot);

	if(IsValidEntity(iWeapon))
	{
		char strClass[64];
		GetEntityClassname(iWeapon, strClass, sizeof(strClass));
		
		FakeClientCommand(client, "use %s", strClass);
	}
}