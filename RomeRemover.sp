#include <tf2items>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Romebot Armor remover",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)
{
	if(iItemDefinitionIndex >= 30143 && iItemDefinitionIndex <= 30161)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}