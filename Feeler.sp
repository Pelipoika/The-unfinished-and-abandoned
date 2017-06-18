#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

static int g_iLaserMaterial, g_iHaloMaterial;

int turn[MAXPLAYERS + 1];

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
		return Plugin_Continue;

	float angles[3]; angles = ang;

	float origin[3]; GetClientAbsOrigin(client, origin);
	float maxs[3]; GetClientMaxs(client, maxs);
	float mins[3]; GetClientMins(client, mins);
	
	angles[0] = 0.0;
	float vForward[3], vLeft[3];
	GetAngleVectors(angles, vForward, vLeft, NULL_VECTOR);

	origin[2] += 18.0;
	ScaleVector(mins, 0.5);
	ScaleVector(maxs, 0.5);
	
	float multiplier = maxs[1] * 2;
	float turnrate = 5.0;
	
	bool bRedHit, bGreenHit, bBlueHit, bWhiteHit;
	
	//Can't draw too much shit at same time.
	if (turn[client] == 0)	//Red, Forward Right
	{
		origin[0] += vForward[0] * multiplier;
		origin[1] += vForward[1] * multiplier;
		
		origin[0] += vLeft[0] * multiplier;
		origin[1] += vLeft[1] * multiplier;
		
		bRedHit = TE_DrawBox(client, origin, mins, maxs, _, view_as<int>( { 255, 0, 0, 255 } ));
	}
	else if(turn[client] == 1)	//Green, Back Left
	{
		origin[0] -= vForward[0] * multiplier;
		origin[1] -= vForward[1] * multiplier;
		
		origin[0] -= vLeft[0] * multiplier;
		origin[1] -= vLeft[1] * multiplier;
		
		bGreenHit = TE_DrawBox(client, origin, mins, maxs, _, view_as<int>( { 0, 255, 0, 255 } ));
	}
	else if(turn[client] == 3)	//Blue, Back Right
	{
		origin[0] += -vForward[0] * multiplier;
		origin[1] += -vForward[1] * multiplier;
		
		origin[0] += vLeft[0] * multiplier;
		origin[1] += vLeft[1] * multiplier;
		
		bBlueHit = TE_DrawBox(client, origin, mins, maxs, _, view_as<int>( { 0, 0, 255, 255 } ));
	}
	else if(turn[client] == 4)	//White, Forward Left
	{
		origin[0] += vForward[0] * multiplier;
		origin[1] += vForward[1] * multiplier;
		
		origin[0] += -vLeft[0] * multiplier;
		origin[1] += -vLeft[1] * multiplier;
		
		bWhiteHit = TE_DrawBox(client, origin, mins, maxs, _, view_as<int>( { 255, 255, 255, 255 } ));
	}
	
	if (++turn[client] > 4) turn[client] = 0;
	
	angles[0] = ang[0];
	
	if((bWhiteHit || bGreenHit) && !bRedHit)	//White = Left
	{
		vel[1] = 500.0;
		
		angles[1] -= (bWhiteHit && bGreenHit) ? (turnrate * 2) : (turnrate);
	}
	
	if((bRedHit || bBlueHit) && !bWhiteHit)
	{
		vel[1] = -500.0;
		
		angles[1] += (bRedHit && bBlueHit) ? (turnrate * 2) : (turnrate);
	}
	
	if(bWhiteHit || bRedHit || bGreenHit || bBlueHit)
		TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);

//	vel[0] = 500.0;
	
	return Plugin_Changed;
}

//Actually a tracehull in disguise
bool TE_DrawBox(int client, float m_vecOrigin[3], float m_vecMins[3], float m_vecMaxs[3], float flDur = 0.1, int color[4])
{
	//Trace top down
	float tStart[3]; tStart = m_vecOrigin;
	float tEnd[3];   tEnd = m_vecOrigin;
	
	tStart[2] = (tStart[2] + m_vecMaxs[2]);
	
//	TE_ShowPole(tStart, view_as<int>( { 255, 0, 255, 255 } ));
//	TE_ShowPole(tEnd, view_as<int>( { 0, 255, 255, 255 } ));
	
	Handle trace = TR_TraceHullFilterEx(tStart, tEnd, m_vecMins, m_vecMaxs, MASK_SHOT|CONTENTS_GRATE, WorldOnly, client);
	bool bDidHit = TR_DidHit(trace);
	
	if( m_vecMins[0] == m_vecMaxs[0] && m_vecMins[1] == m_vecMaxs[1] && m_vecMins[2] == m_vecMaxs[2] )
	{
		m_vecMins = view_as<float>({-15.0, -15.0, -15.0});
		m_vecMaxs = view_as<float>({15.0, 15.0, 15.0});
	}
	else
	{
		AddVectors(m_vecOrigin, m_vecMaxs, m_vecMaxs);
		AddVectors(m_vecOrigin, m_vecMins, m_vecMins);
	}
	
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = m_vecMaxs;
	vPos1[0] = m_vecMins[0];
	vPos2 = m_vecMaxs;
	vPos2[1] = m_vecMins[1];
	vPos3 = m_vecMaxs;
	vPos3[2] = m_vecMins[2];
	vPos4 = m_vecMins;
	vPos4[0] = m_vecMaxs[0];
	vPos5 = m_vecMins;
	vPos5[1] = m_vecMaxs[1];
	vPos6 = m_vecMins;
	vPos6[2] = m_vecMaxs[2];

	TE_SendBeam(client, m_vecMaxs, vPos1, flDur, color);
	TE_SendBeam(client, m_vecMaxs, vPos2, flDur, color);
	TE_SendBeam(client, m_vecMaxs, vPos3, flDur, color);
	TE_SendBeam(client, vPos6, vPos1, flDur, color);
	TE_SendBeam(client, vPos6, vPos2, flDur, color);
	TE_SendBeam(client, vPos6, m_vecMins, flDur, color);
	TE_SendBeam(client, vPos4, m_vecMins, flDur, color);
	TE_SendBeam(client, vPos5, m_vecMins, flDur, color);
	TE_SendBeam(client, vPos5, vPos1, flDur, color);
	TE_SendBeam(client, vPos5, vPos3, flDur, color);
	TE_SendBeam(client, vPos4, vPos3, flDur, color);
	TE_SendBeam(client, vPos4, vPos2, flDur, color);
	
	delete trace;
	
	return bDidHit;
}

void TE_SendBeam(int client, float m_vecMins[3], float m_vecMaxs[3], float flDur = 0.1, int color[4])
{
	TE_SetupBeamPoints(m_vecMins, m_vecMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, flDur, 1.0, 1.0, 1, 0.0, color, 0);
	TE_SendToClient(client);
}

stock void TE_ShowPole(float flPos[3], int Color[4])
{
	float flToPos[3];
	flToPos[0] = flPos[0];
	flToPos[1] = flPos[1];
	flToPos[2] = flPos[2];
	flToPos[2] += 30.0;
	
	//Show a giant vertical beam at our goal node
	TE_SetupBeamPoints(flPos, flToPos, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.1, 2.0, 2.0, 5, 0.0, Color, 30);
	TE_SendToAll();
}

public void OnMapStart()
{
	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
}

public bool WorldOnly(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "entity_medigun_shield"))
	{
		if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	else if(StrEqual(class, "player", false))
	{
		return false;
	}
		
	return !(entity == iExclude);
}
