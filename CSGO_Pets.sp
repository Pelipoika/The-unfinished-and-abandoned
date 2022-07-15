#pragma semicolon 1

#include <sourcemod>
#include <vscriptfun>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[CSGO] Pets",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = ""
};

Handle g_hLookupSequence;
Handle g_hFollow;

Address TheNavAreas;
Address navarea_count;

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("csgo.sentry");
	
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
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CChicken::Follow");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWWORLD);
	if ((g_hFollow = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CChicken::Follow signature!");
	
	delete hConf;
	
	HookUserMessage(GetUserMessageId("TextMsg"), UserMessagesHook, true);
	
	RegAdminCmd("sm_pet", Command_Sentry, ADMFLAG_ROOT);
}

char s_Pokemen[][] = 
{
	"models/rtbmodels/pokemon/arcanine.mdl",
	"models/rtbmodels/pokemon/glaceon.mdl",
	"models/rtbmodels/pokemon/jolteon.mdl",
	"models/rtbmodels/pokemon/umbreon.mdl",
	"models/rtbmodels/pokemon/vaporeon.mdl"
};

/*
	Chicken + 0x730 = CCSNavPath
*/

public void OnMapStart()
{
	Handle hConf = LoadGameConfigFile("csgo.sentry");
	
	navarea_count = GameConfGetAddress(hConf, "navarea_count");
	PrintToServer("navarea_count @ 0x%X", navarea_count);
	
	TheNavAreas = view_as<Address>(LoadFromAddress(navarea_count + view_as<Address>(0x4), NumberType_Int32));
	PrintToServer("TheNavAreas @ 0x%X", TheNavAreas);
	
	delete hConf;

	for (int i = 0; i < sizeof(s_Pokemen); i++)
	{
		PrecacheModel(s_Pokemen[i]);
	}
}

public Action UserMessagesHook(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (reliable)
	{
		char params[PLATFORM_MAX_PATH];
		PbReadString(msg, "params", params, sizeof(params), 0);
		
		if (StrEqual(params, "#Pet_Killed"))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}  

public Action Command_Sentry(int client, int argc)
{
	if(client < 0 || client > MaxClients && !IsClientInGame(client))
		return Plugin_Handled;

	int iAreaCount = LoadFromAddress(navarea_count, NumberType_Int32);

	int iSpawnCount = 0;

	if ( iAreaCount > 0 )
	{
		for (int i = 0; i <= 10; i++)
		{
			Address RandomArea = view_as<Address>(LoadFromAddress(TheNavAreas + view_as<Address>(4 * GetRandomInt(0, iAreaCount - 1)), NumberType_Int32));
			
			float m_nwCorner[3];
			m_nwCorner[0] = view_as<float>(LoadFromAddress(RandomArea + view_as<Address>(4), NumberType_Int32));
			m_nwCorner[1] = view_as<float>(LoadFromAddress(RandomArea + view_as<Address>(8), NumberType_Int32));
			m_nwCorner[2] = view_as<float>(LoadFromAddress(RandomArea + view_as<Address>(12), NumberType_Int32));
			
			float m_seCorner[3];
			m_seCorner[0] = view_as<float>(LoadFromAddress(RandomArea + view_as<Address>(16), NumberType_Int32));
			m_seCorner[1] = view_as<float>(LoadFromAddress(RandomArea + view_as<Address>(20), NumberType_Int32));
			m_seCorner[2] = view_as<float>(LoadFromAddress(RandomArea + view_as<Address>(24), NumberType_Int32));
			
			//Check that the area is bigger than 50 units wide on both sides.
			if((m_seCorner[0] - m_nwCorner[0]) <= 50.0)
				continue;
			
			if((m_seCorner[1] - m_nwCorner[1]) <= 50.0)
				continue;
			
			float vecPos[3];
			AddVectors(m_nwCorner, m_seCorner, vecPos);
			ScaleVector(vecPos, 0.5);
			
			if(UTIL_IsVisibleToTeam(vecPos, 2))
				continue;
				
			if(UTIL_IsVisibleToTeam(vecPos, 3))
				continue;
			
			CreateNPC(client, vecPos);
			iSpawnCount++;
		}
	}
	
	ReplyToCommand(client, "Spawned %i Pokemon", iSpawnCount);
	
	return Plugin_Handled;
}

stock bool UTIL_IsVisibleToTeam(float vecPos[3], int team)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(!IsPlayerAlive(i))
			continue;
			
		if(GetClientTeam(i) != team)
			continue;
		
		if(!IsLineOfFireClear(vecPos, GetEyePosition(i)))
			continue;
			
		return true;
	}
	
	return false;
}

stock bool IsLineOfFireClear(float from[3], float to[3])
{
	Handle trace = TR_TraceRayFilterEx(from, to, CONTENTS_SOLID|CONTENTS_MOVEABLE|0x40|CONTENTS_MONSTER, RayType_EndPoint, FilterPlayers);
	
	float flFraction = TR_GetFraction(trace);
	
	delete trace;
	
	if (flFraction >= 1.0/* && !trace.allsolid*/) 
	{
		return !(flFraction == 0.0);	//allsolid
	}
	
	return false;
}

public bool FilterPlayers(int entity, int contentsMask, any iExclude)
{
	return !(entity > 0 && entity <= MaxClients);
}

stock void CreateNPC(int client, float vecPos[3])
{
	int ent = CreateEntityByName("chicken");
	DispatchKeyValueVector(ent, "origin", vecPos);
	//DispatchKeyValue(ent, "modelscale", "0.5");
	DispatchSpawn(ent);
	
	SetEntProp(ent, Prop_Data, "m_takedamage", 0);
	
	//SetEntProp(ent, Prop_Send, "m_nSolidType", 0);
	//SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
	
	SetEntityModel(ent, s_Pokemen[GetRandomInt(0, sizeof(s_Pokemen) - 1)]);
	
	SDKHook(ent, SDKHook_Touch, OnChickenTouch);
	
	//TODO DELETE
	SDKHook(ent, SDKHook_ThinkPost, OnChickenThinkPos);
	
	SDKCall(g_hFollow, ent, client);
	
	//Fix collisions
	SetEntPropVector(ent, Prop_Send, "m_vecMaxs", view_as<float>( { 16.0, 16.0, 32.0 } ));
	SetEntPropVector(ent, Prop_Data, "m_vecMaxs", view_as<float>( { 16.0, 16.0, 32.0 } ));
	
	SetEntPropVector(ent, Prop_Send, "m_vecMins", view_as<float>( { -16.0, -16.0, 0.0 } ));
	SetEntPropVector(ent, Prop_Data, "m_vecMins", view_as<float>( { -16.0, -16.0, 0.0 } ));
}

enum //PokeBallState
{
	NONE,
	GOING_UP,
	CATCHING
}

enum //Segment?
{
	Segment_Pointer = 0, //0x00
	Segment_unkInt = 4, //0x04
	Segment_x = 8, //0x08
	Segment_y = 12, //0x0C
	Segment_z = 16, //0x10
	Segment_unkInt0 = 18, //0x14
	
	Segmet_SIZE = 24
} //Size 0x18

public void OnChickenThinkPos(int entity)
{
	Address CCSNavPath = GetEntityAddress(entity) + view_as<Address>(0x730);
	int iNumSegments = LoadFromAddress(CCSNavPath + view_as<Address>(0x1800), NumberType_Int32);

	PrintToServer("%X iNumSegments %i", CCSNavPath, iNumSegments);

	if(iNumSegments < 0)
		return;
	
	int i = 1;
	
	do
	{
		Address segment = CCSNavPath + view_as<Address>(Segmet_SIZE * i);
	
		StoreToAddress(segment + view_as<Address>(Segment_unkInt), 9, NumberType_Int32);

		float vecSegment[3];
		vecSegment[0] = view_as<float>(LoadFromAddress(segment + view_as<Address>(Segment_x), NumberType_Int32));
		vecSegment[1] = view_as<float>(LoadFromAddress(segment + view_as<Address>(Segment_y), NumberType_Int32));
		vecSegment[2] = view_as<float>(LoadFromAddress(segment + view_as<Address>(Segment_z), NumberType_Int32)) + 35.5;
		
		segment = CCSNavPath + view_as<Address>(Segmet_SIZE * ++i);
		
		float vecNextSegment[3];
		vecNextSegment[0] = view_as<float>(LoadFromAddress(segment + view_as<Address>(Segment_x), NumberType_Int32));
		vecNextSegment[1] = view_as<float>(LoadFromAddress(segment + view_as<Address>(Segment_y), NumberType_Int32));
		vecNextSegment[2] = view_as<float>(LoadFromAddress(segment + view_as<Address>(Segment_z), NumberType_Int32)) + 35.5;
		
		//Draw line from segment to segment
		VSF.DebugDrawLine(vecSegment, vecNextSegment, 255, 0, 0, true, 0.1);
		
		
		//Draw a pole at each segment
		vecSegment[2] -= 35.5;
		VSF.DebugDrawBox(vecSegment, view_as<float>({ -1.0, -1.0, 0.0 }), view_as<float>({ 2.0, 2.0, 35.5 }), 0, 255, 0, 50, 0.1);
	}
	while (iNumSegments - 1 > i);
}

public Action OnChickenTouch(int entity, int other)
{
	char class[64];
	GetEntityClassname(other, class, sizeof(class));
	
	if(StrEqual(class, "hegrenade_projectile"))
	{
		//Stop lookin for grenades that hit me.
		SDKUnhook(entity, SDKHook_Touch, OnChickenTouch);
	
		//Set detonate time on grenade that hit us
		SetEntDataFloat(other, FindSendPropInfo("CBaseCSGrenadeProjectile", "m_hThrower") + 36, GetGameTime() + 10.0, true);
		
		//Store grenade into the pokemon.
		SetEntPropEnt(entity, Prop_Data, "m_hEffectEntity", other);
		
		//Stuff for keeping track of the grenade once its in hair to know when to start scaling.
		SetEntProp(other, Prop_Data, "m_nBody", NONE);
		
		//Pokeman and Pokeball scaling
		SDKHook(entity, SDKHook_Think, OnChickenThinkDoScale);
		
		//Disable collisions on the nade
		SetEntProp(other, Prop_Send, "m_nSolidType", 0);
		SetEntProp(other, Prop_Data, "m_nSolidType", 0);
		
		//Stop grenade movement
		//SetEntityMoveType(other, MOVETYPE_NONE);
		
		//Stop pokemon movement
		//SDKCall(g_hFollow, entity, 0);
	}

	return Plugin_Continue;
}

public void OnChickenThinkDoScale(int chicken)
{
	int grenade = GetEntPropEnt(chicken, Prop_Data, "m_hEffectEntity");
	if(grenade <= 0)
	{
		//Abort, no grenade to scale with.
		SDKUnhook(chicken, SDKHook_Think, OnChickenThinkDoScale);
		return;
	}
	
	//Set ideal activity to 1 (IDLE)
	SetEntData(chicken, 1732, 1, _, true);
	SetEntProp(chicken, Prop_Send, "m_nSequence", 1);
	SetEntProp(chicken, Prop_Data, "m_nSequence", 1);
	
	//Stop chicken from moving while getting sucked off
	//SetEntPropFloat(chicken, Prop_Data, "m_flGroundSpeed", 0.0);
	
	//SetEntPropFloat(chicken, Prop_Send, "m_flPlaybackRate", 0.0);
	//SetEntPropFloat(chicken, Prop_Data, "m_flPlaybackRate", 0.0);
	
	//Get velocity for state tracking
	float vecVelocity[3];
	GetEntPropVector(grenade, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	
	int iState = GetEntProp(grenade, Prop_Data, "m_nBody");
	if(iState == NONE)
	{
		//Throw nade backwards and up
		NegateVector(vecVelocity);
		NormalizeVector(vecVelocity, vecVelocity);
		
		ScaleVector(vecVelocity, 100.0);
		
		vecVelocity[2] = 150.0;
		
		TeleportEntity(grenade, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		
		SetEntProp(grenade, Prop_Data, "m_nBody", GOING_UP);
		
		return;
	}
	else if(iState == GOING_UP)
	{
		//Track the nade for when it starts falling down (negative z velocity)		
		if(vecVelocity[2] > 0.0)
			return;
		
		SetEntProp(grenade, Prop_Data, "m_nBody", CATCHING);
		
		//Stop grenade movement at peak velocity.
		SetEntityMoveType(grenade, MOVETYPE_NONE);
		
		return;
	}

	float flPokemonScale = GetEntPropFloat(chicken, Prop_Send, "m_flModelScale");
	float flGrenadeScale = GetEntPropFloat(grenade, Prop_Send, "m_flModelScale");
	
	flPokemonScale -= 0.02;
	flGrenadeScale += 0.05;
	
	if(flPokemonScale <= 0.1)
	{
		//Remove Pokemon
		AcceptEntityInput(chicken, "Kill");
		
		//Let grenade fall
		SetEntityMoveType(grenade, MOVETYPE_FLYGRAVITY);
	}
	
	SetEntPropFloat(chicken, Prop_Send, "m_flModelScale", flPokemonScale);
	SetEntPropFloat(grenade, Prop_Send, "m_flModelScale", flGrenadeScale);
}

stock void SetSequence(int entity, int nSequence)
{
	SetEntProp(entity, Prop_Send, "m_nSequence", nSequence);
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

stock float[] GetEyeAngles(int client)
{
	float v[3];
	GetClientEyeAngles(client, v);
	return v;
}

stock float[] GetEyePosition(int client)
{
	float v[3];
	GetClientEyePosition(client, v);
	return v;
}

public Action OnChickenUse(int entity, int activator, int caller, UseType type, float value)
{
	return Plugin_Handled;
}
