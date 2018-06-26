#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required;

static int g_iLaserMaterial, g_iHaloMaterial;

bool g_bHanging[MAXPLAYERS+1];
float g_vecClimbPos[MAXPLAYERS+1][3];

public void OnMapStart()
{
	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
}

public void OnClientPutInServer(int client)
{
	g_bHanging[client] = false;
	g_vecClimbPos[client] = view_as<float>{0.0, 0.0, 0.0};
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon)
{
	if (IsPlayerAlive(client) && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") < 0)
	{
		if(iButtons & IN_JUMP && g_bHanging[client] && !(iButtons & IN_DUCK))
		{
			PrintToChat(client, "Climbed up");
			SetEntityMoveType(client, MOVETYPE_WALK);
			
			g_vecClimbPos[client][2] += 5.0;
			
			TeleportEntity(client, g_vecClimbPos[client], NULL_VECTOR, NULL_VECTOR); 
			
			g_bHanging[client] = false;
			
			SetVariantString("");
			AcceptEntityInput(client, "SetCustomModel");
			SetVariantBool(true);
			AcceptEntityInput(client, "SetCustomModelRotates");
		}
		else if(iButtons & IN_DUCK && g_bHanging[client])
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
			g_bHanging[client] = false;
			
			SetVariantString("");
			AcceptEntityInput(client, "SetCustomModel");
			SetVariantBool(true);
			AcceptEntityInput(client, "SetCustomModelRotates");
		}
		
		float flOrigin[3], flMins[3], flMaxs[3];
		GetClientAbsOrigin(client, flOrigin);
		GetClientMaxs(client, flMaxs);
		GetClientMins(client, flMins);
	
		flMaxs[0] += 2.5;
		flMaxs[1] += 2.5;
		flMins[0] -= 2.5;
		flMins[1] -= 2.5;
		
		Handle TraceRay = TR_TraceHullFilterEx(flOrigin, flOrigin, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterNotSelf, client);
		bool bHit = TR_DidHit(TraceRay);
		TE_SendBox(client, bHit, flOrigin, flMins, flMaxs);
		delete TraceRay;
		
		if(bHit)
		{
			float angles[3], forw[3];
			GetClientEyeAngles(client, angles);
			angles[0] = 0.0;
			GetAngleVectors(angles, forw, NULL_VECTOR, NULL_VECTOR);
			
			MapCircleToSquare(forw, forw);
			
			flOrigin[0] += (forw[0] * 29);
			flOrigin[1] += (forw[1] * 29);
			flOrigin[2] += (forw[2] * 29) + flMaxs[2];
			
			flOrigin[2] += 32.0;
		
			float flHitPos[3];
			TR_TraceRayFilter(flOrigin, view_as<float>{90.0, 0.0, 0.0}, MASK_PLAYERSOLID, RayType_Infinite, TraceFilterNotSelf, client);
			if (TR_DidHit() && !g_bHanging[client])
			{
				TR_GetEndPosition(flHitPos);
				
				TE_SetupBeamPoints(flHitPos, flOrigin, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.1, 1.0, 1.0, 1, 0.0, {0, 255, 0, 100}, 0);
				TE_SendToClient(client);
				
				//Fat hull trace
				GetClientMaxs(client, flMaxs);
				GetClientMins(client, flMins);
				
				TR_TraceHullFilter(flOrigin, flHitPos, flMins, flMaxs, MASK_SOLID, TraceEntityFilterSolid, client);
			
				float fatty[3];

				TR_GetEndPosition(fatty);
				
				TE_SendBox(client, true, fatty, flMins, flMaxs);
				
				TE_SetupBeamRingPoint(fatty, 10.0, 11.0, g_iLaserMaterial, g_iHaloMaterial, 0, 15, 0.1, 1.0, 1.0, {0, 255, 0, 100}, 5, 0);
				TE_SendToClient(client);
				
				GetClientEyePosition(client, flOrigin);
				float flDistance = GetVectorDistance(flOrigin, fatty);
				
				if(flDistance <= 40.0 && flDistance >= 22.0)
				{
					TR_TraceHullFilter(fatty, fatty, flMins, flMaxs, MASK_SOLID, TraceEntityFilterSolid, client);	//Test if we can fit to the dest pos before teleporting
					if(!TR_DidHit())
					{
						PrintToChat(client, "Attached to ledge at distance %f", flDistance);
						
						g_vecClimbPos[client][0] = fatty[0];
						g_vecClimbPos[client][1] = fatty[1];
						g_vecClimbPos[client][2] = fatty[2];
						
						fatty[0] = flOrigin[0];
						fatty[1] = flOrigin[1];
						fatty[2] = (fatty[2] -= flMaxs[2]);
						
						TeleportEntity(client, fatty, NULL_VECTOR, view_as<float>{0.0, 0.0, 0.0}); 
						
						SetEntityMoveType(client, MOVETYPE_NONE);
						
						g_bHanging[client] = true;
						
						char strModel[PLATFORM_MAX_PATH];
						GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
						
						SetVariantString(strModel);
						AcceptEntityInput(client, "SetCustomModel");
						SetVariantBool(false);
						AcceptEntityInput(client, "SetCustomModelRotates");
						SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);		
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entity == 0 && entityhit != entity)
		return true;
	
	return false;
}

public bool TraceEntityFilterSolid(int entityhit, int contentsMask, int entity) 
{
	if (entityhit > MaxClients && entityhit != entity)
	{
		return true;
	}
	
	return false;
}

stock void TE_SendBox(int client, bool bHit, float flOrigin[3], float flMins[3], float flMaxs[3])
{
	float flMaxResult[3], flMinResult[3];
	AddVectors(flOrigin, flMaxs, flMaxResult);
	AddVectors(flOrigin, flMins, flMinResult);

	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = flMaxResult;
	vPos1[0] = flMinResult[0];
	vPos2 = flMaxResult;
	vPos2[1] = flMinResult[1];
	vPos3 = flMaxResult;
	vPos3[2] = flMinResult[2];
	vPos4 = flMinResult;
	vPos4[0] = flMaxResult[0];
	vPos5 = flMinResult;
	vPos5[1] = flMaxResult[1];
	vPos6 = flMinResult;
	vPos6[2] = flMaxResult[2];

	TE_SendBeam(client, flMaxResult, vPos1, bHit);
	TE_SendBeam(client, flMaxResult, vPos2, bHit);
	TE_SendBeam(client, flMaxResult, vPos3, bHit);
	TE_SendBeam(client, vPos6, vPos1, bHit);
	TE_SendBeam(client, vPos6, vPos2, bHit);
	TE_SendBeam(client, vPos6, flMinResult, bHit);
	TE_SendBeam(client, vPos4, flMinResult, bHit);
	TE_SendBeam(client, vPos5, flMinResult, bHit);
	TE_SendBeam(client, vPos5, vPos1, bHit);
	TE_SendBeam(client, vPos5, vPos3, bHit);
	TE_SendBeam(client, vPos4, vPos3, bHit);
	TE_SendBeam(client, vPos4, vPos2, bHit);
}

void TE_SendBeam(int client, float m_vecMins[3], float m_vecMaxs[3], bool bHit)
{
	if(!bHit)
		TE_SetupBeamPoints(m_vecMins, m_vecMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.1, 1.0, 1.0, 1, 0.0, {255, 255, 255, 100}, 0);
	else
		TE_SetupBeamPoints(m_vecMins, m_vecMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.1, 1.0, 1.0, 1, 0.0, {255, 0, 0, 100}, 0);
	TE_SendToClient(client);
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

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}