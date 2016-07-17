#include <sdktools>
#include <tf2_stocks>
#include <profiler>
#include <navmesh>

#pragma newdecls required

enum TFWeaponType
{
	TFWeaponType_Generic   = 0,
	TFWeaponType_Jar       = 1,
	TFWeaponType_Edible    = 2,
	TFWeaponType_Sapper    = 3
}

#define HEALTH_CRITICAL = 50;

int g_iPathLaserModelIndex = -1;
int iResource = -1;
Handle g_hHudInfo;

bool g_bAFK[MAXPLAYERS + 1];
int g_iTargetNode[MAXPLAYERS + 1];
int g_iLastTarget[MAXPLAYERS + 1];
float flNextPathUpdate[MAXPLAYERS + 1];
float flNextStuckCheck[MAXPLAYERS + 1];
float flNextAttack[MAXPLAYERS + 1];
ArrayList g_hPositions[MAXPLAYERS + 1];

//TODO
//Make medic bot pop uber if health drops below 50
//Class priority
//Scout bot should run for money

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
		g_iLastTarget[client] = -1;
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
		//Dont break our pathfinding once we spawn
		flNextStuckCheck[client] = GetGameTime() + 5.0;
		return Plugin_Continue;
	}
	
	bool bChanged = false;
	
	if(TF2_IsNextToWall(client))
		iButtons |= IN_JUMP;
	
	//Always crouch jump
	if(GetEntProp(client, Prop_Send, "m_bJumping"))
	{
		iButtons |= IN_DUCK
		bChanged = true;
	}
	
	TFClassType class = TF2_GetPlayerClass(client);	
	
	if(class == TFClass_Medic)
	{
		int iPatient = TF2_GetPlayerThatNeedsHealing(client);
		if(iPatient > 0)
		{
			float flPos[3], flTPos[3];
			GetClientEyePosition(client, flPos);
			GetClientEyePosition(iPatient, flTPos);
			
			float flDistance = GetVectorDistance(flPos, flTPos);
			
			//Save our patient
			g_iLastTarget[client] = iPatient;
			
			//Check line of sigh
			bool bHasLOS = Client_Cansee(client, iPatient);
			if(bHasLOS && flDistance <= 400.0)
			{
				int iHealTarget = -1;
			
				//If we can see our patient and are in heal range, switch to medigun if not active and start healing our target
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
				
				float flMax[3], flPatientPos[3];
				GetClientAbsOrigin(iPatient, flPatientPos);
				GetEntPropVector(iPatient, Prop_Send, "m_vecMaxs", flMax);
				
				flPatientPos[2] += flMax[2] / 2;
				
				TF2_LookAtPos(client, flPatientPos, 0.1);
				
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
				else
				{
					//Position ourselves behind our patient
					float flPosition[3], flAngles[3];
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
					if(flGoalDist >= 40.0 && Client_Cansee(client, iHealTarget))
					{
						TF2_MoveTo(client, flPosition, fVel, fAng);
					}
					
					//We arent stuck if we are healing our target
					flNextStuckCheck[client] = GetGameTime() + 5.0;
				}
			}
			else
			{
				//Path to our target patient because they are out of range and not visible
				TF2_PathTo(client, iPatient, iButtons, fVel, fAng);

				//Not close enough to our target patient or we can't see them, Heal nearby teammates or shoot visible enemies
				int iEnemy = FindNearestVisibleEnemy(client, 1000.0);
				if(iEnemy > 0)
				{
					g_iLastTarget[client] = iEnemy;
				
					TF2_EquipBestWeaponForThreat(client, iEnemy);
					
					float flMax[3], flEnemyPos[3];
					GetClientAbsOrigin(iEnemy, flEnemyPos);
					GetEntPropVector(iEnemy, Prop_Send, "m_vecMaxs", flMax);
					
					int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					if(GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) == iActiveWeapon)
					{
						//Just get closer
						TF2_MoveTo(client, flEnemyPos, fVel, fAng);
	
						flNextStuckCheck[client] = GetGameTime() + 5.0;
					}
					
					flEnemyPos[2] += flMax[2] / 2;
					TF2_LookAtPos(client, flEnemyPos, 0.1);
					
					iButtons |= IN_ATTACK;
					bChanged = true;
				}
				else
				{
					float flLookPos[3];
					if(TF2_GetLookAheadPosition(client, flLookPos))
					{
						TF2_LookAtPos(client, flLookPos);
					}
				}
			}
		}
	}
	else
	{
		//We are not playing as medic
		int iEnemy = FindNearestVisibleEnemy(client, 1000.0);
		if(iEnemy > 0)
		{
			g_iLastTarget[client] = iEnemy;
		
			TF2_EquipBestWeaponForThreat(client, iEnemy);
			
			float flMax[3], flEnemyPos[3];
			GetClientAbsOrigin(iEnemy, flEnemyPos);
			GetEntPropVector(iEnemy, Prop_Send, "m_vecMaxs", flMax);
			
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			//Using melee weapon
			if(GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) == iActiveWeapon)
			{
				if(TF2_GetPlayerClass(client) == TFClass_Spy)
				{
					bool bReadyToStab = !!GetEntProp(iActiveWeapon, Prop_Send, "m_bReadyToBackstab");
					
					//As a spy we should go for backstabs
					float flPos[3], flAngles[3];
					GetClientAbsOrigin(client, flPos);
					GetClientEyeAngles(iEnemy, flAngles);
					
					flAngles[0] = 0.0;
					
					float vForward[3];
					GetAngleVectors(flAngles, vForward, NULL_VECTOR, NULL_VECTOR);
					flEnemyPos[0] -= (vForward[0] * 50);
					flEnemyPos[1] -= (vForward[1] * 50);
					flEnemyPos[2] -= (vForward[2] * 50);
					
					float flGoalDist = GetVectorDistance(flEnemyPos, flPos);
					if(flGoalDist <= 200.0 && Client_Cansee(client, iEnemy))
					{
						TF2_MoveTo(client, flEnemyPos, fVel, fAng);
						
						float flBotAng[3], flTargetAng[3];
						GetClientEyeAngles(client, flBotAng);
						GetClientEyeAngles(iEnemy, flTargetAng);
						int iAngleDiff = AngleDifference(flBotAng[1], flTargetAng[1]);

						if(iAngleDiff > 90)
						{
							//Move right
							fVel[1] = 450.0;
						}
						else if(iAngleDiff < -90)
						{
							//Move left
							fVel[1] = -450.0;
						}
					}
					else
					{
						TF2_PathTo(client, iEnemy, iButtons, fVel, fAng);
					}
					
					if(bReadyToStab)
					{
						//I'm not going to stab you, I'm not going to stab you! HA! I stabbed you!
						iButtons |= IN_ATTACK;
						bChanged = true;
					}
					else
					{
						if(!TF2_IsPlayerInCondition(client, TFCond_Disguised) && !TF2_IsPlayerInCondition(client, TFCond_Disguising))
						{
							TF2_DisguisePlayer(client, TF2_GetClientTeam(client) == TFTeam_Blue ? TFTeam_Red : TFTeam_Blue, view_as<TFClassType>(GetRandomInt(1, 9)));
						}
					}
				}
				else
				{
					//Otherwise just get closer
					float flPos[3];
					GetClientAbsOrigin(client, flPos);
					
					float flGoalDist = GetVectorDistance(flEnemyPos, flPos);
					if(flGoalDist <= 200.0 && Client_Cansee(client, iEnemy))
					{
						TF2_MoveTo(client, flEnemyPos, fVel, fAng);
						iButtons |= IN_ATTACK;
						bChanged = true;
					}
				}
				
				GetClientAbsOrigin(iEnemy, flEnemyPos);
				flEnemyPos[2] += flMax[2] / 2;
				
				TF2_LookAtPos(client, flEnemyPos, 0.1);
				
				flNextStuckCheck[client] = GetGameTime() + 5.0;
			}
			else
			{
				GetClientAbsOrigin(iEnemy, flEnemyPos);
				flEnemyPos[2] += flMax[2] / 2;
				
				TF2_LookAtPos(client, flEnemyPos, 0.1);
				TF2_PathTo(client, iEnemy, iButtons, fVel, fAng);
				
				if(Client_Cansee(client, iEnemy))
				{
					iButtons |= IN_ATTACK;
					bChanged = true;
				}
			}
		}
		else
		{
			//No visible enemies, target the closest one
			if(TF2_GetPlayerClass(client) == TFClass_Spy)
			{
				if(!TF2_IsPlayerInCondition(client, TFCond_Disguised) && !TF2_IsPlayerInCondition(client, TFCond_Disguising))
				{
					TF2_DisguisePlayer(client, TF2_GetClientTeam(client) == TFTeam_Blue ? TFTeam_Red : TFTeam_Blue, view_as<TFClassType>(GetRandomInt(1, 9)));
				}
			}
			
			if(iEnemy <= 0)
				flNextStuckCheck[client] = GetGameTime() + 5.0;
			
			iEnemy = FindNearestEnemy(client);
			
			if(iEnemy > 0)
			{
				g_iLastTarget[client] = iEnemy;
			
				TF2_PathTo(client, iEnemy, iButtons, fVel, fAng);
				
				float flLookPos[3];
				if(TF2_GetLookAheadPosition(client, flLookPos))
				{
					TF2_LookAtPos(client, flLookPos);
				}
			}
			else
			{
				//We can't be stuck if we are not doing anything
				flNextStuckCheck[client] = GetGameTime() + 5.0;
			}
		}
	}
	
	SetHudTextParams(-0.6, 0.55, 0.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hHudInfo, "Target: %N", g_iLastTarget[client] > 0 ? g_iLastTarget[client] : client);
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

stock void TF2_PathTo(int client, int iTarget, int &iButtons, float fVel[3], float fAng[3])
{
	if(g_hPositions[client] != null)
	{
		//Navigate our path
		if(g_iTargetNode[client] >= 0 && g_iTargetNode[client] < g_hPositions[client].Length)
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
			
			flToPos[2] += 80.0;
			
			//Show a giant vertical beam at our goal node
			TE_SetupBeamPoints(flGoPos, flToPos, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0,	30, 0.1, 5.0, 5.0, 5, 0.0, {255, 0, 0, 255}, 30);
			TE_SendToClient(client);
			
			TF2_MoveTo(client, flGoPos, fVel, fAng);
			
			flGoPos[2] = flPos[2];
			float flNodeDist = GetVectorDistance(flGoPos, flPos);					

			if(flNodeDist <= 25.0)
			{
				//Moving between nodes shouldnt take more than 5 seconds
				flNextStuckCheck[client] = GetGameTime() + 5.0;
				
				g_iTargetNode[client]--;
			}
		}
	}
		
	if (flNextPathUpdate[client] <= GetGameTime())
	{
		iButtons &= ~IN_JUMP;
	
		g_hPositions[client].Clear();
	 	
	 	float flPos[3], flPPos[3];
	 	GetClientAbsOrigin(iTarget, flPPos);
	 	GetClientAbsOrigin(client, flPos);
	 	
	 	flPos[2] += 15.0;
	 	flPPos[2] += 15.0;
	 
		int iStartAreaIndex = NavMesh_GetNearestArea(flPos, false, 3000.0, false);
		int iGoalAreaIndex  = NavMesh_GetNearestArea(flPPos, false, 3000.0, false);
		
		Handle hAreas = NavMesh_GetAreas();
		if (hAreas == INVALID_HANDLE)                      return;
		if (iStartAreaIndex == -1 || iGoalAreaIndex == -1) return;
		delete hAreas;
	
		float flGoalPos[3];
		NavMeshArea_GetCenter(iGoalAreaIndex, flGoalPos);
		
		float flMaxPathLength = 0.0;
		float flMaxStepSize = 40.0;
		int iClosestAreaIndex = 0;
		
		bool bBuilt = NavMesh_BuildPath(iStartAreaIndex, 
			iGoalAreaIndex,
			flGoalPos,
			NavMeshShortestPathCost,
			_,
			iClosestAreaIndex,
			flMaxPathLength,
			flMaxStepSize,
			true);
		
		if(bBuilt)
		{
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
			g_iTargetNode[client] = g_hPositions[client].Length - 2;
		}
		
		flNextPathUpdate[client] = GetGameTime() + 0.5;
	}
	
	return;
}

stock bool TF2_GetLookAheadPosition(int client, float flOut[3])
{
	//Save me from bad code hell

	if(g_hPositions[client] != null && g_hPositions[client].Length > 0)
	{
		int iPointsToLook = 6, iPoints = 0;
		
		float flPoint1[3], flPoint2[3], flPoint3[3], flPoint4[3], flPoint5[3], flPoint6[3];
		
		for (int i = g_iTargetNode[client]; i > g_iTargetNode[client] - iPointsToLook; i--)
		{
			if(i > 0)
			{
				iPoints++;
				
				float flPosTemp[3];
				g_hPositions[client].GetArray(i, flPosTemp);
				
				switch(iPoints)
				{
					case 1:
					{
						flPoint1[0] = flPosTemp[0];
						flPoint1[1] = flPosTemp[1];
						flPoint1[2] = flPosTemp[2];
					}
					case 2:
					{
						flPoint2[0] = flPosTemp[0];
						flPoint2[1] = flPosTemp[1];
						flPoint2[2] = flPosTemp[2];
					}
					case 3:
					{
						flPoint3[0] = flPosTemp[0];
						flPoint3[1] = flPosTemp[1];
						flPoint3[2] = flPosTemp[2];
					}
					case 4:
					{
						flPoint4[0] = flPosTemp[0];
						flPoint4[1] = flPosTemp[1];
						flPoint4[2] = flPosTemp[2];
					}
					case 5:
					{
						flPoint5[0] = flPosTemp[0];
						flPoint5[1] = flPosTemp[1];
						flPoint5[2] = flPosTemp[2];
					}
					case 6:
					{
						flPoint6[0] = flPosTemp[0];
						flPoint6[1] = flPosTemp[1];
						flPoint6[2] = flPosTemp[2];
					}
				}	
			}
		}
		
		if(iPoints > 0)
		{
			flOut[0] = (flPoint1[0] + flPoint2[0] + flPoint3[0] + flPoint4[0] + flPoint5[0] + flPoint6[0]) / iPoints;
			flOut[1] = (flPoint1[1] + flPoint2[1] + flPoint3[1] + flPoint4[1] + flPoint5[1] + flPoint6[1]) / iPoints;
			flOut[2] = (flPoint1[2] + flPoint2[2] + flPoint3[2] + flPoint4[2] + flPoint5[2] + flPoint6[2]) / iPoints;
			
			flOut[2] += 50.0;
			
			float flToPos[3];
			flToPos[0] = flOut[0];
			flToPos[1] = flOut[1];
			flToPos[2] = flOut[2];
			flToPos[2] += 80.0;
			
			//Show a giant vertical beam at our goal node
			TE_SetupBeamPoints(flOut, flToPos, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, 0.1, 5.0, 5.0, 5, 0.0, {0, 0, 255, 255}, 30);
			TE_SendToClient(client);
			
			return true;
		}
	}
	
	return false;
}

stock void TF2_EquipBestWeaponForThreat(int client, int iTarget)
{
	float flPos[3], flTargetPos[3];
	GetClientEyePosition(client, flPos);
	GetClientEyePosition(iTarget, flTargetPos);

	TFClassType class = TF2_GetPlayerClass(client);
	float flDistance = GetVectorDistance(flPos, flTargetPos);
	
	if(class == TFClass_Spy)
	{
		TF2_EquipWeapon(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
	}
	else if(class == TFClass_Pyro)
	{
		if(flDistance <= 400.0)
		{
			TF2_EquipWeapon(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Primary));
		}
		else
		{
			TF2_EquipWeapon(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary));
		}
	}
	else
	{
		if(flDistance <= 100.0)
		{
			TF2_EquipWeapon(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
		}
		else
		{
			TF2_EquipWeapon(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Primary));
		}
	}
}

stock TFWeaponType TF2_GetWeaponType(int iWeapon)
{
	char strClass[64];
	GetEntityNetClass(iWeapon, strClass, sizeof(strClass));
	
	TFWeaponType WeaponType = TFWeaponType_Generic;
	
	if(StrContains(strClass, "CTFJar", false) != -1)               WeaponType = TFWeaponType_Jar;
	else if(StrContains(strClass, "CTFLunchBox", false) != -1)     WeaponType = TFWeaponType_Edible;
	else if(StrContains(strClass, "CTFWeaponSapper", false) != -1) WeaponType = TFWeaponType_Sapper;

	return WeaponType;
}

stock void TF2_EquipWeapon(int client, int iWeapon)
{
	if(IsValidEntity(iWeapon))
	{
		char strClass[64];
		GetEntityClassname(iWeapon, strClass, sizeof(strClass));
		
		FakeClientCommand(client, "use %s", strClass);
	}
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

stock void TF2_LookAtPos(int client, float flGoal[3], float flAimSpeed = 0.05)
{
	float flPos[3];
	GetClientEyePosition(client, flPos);

	float flAng[3];
	GetClientEyeAngles(client, flAng);
	
	// get normalised direction from target to client
	float desired_dir[3];
	MakeVectorFromPoints(flPos, flGoal, desired_dir);
	GetVectorAngles(desired_dir, desired_dir);
	
	// ease the current direction to the target direction
	flAng[0] += AngleNormalize(desired_dir[0] - flAng[0]) * flAimSpeed;
	flAng[1] += AngleNormalize(desired_dir[1] - flAng[1]) * flAimSpeed;

	TeleportEntity(client, NULL_VECTOR, flAng, NULL_VECTOR);
}

stock int AngleDifference(float angle1, float angle2)
{
	int diff = RoundToNearest((angle2 - angle1 + 180)) % 360 - 180;
	return diff < -180 ? diff + 360 : diff;
}

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

stock bool TF2_WeaponHasAmmo(int iWeapon)
{
	
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
		if(i != client && IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == team && TF2_IsVisible(i) && !g_bAFK[i])
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
		int iLastPatient = g_iLastTarget[client];
		if(iLastPatient > 0 && IsClientInGame(iLastPatient) && IsPlayerAlive(iLastPatient))
		{
			iBestTarget = iLastPatient;
		}
		else
		{
			g_iLastTarget[client] = iPlayerarray[GetRandomInt(0, iPlayercount-1)];
		}
	}
	
	return iBestTarget;
}

stock bool TF2_IsVisible(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_DeadRingered)
	|| TF2_IsPlayerInCondition(client, TFCond_Cloaked))
	{
		return false;
	}
	
	return true;
}

stock int FindNearestVisibleEnemy(int iViewer, float flMaxDistance = 9999.0)
{
	float flPos[3];
	GetClientEyePosition(iViewer, flPos);
	
	float flBestDistance = flMaxDistance;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer) && TF2_IsKillable(i) && TF2_IsVisible(i))
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

stock int FindNearestEnemy(int iViewer, float flMaxDistance = 999999.0)
{
	float flPos[3];
	GetClientEyePosition(iViewer, flPos);
	
	float flBestDistance = flMaxDistance;
	int iBestTarget = -1;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != iViewer && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(iViewer) && TF2_IsKillable(i) && TF2_IsVisible(i))
		{
			float flTPos[3];
			GetClientEyePosition(i, flTPos);

			float flDistance = GetVectorDistance(flPos, flTPos);
	
			if(flDistance < flBestDistance)
			{
				flBestDistance = flDistance;
				iBestTarget = i;
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
