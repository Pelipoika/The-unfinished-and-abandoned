#include <sdktools>
#include <sdkhooks>

int stringTable;

public Plugin myinfo = 
{
	name		= "[TF2] Sound Randomizer",
	author		= "Pelipoika",
	description	= "",
	version		= "-1.0",
	url			= "Nah"
};

public void OnPluginStart()
{
	stringTable = FindStringTable("soundprecache");
	
	AddNormalSoundHook(RandonmSH);
}

public Action RandonmSH(clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	int numStrings = GetStringTableNumStrings(stringTable);
	int index = GetRandomInt(0, numStrings);
	
	char strSoundPath[PLATFORM_MAX_PATH];
	ReadStringTable(stringTable, index, strSoundPath, PLATFORM_MAX_PATH);  
	
//	PrintCenterTextAll("%s", strSoundPath);
	
	Format(sample, sizeof(sample), strSoundPath);
//	EmitSoundToAll(sample, entity, channel, level, flags, volume);
	
	return Plugin_Changed;
}

stock bool IsValidClient(int client) 
{
    if ((1 <= client <= MaxClients) && IsClientInGame(client)) 
        return true; 
     
    return false; 
}