#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

enum AttributeType
{
	NONE                    = 0,
	REMOVEONDEATH           = (1 << 0),
	AGGRESSIVE              = (1 << 1),
	SUPPRESSFIRE            = (1 << 3),
	DISABLEDODGE            = (1 << 4),
	BECOMESPECTATORONDEATH  = (1 << 5),
	RETAINBUILDINGS         = (1 << 7),
	SPAWNWITHFULLCHARGE     = (1 << 8),
	ALWAYSCRIT              = (1 << 9),
	IGNOREENEMIES           = (1 << 10),
	HOLDFIREUNTILFULLRELOAD = (1 << 11),
	ALWAYSFIREWEAPON        = (1 << 13),
	TELEPORTTOHINT          = (1 << 14),
	MINIBOSS                = (1 << 15),
	USEBOSSHEALTHBAR        = (1 << 16),
	IGNOREFLAG              = (1 << 17),
	AUTOJUMP                = (1 << 18),
	AIRCHARGEONLY           = (1 << 19),
	VACCINATORBULLETS       = (1 << 20),
	VACCINATORBLAST         = (1 << 21),
	VACCINATORFIRE          = (1 << 22),
	BULLETIMMUNE            = (1 << 23),
	BLASTIMMUNE             = (1 << 24),
	FIREIMMUNE              = (1 << 25),
	PARACHUTE               = (1 << 26),
	PROJECTILESHIELD        = (1 << 27),
};

enum MissionType
{
	NOMISSION         = 0,
	UNKNOWN           = 1,
	DESTROY_SENTRIES  = 2,
	SNIPER            = 3,
	SPY               = 4,
	ENGINEER          = 5,
	REPROGRAMMED      = 6,
};

enum WeaponRestriction
{
	UNRESTRICTED  = 0,
	MELEEONLY     = (1 << 0),
	PRIMARYONLY   = (1 << 1),
	SECONDARYONLY = (1 << 2),
};

//Offsets
int g_iOffsetWeaponRestrictions;
int g_iOffsetBotAttribs;
int g_iOffsetAutoJumpMin;
int g_iOffsetAutoJumpMax;

//Menus
Menu g_hMenuMain;

//Global attribute trackers
AttributeType g_iBotAttributes = NONE;
WeaponRestriction g_iWeaponRestrictions = UNRESTRICTED;
float g_flAutoJumpMin = 0.0;
float g_flAutoJumpMax = 0.0;

public Plugin myinfo = 
{
	name = "[TF2] Bot Fun",
	author = "Pelipoika",
	description = "Fun settings for playing with bots",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	g_hMenuMain = new Menu(MenuMainHandler);
	g_hMenuMain.SetTitle("Bot Settings\n ");
	g_hMenuMain.AddItem("0", "Change Bot Attributes");
	g_hMenuMain.AddItem("1", "Change Bot Weapon Restriction");
	g_hMenuMain.AddItem("2", "Change Bot Autojump Intervals");
	g_hMenuMain.AddItem("3", "Apply changes");
	
	Handle hConf = LoadGameConfigFile("bot-control");
	
	if(LookupOffset(g_iOffsetWeaponRestrictions, "CTFPlayer", "m_iPlayerSkinOverride")) g_iOffsetWeaponRestrictions += GameConfGetOffset(hConf, "m_nWeaponRestrict");
	if(LookupOffset(g_iOffsetBotAttribs,         "CTFPlayer", "m_iPlayerSkinOverride")) g_iOffsetBotAttribs         += GameConfGetOffset(hConf, "m_nBotAttrs");	
	if(LookupOffset(g_iOffsetAutoJumpMin,        "CTFPlayer", "m_iPlayerSkinOverride")) g_iOffsetAutoJumpMin        += GameConfGetOffset(hConf, "m_flAutoJumpMin");
	if(LookupOffset(g_iOffsetAutoJumpMax,        "CTFPlayer", "m_iPlayerSkinOverride")) g_iOffsetAutoJumpMax        += GameConfGetOffset(hConf, "m_flAutoJumpMax");
	
	delete hConf;
	
	RegAdminCmd("sm_botfun", Command_BotFun, ADMFLAG_ROOT, "Open the Bot Modifiers menu");
}

public Action Command_BotFun(int client, int argc)
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
			case 0: DisplayAttributeMenuAtItem(param1);
			case 1: DisplayWeaponMenuAtItem(param1);
			case 2: DisplayAutojumpMenuAtItem(param1);
			case 3:
			{
				UpdateBotAttributes();
				g_hMenuMain.Display(param1, MENU_TIME_FOREVER);
			}
		}
	}
}

//Attribute menu
stock void DisplayAttributeMenuAtItem(int client, int iItem = 0)
{
	Menu g_hMenuAttributes = new Menu(MenuAttributeHandler);
	g_hMenuAttributes.SetTitle("Bot Attributes\n ");
	g_hMenuAttributes.AddItem("0",  IsAttributeSet(NONE)                    ? "✅ NONE"                    : "NONE");
	g_hMenuAttributes.AddItem("1",  IsAttributeSet(AGGRESSIVE)              ? "✅ AGGRESSIVE"              : "AGGRESSIVE");
	g_hMenuAttributes.AddItem("2",  IsAttributeSet(SUPPRESSFIRE)            ? "✅ SUPPRESSFIRE"            : "SUPPRESSFIRE");
	g_hMenuAttributes.AddItem("3",  IsAttributeSet(DISABLEDODGE)            ? "✅ DISABLEDODGE"            : "DISABLEDODGE");
	g_hMenuAttributes.AddItem("4",  IsAttributeSet(RETAINBUILDINGS)         ? "✅ RETAINBUILDINGS"         : "RETAINBUILDINGS");
	g_hMenuAttributes.AddItem("5",  IsAttributeSet(SPAWNWITHFULLCHARGE)     ? "✅ SPAWNWITHFULLCHARGE"     : "SPAWNWITHFULLCHARGE");
	g_hMenuAttributes.AddItem("6",  IsAttributeSet(ALWAYSCRIT)              ? "✅ ALWAYSCRIT"              : "ALWAYSCRIT");
	g_hMenuAttributes.AddItem("7",  IsAttributeSet(IGNOREENEMIES)           ? "✅ IGNOREENEMIES"           : "IGNOREENEMIES");
	g_hMenuAttributes.AddItem("8",  IsAttributeSet(HOLDFIREUNTILFULLRELOAD) ? "✅ HOLDFIREUNTILFULLRELOAD" : "HOLDFIREUNTILFULLRELOAD");
	g_hMenuAttributes.AddItem("9",  IsAttributeSet(ALWAYSFIREWEAPON)        ? "✅ ALWAYSFIREWEAPON"        : "ALWAYSFIREWEAPON");
	g_hMenuAttributes.AddItem("10", IsAttributeSet(TELEPORTTOHINT)          ? "✅ TELEPORTTOHINT"          : "TELEPORTTOHINT");
	g_hMenuAttributes.AddItem("11", IsAttributeSet(MINIBOSS)                ? "✅ MINIBOSS"                : "MINIBOSS");
	g_hMenuAttributes.AddItem("12", IsAttributeSet(USEBOSSHEALTHBAR)        ? "✅ USEBOSSHEALTHBAR"        : "USEBOSSHEALTHBAR");
	g_hMenuAttributes.AddItem("13", IsAttributeSet(IGNOREFLAG)              ? "✅ IGNOREFLAG"              : "IGNOREFLAG");
	g_hMenuAttributes.AddItem("14", IsAttributeSet(AUTOJUMP)                ? "✅ AUTOJUMP"                : "AUTOJUMP");
	g_hMenuAttributes.AddItem("15", IsAttributeSet(AIRCHARGEONLY)           ? "✅ AIRCHARGEONLY"           : "AIRCHARGEONLY");
	g_hMenuAttributes.AddItem("16", IsAttributeSet(VACCINATORBULLETS)       ? "✅ VACCINATORBULLETS"       : "VACCINATORBULLETS");
	g_hMenuAttributes.AddItem("17", IsAttributeSet(VACCINATORBLAST)         ? "✅ VACCINATORBLAST"         : "VACCINATORBLAST");
	g_hMenuAttributes.AddItem("18", IsAttributeSet(VACCINATORFIRE)          ? "✅ VACCINATORFIRE"          : "VACCINATORFIRE");
	g_hMenuAttributes.AddItem("19", IsAttributeSet(BULLETIMMUNE)            ? "✅ BULLETIMMUNE"            : "BULLETIMMUNE");
	g_hMenuAttributes.AddItem("20", IsAttributeSet(BLASTIMMUNE)             ? "✅ BLASTIMMUNE"             : "BLASTIMMUNE");
	g_hMenuAttributes.AddItem("21", IsAttributeSet(FIREIMMUNE)              ? "✅ FIREIMMUNE"              : "FIREIMMUNE");
	g_hMenuAttributes.AddItem("22", IsAttributeSet(PARACHUTE)               ? "✅ PARACHUTE"               : "PARACHUTE");
	g_hMenuAttributes.AddItem("23", IsAttributeSet(PROJECTILESHIELD)        ? "✅ PROJECTILESHIELD"        : "PROJECTILESHIELD");
	g_hMenuAttributes.ExitBackButton = true;
	g_hMenuAttributes.DisplayAt(client, iItem, MENU_TIME_FOREVER);
}

stock bool IsAttributeSet(AttributeType iAttrib)
{
	if(g_iBotAttributes == NONE && iAttrib == NONE)
		return true;
	
	if(g_iBotAttributes & iAttrib)
		return true;
		
	return false;
}

public int MenuAttributeHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:  g_iBotAttributes = NONE;
			case 1:  g_iBotAttributes ^= AGGRESSIVE;
			case 2:  g_iBotAttributes ^= SUPPRESSFIRE;
			case 3:  g_iBotAttributes ^= DISABLEDODGE;
			case 4:  g_iBotAttributes ^= RETAINBUILDINGS;
			case 5:  g_iBotAttributes ^= SPAWNWITHFULLCHARGE;
			case 6:  g_iBotAttributes ^= ALWAYSCRIT;
			case 7:  g_iBotAttributes ^= IGNOREENEMIES;
			case 8:  g_iBotAttributes ^= HOLDFIREUNTILFULLRELOAD;
			case 9:  g_iBotAttributes ^= ALWAYSFIREWEAPON;
			case 10: g_iBotAttributes ^= TELEPORTTOHINT;
			case 11: g_iBotAttributes ^= MINIBOSS;
			case 12: g_iBotAttributes ^= USEBOSSHEALTHBAR;
			case 13: g_iBotAttributes ^= IGNOREFLAG;
			case 14: g_iBotAttributes ^= AUTOJUMP;
			case 15: g_iBotAttributes ^= AIRCHARGEONLY;
			case 16: g_iBotAttributes ^= VACCINATORBULLETS;
			case 17: g_iBotAttributes ^= VACCINATORBLAST;
			case 18: g_iBotAttributes ^= VACCINATORFIRE;
			case 19: g_iBotAttributes ^= BULLETIMMUNE;
			case 20: g_iBotAttributes ^= BLASTIMMUNE;
			case 21: g_iBotAttributes ^= FIREIMMUNE;
			case 22: g_iBotAttributes ^= PARACHUTE;
			case 23: g_iBotAttributes ^= PROJECTILESHIELD;
		}

		DisplayAttributeMenuAtItem(param1, GetMenuSelectionPosition());
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

//WeaponRestriction menu
stock void DisplayWeaponMenuAtItem(int client, int iItem = 0)
{
	Menu g_hMenuWeapons = new Menu(MenuWeaponHandler);
	g_hMenuWeapons.SetTitle("Bot Weapon Restriction\n ");
	g_hMenuWeapons.AddItem("0", IsWeaponRestrictionSet(UNRESTRICTED)  ? "✅ Unrestricted" : "Unrestricted");
	g_hMenuWeapons.AddItem("1", IsWeaponRestrictionSet(MELEEONLY)     ? "✅ Melee"        : "Melee");
	g_hMenuWeapons.AddItem("2", IsWeaponRestrictionSet(SECONDARYONLY) ? "✅ Secondary"    : "Secondary");
	g_hMenuWeapons.AddItem("3", IsWeaponRestrictionSet(PRIMARYONLY)   ? "✅ Primary"      : "Primary");
	g_hMenuWeapons.ExitBackButton = true;
	g_hMenuWeapons.DisplayAt(client, iItem, MENU_TIME_FOREVER);
}

stock bool IsWeaponRestrictionSet(WeaponRestriction iRestriction)
{
	if(g_iWeaponRestrictions == iRestriction)
		return true;
		
	return false;
}

public int MenuWeaponHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: g_iWeaponRestrictions = UNRESTRICTED;
			case 1: g_iWeaponRestrictions = MELEEONLY;
			case 2: g_iWeaponRestrictions = SECONDARYONLY;
			case 3: g_iWeaponRestrictions = PRIMARYONLY;
		}

		DisplayWeaponMenuAtItem(param1, GetMenuSelectionPosition());
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

//Autojump settings menu
stock void DisplayAutojumpMenuAtItem(int client, int iItem = 0)
{
	Menu g_hMenuInterval = new Menu(MenuIntervalHandler);
	g_hMenuInterval.SetTitle("Bot Autojump Interval\n - Min: %.1f, Max: %.1f", g_flAutoJumpMin, g_flAutoJumpMax);
	g_hMenuInterval.AddItem("0", " Adjust Min\n ", ITEMDRAW_DISABLED);
	g_hMenuInterval.AddItem("1", "+ 1 Seconds");
	g_hMenuInterval.AddItem("2", "+ 0.1 Seconds");
	g_hMenuInterval.AddItem("3", "- 1 Seconds");
	g_hMenuInterval.AddItem("4", "- 0.1 Seconds");
	g_hMenuInterval.AddItem("5", " Adjust Max\n ", ITEMDRAW_DISABLED);
	g_hMenuInterval.AddItem("6", "+ 1 Seconds");
	g_hMenuInterval.AddItem("7", "+ 0.1 Seconds");
	g_hMenuInterval.AddItem("8", "- 1 Seconds");
	g_hMenuInterval.AddItem("9", "- 0.1 Seconds");
	g_hMenuInterval.ExitBackButton = true;
	g_hMenuInterval.Pagination = 5;
	g_hMenuInterval.DisplayAt(client, iItem, MENU_TIME_FOREVER);
}

public int MenuIntervalHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1: g_flAutoJumpMin += 1.0;
			case 2: g_flAutoJumpMin += 0.1;
			case 3: g_flAutoJumpMin -= 1.0;
			case 4: g_flAutoJumpMin -= 0.1;
			case 6: g_flAutoJumpMax += 1.0;
			case 7: g_flAutoJumpMax += 0.1;
			case 8: g_flAutoJumpMax -= 1.0;
			case 9: g_flAutoJumpMax -= 0.1;
		}
		
		DisplayAutojumpMenuAtItem(param1, GetMenuSelectionPosition());
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

stock void UpdateBotAttributes()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i))
		{
			SetEntData(i, g_iOffsetBotAttribs, g_iBotAttributes, 4, true);
			SetEntData(i, g_iOffsetWeaponRestrictions, g_iWeaponRestrictions, 4, true);
			SetEntData(i, g_iOffsetAutoJumpMin, g_flAutoJumpMin, 4, true);
			SetEntData(i, g_iOffsetAutoJumpMax, g_flAutoJumpMax, 4, true);
		}
	}
}

bool LookupOffset(int &iOffset, const char[] strClass, const char[] strProp)
{
	iOffset = FindSendPropInfo(strClass, strProp);
	if(iOffset <= 0)
	{
		LogMessage("Could not locate offset for %s::%s!", strClass, strProp);
		return false;
	}

	return true;
}