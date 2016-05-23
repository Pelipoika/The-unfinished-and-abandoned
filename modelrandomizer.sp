#include <sdktools>
#include <sdkhooks>
#include <tf2items>

int stringTable;

public Plugin myinfo = 
{
	name		= "[TF2] Model Randomizer",
	author		= "Pelipoika",
	description	= "",
	version		= "-1.0",
	url			= "Nah"
};

public void OnPluginStart()
{
	stringTable = FindStringTable("modelprecache");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity > MaxClients)
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawn);
}

public void OnEntitySpawn(int entity)
{
	int numStrings = GetStringTableNumStrings(stringTable);
	int mindex = GetRandomInt(0, numStrings);
	
	char strModel[PLATFORM_MAX_PATH];
	ReadStringTable(stringTable, mindex, strModel, PLATFORM_MAX_PATH);
	
	PrintToServer("%i -> %s", entity, strModel);
	
	SetEntProp(entity, Prop_Data, "m_nModelIndexOverrides", mindex);
	SetEntProp(entity, Prop_Data, "m_nModelIndex", mindex);
//	RequestFrame(OnSpawnSpawn, EntIndexToEntRef(entity));	
}

public void OnSpawnSpawn(int iRef)
{
	int iEnt = EntRefToEntIndex(iRef);
	if(iEnt != INVALID_ENT_REFERENCE)
	{
		RequestFrame(OnSpawnSpawnSpawn, EntIndexToEntRef(iEnt));	
	}
}

public void OnSpawnSpawnSpawn(int iRef)
{
	int iEnt = EntRefToEntIndex(iRef);
	if(iEnt != INVALID_ENT_REFERENCE)
	{
		int numStrings = GetStringTableNumStrings(stringTable);
		int mindex = GetRandomInt(0, numStrings);
		
		SetEntProp(iEnt, Prop_Data, "m_nModelIndexOverrides", mindex);
		SetEntProp(iEnt, Prop_Data, "m_nModelIndex", mindex);
	}
}

/*
public int TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int index, int level, int quality, int entity)
{
	int numStrings = GetStringTableNumStrings(stringTable);
	int mindex = GetRandomInt(0, numStrings);
	
	SetEntProp(entity, Prop_Data, "m_nModelIndexOverrides", mindex);
}*/