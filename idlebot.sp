#include <sdktools>
#include <tf2_stocks>
#include <profiler>
#include <navmesh>

#pragma newdecls required

int g_iPathLaserModelIndex = -1;
int iResource = -1;
Handle g_hHudInfo;

bool g_bAFK[MAXPLAYERS + 1];
int g_iTargetNode[MAXPLAYERS + 1];
int g_iLastPatient[MAXPLAYERS + 1];
float flNextPathUpdate[MAXPLAYERS + 1];
float flNextStuckCheck[MAXPLAYERS + 1];
float flNextAttack[MAXPLAYERS + 1];
ArrayList g_hPositions[MAXPLAYERS + 1];

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
		if (!NavMesh_Exists()) 
		{
			ReplyToCommand(client, "This map doesnt support AFK bot");
		
			return Plugin_Handled;
		}
	
		flNextStuckCheck[client] = GetGameTime() + 5.0;
		g_iLastPatient[client] = -1;
		g_bAFK[client] = true;
		ReplyToCommand(client, "[AFK Bot] On");
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon)
{
	if(IsFakeClient(client) || !g_bAFK[client])
		return Plugin_Continue;
		
	if(!IsPlayerAlive(client))
	{
		//Dont break once we spawn and break out pathing
		flNextStuckCheck[client] = GetGameTime() + 5.0;
		return Plugin_Continue;
	}
	
	bool bChanged = false;
	
	int iPatient = TF2_GetPlayerThatNeedsHealing(client);
	int iEnemy = 0;
	
	bool bHasLOS = false;
	
	if(iPatient > 0)
	{
		//Save our patient
		g_iLastPatient[client] = iPatient;
		
		if(TF2_IsNextToWall(client))
			iButtons |= IN_JUMP;
		
		int iHealTarget = -1;
		
		//Check line of sigh
		bHasLOS = Client_Cansee(client, iPatient);
		if(bHasLOS && TF2_GetPlayerClass(client) == TFClass_Medic)
		{
			//If we can see our patient, switch to medigun if not active
			int iSecondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
			if(IsValidEntity(iSecondary))
			{
				//Get our mediguns healtarget to use for later
				iHealTarget = GetEntPropEnt(iSecondary, Prop_Send, "m_hHealingTarget");
		
				int iAWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if(IsValidEntity(iAWeapon))
				{
					int iSlot = GetSlotFromPlayerWeapon(client, iAWeapon);
					if(iSlot != TFWeaponSlot_Secondary)
					{
						TF2_EquipWeapon(client, iSecondary);
					}
				}
			}
			
			float flMax[3], flEPos[3];
			GetClientAbsOrigin(iPatient, flEPos);
			GetEntPropVector(iPatient, Prop_Send, "m_vecMaxs", flMax);
			
			flEPos[2] -= flMax[2] / 2;
			
			TF2_LookAtPos(client, flEPos, 0.1);
			
			//Try to switch medigun targets
			if(iHealTarget != iPatient)
			{
				if(flNextAttack[client] <= GetGameTime())
				{
					iButtons |= IN_ATTACK;
					flNextAttack[client] = GetGameTime() + 0.5;
					bChanged = true;
				}	
			}
		}
		else
		{
			//Nobody to heal, DM
			iEnemy = FindNearestEnemy(client, 1000.0);
			if(iEnemy > 0)
			{
				//If we can see our patient, switch to medigun if not active
				int iPrimary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
				if(IsValidEntity(iPrimary))
				{
					int iAWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					if(IsValidEntity(iAWeapon))
					{
						int iSlot = GetSlotFromPlayerWeapon(client, iAWeapon);
						if(iSlot != TFWeaponSlot_Primary)
						{
							TF2_EquipWeapon(client, iPrimary);
						}
						else
						{
							float flMax[3], flEPos[3];
							GetClientAbsOrigin(iEnemy, flEPos);
							GetEntPropVector(iEnemy, Prop_Send, "m_vecMaxs", flMax);
							
							flEPos[2] -= flMax[2] / 2;
							
							TF2_LookAtPos(client, flEPos, 0.1);
							
							iButtons |= IN_ATTACK;
							bChanged = true;
						}
					}
				}				
			}
		}
		
		if(g_hPositions[client] != null)
		{
			SetHudTextParams(-0.6, 0.55, 0.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(client, g_hHudInfo, "Target: %N\nLine of sight: %s", iPatient, bHasLOS ? "Yes" : "No");
			
			//Navigate our path
			if(g_iTargetNode[client] >= 0 && g_iTargetNode[client] < g_hPositions[client].Length)
			{
				//Crouch jump
				if(GetEntProp(client, Prop_Send, "m_bJumping"))
				{
					iButtons |= IN_DUCK
					bChanged = true;
				}
			
				if(iHealTarget != iPatient)
				{
					if(flNextStuckCheck[client] <= GetGameTime())
					{
						PrintToChat(client, "Stuck. skipping a node...");
						flNextStuckCheck[client] = GetGameTime() + 5.0;
						flNextPathUpdate[client] = GetGameTime() + 5.5;
						
						g_iTargetNode[client]--;
					}
					
					float flPos[3]
					GetClientAbsOrigin(client, flPos);
				
					float flGoPos[3];
					g_hPositions[client].GetArray(g_iTargetNode[client], flGoPos);
					
					float flToPos[3];
					flToPos[0] = flGoPos[0];
					flToPos[1] = flGoPos[1];
					flToPos[2] = flGoPos[2];
					
					if(iEnemy <= 0 && !bHasLOS)
						TF2_LookAtPos(client, flToPos);
						
					flToPos[2] += 80.0;
					
					//Show a giant vertical beam at our goal node
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
					
					TF2_MoveTo(client, flGoPos, fVel, fAng);
					bChanged = true;
					
					flGoPos[2] = flPos[2];
					float flNodeDist = GetVectorDistance(flGoPos, flPos);					

					if(flNodeDist <= 25.0)
					{
						//Moving between nodes shouldnt take more than 5 seconds
						flNextStuckCheck[client] = GetGameTime() + 5.0;
						
						g_iTargetNode[client]--;
					}
				}
				else
				{
					//Position ourselves behind out patient if we have LOS to them and are healing them
					if(bHasLOS && iHealTarget > 0 && iHealTarget <= MaxClients && IsClientInGame(iHealTarget))
					{
						float flPos[3], flPosition[3], flAngles[3];
						GetClientAbsOrigin(client, flPos);
						GetClientAbsOrigin(iHealTarget, flPosition);
						GetClientEyeAngles(iHealTarget, flAngles);

						flAngles[0] = 0.0;
						
						float vForward[3];
						GetAngleVectors(flAngles, vForward, NULL_VECTOR, NULL_VECTOR);
						flPosition[0] -= (vForward[0] * 90);
						flPosition[1] -= (vForward[1] * 90);
						flPosition[2] -= (vForward[2] * 90);

						float flGoalDist = GetVectorDistance(flPosition, flPos);
						if(flGoalDist >= 40.0)
						{
							TF2_MoveTo(client, flPosition, fVel, fAng);
							bChanged = true;
						}
					}
				
					flNextStuckCheck[client] = GetGameTime() + 5.0;
				}
			}
		}
		
		if (flNextPathUpdate[client] <= GetGameTime())
		{
			iButtons &= ~IN_JUMP;
		
			g_hPositions[client].Clear();
		 	
		 	float flPos[3], flPPos[3];
		 	GetClientAbsOrigin(iPatient, flPPos);
		 	GetClientAbsOrigin(client, flPos);
		 	
		 	flPos[2] += 15.0;
		 	flPPos[2] += 15.0;
		 
			int iStartAreaIndex = NavMesh_GetNearestArea(flPos, false, 3000.0, false);
			int iGoalAreaIndex  = NavMesh_GetNearestArea(flPPos, false, 3000.0, false);
			
			Handle hAreas = NavMesh_GetAreas();
			if (hAreas == INVALID_HANDLE) return Plugin_Continue;
			if (iStartAreaIndex == -1 || iGoalAreaIndex == -1) return Plugin_Continue;
			
			float flGoalPos[3];
			NavMeshArea_GetCenter(iGoalAreaIndex, flGoalPos);
			
			float flMaxPathLength = 0.0;
			float flMaxStepSize = 40.0;
			int iClosestAreaIndex = 0;
			
			NavMesh_BuildPath(iStartAreaIndex, 
				iGoalAreaIndex,
				flGoalPos,
				NavMeshShortestPathCost,
				_,
				iClosestAreaIndex,
				flMaxPathLength,
				flMaxStepSize,
				false);
			
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
					0.25,
					5.0,
					5.0,
					5, 
					0.0,
					iColor,
					30);
					
				TE_SendToClient(client);
			}
			
			flNextPathUpdate[client] = GetGameTime() + 0.25;
			
			g_iTargetNode[client] = g_hPositions[client].Length - 2;
		}
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

stock void TF2_EquipWeapon(int client, int iWeapon)
{
	char strClass[64];
	GetEntityClassname(iWeapon, strClass, sizeof(strClass));
	
	FakeClientCommand(client, "use %s", strClass);
}

stock void TF2_MoveTo(int client, float flGoal[3], float fVel[3], float fAng[3])
{
	float flPos[3];
	GetClientAbsOrigin(client, flPos);

	//Perform magic to position ourselves behind our patient
	float newmove[3];
	SubtractVectors(flGoal, flPos, newmove);
	
	newmove[1] = -newmove[1];
	
	float sin = Sine(fAng[1] * FLOAT_PI / 180.0);
	float cos = Cosine(fAng[1] * FLOAT_PI / 180.0);						
	
	fVel[0] = cos * newmove[0] - sin * newmove[1];
	fVel[1] = sin * newmove[0] + cos * newmove[1];
	
	NormalizeVector(fVel, fVel);
	ScaleVector(fVel, 450.0);
}

stock void TF2_LookAtPos(int client, float flPPos[3], float flAimSpeed = 0.05)
{
	//We want to aim at the center of the client
	float flPos[3];
	GetClientAbsOrigin(client, flPos);

	float flAng[3];
	GetClientEyeAngles(client, flAng);
	
	// get normalised direction from target to client
	float desired_dir[3];
	MakeVectorFromPoints(flPos, flPPos, desired_dir);
	GetVectorAngles(desired_dir, desired_dir);
	
	// ease the current direction to the target direction
	flAng[0] += AngleNormalize(desired_dir[0] - flAng[0]) * flAimSpeed;
	flAng[1] += AngleNormalize(desired_dir[1] - flAng[1]) * flAimSpeed;

	TeleportEntity(client, NULL_VECTOR, flAng, NULL_VECTOR);
}

//int AngleDifference(float angle1, float angle2)
//{
 //   int diff = RoundToNearest((angle2 - angle1 + 180)) % 360 - 180;
//    return diff < -180 ? diff + 360 : diff;
//}

stock float AngleNormalize(float angle)
{
	angle = fmodf(angle, 360.0);
	if (angle > 180) 
	{
		angle -= 360;
	}
	if (angle < -180)
	{
		angle += 360;
	}
	
	return angle;
}

stock float fmodf(float number, float denom)
{
	return number - RoundToFloor(number / denom) * denom;
}

stock bool TF2_IsNextToWall(int client)
{
	float flPos[3];
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
	
	delete TraceRay;
	
	return bHit;
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
		if(i != client && IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == team && TF2_IsHealable(i) && !g_bAFK[i])
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
			g_iLastPatient[client] = iPlayerarray[GetRandomInt(0, iPlayercount-1)];
		}
	}
	
	return iBestTarget;
}

stock bool TF2_IsHealable(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_DeadRingered)
	|| TF2_IsPlayerInCondition(client, TFCond_Cloaked))
	{
		return false;
	}
	
	return true;
}

stock int FindNearestEnemy(int iViewer, float flMaxDistance = 9999.0)
{
	float flPos[3];
	GetClientEyePosition(iViewer, flPos);
	
	float flBestDistance = flMaxDistance;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer) && TF2_IsKillable(i))
		{
			float flTPos[3];
			GetClientAbsOrigin(i, flTPos);
			
			float flMaxs[3];
			GetEntPropVector(i, Prop_Send, "m_vecMaxs", flMaxs);
			flTPos[2] += flMaxs[2] / 2;
			
			TR_TraceRayFilter(flPos, flTPos, MASK_SHOT, RayType_EndPoint, AimTargetFilter, iViewer);
			if(TR_DidHit())
			{
				int entity = TR_GetEntityIndex();
				if(entity == i)
				{
					float flDistance = GetVectorDistance(flPos, flTPos);
			
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

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
    return !(entity == iExclude);
}

stock void ClampAngle(float flAngles[3])
{
	while(flAngles[0] > 89.0)  flAngles[0] -= 360.0;
	while(flAngles[0] < -89.0) flAngles[0] += 360.0;
	while(flAngles[1] > 180.0) flAngles[1] -= 360.0;
	while(flAngles[1] <-180.0) flAngles[1] += 360.0;
}
