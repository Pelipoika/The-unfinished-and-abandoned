#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <utilsext>

#pragma newdecls required;

Handle g_hHudInfo;
Handle g_hHudInfo2;

bool g_bTriggerBot[MAXPLAYERS+1];
bool g_bZoomedOnly[MAXPLAYERS+1];
bool g_bIgnoreDeadRinger[MAXPLAYERS+1];
bool g_bIgnoreCloaked[MAXPLAYERS+1];
bool g_bIgnoreDisguised[MAXPLAYERS+1];
bool g_bAutoBackstab[MAXPLAYERS+1];
bool g_bWaitForCharge[MAXPLAYERS+1];
bool g_bNoSlowDown[MAXPLAYERS+1];
bool g_bAllCrits[MAXPLAYERS+1];
bool g_bAutoStrafe[MAXPLAYERS+1];
bool g_bBhop[MAXPLAYERS+1];
bool g_bNoSpread[MAXPLAYERS+1];
bool g_bAimbot[MAXPLAYERS+1];
bool g_bAutoShoot[MAXPLAYERS + 1];
int g_iTriggerPos[MAXPLAYERS+1];

#define TRIGGER_HEAD	1	//1
#define TRIGGER_TORSO	0	//0 1 2 3 4 5 6 7

//Add Sniper Rifle: Wait for charge
//Auto Airblast
//Auto sticky det
//*(NetVar( int*, pBaseWeapon, m_iWeaponState )) = AC_STATE_IDLE;  

public Plugin myinfo = 
{
	name = "[TF2] Badmin",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_hacks", Command_Trigger, ADMFLAG_ROOT);
	
	g_hHudInfo = CreateHudSynchronizer();
	g_hHudInfo2 = CreateHudSynchronizer();
}

public void OnClientPutInServer(int client)
{
	g_bTriggerBot[client] = false;
	g_bZoomedOnly[client] = false;
	g_bIgnoreDeadRinger[client] = true;
	g_bIgnoreCloaked[client] = true;
	g_bIgnoreDisguised[client] = false;
	g_bAutoBackstab[client] = false;
	g_bWaitForCharge[client] = false;
	g_bNoSlowDown[client] = false;
	g_bAllCrits[client] = false;
	g_bAutoStrafe[client] = false;
	g_bBhop[client] = false;
	g_bNoSpread[client] = false;
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_iTriggerPos[client] = TRIGGER_TORSO;
}

public Action Command_Trigger(int client, int args)
{
	if(IsValidClient(client))
		DisplayHackMenuAtItem(client);

	return Plugin_Handled;
}

stock void DisplayHackMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuLegitnessHandler);
	menu.SetTitle("Videogame - Settings");
	if(g_bTriggerBot[client])
		menu.AddItem("1", "Triggerbot: On");
	else
		menu.AddItem("1", "Triggerbot: Off");
		
	if(g_bZoomedOnly[client])
		menu.AddItem("2", "Sniper - Zoomed only: On");
	else
		menu.AddItem("2", "Sniper - Zoomed only: Off");
		
	if(g_bWaitForCharge[client])
		menu.AddItem("3", "Sniper - Wait for Charge: On");
	else
		menu.AddItem("3", "Sniper - Wait for Charge: Off");
		
	if(g_iTriggerPos[client] == TRIGGER_HEAD)
		menu.AddItem("4", "Trigger position: Head");
	else if(g_iTriggerPos[client] == TRIGGER_TORSO)
		menu.AddItem("4", "Trigger position: Torso");
	
	if(g_bIgnoreDeadRinger[client])
		menu.AddItem("5", "Ignore DeadRinger: On");
	else
		menu.AddItem("5", "Ignore DeadRinger: Off");
		
	if(g_bIgnoreCloaked[client])
		menu.AddItem("6", "Ignore Cloaked: On");
	else
		menu.AddItem("6", "Ignore Cloaked: Off");
		
	if(g_bIgnoreDisguised[client])
		menu.AddItem("7", "Ignore Disguised: On");
	else
		menu.AddItem("7", "Ignore Disguised: Off");
		
	if(g_bAutoBackstab[client])
		menu.AddItem("8", "Auto Backstab: On");
	else
		menu.AddItem("8", "Auto Backstab: Off");
		
	if(g_bNoSlowDown[client])
		menu.AddItem("9", "No Slowdown: On");
	else
		menu.AddItem("9", "No Slowdown: Off");
		
	if(g_bAllCrits[client])
		menu.AddItem("10", "Critical Hits: On");
	else
		menu.AddItem("10", "Critical Hits: Off");
	
	if(g_bAutoStrafe[client])
		menu.AddItem("11", "Auto Strafe: On");
	else
		menu.AddItem("11", "Auto Strafe: Off");
		
	if(g_bBhop[client])
		menu.AddItem("11", "Bunny Hop: On");
	else
		menu.AddItem("11", "Bunny Hop: Off");
		
	if(g_bNoSpread[client])
		menu.AddItem("12", "No Spread: On");
	else
		menu.AddItem("12", "No Spread: Off");
		
	if(g_bAimbot[client])
		menu.AddItem("13", "Aimbot: On");
	else
		menu.AddItem("13", "Aimbot: Off");
		
	if(g_bAutoShoot[client])
		menu.AddItem("14", "Auto Shoot: On");
	else
		menu.AddItem("14", "Auto Shoot: Off");
		
	menu.ExitButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int MenuLegitnessHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:  g_bTriggerBot[param1]       = !g_bTriggerBot[param1];
			case 1:  g_bZoomedOnly[param1]       = !g_bZoomedOnly[param1];
			case 2:  g_bWaitForCharge[param1]    = !g_bWaitForCharge[param1];
			case 3:  g_iTriggerPos[param1]       = (g_iTriggerPos[param1] == TRIGGER_HEAD) ? TRIGGER_TORSO : TRIGGER_HEAD;
			case 4:  g_bIgnoreDeadRinger[param1] = !g_bIgnoreDeadRinger[param1];
			case 5:  g_bIgnoreCloaked[param1]    = !g_bIgnoreCloaked[param1];
			case 6:  g_bIgnoreDisguised[param1]  = !g_bIgnoreDisguised[param1];
			case 7:  g_bAutoBackstab[param1]     = !g_bAutoBackstab[param1];
			case 8:  g_bNoSlowDown[param1]       = !g_bNoSlowDown[param1];
			case 9:  g_bAllCrits[param1]         = !g_bAllCrits[param1];
			case 10: g_bAutoStrafe[param1]       = !g_bAutoStrafe[param1];
			case 11: g_bBhop[param1]             = !g_bBhop[param1];
			case 12:
			{
				if(g_bNoSpread[param1])
				{
					g_bNoSpread[param1] = false;
					
					for (int w = 0; w <= view_as<int>(TFWeaponSlot_Secondary); w++)
					{
						int iEntity = GetPlayerWeaponSlot(param1, w);
					
						if(IsValidEntity(iEntity))
						{						
							TF2Attrib_RemoveByName(iEntity, "weapon spread bonus");
						}
					}
				}
				else
				{
					g_bNoSpread[param1] = true;
					
					for (int w = 0; w <= view_as<int>(TFWeaponSlot_Secondary); w++)
					{
						int iEntity = GetPlayerWeaponSlot(param1, w);
					
						if(IsValidEntity(iEntity))
						{
							TF2Attrib_SetByName(iEntity, "weapon spread bonus", 0.0);
						}
					}
				}
			}
			case 13: g_bAimbot[param1]    = !g_bAimbot[param1];
			case 14: g_bAutoShoot[param1] = !g_bAutoShoot[param1];
		}
		
		DisplayHackMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!StrEqual(classname, "instanced_scripted_scene", false)) 
    	return;
    	
    SDKHook(entity, SDKHook_Spawn, OnSceneSpawned);
}

public Action OnSceneSpawned(int entity)
{
    int client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
    char scenefile[128];
    
    GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
    if (StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd"))
    {
        if (g_bAllCrits[client])
        {
        	if (GetRandomInt(1, 4) == 3)
        	{
				PrintToChat(client, "Spycrab taunt allowed!");
			}
			else
			{
				PrintToChat(client, "Spycrab taunt bypassed!");
				AcceptEntityInput(entity, "kill");
				TF2_RemoveCondition(client, TFCond_Taunting);
			}
        }
    }
} 

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
	{
	//	vel[0] = 500.0;
		
		if(GetRandomFloat(1.0, 0.0) > 0.005)
		{
	//		buttons |= IN_JUMP
		}
	}

	if(IsFakeClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;	
		
	bool bChanged = false;
	
	if(g_bAimbot[client])
	{
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
	
		int iPlayerarray[MAXPLAYERS+1];
		int iPlayercount;
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(i != client && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && TF2_IsKillable(i))
			{
				float flPos[3];
				GetClientEyePosition(client, flPos);
					
				float vOrigin[3];
				GetClientAbsOrigin(i, vOrigin);
				
				float vNothing[3];
				
				if(g_iTriggerPos[client] == TRIGGER_HEAD)
					utils_EntityGetBonePosition(i, utils_EntityLookupBone(i, "bip_head"), vOrigin, vNothing);
				else
					utils_EntityGetBonePosition(i, utils_EntityLookupBone(i, "bip_pelvis"), vOrigin, vNothing);
				
				vOrigin[2] += 2.0;
				
				TR_TraceRayFilter(flPos, vOrigin, MASK_SHOT, RayType_EndPoint, AimTargetFilter, client);
				if(TR_DidHit())
				{
					int entity = TR_GetEntityIndex();
					if(entity == i)
					{
						iPlayerarray[iPlayercount] = i;
						iPlayercount++;
					}
				}
			}						
		}
		
		if(iPlayercount)
		{
			char strTargets[32 * MAX_NAME_LENGTH];
			for (int i = 0; i < iPlayercount; i++)
			{
				float flTPos[3], flPos[3];
				GetClientAbsOrigin(iPlayerarray[i], flTPos);
				GetClientEyePosition(client, flPos);
			
				float flDistance = GetVectorDistance(flPos, flTPos) * 0.0254;
				int target = iPlayerarray[i];
				Format(strTargets, sizeof(strTargets), "%s\n%N - %.0f", strTargets, target, flDistance);
			}
			
			SetHudTextParams(-0.6, 0.55, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo2, "%i VISIBLE:%s", iPlayercount, strTargets);
		}
		
		if(!(buttons & IN_ATTACK) && !g_bAutoShoot[client])
			return Plugin_Continue;
		
		int iTarget = FindTargetInViewCone(client);
		if(iTarget != -1)
		{
			SetHudTextParams(0.55, 0.55, 0.1, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "[AIMING AT: %N [%i HP]", iTarget, GetEntProp(iTarget, Prop_Send, "m_iHealth"));
		
			float flPPos[3], vOrigin[3];
			GetClientEyePosition(client, flPPos);
			GetClientAbsOrigin(iTarget, vOrigin);
			
			float vNothing[3];
			
			if(g_iTriggerPos[client] == TRIGGER_HEAD)
				utils_EntityGetBonePosition(iTarget, utils_EntityLookupBone(iTarget, "bip_head"), vOrigin, vNothing);
			else
				utils_EntityGetBonePosition(iTarget, utils_EntityLookupBone(iTarget, "bip_pelvis"), vOrigin, vNothing);
			
			vOrigin[2] += 2.0;
			
			static float vOldOrigin[3];
			static float vOldestOrigin[3];
			float vDeltaOrigin[3];
			
			// Calculate the delta (the change in two vector) origin
			SubtractVectors(vOrigin, vOldestOrigin, vDeltaOrigin);
			vOldestOrigin = vOldOrigin;
			vOldOrigin = vOrigin;
	 
			// Get the latency
	/*		float flLatencyOut  = GetClientLatency(client, NetFlow_Outgoing);
	 		float flLatencyIn   = GetClientLatency(client, NetFlow_Incoming);
	 		float flLatencyBoth = GetClientLatency(client, NetFlow_Both);
	 		
	 		float flLatencyOutAvg  = GetClientAvgLatency(client, NetFlow_Outgoing);
	 		float flLatencyInAvg   = GetClientAvgLatency(client, NetFlow_Incoming);*/
	 		float flLatencyBothAvg = GetClientAvgLatency(client, NetFlow_Both);
	 		
	 	//	PrintCenterText(client, "flLatencyOut %f\nflLatencyIn %f\nflLatencyBoth %f\n-\nflLatencyOutAvg %f\nflLatencyInAvg %f\nflLatencyBothAvg %f", flLatencyOut, flLatencyIn, flLatencyBoth, flLatencyOutAvg, flLatencyInAvg, flLatencyBothAvg);
	 		
			// Compensate the latency
			vDeltaOrigin[0] *= -((100 - flLatencyBothAvg) * (flLatencyBothAvg * 2));
			vDeltaOrigin[1] *= -((100 - flLatencyBothAvg) * (flLatencyBothAvg * 2));
			vDeltaOrigin[2] *= -((100 - flLatencyBothAvg) * (flLatencyBothAvg * 2));
	 		
			// Apply the prediction
			AddVectors(vOrigin, vDeltaOrigin, vOrigin);
			
			float flAimDir[3];
			MakeVectorFromPoints(flPPos, vOrigin, flAimDir);
			GetVectorAngles(flAimDir, flAimDir);
			ClampAngle(flAimDir);
			
			if(g_bWaitForCharge[client] && g_bAutoShoot[client])
			{
				int iWeapon = GetPlayerWeaponSlot(client, 0);
				
				if(IsValidEntity(iWeapon))
				{
					//Sniperrifle
					if(HasEntProp(iWeapon, Prop_Send, "m_flChargedDamage"))
					{
						float flDamage = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargedDamage");
						if (flDamage >= 150.0)
						{
							buttons |= IN_ATTACK;
						}
					}
					else //Ambassador
					{
						float flLastFireTime = GetGameTime() - GetEntPropFloat(iWeapon, Prop_Send, "m_flLastFireTime");
						if(flLastFireTime >= 0.95)
						{
							buttons |= IN_ATTACK;
						}
					}
				}
			}
			else if(g_bAutoShoot[client])
			{
				buttons |= IN_ATTACK;
			}
			
			angles = flAimDir;
			TeleportEntity(client, NULL_VECTOR, flAimDir, NULL_VECTOR);
			
			bChanged = true;
		}
	}
	
	float flStartPos[3], flEyeAng[3];
	GetClientEyePosition(client, flStartPos);
	GetClientEyeAngles(client, flEyeAng);

	bool bStab = false;
	
	if(g_bAutoBackstab[client])
	{
		char strWeapon[64];
		GetClientWeapon(client, strWeapon, sizeof(strWeapon));
		
		if(StrEqual(strWeapon, "tf_weapon_knife", false))
		{
			int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			if(GetEntProp(melee, Prop_Send, "m_bReadyToBackstab") == 1)
			{
				buttons |= IN_ATTACK;
				bStab = true;
				bChanged = true;
			}
		}
	}
	
	if(g_bTriggerBot[client] && !bStab)
	{
		Handle hTrace = TR_TraceRayFilterEx(flStartPos, flEyeAng, MASK_SHOT, RayType_Infinite, TraceRayDontHitEntity, client);
		if(TR_DidHit(hTrace))
		{
			int iHitEntity = TR_GetEntityIndex(hTrace);
			if(IsValidClient(iHitEntity) && GetClientTeam(client) != GetClientTeam(iHitEntity))
			{
				if(g_bIgnoreDisguised[client] && TF2_IsPlayerInCondition(iHitEntity, TFCond_Disguised))
					return Plugin_Continue;
					
				if(g_bIgnoreCloaked[client] && TF2_IsPlayerInCondition(iHitEntity, TFCond_Cloaked))
					return Plugin_Continue;
					
				if(g_bIgnoreDeadRinger[client] && TF2_IsPlayerInCondition(iHitEntity, TFCond_DeadRingered))
					return Plugin_Continue;
					
				bool bShoot = false;
				int iHitGroup = TR_GetHitGroup(hTrace);
				
				if(g_iTriggerPos[client] == TRIGGER_HEAD && iHitGroup == 1)
				{
					if(g_bZoomedOnly[client] && TF2_IsPlayerInCondition(client, TFCond_Zoomed))
					{
						bShoot = true;
					}
					else if(!g_bZoomedOnly[client])
					{
						bShoot = true;
					}
				}
				else if(g_iTriggerPos[client] == TRIGGER_TORSO)
				{
					if(g_bZoomedOnly[client] && TF2_IsPlayerInCondition(client, TFCond_Zoomed))
					{
						bShoot = true;
					}
					else if(!g_bZoomedOnly[client])
					{
						bShoot = true;
					}
				}
				
				if(bShoot)
				{
					buttons |= IN_ATTACK;
					bChanged = true;
				}
			}
		}
		
		delete hTrace;
	}
	
	if(buttons & IN_JUMP)
	{	
		if(GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") == -1)
		{
			if(g_bAutoStrafe[client])
			{
				if(mouse[0] < 0)
					vel[1] = -450.0;
				else if(mouse[0] > 0)
					vel[1] = 450.0;
				
				while(angles[1] > 180)
					angles[1] -= 360;
				
				while(angles[1] < -180)
					angles[1] += 360;
				
				if(angles[0] > 89.0)
					angles[0] = 89.0;
				
				if (angles[0] < -89.0)
					angles[0] = -89.0;
				
				angles[2] = 0.0;
				
				bChanged = true;
			}
			
			if(g_bBhop[client])
			{
				buttons &= ~IN_DUCK;
				buttons &= ~IN_JUMP;
			}
		}
		else if(g_bBhop[client])
		{
			buttons |= IN_JUMP;
		}
	}
	
	if(bChanged)
		return Plugin_Changed;
	
	return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && g_bAllCrits[client])
	{
		result = true;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(condition == TFCond_Slowed && g_bNoSlowDown[client])
	{
		TF2_RemoveCondition(client, TFCond_Slowed);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
	}
}

stock void TE_FireBullets(float vecOrigin[3], float vecAngles0, float vecAngles1, int iWeaponID, int iMode, int iSeed, int iPlayer, float flSpread, bool bCritical = false)
{
	TE_Start("Fire Bullets");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteFloat("m_vecAngles[0]", vecAngles0);
	TE_WriteFloat("m_vecAngles[1]", vecAngles1);
	TE_WriteNum("m_iWeaponID", iWeaponID);
	TE_WriteNum("m_iMode", iMode);
	TE_WriteNum("m_iSeed", iSeed);
	TE_WriteNum("m_iPlayer", iPlayer);
	TE_WriteFloat("m_flSpread", flSpread);
	TE_WriteNum("m_bCritical", bCritical);
	TE_SendToAll();
}

stock bool TF2_IsKillable(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged) 
	|| TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) 
	|| TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen)
	|| TF2_IsPlayerInCondition(client, TFCond_Bonked)
	|| GetEntProp(client, Prop_Data, "m_takedamage") != 2)
	{
		return false;
	}
	
	return true;
}

stock int FindTargetInViewCone(int iViewer, float iOffz = 0.0)
{
	float flPos[3];
	GetClientEyePosition(iViewer, flPos);
	
	float flBestDistance = 99999.0;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer) && TF2_IsKillable(i))
		{
			float vOrigin[3];
			GetClientAbsOrigin(i, vOrigin);
			
			float vNothing[3];
			
			if(g_iTriggerPos[iViewer] == TRIGGER_HEAD)
				utils_EntityGetBonePosition(i, utils_EntityLookupBone(i, "bip_head"), vOrigin, vNothing);
			else
				utils_EntityGetBonePosition(i, utils_EntityLookupBone(i, "bip_pelvis"), vOrigin, vNothing);
			
			vOrigin[2] += 2.0;
			
			TR_TraceRayFilter(flPos, vOrigin, MASK_SHOT, RayType_EndPoint, AimTargetFilter, iViewer);
			if(TR_DidHit())
			{
				int entity = TR_GetEntityIndex();
				if(entity == i)
				{
					float flDistance = GetVectorDistance(flPos, vOrigin);
			
					if(flDistance < flBestDistance)
					{
						flBestDistance = flDistance;
						iBestTarget = i;
					}
				}
			}
		}
	}

	return iBestTarget;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	//Return true to not hit and false to hit.
	
	char class[64];
	GetEntityClassname(entity, class, 64);
//	PrintToServer("%i %s exclude %i", entity, class, iExclude);
	
	if(StrEqual(class, "player"))
	{
		if(GetClientTeam(entity) == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	
	return !(entity == iExclude);
}

stock void ClampAngle(float flAngles[3])
{
	while(flAngles[0] > 89.0)  flAngles[0] -= 360.0;
	while(flAngles[0] < -89.0) flAngles[0] += 360.0;
	while(flAngles[1] > 180.0) flAngles[1] -= 360.0;
	while(flAngles[1] <-180.0) flAngles[1] += 360.0;
}

stock bool ClientViews(int Viewer, int Target, float fMaxDistance = 0.0, float fThreshold = 0.73)
{
    // Retrieve view and target eyes position
    float fViewPos[3];   GetClientEyePosition(Viewer, fViewPos);
    float fViewAng[3];   GetClientEyeAngles(Viewer, fViewAng);
    float fViewDir[3];
    float fTargetPos[3]; GetClientEyePosition(Target, fTargetPos);
    float fTargetDir[3];
    float fDistance[3];
    
    // Calculate view direction
    fViewAng[0] = fViewAng[2] = 0.0;
    GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);
    
    // Calculate distance to viewer to see if it can be seen.
    fDistance[0] = fTargetPos[0]-fViewPos[0];
    fDistance[1] = fTargetPos[1]-fViewPos[1];
    fDistance[2] = 0.0;
    if (fMaxDistance != 0.0)
    {
        if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
            return false;
    }
    
    // Check dot product. If it's negative, that means the viewer is facing
    // backwards to the target.
    NormalizeVector(fDistance, fTargetDir);
    if (GetVectorDotProduct(fViewDir, fTargetDir) < fThreshold) return false;
    
    // Now check if there are no obstacles in between through raycasting
    Handle hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
    if (TR_DidHit(hTrace)) { CloseHandle(hTrace); return false; }
    CloseHandle(hTrace);
    
    // Done, it's visible
    return true;
}

// ----------------------------------------------------------------------------
// ClientViewsFilter()
// ----------------------------------------------------------------------------
public bool ClientViewsFilter(int Entity, int Mask, any Junk)
{
    if (Entity >= 1 && Entity <= MaxClients) return false;
    return true;
} 

public bool TraceRayDontHitEntity(int entity, int mask, any data)
{
	if (entity == data) return false;
	return true;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}