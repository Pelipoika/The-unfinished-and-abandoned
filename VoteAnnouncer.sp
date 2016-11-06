#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Vote Announcer",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("VoteStart"), VoteStart);
	HookUserMessage(GetUserMessageId("VotePass"),  VotePass);
}

public Action VoteStart(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	/*int m_iOnlyTeamToVote    = */
	BfReadByte(msg);
	int m_iEntityHoldingVote = BfReadByte(msg);
	
	char DisplayString[32], DetailsString[32];
	BfReadString(msg, DisplayString, sizeof(DisplayString));
	BfReadString(msg, DetailsString, sizeof(DetailsString));
	
	/*bool IsYesNoVote = */
	BfReadBool(msg);
	int m_iEntityVotedAgainst = BfReadByte(msg);
	
	DataPack pack = new DataPack();
	pack.WriteCell(m_iEntityHoldingVote);
	pack.WriteString(DisplayString);
	pack.WriteString(DetailsString);
	pack.WriteCell(m_iEntityVotedAgainst);
	
	RequestFrame(FrameVoteStart, pack);
	
/*	VoteStart
	m_iOnlyTeamToVote 3
	m_iEntityHoldingVote 1
	DisplayString #TF_vote_kick_player_other #TF_vote_kick_player_scamming #TF_vote_kick_player_idle #TF_vote_kick_player_cheating
	DetailsString Nom Nom Nom
	IsYesNoVote 1
	byte 3*/
	
	return Plugin_Continue;
}

public void FrameVoteStart(DataPack pack)
{
	pack.Reset();
	
	int m_iEntityHoldingVote = pack.ReadCell();
	
	char DisplayString[32], DetailsString[32];
	pack.ReadString(DisplayString, sizeof(DisplayString));
	pack.ReadString(DetailsString, sizeof(DetailsString));
	
	int m_iEntityVotedAgainst = pack.ReadCell();

	char TeamColor[16];
	switch(TF2_GetClientTeam(m_iEntityVotedAgainst))
	{
		case TFTeam_Blue: TeamColor = "{blue}";
		case TFTeam_Red:  TeamColor = "{red}";
		default:          TeamColor = "{gray}";
	}
	
	char Reason[32];
	if(StrEqual(DisplayString,      "#TF_vote_kick_player_other"))    Reason = "{gray}No reason";
	else if(StrEqual(DisplayString, "#TF_vote_kick_player_scamming")) Reason = "{red}Scamming";	
	else if(StrEqual(DisplayString, "#TF_vote_kick_player_idle"))     Reason = "{red}Idle";
	else if(StrEqual(DisplayString, "#TF_vote_kick_player_cheating")) Reason = "{fullred}Cheating";
	
	CPrintToChatAllEx(m_iEntityHoldingVote, "{teamcolor}%N{default} wants to kick %s%s{default} for %s", m_iEntityHoldingVote, TeamColor, DetailsString, Reason);
}

public Action VotePass(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	TFTeam m_iOnlyTeamToVote = view_as<TFTeam>(BfReadByte(msg));
	
	char VotePassedString[32], DetailsString[32];
	BfReadString(msg, VotePassedString, sizeof(VotePassedString));
	BfReadString(msg, DetailsString,    sizeof(DetailsString));
	
	DataPack pack = new DataPack();
	pack.WriteCell(m_iOnlyTeamToVote);
	pack.WriteString(VotePassedString);
	pack.WriteString(DetailsString);
	
	RequestFrame(FrameVotePass, pack);
	
	return Plugin_Continue;
}

public void FrameVotePass(DataPack pack)
{
	pack.Reset();
	
	TFTeam m_iOnlyTeamToVote = pack.ReadCell();
	
	char VotePassedString[32], DetailsString[32];
	pack.ReadString(VotePassedString, sizeof(VotePassedString));
	pack.ReadString(DetailsString, sizeof(DetailsString));

	char TeamColor[16];
	switch(m_iOnlyTeamToVote)
	{
		case TFTeam_Blue: TeamColor = "{blue}";
		case TFTeam_Red:  TeamColor = "{red}";
		default:          TeamColor = "{gray}";
	}
	
	CPrintToChatAll("{default}Kicking player: %s%N{default}...", TeamColor, DetailsString);
}