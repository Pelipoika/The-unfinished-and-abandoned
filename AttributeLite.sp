#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

enum ParticleAttachment
{
	PATTACH_ABSORIGIN = 0,			// Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,		// Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,			// Create at a custom origin, but don't follow
	PATTACH_POINT,					// Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW,			// Create on attachment point, and update to follow the entity
	PATTACH_WORLDORIGIN,			// Used for control points that don't attach to an entity
	PATTACH_ROOTBONE_FOLLOW,		// Create at the root bone of the entity, and update to follow
	MAX_PATTACH_TYPES,
};

public Plugin myinfo = 
{
	name = "[TF2] TF2Attributes Bootleg Edition",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

Handle g_hAddCustomAttribute;
Handle g_hRemoveCustomAttribute;
Handle g_hGetItemSchema;
Handle g_hGetAttributeDefinitionByName;

Handle g_hDispatchParticleEffect;
Handle g_hStopParticleEffects;

public void OnPluginStart()
{
	RegAdminCmd("addparticle",     Command_AddParticle,    ADMFLAG_BAN, "");
	RegAdminCmd("removeparticles", Command_RemoveParticle, ADMFLAG_BAN, "Remove all particles");
	
	RegAdminCmd("addattribute",    Command_Add,    ADMFLAG_BAN, "addattribute <attribute> <value> <duration>");
	RegAdminCmd("removeattribute", Command_Remove, ADMFLAG_BAN, "removeattribute <attribute>");
	
	//DispatchParticleEffect(const char *pszParticleName, ParticleAttachment_t iAttachType, CBaseEntity *pEntity, const char *pszAttachmentName, bool bResetAllParticlesOnEntity)
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x8B\x75\x10\x57\x83\xCF\xFF", 11);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszParticleName
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//iAttachType
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//pEntity
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//pszAttachmentName
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//bResetAllParticlesOnEntity 
	if ((g_hDispatchParticleEffect = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for DispatchParticleEffect signature!");
	
	//StopParticleEffects(CBaseEntity)
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x81\xEC\xAC\x00\x00\x00\x8D\x8D\x54\xFF\xFF\xFF", 15);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	//pEntity
	if ((g_hStopParticleEffects = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for StopParticleEffects signature!");
	
	//CTFPlayer::AddCustomAttribute(const char* attribute) returns "char" for some reason
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\xF3\x0F\x10\x4D\x10\x83\xEC\x10", 11);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);	//strAttribute
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);		//flValue
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);		//flDuration
	if ((g_hAddCustomAttribute = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFPlayer::AddCustomAttribute signature!"); 
	
	//CTFPlayer::RemoveCustomAttribute(const char* attribute) returns CEconItemAttributeDefinition for some reason
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x10\x53\x56\x57\xFF\x75\x08", 12);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);	//strAttribute
	if ((g_hRemoveCustomAttribute = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CTFPlayer::RemoveCustomAttribute signature!"); 
	
	//GetItemSchema()
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\xE8\x2A\x2A\x2A\x2A\x83\xC0\x04\xC3", 9);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemSchema
	if ((g_hGetItemSchema = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetItemSchema signature!"); 	
	
	//CEconItemSchema::GetAttributeDefinitionByName(const char* name)
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x18\x83\x7D\x08\x00\x53\x56\x57\x8B\xD9\x75\x2A\x33\xC0\x5F", 20);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemAttributeDefinition
	if ((g_hGetAttributeDefinitionByName = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CEconItemSchema::GetAttributeDefinitionByName signature!"); 		
}

public Action Command_AddParticle(int client, int args)
{
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	char pszParticleName[PLATFORM_MAX_PATH], strAttachType[8], pszAttachmentName[PLATFORM_MAX_PATH], strResetParticles[8], strEntity[8];
	
	GetCmdArg(1, pszParticleName,   sizeof(pszParticleName));
	GetCmdArg(2, strAttachType,     sizeof(strAttachType));
	GetCmdArg(3, pszAttachmentName, sizeof(pszAttachmentName));
	GetCmdArg(4, strResetParticles, sizeof(strResetParticles));
	GetCmdArg(5, strEntity,         sizeof(strEntity));
	
	bool bResetAllParticlesOnEntity = !!StringToInt(strResetParticles);
	ParticleAttachment iAttachType  = view_as<ParticleAttachment>(StringToInt(strAttachType));
	int iEntity = StringToInt(strEntity);
	
	DispatchParticleEffect(pszParticleName, iAttachType, iEntity == 0 ? client : iEntity, pszAttachmentName, bResetAllParticlesOnEntity);
	ReplyToCommand(client, "Dispatched particle \"%s\" with attachment type \"%i\" on attachment \"%s\" with bResetAllParticlesOnEntity as \"%i\"", pszParticleName, iAttachType, pszAttachmentName, bResetAllParticlesOnEntity);
	
	return Plugin_Handled;
}

public Action Command_RemoveParticle(int client, int args)
{
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	StopParticleEffects(client);
	ReplyToCommand(client, "Stopped all particle effects on you.");
	
	return Plugin_Handled;
}

public Action Command_Add(int client, int args)
{
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: addattribute <attribute> <value> <duration>");
		return Plugin_Handled;	
	}
	
	char strAttrib[64], strDuration[8], strValue[8];
	
	GetCmdArg(1, strAttrib,   sizeof(strAttrib));
	GetCmdArg(2, strValue,    sizeof(strValue));
	GetCmdArg(3, strDuration, sizeof(strDuration));
	
	float flDuration = StringToFloat(strDuration);
	float flValue    = StringToFloat(strValue);
	
	if(!TF2_IsValidAttribute(strAttrib))
	{
		ReplyToCommand(client, "Invalid attribute name \"%s\"", strAttrib);
		return Plugin_Handled;	
	}
	
	TF2_AddAttribute(client, strAttrib, flValue, flDuration);
	ReplyToCommand(client, "Added attribute \"%s\" with value \"%.2f\" for \"%.2f\" seconds", strAttrib, flValue, flDuration);
	
	return Plugin_Handled;
}

public Action Command_Remove(int client, int args)
{
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
	
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: addattribute <attribute>");
		return Plugin_Handled;	
	}
	
	char strAttrib[64];
	GetCmdArg(1, strAttrib, sizeof(strAttrib));
	
	if(!TF2_IsValidAttribute(strAttrib))
	{
		ReplyToCommand(client, "Invalid attribute name \"%s\"", strAttrib);
		return Plugin_Handled;	
	}
	
	TF2_RemoveAttribute(client, strAttrib);
	ReplyToCommand(client, "Removed attribute \"%s\"", strAttrib);
	
	return Plugin_Handled;
}

void DispatchParticleEffect(const char[] pszParticleName, ParticleAttachment iAttachType, int pEntity, const char[] pszAttachmentName, bool bResetAllParticlesOnEntity)
{
	SDKCall(g_hDispatchParticleEffect, pszParticleName, iAttachType, pEntity, pszAttachmentName, bResetAllParticlesOnEntity);
}

void StopParticleEffects(int pEntity)
{
	SDKCall(g_hStopParticleEffects, pEntity);
}

void TF2_RemoveAttribute(int client, const char[] strAttrib)
{
	SDKCall(g_hRemoveCustomAttribute, client, strAttrib);
}

void TF2_AddAttribute(int client, const char[] strAttrib, float flValue, float flDuration)
{
	SDKCall(g_hAddCustomAttribute, client, strAttrib, flValue, flDuration);
}

bool TF2_IsValidAttribute(const char[] attribute)
{
	Address CEconItemSchema = SDKCall(g_hGetItemSchema);
	if(CEconItemSchema == Address_Null)
		return false;
	
	Address CEconItemAttributeDefinition = SDKCall(g_hGetAttributeDefinitionByName, CEconItemSchema, attribute);
	if(CEconItemAttributeDefinition == Address_Null)
		return false;
	
	return true;
}