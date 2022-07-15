#pragma semicolon 1

//#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <emitsoundany>

#pragma newdecls required

#define EF_BONEMERGE       (1 << 0)
#define EF_PARENT_ANIMATES (1 << 9)

/*
for animating:
	LookupSequence //Lookup attachment index by name
	CBaseAnimating::GetAttachment //Get attachment positon with the index
	
	CBaseAnimating::StudioFrameAdvance //Advance animation
	CBaseAnimating::ResetSequence    //Set animation
	
	CBaseAnimating::LookupPoseParameter //Get a poseparameter index by name
	CBaseAnimating::GetPoseParameter //Get sentry gun rotation and stuff
	CBaseAnimating::SetPoseParameter //Set sentry gun rotation and stuff

for layered anims:
	CBaseAnimatingOverlay::AddGestureSequence

for firing:
to get muzzle attachment position
	Studio_FindAttachment
and
	CBaseAnimating::GetAttachment
*/

public Plugin myinfo = 
{
	name = "[CSGO] Sentry Gun",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = ""
};

Handle g_hResetSequence;
Handle g_hLookupSequence;
Handle g_hLookupActivity;

//Layered anims
Handle g_hAddLayeredSequence;

Handle g_hStudioFrameAdvance;

Handle g_hLookupPoseParameter;

Handle g_hGetAttachment;

//static int m_fFlags    = 0x5C;
static int m_fFlags    = 0x0;
static int m_nSequence = 0x8;

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("csgo.sentry");

	//LookupPoseParameter(CStudioHdr *pStudioHdr, const char *szName);
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);     //szName
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hLookupPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::LookupPoseParameter");
	
	//-----------------------------------------------------------------------------
	// Purpose: Looks up a sequence by sequence name first, then by activity name.
	// Input  : label - The sequence name or activity name to look up.
	// Output : Returns the sequence index of the matching sequence, or ACT_INVALID.
	//-----------------------------------------------------------------------------
	//LookupSequence(const char *label);
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	if((g_hLookupSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::LookupSequence");
	
	//ResetSequence(int nSequence);
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

	//int CBaseAnimatingOverlay::AddLayeredSequence( int sequence, int iPriority )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddLayeredSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  //sequence
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//priority
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return layer
	if((g_hAddLayeredSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AddLayeredSequence");
	
	//=========================================================
	// StudioFrameAdvance - advance the animation frame up some interval (default 0.1) into the future
	//=========================================================
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance signature!"); 	
	
	//-----------------------------------------------------------------------------
	// Purpose: Returns the world location and world angles of an attachment
	// Input  : attachment name
	// Output :	location and angles
	//-----------------------------------------------------------------------------
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetAttachment");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//Attachment name
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //absOrigin
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK); //absAngles
	if((g_hGetAttachment = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::GetAttachment");
	
	delete hConf;
	
	RegAdminCmd("sm_sentry", Command_Sentry, ADMFLAG_ROOT);
}

public void OnMapStart()
{
	PrecacheSoundAny("sentrymp3/sentry_empty.mp3");
	PrecacheSoundAny("sentrymp3/sentry_finish.mp3");
	PrecacheSoundAny("sentrymp3/sentry_scan.mp3");
	PrecacheSoundAny("sentrymp3/sentry_scan2.mp3");
	PrecacheSoundAny("sentrymp3/sentry_scan3.mp3");
	PrecacheSoundAny("sentrymp3/sentry_shoot.mp3");
	PrecacheSoundAny("sentrymp3/sentry_shoot_mini.mp3");
	PrecacheSoundAny("sentrymp3/sentry_shoot2.mp3");
	PrecacheSoundAny("sentrymp3/sentry_shoot3.mp3");
	PrecacheSoundAny("sentrymp3/sentry_spot.mp3");
	PrecacheSoundAny("sentrymp3/sentry_spot_client.mp3");
	PrecacheSoundAny("sentrymp3/sentry_rocket.mp3");
	
	PrecacheEffect("ParticleEffect");
	PrecacheParticleEffect("weapon_tracers_50cal");
	PrecacheParticleEffect("weapon_muzzle_flash_awp");
	PrecacheParticleEffect("impact_dirt");
	PrecacheParticleEffect("blood_impact_heavy");
	
	PrecacheModel("models/buildables/sentry1.mdl");
	PrecacheModel("models/buildables/sentry2.mdl");
	PrecacheModel("models/buildables/sentry3.mdl");
	PrecacheModel("models/buildables/sentry3_rockets.mdl");
}

#define SENTRY_THINK_DELAY 0.05

#define SENTRYGUN_EYE_OFFSET_LEVEL_1	32.0
#define SENTRYGUN_EYE_OFFSET_LEVEL_2	40.0
#define SENTRYGUN_EYE_OFFSET_LEVEL_3	46.0

#define ANIM_LAYER_ACTIVE		0x0001
#define ANIM_LAYER_AUTOKILL		0x0002
#define ANIM_LAYER_KILLME		0x0004
#define ANIM_LAYER_DONTRESTORE	0x0008
#define ANIM_LAYER_CHECKACCESS	0x0010
#define ANIM_LAYER_DYING		0x0020

enum
{
	SENTRY_STATE_INACTIVE = 0,
	SENTRY_STATE_SEARCHING,
	SENTRY_STATE_ATTACKING,
	SENTRY_STATE_UPGRADING,

	SENTRY_NUM_STATES,
};

float m_flNextAttack;
float m_flNextRocketAttack;

// Rotation
int m_iRightBound;
int m_iLeftBound;

bool m_bTurningRight;

float m_vecCurAngles[3];
float m_vecGoalAngles[3];

float m_flTurnRate;

// Target player / object
int m_hEnemy = INVALID_ENT_REFERENCE;

int m_iState = SENTRY_STATE_INACTIVE;

int m_iAmmoRockets = 99999999999;
int m_iAmmoShells = 99999999999;
int m_iUpgradeLevel = 1;

methodmap SentryGun
{
	public SentryGun(int owner, float vecPos[3], float vecAng[3], int iUpgradeLevel = 1)
	{
		int index = -1;
		while ((index = FindEntityByClassname(index, "monster_generic")) != -1)
		{
			AcceptEntityInput(index, "Kill");
		}
	
		int ent = CreateEntityByName("monster_generic");
		DispatchKeyValueVector(ent, "origin", vecPos);
		DispatchKeyValueVector(ent, "angles", vecAng);
		
		if(GetClientTeam(owner) == CS_TEAM_CT)
			DispatchKeyValue(ent, "skin", "1");
		else
			DispatchKeyValue(ent, "skin", "0");
		
		switch(iUpgradeLevel)
		{
			case 1: DispatchKeyValue(ent, "model", "models/buildables/sentry1.mdl");
			case 2: DispatchKeyValue(ent, "model", "models/buildables/sentry2.mdl");
			case 3: DispatchKeyValue(ent, "model", "models/buildables/sentry3.mdl");
		}
		
		DispatchSpawn(ent);
			
		m_iUpgradeLevel = iUpgradeLevel;
		
		SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);
		SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(owner));
		
		// Orient it
		float angles[3]; angles = GetAbsAngles(ent);
	
		m_vecCurAngles[1] = UTIL_AngleMod(angles[1]);
		m_iRightBound = RoundToNearest(UTIL_AngleMod(angles[1] - 50.0));
		m_iLeftBound  = RoundToNearest(UTIL_AngleMod(angles[1] + 50.0));
		
		if (m_iRightBound > m_iLeftBound)
		{
			m_iRightBound = m_iLeftBound;
			m_iLeftBound = RoundToNearest(UTIL_AngleMod(angles[1] - 50));
		}
		
		// Start it rotating
		m_vecGoalAngles[1] = float(m_iRightBound);
		m_vecGoalAngles[0] = m_vecCurAngles[0] = 0.0;
		m_bTurningRight = true;		
		
		m_iState = SENTRY_STATE_SEARCHING;
		m_hEnemy = INVALID_ENT_REFERENCE;
		
		SDKHook(ent, SDKHook_SetTransmit, OnSentryThink);
		
		return view_as<SentryGun>(ent);
	}
	
	property int index {
		public get() { 
			return view_as<int>(this); 
		}
	}
	public int GetOwner() {
		return GetEntPropEnt(this.index, Prop_Send, "m_hOwnerEntity");
	}
	public int GetTeam() {
		return GetEntProp(this.index, Prop_Send, "m_iTeamNum");
	}
	public Address GetStudioHdr() {
		return view_as<Address>(GetEntData(this.index, view_as<int>(1216)));
	}
	public Address CBaseAnimatingOverlay() {
		int iOffset = (view_as<int>(GetEntityAddress(this.index)) + FindDataMapInfo(this.index, "m_AnimOverlay"));
		return view_as<Address>(LoadFromAddress(view_as<Address>(iOffset), NumberType_Int32));
	}
	public void SetPoseParameter(int iParameter, float flStart, float flEnd, float flValue)	{
		float ctlValue = (flValue - flStart) / (flEnd - flStart);
		if (ctlValue < 0) ctlValue = 0.0;
		if (ctlValue > 1) ctlValue = 1.0;
		
		SetEntPropFloat(this.index, Prop_Send, "m_flPoseParameter", ctlValue, iParameter);
	}
	public int LookupPoseParameter(const char[] szName)	{
		Address pStudioHdr = this.GetStudioHdr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupPoseParameter, this.index, pStudioHdr, szName);
	}
	public void GetAttachment(const char[] szName, float absOrigin[3], float absAngles[3])	{
		SDKCall(g_hGetAttachment, this.index, szName, absOrigin, absAngles);
		
		//PrintToServer("GetAttachment %s - %f %f %f | %f %f %f", szName, absOrigin[0], absOrigin[1], absOrigin[2], absAngles[0], absAngles[1], absAngles[2]);
	}
	public int LookupSequence(const char[] anim) {
		return SDKCall(g_hLookupSequence, this.index, anim);
	}
	public int LookupActivity(const char[] anim) {
		return SDKCall(g_hLookupActivity, this.index, anim);
	}
	public void SetAnimation(const char[] anim)	{
		int iSequence = this.LookupSequence(anim);
		if(iSequence < 0)
			return;
			
		SDKCall(g_hResetSequence, this.index, iSequence);
	}
	public int FindGestureLayer(const char[] anim) {
		int iSequence = this.LookupSequence(anim);
		if(iSequence < 0)
			return -1;
		
		Address overlay = this.CBaseAnimatingOverlay();
		
		//PrintToServer("Overlay count = %i", GetEntData(this.index, 1248) );
		
		for (int i = 0; i < GetEntData(this.index, 1248); i++)
		{
			//Offset to a layers m_fFlags.
			int fFlags = LoadFromAddress(overlay + view_as<Address>(m_fFlags * i), NumberType_Int32);
			
			if (!(fFlags & ANIM_LAYER_ACTIVE))
				continue;
			
			if (fFlags & ANIM_LAYER_KILLME)
				continue;
			
			int sequence = LoadFromAddress(overlay + view_as<Address>(m_nSequence * i), NumberType_Int32);
			if(sequence == iSequence)
				return i;
		}
		
		return -1;
	}
	public void AddGesture(const char[] anim, bool bAutokill  = true) {
		int iSequence = this.LookupSequence(anim);
		if(iSequence < 0)
			return;
		
		//1212 = m_AnimOverlay.Count(), if this offset ever breaks; repalce it with 15 because it doesn't really matter. All you will be doing is accessing unallocated memory :o
		int iCount = GetEntData(this.index, 1248);
		
		int iLayer = SDKCall(g_hAddLayeredSequence, this.index, iSequence, 0);
		if(iLayer >= 0 && iLayer <= iCount && bAutokill)
		{
			Address overlay = this.CBaseAnimatingOverlay();
			
			//Offset to a layers m_fFlags.
			int iOffsetFlags    = m_fFlags    * iLayer;
			int iOffsetSequence = m_nSequence * iLayer;
			
			int fFlags = LoadFromAddress(overlay + view_as<Address>(iOffsetFlags), NumberType_Int32);
			StoreToAddress(overlay + view_as<Address>(iOffsetFlags), fFlags |= (ANIM_LAYER_AUTOKILL|ANIM_LAYER_KILLME), NumberType_Int32);
			
			//Needed because valve is incompetent.
			StoreToAddress(overlay + view_as<Address>(iOffsetSequence), iSequence, NumberType_Int32);
		}
		
		#if defined DEBUG
		PrintToChatAll("AddGesture %s %i layer %i autokill %s", anim, iSequence, iLayer, bAutokill ? "YES" : "NO");
		#endif
	}
	public bool IsPlayingGesture(const char[] anim)	{
		return this.FindGestureLayer(anim) != -1 ? true : false;
	}
	public void RemoveGesture(const char[] anim) {
		int iLayer = this.FindGestureLayer(anim);
		if (iLayer == -1)
			return;
		
		Address overlay = this.CBaseAnimatingOverlay();
		
		int iOffset = m_fFlags * iLayer;
		int fFlags = LoadFromAddress(overlay + view_as<Address>(iOffset), NumberType_Int32);
		
		StoreToAddress(overlay + view_as<Address>(iOffset), fFlags |= (ANIM_LAYER_KILLME|ANIM_LAYER_AUTOKILL|ANIM_LAYER_DYING), NumberType_Int32);
		
		#if defined DEBUG
		PrintToChatAll("RemoveGesture %s layer %i", anim, iLayer);
		#endif
	}
	public int GetBaseTurnRate() { return 2; }
	
	public void AttachTrail(int entity, float vecSrc[3], float vecAimDir[3], const char[] attachment)
	{
		int index = CreateEntityByName("env_rockettrail");
		DispatchKeyValueVector(index, "origin", vecSrc);
		DispatchKeyValueVector(index, "angles", vecAimDir);
		SetEntPropFloat(index, Prop_Send, "m_Opacity", 0.5);
		SetEntPropFloat(index, Prop_Send, "m_SpawnRate", 100.0);
		SetEntPropFloat(index, Prop_Send, "m_ParticleLifetime", 0.3);
		SetEntPropVector(index, Prop_Send, "m_StartColor", view_as<float>({0.5, 0.5, 0.5}));
		SetEntPropFloat(index, Prop_Send, "m_StartSize", 3.0);
		SetEntPropFloat(index, Prop_Send, "m_EndSize", 15.0);
		SetEntPropFloat(index, Prop_Send, "m_SpawnRadius", 0.0);
		SetEntPropFloat(index, Prop_Send, "m_MinSpeed", 0.0);
		SetEntPropFloat(index, Prop_Send, "m_MaxSpeed", 100.0);
		SetEntPropFloat(index, Prop_Send, "m_flFlareScale", 1.0);
		DispatchSpawn(index);
		ActivateEntity(index);
		
		SetVariantString("!activator");
		AcceptEntityInput(index, "SetParent", entity);
		
		SetVariantString(attachment);
		AcceptEntityInput(index, "SetParentAttachment");
	}
	
	public void SentryRocketCreate(float vecSrc[3], float vecAimDir[3])
	{
		//return; 
		int rocket = CreateEntityByName("monster_generic");
		DispatchKeyValue(rocket, "model", "models/buildables/sentry3_rockets.mdl");
		DispatchKeyValueVector(rocket, "origin", vecSrc);
		DispatchKeyValueVector(rocket, "angles", vecAimDir);
		DispatchSpawn(rocket);
		
		SetEntityMoveType(rocket, MOVETYPE_FLY);
		
		SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", this.GetOwner());

		this.AttachTrail(rocket, vecSrc, vecAimDir, "rocket1");
		this.AttachTrail(rocket, vecSrc, vecAimDir, "rocket2");
		this.AttachTrail(rocket, vecSrc, vecAimDir, "rocket3");
		this.AttachTrail(rocket, vecSrc, vecAimDir, "rocket4");
		
		SetEntPropFloat(rocket, Prop_Data, "m_flNextDodgeTime", GetGameTime());
		
		SDKHook(rocket, SDKHook_SetTransmit, OnRocketThink);
		SDKHook(rocket, SDKHook_StartTouch,  OnRocketTouch);
		//SDKHook(rocket, SDKHook_Touch,  OnRocketTouch);
	}
	
	//-----------------------------------------------------------------------------
	// Purpose: Validate target
	//-----------------------------------------------------------------------------
	public bool ValidTargetPlayer( int pPlayer, const float vecStart[3], const float vecEnd[3] )
	{
		// Ray trace!!!
		TR_TraceRayFilter(vecStart, vecEnd, (MASK_SHOT|CONTENTS_GRATE), RayType_EndPoint, AimTargetFilter, this.index);
		if(!TR_DidHit() || TR_GetEntityIndex() == pPlayer)
		{
			return true;
		}
		
		return false;
	}
	
	public void SelectTargetPoint(float vecSrc[3], float vecMidEnemy[3])
	{
		vecMidEnemy = WorldSpaceCenter(EntRefToEntIndex(m_hEnemy));
	
		// If we cannot see their WorldSpaceCenter ( possible, as we do our target finding based
		// on the eye position of the target ) then fire at the eye position
		TR_TraceRayFilter(vecSrc, vecMidEnemy, MASK_SOLID, RayType_EndPoint, AimTargetFilter, this.index);
		if(TR_DidHit() && (TR_GetEntityIndex() >= MaxClients || TR_GetEntityIndex() <= 0))
		{
			// Hack it lower a little bit..
			// The eye position is not always within the hitboxes for a standing CS Player
			vecMidEnemy = EyePosition(EntRefToEntIndex(m_hEnemy));
			vecMidEnemy[2] -= 5.0;
		}
	}
	
	//-----------------------------------------------------------------------------
	// Found a Target
	//-----------------------------------------------------------------------------
	public void FoundTarget(int pTarget, const float vecSoundCenter[3] )
	{	
		m_hEnemy = EntIndexToEntRef(pTarget);
	
		if ((m_iAmmoShells > 0 ) || (m_iAmmoRockets > 0 && m_iUpgradeLevel == 3 ))
		{
		/*	// Play one sound to everyone but the target.
			CPASFilter filter( vecSoundCenter );
	
			if (IsPlayer(pTarget))
			{
				CTFPlayer *pPlayer = ToTFPlayer( pTarget );
	
				// Play a specific sound just to the target and remove it from the genral recipient list.
				CSingleUserRecipientFilter singleFilter( pPlayer );
				EmitSound( singleFilter, entindex(), "Building_Sentrygun.AlertTarget" );
				filter.RemoveRecipient( pPlayer );
			}*/
			
			EmitAmbientSoundAny("sentrymp3/sentry_spot.mp3", WorldSpaceCenter(this.index));
		}
	
		// Update timers, we are attacking now!
		m_iState = SENTRY_STATE_ATTACKING;
		m_flNextAttack = GetGameTime() + SENTRY_THINK_DELAY;
		
		if (m_flNextRocketAttack < GetGameTime())
		{
			m_flNextRocketAttack = GetGameTime() + 0.5;
		}
	}
	
	//-----------------------------------------------------------------------------
	// Look for a target
	//-----------------------------------------------------------------------------
	public bool FindTarget()
	{
		// Loop through players within 1100 units (sentry range).
		float vecSentryOrigin[3]; vecSentryOrigin = EyePosition(this.index);
	
		// Find the opposing team.
		int pTeam = this.GetTeam();
	
		int iEnemyTeam;
		
		if(pTeam == CS_TEAM_T)
			iEnemyTeam = CS_TEAM_CT;
		else
			iEnemyTeam = CS_TEAM_T;
			
		// If we have an enemy get his minimum distance to check against.
		float vecSegment[3];
		float vecTargetCenter[3];
		
		float flMinDist2 = 1100.0 * 1100.0;
		
		int pTargetCurrent = INVALID_ENT_REFERENCE;
		int pTargetOld = EntRefToEntIndex(m_hEnemy);
		
		float flOldTargetDist2 = 99999999999.0;
	
		// Sentries will try to target players first, then objects.  However, if the enemy held was an object it will continue
		// to try and attack it first.
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{	
			if(!IsClientInGame(iPlayer))
				continue;
		
			// Make sure the player is alive.
			if (!IsPlayerAlive(iPlayer))
				continue;
		
			if (GetEntityFlags(iPlayer) & FL_NOTARGET)
				continue;
				
			if(GetClientTeam(iPlayer) != iEnemyTeam)
				continue;
			
			vecTargetCenter = GetAbsOrigin(iPlayer);
			vecTargetCenter[2] += GetEntPropFloat(iPlayer, Prop_Send, "m_vecViewOffset[2]");
			
			SubtractVectors(vecTargetCenter, vecSentryOrigin, vecSegment);
			
			float flDist2 = GetVectorLength(vecSegment, true);

			// Store the current target distance if we come across it
			if (iPlayer == pTargetOld)
			{
				flOldTargetDist2 = flDist2;
			}
			
			// Check to see if the target is closer than the already validated target.
			if (flDist2 > flMinDist2)
				continue;
			
			// It is closer, check to see if the target is valid.
			if (this.ValidTargetPlayer(iPlayer, vecSentryOrigin, vecTargetCenter))
			{
				flMinDist2 = flDist2;
				pTargetCurrent = iPlayer;
			}
		}
		
		// If we already have a target, don't check objects.
		if (pTargetCurrent == INVALID_ENT_REFERENCE)
		{
			int iChicken = MAXPLAYERS + 1;
			while((iChicken = FindEntityByClassname(iChicken, "chicken")) != -1)
			{
				vecTargetCenter = EyePosition(iChicken);
				
				SubtractVectors( vecTargetCenter, vecSentryOrigin, vecSegment );
				
				float flDist2 = GetVectorLength(vecSegment, true);
	
				// Store the current target distance if we come across it
				if ( iChicken == pTargetOld )
				{
					flOldTargetDist2 = flDist2;
				}
	
				// Check to see if the target is closer than the already validated target.
				if ( flDist2 > flMinDist2 )
					continue;
	
				// It is closer, check to see if the target is valid.
				if ( this.ValidTargetPlayer( iChicken, vecSentryOrigin, vecTargetCenter ) )
				{
					flMinDist2 = flDist2;
					pTargetCurrent = iChicken;
				}
			}
		}
	
		// We have a target.
		if (pTargetCurrent != INVALID_ENT_REFERENCE)
		{
			if (pTargetCurrent != pTargetOld)
			{
				// flMinDist2 is the new target's distance
				// flOldTargetDist2 is the old target's distance
				// Don't switch unless the new target is closer by some percentage
				if (flMinDist2 < (flOldTargetDist2 * 0.75))
				{
					this.FoundTarget(pTargetCurrent, vecSentryOrigin);
				}
			}
			
			return true;
		}
	
		return false;
	}
	
	public bool MoveTurret()
	{
		bool bMoved = false;
		
		int iBaseTurnRate = this.GetBaseTurnRate();
		
		// any x movement?
		if (m_vecCurAngles[0] != m_vecGoalAngles[0])
		{
			float flDir = m_vecGoalAngles[0] > m_vecCurAngles[0] ? 1.0 : -1.0 ;
	
			m_vecCurAngles[0] += SENTRY_THINK_DELAY * (iBaseTurnRate * 5) * flDir;
	
			// if we started below the goal, and now we're past, peg to goal
			if (flDir == 1)
			{
				if (m_vecCurAngles[0] > m_vecGoalAngles[0])
					m_vecCurAngles[0] = m_vecGoalAngles[0];
			} 
			else
			{
				if (m_vecCurAngles[0] < m_vecGoalAngles[0])
					m_vecCurAngles[0] = m_vecGoalAngles[0];
			}
	
			this.SetPoseParameter(this.LookupPoseParameter("aim_pitch"), -50.0, 50.0, -m_vecCurAngles[0]);
			//this.SetPoseParameter(0, -50.0, 50.0, -m_vecCurAngles[0]);
			
			bMoved = true;
		}
		
		if (m_vecCurAngles[1] != m_vecGoalAngles[1])
		{
			float flDir = m_vecGoalAngles[1] > m_vecCurAngles[1] ? 1.0 : -1.0 ;
			float flDist = FloatAbs(m_vecGoalAngles[1] - m_vecCurAngles[1]);
			bool bReversed = false;
	
			if (flDist > 180)
			{
				flDist = 360 - flDist;
				flDir = -flDir;
				bReversed = true;
			}
	
			if (m_hEnemy == INVALID_ENT_REFERENCE)
			{
				if (flDist > 30)
				{
					if (m_flTurnRate < iBaseTurnRate * 10)
					{
						m_flTurnRate += iBaseTurnRate;
					}
				}
				else
				{
					// Slow down
					if (m_flTurnRate > (iBaseTurnRate * 5))
						m_flTurnRate -= iBaseTurnRate;
				}
			}
			else
			{
				// When tracking enemies, move faster and don't slow
				if (flDist > 30)
				{
					if (m_flTurnRate < iBaseTurnRate * 30)
					{
						m_flTurnRate += iBaseTurnRate * 3;
					}
				}
			}
	
			m_vecCurAngles[1] += SENTRY_THINK_DELAY * m_flTurnRate * flDir;
	
			// if we passed over the goal, peg right to it now
			if (flDir == -1)
			{
				if ((bReversed == false && m_vecGoalAngles[1] > m_vecCurAngles[1]) ||
					(bReversed == true  && m_vecGoalAngles[1] < m_vecCurAngles[1]))
				{
					m_vecCurAngles[1] = m_vecGoalAngles[1];
				}
			} 
			else
			{
				if ((bReversed == false && m_vecGoalAngles[1] < m_vecCurAngles[1]) ||
	                (bReversed == true  && m_vecGoalAngles[1] > m_vecCurAngles[1]))
				{
					m_vecCurAngles[1] = m_vecGoalAngles[1];
				}
			}
	
			if (m_vecCurAngles[1] < 0)
			{
				m_vecCurAngles[1] += 360;
			}
			else if (m_vecCurAngles[1] >= 360)
			{
				m_vecCurAngles[1] -= 360;
			}
	
			if (flDist < (SENTRY_THINK_DELAY * 0.5 * iBaseTurnRate))
			{
				m_vecCurAngles[1] = m_vecGoalAngles[1];
			}
	
			float angles[3]; angles = GetAbsAngles(this.index);
			
			float flYaw = AngleNormalize(m_vecCurAngles[1] - angles[1]);
			
			this.SetPoseParameter(this.LookupPoseParameter("aim_yaw"), -180.0, 180.0, -flYaw);
			//this.SetPoseParameter(1, -180.0, 180.0, -flYaw);
	
			bMoved = true;
		}
	
		if (!bMoved || m_flTurnRate <= 0)
		{
			m_flTurnRate = float(iBaseTurnRate * 5);
		}
	
		return bMoved;
	}
	
	//-----------------------------------------------------------------------------
	// Rotate and scan for targets
	//-----------------------------------------------------------------------------
	public void SentryRotate()
	{
		// if we're playing a fire gesture, stop it
		if (this.IsPlayingGesture("ACT_RANGE_ATTACK1"))
		{
			this.RemoveGesture("ACT_RANGE_ATTACK1");
		}
	
		if (this.IsPlayingGesture("ACT_RANGE_ATTACK1_LOW"))
		{
			this.RemoveGesture("ACT_RANGE_ATTACK1_LOW");
		}
	
		// Look for a target
		if (this.FindTarget())
		{
			return;
		}
	
		// Rotate
		if (!this.MoveTurret())
		{
			// Change direction
	
			switch(m_iUpgradeLevel)
			{
				case 1: EmitAmbientSoundAny("sentrymp3/sentry_scan.mp3", WorldSpaceCenter(this.index));
				case 2: EmitAmbientSoundAny("sentrymp3/sentry_scan2.mp3", WorldSpaceCenter(this.index));
				case 3: EmitAmbientSoundAny("sentrymp3/sentry_scan3.mp3", WorldSpaceCenter(this.index));
			}
	
			// Switch rotation direction
			if (m_bTurningRight)
			{
				m_bTurningRight = false;
				m_vecGoalAngles[1] = float(m_iLeftBound);
			}
			else
			{
				m_bTurningRight = true;
				m_vecGoalAngles[1] = float(m_iRightBound);
			}

			// Randomly look up and down a bit
			if (GetRandomFloat(0.0, 1.0) < 0.3)
			{
				m_vecGoalAngles[0] = float(RoundToNearest(GetRandomFloat(-10.0, 10.0)));
			}
		}
	}
	
	//-----------------------------------------------------------------------------
	// Fire on our target
	//-----------------------------------------------------------------------------
	public bool Fire()
	{
		//NDebugOverlay::Cross3D( m_hEnemy->WorldSpaceCenter(), 10, 255, 0, 0, false, 0.1 );
	
		float vecAimDir[3];
	
		// Level 3 Turrets fire rockets every 3 seconds
		if ( m_iUpgradeLevel == 3 && m_iAmmoRockets > 0 && m_flNextRocketAttack < GetGameTime())
		{
			float vecSrc[3];
			float vecAng[3];
	
			// alternate between the 2 rocket launcher ports.
			if ( m_iAmmoRockets & 1 ) {
				this.GetAttachment( "rocket_l", vecSrc, vecAng );
			} else {
				this.GetAttachment( "rocket_r", vecSrc, vecAng );
			}
	
			SubtractVectors(WorldSpaceCenter(EntRefToEntIndex(m_hEnemy)), vecSrc, vecAimDir);
			NormalizeVector(vecAimDir, vecAimDir);
	
			// NOTE: vecAng is not actually set by GetAttachment!!!
			float angDir[3];
			GetVectorAngles( vecAimDir, angDir );
	
			EmitAmbientSoundAny("sentrymp3/sentry_rocket.mp3", WorldSpaceCenter(this.index));
			
			this.AddGesture("ACT_RANGE_ATTACK2");
		
			float angAimDir[3];
			GetVectorAngles( vecAimDir, angAimDir );
			
			this.SentryRocketCreate(vecSrc, angAimDir);
	
			// Setup next rocket shot
			m_flNextRocketAttack = GetGameTime() + 3;
	
			m_iAmmoRockets--;
		}
	
		// All turrets fire shells
		if ( m_iAmmoShells > 0)
		{
			if (!this.IsPlayingGesture("ACT_RANGE_ATTACK1"))
			{
				this.RemoveGesture("ACT_RANGE_ATTACK1_LOW");
				this.AddGesture("ACT_RANGE_ATTACK1");
			}
	
			float vecSrc[3];
			float vecAng[3];
	
			if ( m_iUpgradeLevel > 1 )
			{
				// level 2 and 3 turrets alternate muzzles each time they fizzy fizzy fire.
				if(m_iAmmoShells & 1)
				{
					this.GetAttachment( "muzzle_l", vecSrc, vecAng );
				}
				else
				{
					switch( m_iUpgradeLevel )
					{
						case 1:	EmitAmbientSoundAny("sentrymp3/sentry_shoot.mp3", WorldSpaceCenter(this.index));
						case 2: EmitAmbientSoundAny("sentrymp3/sentry_shoot2.mp3", WorldSpaceCenter(this.index));
						case 3: EmitAmbientSoundAny("sentrymp3/sentry_shoot3.mp3", WorldSpaceCenter(this.index));
					}
	
					this.GetAttachment( "muzzle_r", vecSrc, vecAng );					
				}
			}
			else
			{
				switch( m_iUpgradeLevel )
				{
					case 1:	EmitAmbientSoundAny("sentrymp3/sentry_shoot.mp3", WorldSpaceCenter(this.index));
					case 2: EmitAmbientSoundAny("sentrymp3/sentry_shoot2.mp3", WorldSpaceCenter(this.index));
					case 3: EmitAmbientSoundAny("sentrymp3/sentry_shoot3.mp3", WorldSpaceCenter(this.index));
				}
			
				this.GetAttachment( "muzzle", vecSrc, vecAng );
			}
	
			float vecMidEnemy[3]; 
			this.SelectTargetPoint(vecSrc, vecMidEnemy); // WorldSpaceCenter(EntRefToEntIndex(m_hEnemy));
	
			SubtractVectors(vecMidEnemy, vecSrc, vecAimDir);
			float flDistToTarget = GetVectorLength(vecAimDir);
			NormalizeVector(vecAimDir, vecAimDir);
			
			//CS:GO Away
			//PrecacheParticleEffect("weapon_tracers_50cal");
			FireBullet(this.index, this.GetOwner(), vecSrc, vecAimDir, 16.0, flDistToTarget * 500, DMG_BULLET, "weapon_tracers_50cal");
			
			// Muzzle flash
			TE_DispatchEffect("weapon_muzzle_flash_awp", vecSrc, vecSrc, vecAng);
			TE_SendToAll();
			
			m_iAmmoShells--;
		}
		else
		{
			if (m_iUpgradeLevel > 1)
			{
				if (!this.IsPlayingGesture("ACT_RANGE_ATTACK1_LOW"))
				{
					this.RemoveGesture("ACT_RANGE_ATTACK1");
					this.AddGesture("ACT_RANGE_ATTACK1_LOW");
				}
			}
	
			// Out of ammo, play a click
			EmitAmbientSoundAny("sentrymp3/sentry_empty.mp3", WorldSpaceCenter(this.index));
			m_flNextAttack = GetGameTime() + 0.2;
		}
	
		return true;
	}

	//-----------------------------------------------------------------------------
	// Make sure our target is still valid, and if so, fire at it
	//-----------------------------------------------------------------------------
	public void Attack()
	{
		if (!this.FindTarget())
		{
			#if defined DEBUG
			PrintToServer("Attack() No target");
			#endif
			m_iState = SENTRY_STATE_SEARCHING;
			m_hEnemy = INVALID_ENT_REFERENCE;
			return;
		}
	
		// Track enemy
		float vecMid[3];      vecMid      = WorldSpaceCenter(this.index);
		float vecMidEnemy[3];
		this.SelectTargetPoint(vecMid, vecMidEnemy); //WorldSpaceCenter(EntRefToEntIndex(m_hEnemy));
		
		float vecDirToEnemy[3];
		SubtractVectors(vecMidEnemy, vecMid, vecDirToEnemy);
	
		float angToTarget[3];
		GetVectorAngles(vecDirToEnemy, angToTarget);
	
		angToTarget[1] = UTIL_AngleMod(angToTarget[1]);
		if (angToTarget[0] < -180)
			angToTarget[0] += 360;
		if (angToTarget[0] > 180)
			angToTarget[0] -= 360;
	
		// now all numbers should be in [1...360]
		// pin to turret limitations to [-50...50]
		if (angToTarget[0] > 50)
			angToTarget[0] = 50.0;
		else if (angToTarget[0] < -50)
			angToTarget[0] = -50.0;
			
		m_vecGoalAngles[1] = angToTarget[1];
		m_vecGoalAngles[0] = angToTarget[0];
	
		this.MoveTurret();
		
		float subtracted[3];
		SubtractVectors(m_vecGoalAngles, m_vecCurAngles, subtracted);
		
		// Fire on the target if it's within 10 units of being aimed right at it
		if ( m_flNextAttack <= GetGameTime() && GetVectorLength(subtracted) <= 10 )
		{
			this.Fire();
		
			if ( m_iUpgradeLevel == 1 )
			{
				// Level 1 sentries fire slower
				m_flNextAttack = GetGameTime() + 0.2;
			}
			else
			{
				m_flNextAttack = GetGameTime() + 0.1;
			}
		}
		
		if(GetVectorLength(subtracted) > 10)
		{
			// if we're playing a fire gesture, stop it
			if (this.IsPlayingGesture("ACT_RANGE_ATTACK1"))
			{
				this.RemoveGesture("ACT_RANGE_ATTACK1");
			}
		}
	}
}

public Action Command_Sentry(int client, int argc)
{
	if(client <= 0 || client > MaxClients && !IsClientInGame(client))
		return Plugin_Handled;
		
	SentryGun(client, GetAbsOrigin(client), GetAbsAngles(client), GetRandomInt(1, 3));
	
	return Plugin_Handled;
}

public void OnSentryThink(int entity, int client)
{
	static int iThinkWhenClient = 1;
	
	//This bad code ensures that we don't think any more than we should
	if(!IsClientInGame(iThinkWhenClient)) {
		iThinkWhenClient = client;
	}
	
	if(iThinkWhenClient != client) {
		return;
	}
	
	// animate
	SDKCall(g_hStudioFrameAdvance, entity);
	
	SentryGun sentry = view_as<SentryGun>(entity);
	
	switch( m_iState )
	{
		case SENTRY_STATE_SEARCHING: sentry.SentryRotate();
		case SENTRY_STATE_ATTACKING: sentry.Attack();
		//case SENTRY_STATE_UPGRADING: sentry.UpgradeThink();
	}
}

//TODO
// Trace between position before setting new origin and new origin to not miss anything
public void OnRocketThink(int entity, int client)
{
	static int iThinkWhenClient = 1;
	
	//This bad code ensures that we don't think any more than we should
	if(!IsClientInGame(iThinkWhenClient)) {
		iThinkWhenClient = client;
	}
	
	if(iThinkWhenClient != client) {
		return;
	}

	float ang[3]; ang = GetAbsAngles(entity);
	float pos[3]; pos = GetAbsOrigin(entity);
	
	float vForward[3];
	GetAngleVectors(ang, vForward, NULL_VECTOR, NULL_VECTOR);
	
	pos[0] += vForward[0] * 5.0;
	pos[1] += vForward[1] * 5.0;
	pos[2] += vForward[2] * 5.0;
	
	SDKCall(g_hStudioFrameAdvance, entity);
	
	DispatchKeyValueVector(entity, "origin", pos);
}

//Mine now TriHard https://github.com/Rachnus/Small-SourceMod-Plugins/blob/master/explodedroppedgrenades.sp#L63
void CS_CreateExplosion(int client, int damage, int radius, float pos[3])
{
	int entity;
	if((entity = CreateEntityByName("env_explosion")) != -1)
	{
		//DispatchKeyValue(entity, "spawnflags", "552");
		DispatchKeyValue(entity, "rendermode", "5");
		SetEntProp(entity, Prop_Data, "m_iMagnitude", damage);
		SetEntProp(entity, Prop_Data, "m_iRadiusOverride", radius);
		SetEntProp(entity, Prop_Data, "m_iTeamNum", GetClientTeam(client));
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);

		DispatchSpawn(entity);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		EmitAmbientSound("weapons/hegrenade/explode4.wav", pos, entity);
		RequestFrame(TriggerExplosion, entity);
	}
}

public void TriggerExplosion(int entity)
{
	AcceptEntityInput(entity, "explode");
	AcceptEntityInput(entity, "Kill");
}

public void OnRocketTouch(int entity, int other)
{	
	char class[64]; GetEntityClassname(other, class, sizeof(class));
	
	float flSpawnTime = GetGameTime() - GetEntPropFloat(entity, Prop_Data, "m_flNextDodgeTime");
	if( flSpawnTime < 0.05 && !StrEqual(class, "player"))
		return;
	
	float pos[3]; pos = GetAbsOrigin(entity);
	CS_CreateExplosion(view_as<SentryGun>(entity).GetOwner(), 100, 150, pos);
	
	#if defined DEBUG
	PrintToChatAll("Rocket touch %s %i", class, other);
	#endif
	
	AcceptEntityInput(entity, "Kill");
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] EyePosition(int ent)
{
	float v[3]; v = GetAbsOrigin(ent);
	
	if (HasEntProp(ent, Prop_Send, "m_vDefaultEyeOffset"))
	{
		switch(m_iUpgradeLevel)
		{
			case 1: v[2] += SENTRYGUN_EYE_OFFSET_LEVEL_1;
			case 2: v[2] += SENTRYGUN_EYE_OFFSET_LEVEL_2;
			case 3: v[2] += SENTRYGUN_EYE_OFFSET_LEVEL_3;
		}
	}
	else
	{
		float max[3];
		GetEntPropVector(ent, Prop_Data, "m_vecMaxs", max);
		v[2] += max[2];
	}

	return v;
}

stock float[] WorldSpaceCenter(int ent)
{
	float v[3]; v = GetAbsOrigin(ent);
	
	float max[3];
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", max);
	v[2] += max[2] / 2;
	
	return v;
}

stock float[] GetAbsAngles(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", v);
	
	return v;
}

stock float[] GetEyeAngles(int client)
{
	float v[3];
	GetClientEyeAngles(client, v);
	return v;
}

public float UTIL_AngleMod(float a)
{
	a = (360.0 / 65536) * (RoundToNearest(a * (65536.0 / 360.0)) & 65535);
	return a;
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

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
}

stock float operator%(float oper1, float oper2)
{
	return fmodf(oper1, oper2);
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "monster_generic"))
	{
		return false;
	}

	return !(entity == iExclude);
}

stock void FireBullet(int m_pAttacker, int m_pDamager, float m_vecSrc[3], float m_vecDirShooting[3], float m_flDamage, float m_flDistance, int nDamageType, const char[] tracerEffect)
{
	float vecEnd[3];
	vecEnd[0] = m_vecSrc[0] + m_vecDirShooting[0] * m_flDistance; 
	vecEnd[1] = m_vecSrc[1] + m_vecDirShooting[1] * m_flDistance;
	vecEnd[2] = m_vecSrc[2] + m_vecDirShooting[2] * m_flDistance;
	
	// Fire a bullet (ignoring the shooter).
	Handle trace = TR_TraceRayFilterEx(m_vecSrc, vecEnd, ( MASK_SOLID | CONTENTS_HITBOX ), RayType_EndPoint, AimTargetFilter, m_pAttacker);

	if ( TR_GetFraction(trace) < 1.0 )
	{
		// Verify we have an entity at the point of impact.
		if(TR_GetEntityIndex(trace) == -1)
		{
			delete trace;
			return;
		}
		
		float endpos[3]; TR_GetEndPosition(endpos, trace);
		SDKHooks_TakeDamage(TR_GetEntityIndex(trace), m_pAttacker, m_pDamager, m_flDamage, nDamageType, m_pAttacker, CalculateBulletDamageForce(m_vecDirShooting, 1.0), endpos);
		
		// Sentryguns are perfectly accurate, but this doesn't look good for tracers.
		// Add a little noise to them, but not enough so that it looks like they're missing.
		endpos[0] += GetRandomFloat(-10.0, 10.0);
		endpos[1] += GetRandomFloat(-10.0, 10.0);
		endpos[2] += GetRandomFloat(-10.0, 10.0);
		
		// Bullet tracer
		TE_DispatchEffect(tracerEffect, endpos, m_vecSrc, NULL_VECTOR);
		TE_SendToAll();
		
		float vecNormal[3];	TR_GetPlaneNormal(trace, vecNormal);
		GetVectorAngles(vecNormal, vecNormal);
		
		if(TR_GetEntityIndex(trace) <= 0 || TR_GetEntityIndex(trace) > MaxClients)
		{
			//Can't get surface properties from traces unfortunately.
			//Just another shortsighting from the SM devs :///
			TE_DispatchEffect("impact_dirt", endpos, endpos, vecNormal);
			TE_SendToAll();
			
			TE_Start("Impact");
			TE_WriteVector("m_vecOrigin", endpos);
			TE_WriteVector("m_vecNormal", vecNormal);
			TE_WriteNum("m_iType", GetRandomInt(1, 10));
			TE_SendToAll();
		}
		else if(TR_GetEntityIndex(trace) > 0 && TR_GetEntityIndex(trace) <= MaxClients)
		{
			TE_DispatchEffect("blood_impact_heavy", endpos, endpos, vecNormal);
			TE_SendToAll();
		}
	}
	
	delete trace;
}

float[] CalculateBulletDamageForce( const float vecBulletDir[3], float flScale )
{
	float vecForce[3]; vecForce = vecBulletDir;
	NormalizeVector( vecForce, vecForce );
	ScaleVector(vecForce, FindConVar("phys_pushscale").FloatValue);
	ScaleVector(vecForce, flScale);
	return vecForce;
}

stock bool IsPlayer(int entity)
{
	return (entity > 0 && entity <= MaxClients);
}

//Thanks Chaosxk
//https://github.com/xcalvinsz/zeustracerbullets/blob/master/addons/sourcemod/scripting/zeustracers.sp
void TE_DispatchEffect(const char[] particle, const float pos[3], const float endpos[3], const float angles[3] = NULL_VECTOR, int attachment = -1)
{
	TE_Start("EffectDispatch");
	TE_WriteFloat("m_vStart.x", pos[0]);
	TE_WriteFloat("m_vStart.y", pos[1]);
	TE_WriteFloat("m_vStart.z", pos[2]);
	TE_WriteFloat("m_vOrigin.x", endpos[0]);
	TE_WriteFloat("m_vOrigin.y", endpos[1]);
	TE_WriteFloat("m_vOrigin.z", endpos[2]);
	TE_WriteVector("m_vAngles", angles);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(particle));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	
	if(attachment != -1)
	{
		TE_WriteNum("m_nAttachmentIndex", attachment);
	}
}

void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");
		
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");
		
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}
