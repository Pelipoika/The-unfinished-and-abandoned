#include <sdktools>
#include <sdkhooks>

#pragma newdecls required;

#define Address(%1) view_as<Address>(%1)
#define int(%1) view_as<int>(%1)

bool g_bAimbot[MAXPLAYERS + 1];

enum 
{
	AIM_NEAR = 0,
	AIM_FOV,
	
	NUM_AIM_MODES,
};

int g_iAimType[MAXPLAYERS + 1];
float g_flAimFOV[MAXPLAYERS + 1];

bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bBunnyHop[MAXPLAYERS + 1];
bool g_bHeadshots[MAXPLAYERS + 1];
bool g_bAnnouncer[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[L4D2] Aimbot V2",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

Handle g_hGetBonePosition;

Address TheZombieManager;

int g_iOffsetStudioHdr;

//TODO

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks", Command_Trigger, ADMFLAG_BAN);
	
	RegAdminCmd("sm_zombiemanager", Command_TheZombieManager, 0);
	
	for (int i = 1; i <= MaxClients; i++) {	
		OnClientPutInServer(i); 
	}
	
	Handle hConf = LoadGameConfigFile("l4d2_aimbot");
	
	// STR: "rhand", "ValveBiped.Bip01_L_Hand", "lhand", "ValveBiped.Bip01_R_Hand"
	//void CBaseAnimating::GetBonePosition ( int iBone, Vector &origin, QAngle &angles )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetBonePosition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
	
	//Get TheZombieManager ptr
	TheZombieManager = GameConfGetAddress(hConf, "TheZombieManager");
	PrintToServer("Found \"TheZombieManager\" @ 0x%X", TheZombieManager);
	
	delete hConf;
	
	HookEvent("player_death", Event_Kill, EventHookMode_Post);

	g_iOffsetStudioHdr = FindSendPropInfo("CTerrorPlayer", "m_flexWeight") - 552;
}

public Action Command_TheZombieManager(int client, int argc)
{
	ReplyToCommand(client, "\"TheZombieManager\" is @ 0x%X", TheZombieManager);

	return Plugin_Handled;
}

/*
"Gambler"
"Producer"
"Coach"
"Mechanic"
"NamVet"
"TeenGirl"
"Biker"
"Manager"

"Nick"
"Rochelle"
"Coach"
"Ellis"
"Bill"
"Zoey"
"Francis"
"Louis"

Server event "player_death", Tick 9773:
- "userid" = "0"
- "entityid" = "160"
- "attacker" = "2"
- "attackername" = ""
- "attackerentid" = "0"
- "weapon" = "rifle_ak47"
- "headshot" = "1"
- "attackerisbot" = "0"
- "victimname" = "Infected"
- "victimisbot" = "1"
- "abort" = "0"
- "type" = "-1073741822"
- "victim_x" = "-5937.33"
- "victim_y" = "-2766.72"
- "victim_z" = "628.03"
*/
public void Event_Kill(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	
	if(!g_bAnnouncer[client])
		return;
	
	bool bWasHeadShot = event.GetBool("headshot");
	
	char victimname[32], weapon[32];
	event.GetString("victimname", victimname, sizeof(victimname));
	event.GetString("weapon", weapon, sizeof(weapon));
	
	char sMessage[PLATFORM_MAX_PATH];
	Format(sMessage, PLATFORM_MAX_PATH, "[AIMBOT] Killed \"%s\" with \"%s\" %s", victimname, weapon, bWasHeadShot ? "by headshot!" : "");
	
	float flRate = 2.0;
	
	Handle msg = StartMessageOne("MessageText", client);
	BfWriteByte(msg, RoundToNearest(Cosine((GetGameTime() * flRate) + client + 0) * 127.5 + 127.5));	//RED
	BfWriteByte(msg, RoundToNearest(Cosine((GetGameTime() * flRate) + client + 2) * 127.5 + 127.5));	//GREEN
	BfWriteByte(msg, RoundToNearest(Cosine((GetGameTime() * flRate) + client + 4) * 127.5 + 127.5)); 	//BLUE	
	BfWriteString(msg, sMessage);
	EndMessage();

	//PrintToChat(client, "[AIMBOT] Killed \"%s\" with \"%s\" %s", victimname, weapon, bWasHeadShot ? "by headshot!" : "");
}

public void OnClientPutInServer(int client)
{
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bSilentAim[client] = false;
	g_bAnnouncer[client] = false;
	
	g_iAimType[client] = AIM_NEAR;
	g_flAimFOV[client] = 10.0;
	
	g_bBunnyHop[client] = false;
	g_bHeadshots[client] = false;
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
	menu.SetTitle("LMAOBOX L4D2");
	menu.AddItem("0", "Aimbot");
	menu.AddItem("1", "Misc");
	
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
	
	if(g_iAimType[client] == AIM_NEAR)
		menu.AddItem("1", "Aim Type: Closest");
	else if(g_iAimType[client] == AIM_FOV)
		menu.AddItem("1", "Aim Type: FOV");
		
	char FOV[64];
	Format(FOV, sizeof(FOV), "Aim FOV: %.2f", g_flAimFOV[client]);
	menu.AddItem("2", FOV);
	
	if(g_bAutoShoot[client])
		menu.AddItem("3", "Auto Shoot: On");
	else
		menu.AddItem("3", "Auto Shoot: Off");

	if(g_bSilentAim[client])
		menu.AddItem("4", "Silent Aim: On");
	else
		menu.AddItem("4", "Silent Aim: Off");
		
	if(g_bHeadshots[client])
		menu.AddItem("5", "Headshots only: On");
	else
		menu.AddItem("5", "Headshots only: Off");
		
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
		
	if(g_bAnnouncer[client])
		menu.AddItem("1", "Kill Announcer: On");
	else
		menu.AddItem("1", "Kill Announcer: Off");
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
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
					
					//TE_Start("FoundryHelpers");
					//TE_WriteNum("m_iEntity", -1);
					//TE_SendToClient(param1);
				}
			}
			case 1: 
			{
				if     (g_iAimType[param1] == AIM_NEAR) g_iAimType[param1] = AIM_FOV;
				else if(g_iAimType[param1] == AIM_FOV)  g_iAimType[param1] = AIM_NEAR;
			}
			case 2: { PrintToConsole(param1, "Fuck all."); }
			case 3: 
			{
				g_bAutoShoot[param1] = !g_bAutoShoot[param1];
			}
			case 4: 
			{
				g_bSilentAim[param1] = !g_bSilentAim[param1];
			}
			case 5: 
			{
				g_bHeadshots[param1] = !g_bHeadshots[param1];
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
			case 1: g_bAnnouncer[param1] = !g_bAnnouncer[param1];
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

public int MenuLegitnessHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: DisplayAimbotMenuAtItem(param1);
			case 1: DisplayMiscMenuAtItem(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	bool bShouldHighlight = false;
	
	if(entity > 0 && entity <= MaxClients)
	{
		bShouldHighlight = true;
	}
	
	if (StrEqual(classname, "infected") || StrEqual(classname, "witch"))
	{
		bShouldHighlight = true;
	}

	if(bShouldHighlight)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			if(IsFakeClient(i))
				continue;
			
			if(!g_bAimbot[i])
				continue;
			
			if(i == entity)
				continue;
			
			//TE_Start("FoundryHelpers");
			//TE_WriteNum("m_iEntity", entity);
			//TE_SendToClient(i);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client)) 
		return Plugin_Continue;	
	
	//On a ladder
	if(GetEntityMoveType(client) == MOVETYPE_LADDER)
		return Plugin_Continue; 
	
	//Can't do anything while hanging from ledge
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return Plugin_Continue;
	
	float oldAngle[3]; oldAngle = angles;
	float oldForward  = vel[0];
	float oldSideMove = vel[1];
	
	if(g_bBunnyHop[client])
	{
		if((buttons & IN_JUMP) && GetEntityFlags(client) & FL_ONGROUND)
		{
			int nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			SetEntProp(client, Prop_Data, "m_nOldButtons", (nOldButtons &= ~(IN_JUMP|IN_DUCK)));
		}
	}
	
	if(g_bAimbot[client]) 
	{
		int iAw = GetActiveWeapon(client);
	
		//Not holding a weapon
		if(!IsValidEntity(iAw) || IsPlayerReloading(client))
			return Plugin_Continue;
		
		//Not a shooty weapon
		if(!HasEntProp(iAw, Prop_Send, "m_iPrimaryAmmoType") 
		|| GetEntProp(iAw, Prop_Send, "m_iPrimaryAmmoType") == -1
		|| !HasEntProp(iAw, Prop_Data, "m_iClip1") 
		|| GetEntProp(iAw, Prop_Data, "m_iClip1") <= 0)
			return Plugin_Continue;
		
		//Remove recoil
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
		SetEntPropVector(client, Prop_Data, "m_vecPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", view_as<float>({0.0, 0.0, 0.0}));
		SetEntPropVector(client, Prop_Data, "m_vecPunchAngleVel", view_as<float>({0.0, 0.0, 0.0}));
	
		static int iOffsetToSpread;
		if(iOffsetToSpread == 0) {
			PrintToServer("[AIMBOT] Updated max_spread offset!");
			iOffsetToSpread = FindSendPropInfo("CTerrorWeapon", "m_DroppedByInfectedGender") + 60;
		}
		
		static int iOffsetPunchAngle;
		if(iOffsetPunchAngle == 0) {
			PrintToServer("[AIMBOT] Updated PunchAngle offset!");
			iOffsetPunchAngle = FindSendPropInfo("CBasePlayer", "m_Local") + 112;
		}

		//Some weird weapon recoil property hidden in the player
		SetEntDataVector(client, iOffsetPunchAngle, view_as<float>( { 0.0, 0.0, 0.0 } ));
		
		//Make the spread huge so the game doesn't have time to add any to it before the bullet trace happens.
		SetEntDataFloat(iAw, iOffsetToSpread, -90.0);
		
		DoAimbot(client, iAw, buttons, oldAngle, angles, vel[0], vel[1], oldForward, oldSideMove);
	}

	FixSilentAimMovement(client, oldAngle, angles, vel[0], vel[1], oldForward, oldSideMove);
	
	return Plugin_Changed;
}

stock bool DoAimbot(int client, int iAw, int &buttons, const float vOldAngles[3], float vViewAngles[3], 
					float &flForwardMove, float &flSideMove, float &fOldForward, float &fOldSidemove)
{
	SetEntProp(client, Prop_Data, "m_bLagCompensation", false);
	SetEntProp(client, Prop_Data, "m_bPredictWeapons", false);	

	//float spread = GetEntDataFloat(iAw, iOffsetToSpread);
	//PrintToServer("spread %f", spread);
	
	//float flSpreadX = SDKCall(g_hSharedRandomFloat, "CTerrorGun::FireBullet HorizSpread", -spread, spread, 0);
	//float flSpreadY = SDKCall(g_hSharedRandomFloat, "CTerrorGun::FireBullet VertSpread",  -spread, spread, 0);
	//
	//PrintToServer("flSpreadX %f, flSpreadY %f", flSpreadX, flSpreadY);
	
	//angles[0] += flSpreadX;
	//angles[1] += flSpreadY;
	
	//Force aim if user is holding m1
	if(!(buttons & IN_ATTACK)) {
		if(IsPlayerReloading(client) || !g_bAutoShoot[client]) {
			return false;
		}
	}
	
	int iTarget = INVALID_ENT_REFERENCE;
	float target_point[3]; target_point = SelectBestTargetPos(client, vOldAngles, iTarget);		
	if (iTarget == INVALID_ENT_REFERENCE)
		return false;
	
	if(g_bAutoShoot[client] && (!(buttons & IN_ATTACK)))
	{
		//We can't simply hold M1 to fire, gotta let go of M1 every once in a while
		if(IsPlayerReloading(client)) {
			buttons &= ~IN_ATTACK;
		} else {
			buttons |= IN_ATTACK;
		}
		
		//(IsPlayerReloading(client) ? (buttons &= ~IN_ATTACK) : (buttons |= IN_ATTACK))
	}
	
	float target_point_adjusted[3];
	
	if(fOldForward != 0 || fOldSidemove != 0)
	{
		//Extrapolate target_point if we are moving.
		SubtractVectors(VelocityExtrapolate(iTarget, target_point),  
						VelocityExtrapolate(client, GetEyePosition(client)),  
						target_point_adjusted);
	}
	else
	{
		SubtractVectors(target_point, GetEyePosition(client), target_point_adjusted);
	}
	
	SnapEyeAngles(client, target_point_adjusted, vViewAngles);
	
	return true;
}

stock int GetEnemyTeam(int ent)
{
	int enemy_team = GetClientTeam(ent);
	switch(enemy_team)
	{
		case 2: enemy_team = 3;
		case 3: enemy_team = 2;
	}
	
	return enemy_team;
}

float[] VelocityExtrapolate(int client, float point[3])
{
	float absVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", absVel);
	
	float v[3];
	
	v[0] = point[0] + (absVel[0] * GetTickInterval());
	v[1] = point[1] + (absVel[1] * GetTickInterval());
	v[2] = point[2] + (absVel[2] * GetTickInterval());
	
	return v;
}

float[] SelectBestTargetPos(int client, const float oldAngles[3], int &iBestEnemy)
{
	float flMyPos[3]; flMyPos = GetEyePosition(client);

	float flTargetPos[3];
	float flClosestDistance = 8192.0;

	//FOV aim stuff
	float nearest;
	float fov = g_flAimFOV[client];


	//Shoot special infected
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;

		//SetEntProp(i, Prop_Send, "m_iGlowType", 0);
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(!IsValidAliveTarget(client, i))
			continue;
		
		//SetEntProp(i, Prop_Send, "m_iGlowType", 3);
		//SetEntProp(i, Prop_Send, "m_glowColorOverride", 255 + (0 * 256) + (255 * 65536));
		
		float vVisiblePos[3]; 
		
		//Not visible at all.
		if(!GetBestHitBox(client, i, vVisiblePos))
			continue;
		
		if(g_iAimType[client] == AIM_FOV)
		{
			nearest = GetFov(oldAngles, CalcAngle(GetEyePosition(client), GetEyePosition(i)));
		
			if (nearest > fov)
				continue;
			
			float distance = GetDistance(GetAbsOrigin(client), GetAbsOrigin(i));
			
			if (FloatAbs(fov - nearest) < 5)
			{
				if (distance < flClosestDistance)
				{
					fov = nearest;
					flClosestDistance = distance;
					flTargetPos = vVisiblePos;
					
					iBestEnemy = i;
				}
			}
			else if (nearest < fov)
			{
				fov = nearest;
				flClosestDistance = distance;
				flTargetPos = vVisiblePos;
				
				iBestEnemy = i;
			}
		}
		else
		{
			float flDistance = GetVectorDistance(flMyPos, vVisiblePos);
			if(flDistance < flClosestDistance)
			{
				flClosestDistance = flDistance;
				
				flTargetPos = vVisiblePos;
				
				iBestEnemy = i;
			}
		}
	}
	
	if(iBestEnemy > 0) 
	{
		return flTargetPos;
	}
	

	//Shoot infected because we didn't find special infected.
	int infected = -1;
	while((infected = FindEntityByClassname(infected, "infected")) != -1)
	{
		//SetEntProp(infected, Prop_Send, "m_iGlowType", 0);
	
		if(!IsValidAliveTarget(client, infected))
			continue;
		
		//SetEntProp(infected, Prop_Send, "m_iGlowType", 3);
		//SetEntProp(infected, Prop_Send, "m_glowColorOverride", 255 + (0 * 256) + (0 * 65536));
		
		float vVisiblePos[3]; 
		
		//Not visible at all.
		if(!GetBestHitBox(client, infected, vVisiblePos))
			continue;
			
		if(g_iAimType[client] == AIM_FOV)
		{
			//TODO FIX GetEyePosition for infected
			nearest = GetFov(oldAngles, CalcAngle(GetEyePosition(client), GetPlayerCenterOfMass(infected)));
		
			if (nearest > fov)
				continue;
				
			float distance = GetDistance(GetAbsOrigin(client), GetAbsOrigin(infected));
			
			if (FloatAbs(fov - nearest) < 5)
			{
				if (distance < flClosestDistance)
				{
					fov = nearest;
					flClosestDistance = distance;
					flTargetPos = vVisiblePos;
					
					iBestEnemy = infected;
				}
			}
			else if (nearest < fov)
			{
				fov = nearest;
				flClosestDistance = distance;
				flTargetPos = vVisiblePos;
				
				iBestEnemy = infected;
			}
		}
		else
		{
			float flDistance = GetVectorDistance(flMyPos, vVisiblePos);
			if(flDistance < flClosestDistance)
			{
				flClosestDistance = flDistance;
				
				flTargetPos = vVisiblePos;
				
				iBestEnemy = infected;
			}
		}
	}
	
	//if(iBestEnemy > 0) 
	//{
		//SetEntProp(iBestEnemy, Prop_Send, "m_glowColorOverride", 55 + (255 * 256) + (0 * 65536));
	//}
	
	return flTargetPos;
}

bool IsValidAliveTarget(int client, int entity)
{
	//Target is not alive
	if(GetEntProp(entity, Prop_Data, "m_lifeState") != 0)
		return false;

	//Burning zombies die off naturally
	if(HasEntProp(entity, Prop_Data, "m_bIsBurning") && GetEntProp(entity, Prop_Data, "m_bIsBurning"))
		return false;
	
	//Target is not an enemy
	if(GetEntProp(entity, Prop_Data, "m_iTeamNum") != GetEnemyTeam(client))
		return false;
	
	return true;
}

bool IsPlayerReloading(int client)
{
	int PlayerWeapon = GetActiveWeapon(client);
	if(!IsValidEntity(PlayerWeapon))
		return true;
		
	bool bReloading = true;
	
	float flNextPrimaryAttack   = GetGameTime() - GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flNextPrimaryAttack");
	
	bool m_bInReload = !!GetEntProp(PlayerWeapon, Prop_Data, "m_bInReload");
	
	//Can fire?
	if(flNextPrimaryAttack > 0)
		bReloading = false;
	
	//Has ammo and is not reloading
	if(GetEntProp(PlayerWeapon, Prop_Send, "m_iClip1") <= 0 && m_bInReload)
		bReloading = true;
	
	return bReloading;
}

enum //hitgroup_t
{
	HITGROUP_GENERIC,
	HITGROUP_HEAD,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
	
	NUM_HITGROUPS
};

int g_iHitBoxOrderHeadshot[] = 
{
	HITGROUP_HEAD,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_GENERIC,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
}

int g_iHitBoxOrderBullet[] = 
{
	HITGROUP_STOMACH,
	HITGROUP_CHEST,
	HITGROUP_GENERIC,
	HITGROUP_HEAD,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
}

stock bool GetBestHitBox(int client, int entity, float vBestOut[3])
{
	Address pStudioHdr = Address(Dereference(Address(GetEntData(entity, g_iOffsetStudioHdr))));
	if(pStudioHdr == Address_Null)
		return false;
	
	int m_nHitboxSet = GetEntProp(entity, Prop_Send, "m_nHitboxSet");
	if(m_nHitboxSet != 0)
		return false;
	
	Address pHitBoxSet = pStudioHdr + Address(ReadInt(pStudioHdr + Address(0xB0)));
	if(pHitBoxSet == Address_Null)
		return false;
	
	int iNumHitboxes = ReadInt(pHitBoxSet + Address(0x4));
	
	//Into the abyss.
	pHitBoxSet += Address(0xC);
	
	//Check if any hitbox is visible in an order
	//that makes sense for our active weapon
	//In L4D2 all weapons can headshot (i think)
	bool bShouldHeadshot = true;
	
	//Loop all hitgroups
	for (int i = 0; i < NUM_HITGROUPS; i++)
	{
		//Match hitgroup to order we want to check
		int hitGroup = (bShouldHeadshot ? (g_iHitBoxOrderHeadshot[i]) : (g_iHitBoxOrderBullet[i]));
	
		//User wants headshots only, don't check for any other hitbox than head.
		if(g_bHeadshots[client] && hitGroup != HITGROUP_HEAD)
			continue;
	
		for (int iHitBox = 0; iHitBox < iNumHitboxes; iHitBox++)
		{
			//mstudiobbox_t 
			Address pbox = Address(pHitBoxSet + Address(iHitBox * 0x44));
			if(pbox == Address_Null)
				continue;
			
			int iBone  = ReadInt(pbox);
			int iGroup = ReadInt(pbox + Address(0x4));
			
			if(iGroup != hitGroup)
				continue;
			
			float vBonePosition[3], vBoneAngles[3];
			GetBonePosition(entity, iBone, vBonePosition, vBoneAngles);
						
			//TODO
			//If doing headshot only, perform multipoint checking on head hitbox.
			//Is center visible?
			bool bVisible = false;
						
			if(g_bHeadshots[client] && iGroup == HITGROUP_HEAD)
			{
				float vMins[3]; vMins = ExtractVectorFromAddress(pbox + Address(0x8)); 
				float vMaxs[3]; vMaxs = ExtractVectorFromAddress(pbox + Address(0x14)); 
			
				//Hitbox Size
				float vSize[3];
				vSize[0] = FloatAbs(vMaxs[0]) + FloatAbs(vMins[0]);
				vSize[1] = FloatAbs(vMaxs[1]) + FloatAbs(vMins[1]);
				vSize[2] = FloatAbs(vMaxs[2]) + FloatAbs(vMins[2]);
				
				//Hitbox Origin
				float vCenter[3]; 
				AddVectors(vMins, vMaxs, vCenter);
				ScaleVector(vCenter, 0.5);
				
				//Angle vectors
				float vForward[3], vLeft[3], vUp[3];
				GetAngleVectors(vBoneAngles, vForward, vLeft, vUp);
				
				//Center bone pos to hitbox
				vBonePosition[0] += vLeft[2] * vCenter[2];
				vBonePosition[1] += vLeft[0] * vCenter[0];
				vBonePosition[2] -= vLeft[2] * vCenter[1];
			}
			
			bVisible = (IsPointVisible(client, entity, GetEyePosition(client), vBonePosition, hitGroup));
			
			if(bVisible)
			{
				//Since we traverse the hitboxes in an ideal order, 
				//we may break/return on the first visible hitbox.
				vBestOut = vBonePosition;
				
				return true;
			}
		}
	}
	
	return false;
}

//TODO
stock float[] GetHitBox(int entity, int hitbox)
{
	
}

//Correct movement for silent aim
stock void FixSilentAimMovement(int client, const float vOldAngles[3],    float vViewAngles[3], float &flForwardMove, float &flSideMove,      float fOldForward, float fOldSidemove)
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
	
	flForwardMove = Cosine(DegToRad(deltaView)) * fOldForward + Cosine(DegToRad(deltaView + 90.0)) * fOldSidemove;
	flSideMove    =   Sine(DegToRad(deltaView)) * fOldForward +   Sine(DegToRad(deltaView + 90.0)) * fOldSidemove;
}

stock bool IsPointVisible(int looker, int target, float start[3], float point[3], int expectedHitGroup)
{
	TR_TraceRayFilter(start, point, 0x46004003, RayType_EndPoint, ShouldHitEntity, looker);
	
	int hitGroup = TR_GetHitGroup();
	int hitEnt   = TR_GetEntityIndex();
	
	//PrintToServer("hitEnt %i; got %i expected %i == %s", hitEnt, hitGroup, expectedHitGroup, hitGroup == expectedHitGroup ? "YES" : "NO"); 
	
	if(!TR_DidHit() || hitEnt == target)
	{
		//Ignore hitgroup expectance if not headshot only.
		if(g_bHeadshots[looker]) {
			return hitGroup == expectedHitGroup
		} else {
			return true;
		}
	}
	
	return false;
}

public bool ShouldHitEntity(int entity, int contentsMask, any iExclude)
{
	char class[64]; GetEntityClassname(entity, class, sizeof(class));
	
	if(entity > MaxClients) 
	{
		//We can shoot through these :)
		if(StrEqual(class, "func_breakable")                || StrEqual(class, "func_brush")
		|| StrEqual(class, "prop_door_rotating")            || StrEqual(class, "prop_dynamic")
		|| StrEqual(class, "prop_physics")                  || StrEqual(class, "func_simpleladder")
		|| StrEqual(class, "prop_door_rotating_checkpoint") || StrEqual(class, "phys_bone_follower")
		|| StrEqual(class, "prop_car_alarm")                || StrEqual(class, "prop_car_glass")
		|| StrEqual(class, "func_breakable_surf")           || StrEqual(class, "env_player_blocker"))
		{
			return GetEntProp(entity, Prop_Data, "m_takedamage") != 2;
		}
		
		//if(!StrEqual(class, "infected"))
			//PrintToServer("ShouldHitEntity %s", class);
	}

	return !(entity == iExclude);
}

stock void SnapEyeAngles(int client, float target_point[3], float cmdAngles[3])
{
	float eye_to_target[3];
	GetVectorAngles(target_point, eye_to_target);
	
	eye_to_target[0] = AngleNormalize(eye_to_target[0]);
	eye_to_target[1] = AngleNormalize(eye_to_target[1]);
	eye_to_target[2] = 0.0;

	cmdAngles = eye_to_target;

	if(!g_bSilentAim[client]) {
		TeleportEntity(client, NULL_VECTOR, eye_to_target, NULL_VECTOR);
	}
}

stock float[] GetPlayerCenterOfMass(int client)
{
	float v[3]; v = GetAbsOrigin(client);
	
	float vecMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", vecMaxs);
	
	v[2] += (vecMaxs[2] / 2);
	
	return v;
}

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock void GetBonePosition(int iEntity, int iBone, float origin[3], float angles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, origin, angles);
}

stock float GetFov(const float viewAngle[3], const float aimAngle[3])
{
	float ang[3], aim[3];
	
	GetAngleVectors(viewAngle, aim, NULL_VECTOR, NULL_VECTOR);
	GetAngleVectors(aimAngle,  ang, NULL_VECTOR, NULL_VECTOR);

	return RadToDeg(ArcCosine(GetVectorDotProduct(aim, ang) / GetVectorLength(aim, true)));
}

stock float[] CalcAngle(float src[3], float dst[3])
{
	float angles[3];
	float delta[3];
	SubtractVectors(dst, src, delta);

	GetVectorAngles(delta, angles);

	return angles;
}

stock float GetDistance(float src[3], float dst[3])
{
	return SquareRoot(Pow(src[0] - dst[0], 2.0) + Pow(src[1] - dst[1], 2.0) + Pow(src[2] - dst[2], 2.0));
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

stock float[] ExtractVectorFromAddress(Address address)
{
	float v[3];
	
	v[0] = view_as<float>(ReadInt(address + Address(0x0)));
	v[1] = view_as<float>(ReadInt(address + Address(0x4)));
	v[2] = view_as<float>(ReadInt(address + Address(0x8)));
	
	return v;
}

stock Address Transpose(Address pAddr, int iOffset)		
{
	return Address(int(pAddr) + iOffset);		
}

stock int Dereference(Address pAddr, int iOffset = 0)		
{
	if(pAddr == Address_Null)		
	{
		return -1;
	}
	
	return ReadInt(Transpose(pAddr, iOffset));
} 

stock int ReadInt(Address pAddr)
{
	if(pAddr == Address_Null)
	{
		return -1;
	}
	
	return LoadFromAddress(pAddr, NumberType_Int32);
}