#include <sourcemod>
#include <sdktools>

Handle g_CritBucket;

bool g_bWantsTheBucket[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_CritBucket = CreateHudSynchronizer();
	
	CreateTimer(0.1, Timer_UpdateBucketHUD, _, TIMER_REPEAT);
	
	RegAdminCmd("sm_critbucket", Command_CritBucketInfo, 0);
}

public void OnClientPutInServer(int client)
{
	g_bWantsTheBucket[client] = false;
}

public Action Timer_UpdateBucketHUD(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!g_bWantsTheBucket[i])
			continue;
	
		if(!IsClientInGame(i))
			continue;
			
		int iOriginal = i;
			
		//Print observed targets crit info.
		int iObserved = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
		if(GetClientTeam(i) == 1 && iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved))
			i = iObserved;
			
		int iActiveWeapon = GetEntPropEnt(i, Prop_Data, "m_hActiveWeapon");
		if(!IsValidEntity(iActiveWeapon))
			return Plugin_Handled;
		
		int m_hOwner_Offset = FindSendPropInfo("CBaseCombatWeapon", "m_hOwner");
		int iCritAmount_Offset         = m_hOwner_Offset + 4;	
		int inCritChecks_Offset        = m_hOwner_Offset + 8;
		int inCritSeedRequests_Offset  = m_hOwner_Offset + 12;
		
		//Bucket Cap
		float flCap     = FindConVar("tf_weapon_criticals_bucket_cap").FloatValue;
		float flBottom  = FindConVar("tf_weapon_criticals_bucket_bottom").FloatValue;
		float flDefault = FindConVar("tf_weapon_criticals_bucket_default").FloatValue;
		
		//Crit tokens in gun
		float m_flCritTokenBucket = GetEntDataFloat(iActiveWeapon, iCritAmount_Offset); 
		float flPercentage = (m_flCritTokenBucket / flCap) * 100;
		
		int m_nCritChecks       = GetEntData(iActiveWeapon, inCritChecks_Offset);		//1432
		int m_nCritSeedRequests = GetEntData(iActiveWeapon, inCritSeedRequests_Offset);	//1436
		
		SetHudTextParams(1.0, 0.5, 0.15, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(iOriginal, g_CritBucket, "Crit Bucket Info\nTokens %.1f / %.1f (%.0f %%)\nDefault %.1f\nCap %.1f\nBottom %.1f\nm_nCritChecks %i\nm_nCritSeedRequests %i", m_flCritTokenBucket, flCap, flPercentage, flDefault, flCap, flBottom, m_nCritChecks, m_nCritSeedRequests);
	}
	
	return Plugin_Continue;
}

/*
stock bool IsAllowedToWithdrawFromCritBucket(int client, float flDamage, int m_nCritSeedRequests, int m_nCritChecks, float m_flCritTokenBucket)
{
	static int TF_DAMAGE_CRIT_MULTIPLIER = 3;

	int iActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	bool bIsMeleeWeapon = GetPlayerWeaponSlot(client, 0) == iActiveWeapon;

	// Adjust token cost based on the ratio of requests vs granted, except
	// melee, which crits much more than ranged (as high as 60% chance)
	float flMult = (bIsMeleeWeapon) ? 0.5 : RemapValClamped((float(m_nCritSeedRequests) / float(m_nCritChecks)), 0.1, 1.0, 1.0, 3.0);

	// Would this take us below our limit?
	float flCost = (flDamage * TF_DAMAGE_CRIT_MULTIPLIER) * flMult;
	if ( flCost > m_flCritTokenBucket )
		return false;

	return true;
}

stock float RemapValClamped( float val, float A, float B, float C, float D)
{
	if (A == B)
		return val >= B ? D : C;
	
	float cVal = (val - A) / (B - A);
	cVal = clamp(cVal, 0.0, 1.0);

	return C + (D - C) * cVal;
}

public float clamp(float a, float b, float c) { return (a > c ? c : (a < b ? b : a)); }
*/
public Action Command_CritBucketInfo(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;

	g_bWantsTheBucket[client] = !g_bWantsTheBucket[client];
	ReplyToCommand(client, "Crit Bucket HUD: %s", g_bWantsTheBucket[client] ? "On":"Off");

	return Plugin_Handled
}
