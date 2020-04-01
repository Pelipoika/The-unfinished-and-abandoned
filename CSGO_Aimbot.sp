#include <sourcemod>
#include <vscriptfun>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required;

Handle g_hHudRadar[MAXPLAYERS + 1];

bool g_bAimbot[MAXPLAYERS + 1];
bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bBunnyHop[MAXPLAYERS + 1];
bool g_bHeadshots[MAXPLAYERS + 1];
bool g_bRecoilControl[MAXPLAYERS + 1];
bool g_bESP[MAXPLAYERS + 1];
bool g_bSnapLines[MAXPLAYERS + 1];


bool g_bShowFake[MAXPLAYERS + 1];
int g_iFakeRef[MAXPLAYERS + 1];
int g_iAntiAimType[MAXPLAYERS + 1];


#define UMSG_SPAM_DELAY 0.1
float g_flNextTime[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[CSGO] Aimbot",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

Handle g_hLookupBone;
Handle g_hGetBonePosition;


#define NUM_LAYERS 12
#define EF_BONEMERGE       (1 << 0)
#define EF_PARENT_ANIMATES (1 << 9)

const int CAnimationLayer_Size = 0x5C;

Handle g_hResetSequence;
Handle g_hStudioFrameAdvance;
Handle g_hAllocateLayer;

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks", Command_Trigger, 0);

	for (int i = 1; i <= MaxClients; i++)
	{	
		if(IsClientInGame(i)) 
		{ 
			OnClientPutInServer(i); 
		}
		
		g_hHudRadar[i] = CreateHudSynchronizer();
	}
	
	//-----------------------------------------------------------------------------
	// Purpose: Returns index number of a given named bone
	// Input  : name of a bone
	// Output : Bone index number or -1 if bone not found
	//-----------------------------------------------------------------------------
	//int CBaseAnimating::LookupBone( const char *szName )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x57\x8B\xF9\x83\xBF\x9C\x04\x00\x00\x00\x75\x2A\xA1\x2A\x2A\x2A\x2A\x8B\x30\x8B\x07\xFF\x50\x18\x8B\x0D\x2A\x2A\x2A\x2A\x50\xFF\x56\x04\x85\xC0\x74\x2A\x8B\xCF\xE8\x2A\x2A\x2A\x2A\x8B\x8F\x9C\x04\x00\x00\x85\xC9\x0F\x84\x2A\x2A\x2A\x2A", 63);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
	
	//void CBaseAnimating::GetBonePosition ( int iBone, Vector &origin, QAngle &angles )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xE4\xF8\x83\xEC\x30\x56\x57\x8B\xF9\x83\xBF\x9C\x04\x00\x00\x00\x75\x2A\xA1\x2A\x2A\x2A\x2A\x8B\x30\x8B\x07\xFF\x50\x18\x8B\x0D\x2A\x2A\x2A\x2A\x50\xFF\x56\x04\x85\xC0\x74\x2A\x8B\xCF\xE8\x2A\x2A\x2A\x2A\x8B\x87\x9C\x04\x00\x00", 61);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
	
	
	
	//ResetSequence(int nSequence);
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\xA1\x2A\x2A\x2A\x2A\x83\xEC\x08\x53\x56\x8B\xD9", 15);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

	//int CBaseAnimatingOverlay::AllocateLayer( int iPriority )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x14\x53\x8B\xC1", 9);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//priority
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return iOpenLayer
	if((g_hAllocateLayer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AllocateLayer");
	
	// StudioFrameAdvance - advance the animation frame up some interval (default 0.1) into the future
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xE4\xC0\xA1\x2A\x2A\x2A\x2A\x83\xEC\x34\xF3\x0F\x10\x48\x10", 19);
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance signature!");
	
	
}

//Remove all clones
public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		int iClone = EntRefToEntIndex(g_iFakeRef[i]);
		if(IsValidEntity(iClone))
		{
			//AcceptEntityInput(iClone, "Kill");
		}
	}
}

public void OnClientPutInServer(int client)
{
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bSilentAim[client] = false;
	g_bRecoilControl[client] = false;
	
	g_bESP[client] = false;
	
	g_bShowFake[client] = false;
	g_iFakeRef[client] = INVALID_ENT_REFERENCE;
	g_iAntiAimType[client] = 0;
	
	g_bBunnyHop[client] = false;
	g_bHeadshots[client] = false;

	g_flNextTime[client] = 0.0;
}

public Action Command_Trigger(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		DisplayHackMenuAtItem(client);
	}

	return Plugin_Handled;
}

stock void DisplayHackMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuLegitnessHandler);
	menu.SetTitle("LMAOBOX CS:GO");
	menu.AddItem("0", "Aimbot");
	menu.AddItem("1", "Misc");
	menu.AddItem("2", "Confused Boyes");

	menu.ExitButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayAimbotMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuAimbotHandler);
	menu.SetTitle("Aimbot - Settings");
	
	if(g_bAimbot[client])
		menu.AddItem("0", "Aimbot: On");
	else
		menu.AddItem("0", "Aimbot: Off");	
	
	if(g_bAutoShoot[client])
		menu.AddItem("1", "Auto Shoot: On");
	else
		menu.AddItem("1", "Auto Shoot: Off");

	if(g_bSilentAim[client])
		menu.AddItem("2", "Silent Aim: On");
	else
		menu.AddItem("2", "Silent Aim: Off");
		
	if(g_bHeadshots[client])
		menu.AddItem("3", "Headshots only: On");
	else
		menu.AddItem("3", "Headshots only: Off");
		
	if(g_bRecoilControl[client])
		menu.AddItem("4", "Recoil Assist: On");
	else
		menu.AddItem("4", "Recoil Assist: Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMiscMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuMiscHandler);
	menu.SetTitle("Misc - Settings");
	
	if(g_bBunnyHop[client])
		menu.AddItem("0", "Bunny Hop: On");
	else
		menu.AddItem("0", "Bunny Hop: Off");
		
	if(g_bESP[client])
		menu.AddItem("1", "ESP: On", (client > 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	else
		menu.AddItem("1", "ESP: Off", (client > 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		
	if(g_bSnapLines[client])
		menu.AddItem("2", "ESP Snap Lines: On", (client > 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	else
		menu.AddItem("2", "ESP Snap Lines: Off", (client > 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	if(g_bShowFake[client])
		menu.AddItem("3", "Show Fake Angles: On");
	else
		menu.AddItem("3", "Show Fake Angles: Off");	
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplaySpinbotMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuSpinHandler);
	menu.SetTitle("Spinbot - Settings");
	
	switch(g_iAntiAimType[client])
	{
		case 0: menu.AddItem("0", "Type: OFF");
		case 1: menu.AddItem("1", "Type: Scared");
	}
	
	DrawServerHitboxes(client);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}


/*
	Signature for CBaseAnimating__DrawServerHitboxes:
	55 8B EC 81 EC A0 00 00 00 53 
	\x55\x8B\xEC\x81\xEC\xA0\x00\x00\x00\x53
*/

#define Pointer Address
#define nullptr Address_Null

#define Address(%1) view_as<Address>(%1)
#define int(%1) view_as<int>(%1)

float hullcolor[][] = 
{
	{1.0, 1.0, 1.0},
	{1.0, 0.5, 0.5},
	{0.5, 1.0, 0.5},
	{1.0, 1.0, 0.5},
	{0.5, 0.5, 1.0},
	{1.0, 0.5, 1.0},
	{0.5, 1.0, 1.0},
	{1.0, 1.0, 1.0}
};

void DrawServerHitboxes(int entity)
{
	Address pStudioHdr = view_as<Address>(GetEntData(entity, 295 * 4));	//1180
	if(pStudioHdr == Address_Null)
		return;
	
	pStudioHdr = Address(Dereference(pStudioHdr));
	
	int iHitboxSetIndex = ReadInt(pStudioHdr + Address(0xB0) );
	Address pStudioHitboxSet = pStudioHdr + Address(iHitboxSetIndex);
	if(pStudioHitboxSet == Address_Null)
		return;
	
	int iNumHitboxes = ReadInt( pStudioHitboxSet + Address(0x4) );
	int iHitboxIdx   = ReadInt( pStudioHitboxSet + Address(0x8) );
	
	PrintToServer("pStudioHdr 0x%x | iHitboxSetIndex %i | pStudioHitboxSet 0x%X", pStudioHdr, iHitboxSetIndex, pStudioHitboxSet);
	PrintToServer("iNumHitboxes %i | iHitboxIdx %i", iNumHitboxes, iHitboxIdx);
	
	pStudioHitboxSet += Address(0xC);

	PrintToServer("BoneMatrix 0x%X", GetEntityAddress(entity));

	//PrintToServer("%3s %-10s %12s %13s\n", "#", "X", "Y", "Z");

	for ( int i = 0; i < iNumHitboxes; i++ )
	{
		float position[3], angles[3];
		float vMins[3], vMaxs[3];
		
		//mstudiobbox_t 
		Pointer pbox = Address(pStudioHitboxSet + Address(i * 68));
		
		int iBone = ReadInt(pbox);
		
		PrintToServer("pbox 0x%X", pbox);
		
		GetBonePosition(entity, iBone, position, angles);
		
		vMins[0] = view_as<float>(ReadInt(pbox + Address(0x8)));
		vMins[1] = view_as<float>(ReadInt(pbox + Address(0xC)));
		vMins[2] = view_as<float>(ReadInt(pbox + Address(0x10)));
		
		vMaxs[0] = view_as<float>(ReadInt(pbox + Address(0x14)));
		vMaxs[1] = view_as<float>(ReadInt(pbox + Address(0x18)));
		vMaxs[2] = view_as<float>(ReadInt(pbox + Address(0x1C)));
		
		PrintToServer("%-3d %-6.1f %-6.1f %-6.1f  %-6.1f %-6.1f %-6.1f", iBone, position[0], position[1], position[2], angles[0], angles[1], angles[2]);
		PrintToServer("%-3s %-6.1f %-6.1f %-6.1f  %-6.1f %-6.1f %-6.1f", "", vMins[0], vMins[1], vMins[2], vMaxs[0], vMaxs[1], vMaxs[2]);
		
		int j = (ReadInt(pbox + Address(0x4)) % 8);
		
		int r = RoundToFloor( 255.0 * hullcolor[j][0] );
		int g = RoundToFloor( 255.0 * hullcolor[j][1] );
		int b = RoundToFloor( 255.0 * hullcolor[j][2] );
		
		float flRadius = view_as<float>(ReadInt(pbox + Address(0x30)));
		if(flRadius == -1.0)
		{
			//Box style hitbox
		}
		else
		{
			//New capsule style hitbox
		}
		
		PrintToServer("%-10s %-6.1f", "m_flRadius", flRadius);
		
		VSF.DebugDrawBox(position, vMaxs, vMins, r, g, b, 155, 5.0);
	}
}

stock Pointer Transpose(Pointer pAddr, int iOffset)		
{
	return Address(int(pAddr) + iOffset);		
}
stock int Dereference(Pointer pAddr, int iOffset = 0)		
{
	if(pAddr == nullptr)		
	{
		return -1;
	}
	
	return ReadInt(Transpose(pAddr, iOffset));
} 
stock int ReadInt(Pointer pAddr)
{
	if(pAddr == nullptr)
	{
		return -1;
	}
	
	return LoadFromAddress(pAddr, NumberType_Int32);
}








public int MenuAimbotHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{		
			case 0: 
			{
				g_bAimbot[param1] = !g_bAimbot[param1];
				
				if(!g_bAimbot[param1])
				{
					SetEntProp(param1, Prop_Data, "m_bLagCompensation", true);
					SetEntProp(param1, Prop_Data, "m_bPredictWeapons", true);
				}
			}
			case 1: g_bAutoShoot[param1]     = !g_bAutoShoot[param1];
			case 2: g_bSilentAim[param1]     = !g_bSilentAim[param1];
			case 3: g_bHeadshots[param1]     = !g_bHeadshots[param1];
			case 4: 
			{
				g_bRecoilControl[param1] = !g_bRecoilControl[param1];
				
				if(g_bRecoilControl[param1])
					SendConVarValue(param1, FindConVar("weapon_recoil_scale"), "0");
				else
					SendConVarValue(param1, FindConVar("weapon_recoil_scale"), "2");
			}
		}
		
		DisplayAimbotMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuMiscHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: g_bBunnyHop[param1]  = !g_bBunnyHop[param1];
			case 1: g_bESP[param1]       = !g_bESP[param1];
			case 2: g_bSnapLines[param1] = !g_bSnapLines[param1];
			case 3: 
			{
				g_bShowFake[param1] = !g_bShowFake[param1];
				
				if(g_bShowFake[param1])
				{
					CreateClone(param1);
				}
				else
				{
					DeleteClone(param1);
				}
			}
		}
		
		DisplayMiscMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuSpinHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if(++g_iAntiAimType[param1] >= 2)
			g_iAntiAimType[param1] = 0;
		
		DisplaySpinbotMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock void CreateClone(int client)
{
	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	
	int ent = CreateEntityByName("monster_generic");
	DispatchKeyValueVector(ent, "origin", GetAbsOrigin(client));
	DispatchKeyValueVector(ent, "angles", GetAbsAngles(client));
	DispatchKeyValue(ent, "model", strModel);
	DispatchKeyValue(ent, "spawnflags", "5000");
	DispatchSpawn(ent);
	
	SetEntProp(ent, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
	SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
	
	////////////////////////////
	//Copy weapon
	//Not nescessary
	////////////////////////////
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, GetEntProp(GetActiveWeapon(client), Prop_Send, "m_iWorldModelIndex"), strModel, PLATFORM_MAX_PATH);  
	
	if(!StrEqual(strModel, ""))
	{	
		int item = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(item, "model", strModel);
		DispatchSpawn(item);
		
		SetEntProp(item, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
		SetEntProp(item, Prop_Send, "m_hOwnerEntity", ent);
		SetEntProp(item, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES);
		
		SetEntPropEnt(ent, Prop_Data, "m_hEffectEntity", item);
		
		SetVariantString("!activator");
		AcceptEntityInput(item, "SetParent", ent);
		
		SetVariantString("weapon_hand_r");
		AcceptEntityInput(item, "SetParentAttachmentMaintainOffset"); 
	}
	////////////////////////////
	
	g_iFakeRef[client] = EntIndexToEntRef(ent);
	
	RequestFrame(Clone_SetupLayers, ent);
	RequestFrame(Clone_SetupAnimations, ent);
	
	SDKHook(client, SDKHook_PostThinkPost, OnClientThink);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitch);
	
	SetEntProp(client, Prop_Send, "m_fEffects", 32);
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, .a = 0);
	
	for (int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (weapon == INVALID_ENT_REFERENCE)
			continue;
		
		weapon = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
		if (weapon == INVALID_ENT_REFERENCE)
			continue;
		
		SDKHook(weapon, SDKHook_SetTransmit, BlockTransmit);
	}
}

stock void DeleteClone(int client)
{
	SDKUnhook(client, SDKHook_PostThinkPost, OnClientThink);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitch);
	
	SetEntProp(client, Prop_Send, "m_fEffects", 0);
	SetEntityRenderMode(client, RENDER_NORMAL);
	SetEntityRenderColor(client, .a = 255);
	
	int iClone = EntRefToEntIndex(g_iFakeRef[client]);
	if(IsValidEntity(iClone))
	{
		AcceptEntityInput(iClone, "Kill");
	}
	
	for (int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (weapon == INVALID_ENT_REFERENCE)
			continue;
		
		weapon = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
		if (weapon == INVALID_ENT_REFERENCE)
			continue;
		
		SDKUnhook(weapon, SDKHook_SetTransmit, BlockTransmit);
	}
}

public void OnClientWeaponSwitch(int client, int weapon)
{
	int iClone = EntRefToEntIndex(g_iFakeRef[client]);
	if(iClone == INVALID_ENT_REFERENCE)
		return;

	//Hide any new weapons that might come up.
	int weaponWorld = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
	if (weaponWorld != INVALID_ENT_REFERENCE)
	{
		//Can't doublehook so it's fine.
		SDKHook(weaponWorld, SDKHook_SetTransmit, BlockTransmit);
	}

	//Update player clones weapon.
	int table = FindStringTable("modelprecache");
	
	char strModel[PLATFORM_MAX_PATH];
	ReadStringTable(table, GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex"), strModel, PLATFORM_MAX_PATH);  
	
	if(StrEqual(strModel, ""))
		return;

	int item = GetEntPropEnt(iClone, Prop_Data, "m_hEffectEntity");
	if(item == INVALID_ENT_REFERENCE)
		return;
	
	SetEntityModel(item, strModel);
	
	//SetEntProp(item, Prop_Send, "m_nSkin",       GetEntProp(weapon, Prop_Send, "m_nSkin"));
	//SetEntProp(item, Prop_Send, "m_nModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));
}

public void OnClientThink(int client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);

	int iClone = EntRefToEntIndex(g_iFakeRef[client]);
	if(iClone == INVALID_ENT_REFERENCE)
		return;
	
	DispatchKeyValueVector(iClone, "origin", GetAbsOrigin(client));
	DispatchKeyValueVector(iClone, "angles", GetAbsAngles(client));
	
	//TeleportEntity(iClone, GetAbsOrigin(client), GetAbsAngles(client), NULL_VECTOR);	
	
	Clone_SetupAnimations(iClone);
}

public Action BlockTransmit(int entity, int client)
{
	return Plugin_Handled;
}

methodmap CBaseAnimating
{
	public CBaseAnimating(int entity) {
		return view_as<CBaseAnimating>(entity);
	}
	
	property int index {
		public get() { 
			return view_as<int>(this); 
		}
	}
	public Address CBaseAnimatingOverlay() {
		int iOffset = (view_as<int>(GetEntityAddress(this.index)) + FindDataMapInfo(this.index, "m_AnimOverlay"));
		return view_as<Address>(LoadFromAddress(view_as<Address>(iOffset), NumberType_Int32));
	}
}

public void Clone_SetupLayers(int iEntity)
{
	//Allocate n layers for max copycat
	for (int i = 0; i <= NUM_LAYERS; i++)
		SDKCall(g_hAllocateLayer, iEntity, 0);
}

public void Clone_SetupAnimations(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	if(client <= 0)
		return;

	SDKCall(g_hResetSequence, iEntity, GetEntProp(client, Prop_Send, "m_nSequence"));
	
	Address overlayP = CBaseAnimating(client).CBaseAnimatingOverlay();
	Address overlay = CBaseAnimating(iEntity).CBaseAnimatingOverlay();
	
	//The magic maker
	for (int i = 0; i <= NUM_LAYERS; i++)
	{
		Address layerP = (overlayP + view_as<Address>(i * CAnimationLayer_Size));
		Address layer  = (overlay  + view_as<Address>(i * CAnimationLayer_Size));
		
		//Copy all teh fun bytes :)))))))))))))))))))))))
		for (int x = 0; x < (CAnimationLayer_Size / 4); x++)
		{
			if(x == 4)
			{
				//Playback rate to 0
				StoreToAddress(layer + view_as<Address>(x * 4), 0, NumberType_Int32);
			}
			else
			{
				any iData = LoadFromAddress(layerP + view_as<Address>(x * 4), NumberType_Int32);
				
				//PrintToServer("%i 0x%X - %i %i from 0x%X", i, layer, x, iData, layerP);
				StoreToAddress(layer + view_as<Address>(x * 4), iData, NumberType_Int32);
			}
		}
	}
	
	for (int i = 0; i < 24; i++)
	{
		float flValue = GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", i);
		SetEntPropFloat(iEntity, Prop_Send, "m_flPoseParameter", flValue, i);
	}
	
	//Play anims a bit so they get played to their set values
	SDKCall(g_hStudioFrameAdvance, iEntity);
}


public int MenuLegitnessHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: DisplayAimbotMenuAtItem(param1);
			case 1: DisplayMiscMenuAtItem(param1);
			case 2: DisplaySpinbotMenuAtItem(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client)) 
		return Plugin_Continue;	
	
	if(!IsPlayerAlive(client))
	{
		if(g_bShowFake[client] && EntRefToEntIndex(g_iFakeRef[client]) != INVALID_ENT_REFERENCE)
		{
			//Remove clone while we are dead.
			DeleteClone(client);
		}
		
		return Plugin_Continue;	
	}
	
	bool bChanged = false;
	
	float oldAngle[3]; oldAngle = angles;
	float oldForward  = vel[0];
	float oldSideMove = vel[1];
	
	if(g_bBunnyHop[client])
	{
		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			int nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			SetEntProp(client, Prop_Data, "m_nOldButtons", (nOldButtons &= ~(IN_JUMP|IN_DUCK)));
		}
	}
	
	if(g_bRecoilControl[client])
	{
		float vPunch[3]; vPunch = GetAimPunchAngle(client);
		ScaleVector(vPunch, -(FindConVar("weapon_recoil_scale").FloatValue));
		
		AddVectors(angles, vPunch, angles);
		
		if(!g_bSilentAim[client]) {
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
		}
		
		//SetEntPropVector(client, Prop_Send, "m_viewPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
		//SetEntPropVector(client, Prop_Send, "m_aimPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
		//SetEntPropVector(client, Prop_Send, "m_aimPunchAngleVel", view_as<float>({0.0, 0.0, 0.0}));
		
		//PrintToServer("%f %f %f", angles[0], angles[1], angles[2]);
		
		bChanged = true;
	}
	
	if(g_bESP[client])
	{
		Radar(client, angles);
		
		if(g_flNextTime[client] <= GetGameTime())
		{
			g_flNextTime[client] = GetGameTime() + UMSG_SPAM_DELAY;
		}
	}
	
	if(g_iAntiAimType[client] != 0 && !(buttons & IN_USE))
	{
		bool bFoundWall = DoAntiAim(client, angles[1]);
		
		angles[0] = 36000088.0;
		
		//Backwards if no wall
		if (!bFoundWall)
		{
			angles[1] -= 180.0;
		}
		
		FixSilentAimMovement(client, oldAngle, angles, vel[0], vel[1], oldForward, oldSideMove);
	}
	
	if(g_bShowFake[client] && EntRefToEntIndex(g_iFakeRef[client]) == INVALID_ENT_REFERENCE)
	{
		CreateClone(client);
	}
	
	if(g_bAimbot[client])
	{
		SetEntProp(client, Prop_Data, "m_bLagCompensation", false);
		SetEntProp(client, Prop_Data, "m_bPredictWeapons", false);
		
		int iAw = GetActiveWeapon(client);
		if(!IsValidEntity(iAw))
			return Plugin_Continue;
	
		if(!(buttons & IN_ATTACK))
		{
			if(IsPlayerReloading(client) || !g_bAutoShoot[client])
				return Plugin_Continue;
		}
		
		int iTarget = -1;
		float target_point[3]; target_point = SelectBestTargetPos(client, angles, iTarget);		
		if (target_point[2] == 0 || iTarget == -1)
			return Plugin_Continue;
		
		if(g_bAutoShoot[client] && (!(buttons & IN_ATTACK)))
		{
			if(IsPlayerReloading(client)) {
				buttons &= ~IN_ATTACK;
			} else {
				buttons |= IN_ATTACK;
			}
		}
		
		float eye_to_target[3];
		
		SubtractVectors(VelocityExtrapolate(iTarget, target_point), 
						VelocityExtrapolate(client, GetEyePosition(client)), 
						eye_to_target);
						
		GetVectorAngles(eye_to_target, eye_to_target);
		
		eye_to_target[0] = AngleNormalize(eye_to_target[0]);
		eye_to_target[1] = AngleNormalize(eye_to_target[1]);
		eye_to_target[2] = 0.0;

		float vPunch[3]; vPunch = GetAimPunchAngle(client);
		ScaleVector(vPunch, -(FindConVar("weapon_recoil_scale").FloatValue));
		
		AddVectors(eye_to_target, vPunch, eye_to_target);
		
		angles = eye_to_target;
		
		if(!g_bSilentAim[client]) {
			TeleportEntity(client, NULL_VECTOR, eye_to_target, NULL_VECTOR);
		}
		else {
			FixSilentAimMovement(client, oldAngle, angles, vel[0], vel[1], oldForward, oldSideMove);
		}
		
		bChanged = true;
		
		SetEntPropFloat(iAw, Prop_Send, "m_fAccuracyPenalty", 0.0);
		//SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

stock bool DoAntiAim(int client, float &angle)
{
	float position[3]; position = GetEyePosition(client); 
	
	float closest_distance = 100.0;
	
	//float radius = 25.3;
	float radius = 40.0;
	float step = FLOAT_PI * 2.0 / 16;
	
	for (float a = 0.0; a < (FLOAT_PI * 2.0); a += step)
	{
		float location[3];
		location[0] = radius * Cosine(a) + position[0];
		location[1] = radius * Sine(a)   + position[1];
		location[2] = position[2];
		
		Handle trace = TR_TraceRayFilterEx(position, location, CONTENTS_SOLID, RayType_EndPoint, AimTargetFilter, client);
		
		if (TR_DidHit(trace))
		{
			float posEnd[3];
			TR_GetEndPosition(posEnd, trace);
				
			//VSF.DebugDrawLine(position, posEnd, 0, 255, 0, true, 0.05);
			
			float distance = GetVectorDistance(position, posEnd);
			
			if (distance < closest_distance)
			{
				closest_distance = distance;
				angle = RadToDeg(a);
			}
		}
		else
		{
			//VSF.DebugDrawLine(position, location, 255, 0, 0, true, 0.05);
		}
		
		delete trace;
	}
 
	return closest_distance < 25.0;
}

float[] VelocityExtrapolate(int client, float eyepos[3])
{
	float absVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", absVel);
	
	float v[3];
	
	v[0] = eyepos[0] + (absVel[0] * GetTickInterval());
	v[1] = eyepos[1] + (absVel[1] * GetTickInterval());
	v[2] = eyepos[2] + (absVel[2] * GetTickInterval());
	
	return v;
}

float[] SelectBestTargetPos(int client, const float realAngles[3], int &iBestEnemy)
{
	float flMyPos[3]; flMyPos = GetAbsOrigin(client);

	float flTargetPos[3];
	float flClosestDistance = 999999999999999.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if (GetEntProp(i, Prop_Send, "m_bGunGameImmunity"))
			continue;
		
		if(GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		int iBone = LookupBone(i, "ValveBiped.Bip01_Head");
		if(iBone < 0)
			continue;
			
		float vecHead[3], vecBad[3];
		GetBonePosition(i, iBone, vecHead, vecBad);
		
		//Give this man a raise!
		vecHead[2] += 4.0;
		
		if(!IsPointVisible(client, i, GetEyePosition(client), vecHead))
		{
			if(g_bHeadshots[client])
				continue;
		
			bool bVisibleOther = false;
		
			//Head wasn't visible, check other bones.
			for (int b = 0; b < 40; b++)
			{
				GetBonePosition(i, b, vecHead, vecBad);
				
				if(IsPointVisible(client, i, GetEyePosition(client), vecHead))
				{
					bVisibleOther = true;
					break;
				}
			}
			
			//PrintToServer("BodyAim ? %s", bVisibleOther ? "YES" : "NO");
			
			if(!bVisibleOther)
				continue;
		}

		float flEnemyPos[3]; flEnemyPos = GetAbsOrigin(i);
			
		float flDistance = GetVectorDistance(flEnemyPos, flMyPos, true)
		if(flDistance < flClosestDistance)
		{
			flClosestDistance = flDistance;
			flTargetPos = vecHead;
			
			iBestEnemy = i;
		}
	}
	
	return flTargetPos;
}

bool IsPlayerReloading(int client)
{
	int PlayerWeapon = GetActiveWeapon(client);
	
	if(!IsValidEntity(PlayerWeapon))
		return false;
	
	//Out of ammo?
	if(GetEntProp(PlayerWeapon, Prop_Data, "m_iClip1") == 0)
		return true;
	
	//Reloading?
	if(GetEntProp(PlayerWeapon, Prop_Data, "m_bInReload"))
		return true;
	
	//Ready to fire?
	if(GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flNextPrimaryAttack") <= GetGameTime())
		return false;
	
	return true;
}

stock void Radar(int client, float playerAngles[3])
{
	//float flMyPos[3];
	//GetClientAbsOrigin(client, flMyPos);
	
	//float screenx, screeny;
	//float vecGrenDelta[3];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		//float vecMaxs[3], vecMins[3];
		//GetEntPropVector(i, Prop_Send, "m_vecMaxs", vecMaxs);
		//GetEntPropVector(i, Prop_Send, "m_vecMins", vecMins);
		
		if(g_bSnapLines[client])
			VSF.DebugDrawLine(GetAbsOrigin(client), GetAbsOrigin(i), 255, 0, 0, true, 0.05);
		
		HealthBar(i, playerAngles);
	/*	
		float flEnemyPos[3];
		flEnemyPos[2] = flMyPos[2]; //We only care about 2D
		
		vecGrenDelta = GetDeltaVector(client, i);
		NormalizeVector(vecGrenDelta, vecGrenDelta);
		GetEnemyPosToScreen(client, playerAngles, vecGrenDelta, screenx, screeny, GetVectorDistance(flMyPos, GetAbsOrigin(i)) * 0.25);
		
		SetHudTextParams(screenx, screeny, UMSG_SPAM_DELAY + 0.5, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudRadar[i], "⬤");*/
	}
}

void HealthBar( int pEntity, float playerAngles[3] )
{
	float vecOrigin[3]; vecOrigin = GetAbsOrigin(pEntity);
	
	float vecMaxs[3], vecMins[3];
	GetEntPropVector(pEntity, Prop_Send, "m_vecMaxs", vecMaxs);
	GetEntPropVector(pEntity, Prop_Send, "m_vecMins", vecMins);
	
	VSF.DebugDrawBox(vecOrigin, vecMaxs, vecMins, 255, 0, 0, 55, 0.05);
	
	float vLeft[3];
	GetAngleVectors(playerAngles, NULL_VECTOR, vLeft, NULL_VECTOR);
	
	MapCircleToSquare(vLeft, vLeft);
	
	vecOrigin[0] -= (vLeft[0] * vecMaxs[0]) * 1.15;
	vecOrigin[1] -= (vLeft[1] * vecMaxs[1]) * 1.15;
	
	int iBoxes = RoundToCeil(GetClientHealth(pEntity) / 10.0);
	
	vecMaxs[2] = (vecMaxs[2] / 100) * 10;
	
	//Healthbar width stuff
	vecMaxs[0] = vecMaxs[1] = 2.0;
	vecMins[0] = vecMins[1] = -2.0;
	
	float flHPRatio = (GetClientHealth(pEntity) / 100.0) * 100;

	int R = flHPRatio < 50 ? 255 : RoundToFloor(255 - (flHPRatio * 2 - 100) * 255 / 100);
	int G = flHPRatio > 50 ? 255 : RoundToFloor((flHPRatio * 2) * 255 / 155);
	int B = 0;

	for ( int i = 0; i < iBoxes; i++ )
	{
		VSF.DebugDrawBox(vecOrigin, vecMaxs, vecMins, R, G, B, 55, 0.05);
	
		vecOrigin[2] += vecMaxs[2];
	}
}

void MapCircleToSquare(float out[3], const float input[3]) 
{ 
	float x = input[0], y = input[1]; 
	float nx, ny; 
	
	if(x < 0.000002 && x > -0.000002) 
	{ 
		nx = 0.0; 
		ny = y; 
	} 
	else if(y < 0.000002 && y > -0.000002) 
	{ 
		nx = x; 
		ny = 0.0; 
	} 
	else if (y > 0.0) 
	{ 
		if (x > 0.0) 
		{ 
			if (x < y) 
			{ 
				nx = x / y; 
				ny = 1.0; 
			} 
			else 
			{ 
				nx = 1.0; 
				ny = y / x; 
			} 
		} 
		else 
		{ 
			if (x < -y) 
			{ 
				nx = -1.0; 
				ny = -(y / x); 
			} 
			else 
			{ 
				nx = x / y; 
				ny = 1.0; 
			} 
		} 
	}
	else 
	{ 
		if (x > 0.0) 
		{ 
			if (-x > y) 
			{
				nx = -(x / y); 
				ny = -1.0; 
			} 
			else 
			{ 
				nx = 1.0; 
				ny = (y / x); 
			} 
		} 
		else 
		{ 
			if (x < y) 
			{ 
				nx = -1.0; 
				ny = -(y / x); 
			} 
			else 
			{ 
				nx = -(x / y); 
				ny = -1.0; 
			} 
		} 
	}
	
	out[0] = nx; 
	out[1] = ny; 
}  

stock void GetEnemyPosToScreen(int client, float playerAngles[3], float vecDelta[3], float& xpos, float& ypos, float flRadius)
{
	if(flRadius > 400.0)
		flRadius = 400.0;

	float vecforward[3], right[3], up[3] = { 0.0, 0.0, 1.0 };
	GetAngleVectors(playerAngles, vecforward, NULL_VECTOR, NULL_VECTOR );
	vecforward[2] = 0.0;

	NormalizeVector(vecforward, vecforward);
	GetVectorCrossProduct(up, vecforward, right);

	float front = GetVectorDotProduct(vecDelta, vecforward);
	float side  = GetVectorDotProduct(vecDelta, right);

	xpos = flRadius * -front;
	ypos = flRadius * -side;
	
	float flRotation = (ArcTangent2(xpos, ypos) + FLOAT_PI) * (180.0 / FLOAT_PI);
	
	float yawRadians = -flRotation * FLOAT_PI / 180.0; // Convert back to radians
	
	// Rotate it around the circle
	xpos = (500 + (flRadius * Cosine(yawRadians))) / 1000.0; // divide by 1000 to make it fit with HudTextParams
	ypos = (500 - (flRadius * Sine(yawRadians)))   / 1000.0;
}

stock float[] GetDeltaVector(const int client, const int target)
{
	float vec[3];

	float vecPlayer[3];	
	GetClientAbsOrigin(client, vecPlayer);
	
	float vecPos[3];	
	GetClientAbsOrigin(target, vecPos);
	
	SubtractVectors(vecPlayer, vecPos, vec);
	return vec;
}


#define DEG2RAD(%1) ((%1) * FLOAT_PI / 180.0)

stock void FixSilentAimMovement(int client, float vOldAngles[3],    float vViewAngles[3], float &flForwardMove, float &flSideMove,      float fOldForward, float fOldSidemove)
{
	float deltaView;
	float f1;
	float f2;
	
	if (vOldAngles[1] < 0.0)
		f1 = 360.0 + vOldAngles[1];
	else
		f1 = vOldAngles[1];
	
	if (vViewAngles[1] < 0.0)
		f2 = 360.0 + vViewAngles[1];
	else
		f2 = vViewAngles[1];
	
	if (f2 < f1)
		deltaView = FloatAbs(f2 - f1);
	else
		deltaView = 360.0 - FloatAbs(f1 - f2);
		
	deltaView = 360.0 - deltaView;
	
	flForwardMove = Cosine(DEG2RAD(deltaView)) * fOldForward + Cosine(DEG2RAD(deltaView + 90.0)) * fOldSidemove;
	flSideMove    =   Sine(DEG2RAD(deltaView)) * fOldForward +   Sine(DEG2RAD(deltaView + 90.0)) * fOldSidemove;
}

stock bool IsPointVisible(int looker, int target, float start[3], float point[3])
{
	TR_TraceRayFilter(start, point, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, looker);
	if(!TR_DidHit() || TR_GetEntityIndex() == target)
	{
		return true;
	}
	
	return false;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "player"))
	{
		return false;
	}
	
	return !(entity == iExclude);
}

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock int LookupBone(int iEntity, const char[] szName)
{
	return SDKCall(g_hLookupBone, iEntity, szName);
}

stock void GetBonePosition(int iEntity, int iBone, float origin[3], float angles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, origin, angles);
}

stock float[] GetViewPunchAngle(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_viewPunchAngle", v);
	return v;
}

stock float[] GetAimPunchAngle(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_aimPunchAngle", v);
	return v;
}

stock float[] GetAbsVelocity(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", v);
	return v;
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] GetAbsAngles(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", v);
	
	return v;
}

stock float[] GetEyePosition(int client)
{
	float v[3];
	GetClientEyePosition(client, v);
	return v;
}

stock float[] GetEyeAngles(int client)
{
	float v[3];
	GetClientEyeAngles(client, v);
	return v;
}

stock int GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}