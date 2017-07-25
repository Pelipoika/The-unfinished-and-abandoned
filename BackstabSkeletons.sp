#pragma semicolon 1

#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

Handle g_hSDKWorldSpaceCenter;
Handle g_hSendWeaponAnim;

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("bot-control");
	
	//This entity is used to get an entitys center position
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((g_hSDKWorldSpaceCenter = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CBaseEntity::WorldSpaceCenter offset!");
	
	//This entity is used to get an entitys center position
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(241);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSendWeaponAnim = EndPrepSDKCall()) == null) SetFailState("Failed to create SDKCall for CTFWeaponBase::SendWeaponAnim(int) offset!");
	
	delete hConf;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "tf_zombie"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool bIsKnife = HasEntProp(weapon, Prop_Send, "m_bReadyToBackstab");
	if(bIsKnife)
	{
		bool m_bReadyToBackstab = !!GetEntProp(weapon, Prop_Send, "m_bReadyToBackstab");
		if(m_bReadyToBackstab)
		{			
			damagetype |= DMG_CRIT;
			damagecustom = TF_CUSTOM_BACKSTAB;
			damage *= 4;
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	//Let's pretend this is CTFKnife::BackstabVMThink
	
	//if ( GetActivity() == ACT_VM_IDLE || GetActivity() == ACT_BACKSTAB_VM_IDLE )
	int wep = GetPlayerWeaponSlot(client, 2);
	if(!IsValidEntity(wep))
		return; 
	
	bool bIsKnife = HasEntProp(wep, Prop_Send, "m_bReadyToBackstab");
	if(!bIsKnife)
		return;
	
	bool m_bReadyToBackstab = !!GetEntProp(wep, Prop_Send, "m_bReadyToBackstab");
	
	Handle tr;
	if(DoSwingTrace(client, tr) && GetTeamNumber(TR_GetEntityIndex(tr)) != GetClientTeam(client) && IsBehindAndFacingTarget(client, TR_GetEntityIndex(tr)))
	{
		int target = TR_GetEntityIndex(tr);		
		if(target > 0 && IsBehindAndFacingTarget( client, target))
		{
			SetEntProp(wep, Prop_Send, "m_bReadyToBackstab", true);
			
			if ( !m_bReadyToBackstab )
			{
				SDKCall(g_hSendWeaponAnim, wep, 1655);
			}
		}
		else
		{
			SetEntProp(wep, Prop_Send, "m_bReadyToBackstab", false);
			
			if ( m_bReadyToBackstab )
			{	
				SDKCall(g_hSendWeaponAnim, wep, 1656);
			}
		}
	}
	
	delete tr;
}

bool IsBehindAndFacingTarget( int client, int pTarget )
{
	// Get the forward view vector of the target, ignore Z
	float vecVictimForward[3];
	GetAngleVectors( EntityEyeAngles(pTarget), vecVictimForward, NULL_VECTOR, NULL_VECTOR );
	vecVictimForward[2] = 0.0;
	NormalizeVector(vecVictimForward, vecVictimForward);

	// Get a vector from my origin to my targets origin
	float vecToTarget[3];
	SubtractVectors( WorldSpaceCenter(pTarget), WorldSpaceCenter(client), vecToTarget);
	vecToTarget[2] = 0.0;
	NormalizeVector(vecToTarget, vecToTarget);

	// Get a forward vector of the attacker.
	float vecOwnerForward[3];
	GetAngleVectors( EntityEyeAngles(client), vecOwnerForward, NULL_VECTOR, NULL_VECTOR );
	vecOwnerForward[2] = 0.0;
	NormalizeVector(vecOwnerForward, vecOwnerForward);

	float flDotOwner = GetVectorDotProduct( vecOwnerForward, vecToTarget );
	float flDotVictim = GetVectorDotProduct( vecVictimForward, vecToTarget );

	// Make sure they're actually facing the target.
	// This needs to be done because lag compensation can place target slightly behind the attacker.
	if ( flDotOwner > 0.5 )
		return ( flDotVictim > -0.1 );

	return false;
}

bool DoSwingTrace( int pPlayer, Handle &trace )
{
	// Setup a volume for the melee weapon to be swung - approx size, so all melee behave the same.
	static float vecSwingMins[3]; vecSwingMins = view_as<float>({-18, -18, -18});
	static float vecSwingMaxs[3]; vecSwingMaxs = view_as<float>({18, 18, 18});

	// Setup the swing range.
	float vecForward[3]; 
	GetAngleVectors( EntityEyeAngles(pPlayer), vecForward, NULL_VECTOR, NULL_VECTOR );
	
	float vecSwingStart[3]; vecSwingStart = PlayerEyePosition(pPlayer);
	
	float vecSwingEnd[3];
	vecSwingEnd[0] = vecSwingStart[0] + vecForward[0] * 48;
	vecSwingEnd[1] = vecSwingStart[1] + vecForward[1] * 48;
	vecSwingEnd[2] = vecSwingStart[2] + vecForward[2] * 48;
	
	// See if we hit anything.
	trace = TR_TraceRayFilterEx( vecSwingStart, vecSwingEnd, MASK_SOLID, RayType_EndPoint, FilterData, pPlayer );
	if ( TR_GetFraction(trace) >= 1.0 )
	{
		delete trace;
		trace = TR_TraceHullFilterEx( vecSwingStart, vecSwingEnd, vecSwingMins, vecSwingMaxs, MASK_SOLID, FilterData, pPlayer );
		if ( TR_GetFraction(trace) < 1.0 )
		{
			// This is the point on the actual surface (the hull could have hit space)
			TR_GetEndPosition(vecSwingEnd, trace);	
		}
	}

	return ( TR_GetFraction(trace) < 1.0 );
}

public bool FilterData(int entity, int contentsMask, any data)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "tf_zombie"))
	{
		return true;
	}
	
	return !(entity == data);
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

stock float [] EntityEyeAngles(int entity)
{
	float vecTargetEyeAng[3]; 
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vecTargetEyeAng);
	
	return vecTargetEyeAng;
}

stock float [] PlayerEyePosition(int client)
{
	float vec[3]; 
	GetClientEyePosition(client, vec);
	
	return vec;
}

int GetTeamNumber(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iTeamNum");
}


/*
//-----------------------------------------------------------------------------
// Purpose: 
//-----------------------------------------------------------------------------
bool CTFPlayer::CanAttack( void )
{
	CTFGameRules *pRules = TFGameRules();

	Assert( pRules );

	// Only regular cloak prevents us from firing.
	if ( m_Shared.GetStealthNoAttackExpireTime() > gpGlobals->curtime || m_Shared.InCond( TF_COND_STEALTHED ) )
	{
		return false;
	}

	if ( ( pRules->State_Get() == GR_STATE_TEAM_WIN ) && ( pRules->GetWinningTeam() != GetTeamNumber() ) )
	{
		return false;
	}

	return true;
}
*/