#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] PlayerTauntSoundLoopStart",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("PlayerTauntSoundLoopStart"), HookTauntMessage, true);
}

public Action HookTauntMessage(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int byte = msg.ReadByte();
	char string[PLATFORM_MAX_PATH];
	msg.ReadString(string, PLATFORM_MAX_PATH);
	
	PrintToServer("%i %s", byte, string);
	
	if (StrEqual(string, "music.conga_loop"))
	{
		RequestFrame(ReSendWithNewSound, byte);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void ReSendWithNewSound(int byte)
{
	Handle message = StartMessageAll("PlayerTauntSoundLoopStart");
	BfWriteByte(message, byte);
	BfWriteString(message, "music.aerobic_loop");
	EndMessage();
}