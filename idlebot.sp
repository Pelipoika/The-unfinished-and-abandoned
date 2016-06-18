#include <sdktools>
#include <tf2_stocks>
#include <profiler>
#include <navmesh>

#pragma newdecls required

int g_iPathLaserModelIndex = -1;
int iResource = -1;

bool g_bAFK[MAXPLAYERS + 1];
int g_iTargetNode[MAXPLAYERS + 1];
int g_iLastPatient[MAXPLAYERS + 1];
float flNextPathUpdate[MAXPLAYERS + 1];

Handle g_hHudInfo;

ArrayList g_hPositions[MAXPLAYERS + 1];

//TODO:
//Stay behind patient when healed entity is patient

public Plugin myinfo = 
{
	name = "[TF2] Idle Bot",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_afk", Command_Idle, "The server plays for you");
	
	g_hHudInfo = CreateHudSynchronizer();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnMapStart()
{
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	iResource = GetPlayerResourceEntity();
}

public void OnClientDisconnect(int client)
{
	g_bAFK[client] = false;
	delete g_hPositions[client];
}

public void OnClientPutInServer(int client)
{
	delete g_hPositions[client];
	g_hPositions[client] = new ArrayList(3);
}

public Action Command_Idle(int client, int argc)
{
	if(g_bAFK[client])
	{
		g_bAFK[client] = false;
		ReplyToCommand(client, "[AFK Bot] Off");
	}
	else
	{
		g_bAFK[client] = true;
		ReplyToCommand(client, "[AFK Bot] On");
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon)
{
	if(IsFakeClient(client) || !IsPlayerAlive(client) || !g_bAFK[client])
		return Plugin_Continue;
	
	if(TF2_GetPlayerClass(client) != TFClass_Medic)
	{
		TF2_SetPlayerClass(client, TFClass_Medic);
		ForcePlayerSuicide(client);
		
		return Plugin_Continue;
	}
	
	bool bChanged = false;
	
	int iPatient = TF2_GetPlayerThatNeedsHealing(client);
	if(iPatient > 0)
	{
		//Save our patient
		g_iLastPatient[client] = iPatient;
		
		float flPPos[3], flPos[3];
		GetClientAbsOrigin(iPatient, flPPos);
		GetClientAbsOrigin(client, flPos);
	
		float flMaxs[3], flMins[3];
		GetEntPropVector(client, Prop_Send, "m_vecMaxs", flMaxs);
		GetEntPropVector(client, Prop_Send, "m_vecMins", flMins);
		
		flMaxs[0] += 2.5;
		flMaxs[1] += 2.5;
		flMins[0] -= 2.5;
		flMins[1] -= 2.5;
		
		flPos[2] += 18.0;
		
		//Perform a wall check to see if we are near any obstacles we should try jump over
		Handle TraceRay = TR_TraceHullFilterEx(flPos, flPos, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterSelf, client);
		
		bool bHit = TR_DidHit(TraceRay);
		if (bHit)
			iButtons |= IN_JUMP;
		
		delete TraceRay;
		
		//Check line of sigh
		bool bHasLOS = Client_Cansee(client, iPatient);
		if(bHasLOS)
		{
			int iHealTarget = -1;
			
			//If we can see our patient, switch to medigun if not active
			int iSecondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if(IsValidEntity(iSecondary))
			{
				iHealTarget = GetEntPropEnt(iSecondary, Prop_Send, "m_hHealingTarget");
		
				int iAWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if(IsValidEntity(iAWeapon))
				{
					int iSlot = GetSlotFromPlayerWeapon(client, iAWeapon);
					if(iSlot != TFWeaponSlot_Secondary)
					{
						char strClass[64];
						GetEntityClassname(iSecondary, strClass, sizeof(strClass));
						
						FakeClientCommand(client, "use %s", strClass);
						SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iSecondary);
					}
				}
			}
			
			GetClientAbsOrigin(iPatient, flPPos);
			GetClientAbsOrigin(client, flPos);
			flPPos[2] -= flMaxs[2] / 2;
			
			float flAimDir[3];
			MakeVectorFromPoints(flPos, flPPos, flAimDir);
			GetVectorAngles(flAimDir, flAimDir);
			
			PrintCenterText(client, "iHealTarget = %i\niPatient = %i", iHealTarget, iPatient);
			
			TeleportEntity(client, NULL_VECTOR, flAimDir, NULL_VECTOR);
			
			if(iHealTarget != iPatient && iHealTarget == -1)
			{
				iButtons |= IN_ATTACK;
				bChanged = true;
			}
			
			if(iHealTarget != iPatient)
			{
				iButtons |= IN_ATTACK;
				bChanged = true;
			}
		}
		
		if(g_hPositions[client] != null)
		{
			SetHudTextParams(-0.6, 0.55, 0.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "Healing %N\nLine of sight: %s\nNodes: %i\nTargetNode: %i\nIN_ATTACK: %s", 
				iPatient, 
				bHasLOS ? "Yes" : "No", 
				g_hPositions[client].Length, 
				g_iTargetNode[client], 
				iButtons & IN_ATTACK ? "Yes" : "No");

			//Navigate our path
			if(g_iTargetNode[client] >= 0 && g_iTargetNode[client] < g_hPositions[client].Length)
			{
				GetClientAbsOrigin(client, flPos);
			
				float flGoPos[3];
				g_hPositions[client].GetArray(g_iTargetNode[client], flGoPos);
				
				float flToPos[3];
				flToPos[0] = flGoPos[0];
				flToPos[1] = flGoPos[1];
				flToPos[2] = flGoPos[2];
				
				flToPos[2] += 80.0;
				
				TE_SetupBeamPoints(flGoPos,
					flToPos,
					g_iPathLaserModelIndex,
					g_iPathLaserModelIndex,
					0,
					30,
					0.1,
					5.0,
					5.0,
					5, 
					0.0,
					{255, 0, 0, 255},
					30);
					
				TE_SendToClient(client);
				
				float flNodeDist = GetVectorDistance(flGoPos, flPos);
				float newmove[3];
		
				SubtractVectors(flGoPos, flPos, newmove);
				NormalizeVector(newmove, newmove);
				ScaleVector(newmove, 450.0);
				
				newmove[1] = -newmove[1];
				
				float sin = Sine(fAng[1] * FLOAT_PI / 180.0);
				float cos = Cosine(fAng[1] * FLOAT_PI / 180.0);
				fVel[0] = cos * newmove[0] - sin * newmove[1];
				fVel[1] = sin * newmove[0] + cos * newmove[1];
				
				if(flNodeDist <= 25.0)
				{
					g_iTargetNode[client]--;
				}
			}
		}
		
		if (flNextPathUpdate[client] <= GetGameTime())
		{
			iButtons &= ~IN_JUMP;
		
			g_hPositions[client].Clear();
		 
		 	flPos[2] += 15.0;
		 	flPPos[2] += 15.0;
		 
			int iStartAreaIndex = NavMesh_GetNearestArea(flPos, true, 10000.0, true);
			int iGoalAreaIndex  = NavMesh_GetNearestArea(flPPos, true, 10000.0, true);
			
			Handle hAreas = NavMesh_GetAreas();
			if (hAreas == INVALID_HANDLE) return Plugin_Continue;
			if (iStartAreaIndex == -1 || iGoalAreaIndex == -1) return Plugin_Continue;
			
			float flGoalPos[3];
			NavMeshArea_GetCenter(iGoalAreaIndex, flGoalPos);
			
			float flMaxPathLength = 0.0;
			float flMaxStepSize = 0.0;
			int iClosestAreaIndex = 0;
			
			NavMesh_BuildPath(iStartAreaIndex, 
				iGoalAreaIndex,
				flGoalPos,
				NavMeshShortestPathCost,
				_,
				iClosestAreaIndex,
				flMaxPathLength,
				flMaxStepSize);
			
			int iTempAreaIndex = iClosestAreaIndex;
			int iParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex);
			int iNavDirection;
			float flHalfWidth;
			
			float flCenterPortal[3], flClosestPoint[3];
			
			g_hPositions[client].PushArray(flGoalPos, 3);
			
			while (iParentAreaIndex != -1)
			{
				float flTempAreaCenter[3], flParentAreaCenter[3];
				NavMeshArea_GetCenter(iTempAreaIndex, flTempAreaCenter);
				NavMeshArea_GetCenter(iParentAreaIndex, flParentAreaCenter);
				
				iNavDirection = NavMeshArea_ComputeDirection(iTempAreaIndex, flParentAreaCenter);
				NavMeshArea_ComputePortal(iTempAreaIndex, iParentAreaIndex, iNavDirection, flCenterPortal, flHalfWidth);
				NavMeshArea_ComputeClosestPointInPortal(iTempAreaIndex, iParentAreaIndex, iNavDirection, flCenterPortal, flClosestPoint);
				
				flClosestPoint[2] = NavMeshArea_GetZ(iTempAreaIndex, flClosestPoint);
				
				g_hPositions[client].PushArray(flClosestPoint, 3);
				
				iTempAreaIndex = iParentAreaIndex;
				iParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex);
			}
			
			float flStartPos[3];
			NavMeshArea_GetCenter(iStartAreaIndex, flStartPos);
			g_hPositions[client].PushArray(flStartPos, 3);
				
			int iColor[4] = { 0, 255, 0, 255 };
			for (int i = g_hPositions[client].Length - 1; i > 0; i--)
			{
				float flFromPos[3], flToPos[3];
				g_hPositions[client].GetArray(i, flFromPos, 3);
				g_hPositions[client].GetArray(i - 1, flToPos, 3);
				
				TE_SetupBeamPoints(flFromPos,
					flToPos,
					g_iPathLaserModelIndex,
					g_iPathLaserModelIndex,
					0,
					30,
					0.5,
					5.0,
					5.0,
					5, 
					0.0,
					iColor,
					30);
					
				TE_SendToClient(client);
			}
			
			flNextPathUpdate[client] = GetGameTime() + 0.5;
			
			g_iTargetNode[client] = g_hPositions[client].Length - 2;
		}
	}
	else
	{
		SetHudTextParams(-0.6, 0.55, 0.1, 255, 155, 0, 255, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudInfo, "No available patients");
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

public int SlenderChaseBossShortestPathCost(int iAreaIndex,int iFromAreaIndex,int iLadderIndex, any iStepSize)
{
	if (iFromAreaIndex == -1)
	{
		return 0;
	}
	else
	{
		int iDist;
		float flAreaCenter[3], flFromAreaCenter[3];
		NavMeshArea_GetCenter(iAreaIndex, flAreaCenter);
		NavMeshArea_GetCenter(iFromAreaIndex, flFromAreaCenter);
		
		if (iLadderIndex != -1)
		{
			iDist = RoundFloat(NavMeshLadder_GetLength(iLadderIndex));
		}
		else
		{
			iDist = RoundFloat(GetVectorDistance(flAreaCenter, flFromAreaCenter));
		}
		
		int iCost = iDist + NavMeshArea_GetCostSoFar(iFromAreaIndex);
		
		int iAreaFlags = NavMeshArea_GetFlags(iAreaIndex);
		if (iAreaFlags & NAV_MESH_CROUCH) iCost += 20;
		if (iAreaFlags & NAV_MESH_JUMP) iCost += (5 * iDist);
		
		if ((flAreaCenter[2] - flFromAreaCenter[2]) > iStepSize) iCost += iStepSize;
		
		return iCost;
	}
}

stock int GetSlotFromPlayerWeapon(int iClient, int iWeapon)
{
    for (int i = 0; i <= 5; i++)
    {
        if (iWeapon == GetPlayerWeaponSlot(iClient, i))
        {
            return i;
        }
    }
    
    return -1;
}  

stock int TF2_GetPlayerThatNeedsHealing(int client)
{
	TFTeam team = TF2_GetClientTeam(client);
	
	int iLowestHP = 99999;
	int iBestTarget = 0;
	
	int iPlayerarray[MAXPLAYERS+1];
	int iPlayercount;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == team)
		{
			int iHealth = GetClientHealth(i);
			int iMaxHealth = GetEntProp(iResource, Prop_Send, "m_iMaxHealth", _, i);
			
			bool bNeedsHealing = iHealth < iMaxHealth;
			
			iPlayerarray[iPlayercount] = i;
			iPlayercount++;
			
			if(iLowestHP > iHealth && bNeedsHealing)
			{
				iLowestHP = iHealth;
				iBestTarget = i;
			}
		}
	}
	
	//Nobody needs healing, choose random player
	if(iBestTarget <= 0 && iPlayercount > 0)
	{
		int iLastPatient = g_iLastPatient[client];
		if(iLastPatient > 0 && IsClientInGame(iLastPatient) && IsPlayerAlive(iLastPatient))
		{
			iBestTarget = iLastPatient;
		}
		else
		{
			g_iLastPatient[client] = GetRandomInt(0, iPlayercount);
		}
	}
	
	return iBestTarget;
}

stock bool Client_Cansee(int iViewer, int iTarget)
{
	float flStart[3], flEnd[3];
	GetClientEyePosition(iTarget, flEnd);
	GetClientEyePosition(iViewer, flStart);

	bool bSee = true;
	Handle hTrace = TR_TraceRayFilterEx(flStart, flEnd, MASK_SOLID, RayType_EndPoint, TraceFilterSelf, iViewer);
	if(hTrace != INVALID_HANDLE)
	{
		if(TR_DidHit(hTrace))
			bSee = false;
			
		CloseHandle(hTrace);
	}
	
	return bSee;
}

public bool TraceFilterSelf(int entity, int contentsMask, any iSelf)
{
	if(entity == iSelf || entity > MaxClients || (entity >= 1 && entity <= MaxClients))
		return false;
	
	return true;
}
