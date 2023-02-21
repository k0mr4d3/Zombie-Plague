/**
 * ============================================================================
 *
 *  Zombie Plague
 *
 *  File:          playersounds.sp
 *  Type:          Module 
 *  Description:   Player sound effects.
 *
 *  Copyright (C) 2015-2023 qubka (Nikita Ushakov)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 **/
 
/**
 * @section Struct of sounds used by the plugin.
 **/
enum struct SoundData
{
	int Start;
	int Count;
	int Blast;
}
/**
 * @endsection
 **/
 
/**
 * Array to store sound data in.
 **/
SoundData gSoundData;

/**
 * @brief Prepare all player sounds data.
 **/
void PlayerSoundsOnOnLoad()
{
	static char sBuffer[SMALL_LINE_LENGTH];

	gCvarList.SEFFECTS_ROUND_START.GetString(sBuffer, sizeof(sBuffer));
	gSoundData.Start = SoundsKeyToIndex(sBuffer);

	gCvarList.SEFFECTS_ROUND_COUNT.GetString(sBuffer, sizeof(sBuffer));
	gSoundData.Count = SoundsKeyToIndex(sBuffer);
	
	gCvarList.SEFFECTS_ROUND_BLAST.GetString(sBuffer, sizeof(sBuffer));
	gSoundData.Blast = SoundsKeyToIndex(sBuffer);
}

/**
 * @brief Hook player sounds cvar changes.
 **/
void PlayerSoundsOnCvarInit()
{
	gCvarList.SEFFECTS_INFECT            = FindConVar("zp_seffects_infect");
	gCvarList.SEFFECTS_COMEBACK          = FindConVar("zp_seffects_comeback");
	gCvarList.SEFFECTS_MOAN              = FindConVar("zp_seffects_moan");
	gCvarList.SEFFECTS_BURN              = FindConVar("zp_seffects_burn");
	gCvarList.SEFFECTS_DEATH             = FindConVar("zp_seffects_death");
	gCvarList.SEFFECTS_FOOTSTEPS         = FindConVar("zp_seffects_footsteps");
	gCvarList.SEFFECTS_CLAWS             = FindConVar("zp_seffects_claws");
	gCvarList.SEFFECTS_ROUND_START       = FindConVar("zp_seffects_round_start");   
	gCvarList.SEFFECTS_ROUND_COUNT       = FindConVar("zp_seffects_round_count");   
	gCvarList.SEFFECTS_ROUND_BLAST       = FindConVar("zp_seffects_round_blast");

	HookConVarChange(gCvarList.SEFFECTS_ROUND_START,       PlayerSoundsOnCvarHook);
	HookConVarChange(gCvarList.SEFFECTS_ROUND_COUNT,       PlayerSoundsOnCvarHook);
	HookConVarChange(gCvarList.SEFFECTS_ROUND_BLAST,       PlayerSoundsOnCvarHook);
}

/**
 * @brief The counter is begin.
 **/
void PlayerSoundsOnCounterStart()
{
	SEffectsEmitToAll(gSoundData.Start, _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
}

/**
 * @brief Timer callback, the round is ending. *(Next frame)
 *
 * @param reason            The reason index.
 **/
public Action PlayerSoundsOnRoundEndPost(Handle hTimer, CSRoundEndReason reason)
{
	gServerData.EndTimer = null;
	
	switch (reason)
	{
		case CSRoundEnd_TerroristWin : SEffectsEmitToAll(ModesGetSoundEndZombieID(gServerData.RoundMode), _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);   
		case CSRoundEnd_CTWin :        SEffectsEmitToAll(ModesGetSoundEndHumanID(gServerData.RoundMode), _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
		case CSRoundEnd_Draw :         SEffectsEmitToAll(ModesGetSoundEndDrawID(gServerData.RoundMode), _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
	}
	
	return Plugin_Stop;
}

/**
 * @brief The counter is working.
 *
 * @return                  True or false.
 **/
bool PlayerSoundsOnCounter()
{
	return SEffectsEmitToAll(gSoundData.Count, gServerData.RoundCount, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
}

/**
 * @brief Timer callback, the blast is started. *(Next frame)
 **/
public Action PlayerSoundsOnBlastPost(Handle hTimer)
{
	gServerData.BlastTimer = null;
	
	SEffectsEmitToAll(gSoundData.Blast, _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);

	return Plugin_Stop;
}

/**
 * @brief The gamemode is starting.
 **/
void PlayerSoundsOnGameModeStart()
{
	SEffectsEmitToAll(ModesGetSoundStartID(gServerData.RoundMode), _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
}

/**
 * @brief Client has been killed.
 * 
 * @param client            The client index.
 **/
void PlayerSoundsOnClientDeath(int client)
{
	bool bDeath = gCvarList.SEFFECTS_DEATH.BoolValue;
	if (!bDeath)
	{
		return;
	}

	SEffectsEmitToAll(ClassGetSoundDeathID(gClientData[client].Class), _, client, SNDCHAN_STATIC);
}

/**
 * @brief Client has been hurt.
 * 
 * @param client            The client index.
 * @param bBurning          The burning type of damage. 
 **/
void PlayerSoundsOnClientHurt(int client, bool bBurning)
{
	if (bBurning)
	{
		if (gCvarList.SEFFECTS_BURN.BoolValue) 
		{
			static float flBurn[MAXPLAYERS+1];
			
			SEffectsEmitToAllNoRestart(flBurn[client], ClassGetSoundBurnID(gClientData[client].Class), _, client, SNDCHAN_WEAPON);
			return; /// Exit here
		}
	}
	
	static float flGroan[MAXPLAYERS+1];

	SEffectsEmitToAllNoRestart(flGroan[client], ClassGetSoundHurtID(gClientData[client].Class), _, client, SNDCHAN_BODY);
}

/**
 * @brief Client has been infected.
 * 
 * @param client            The client index.
 * @param attacker          The attacker index.
 **/
void PlayerSoundsOnClientInfected(int client, int attacker)
{
	if (gCvarList.SEFFECTS_INFECT.BoolValue) 
	{
		if (attacker < 1)
		{
			SEffectsEmitToAll(ClassGetSoundRespawnID(gClientData[client].Class), _, client, SNDCHAN_STATIC);
		}
		else
		{
			SEffectsEmitToAll(ClassGetSoundInfectID(gClientData[client].Class), _, client, SNDCHAN_STATIC);
		}
	}
	
	if (gCvarList.SEFFECTS_COMEBACK.BoolValue && gServerData.RoundStart && attacker == -1)
	{
		SEffectsEmitToHumans(ModesGetSoundComebackID(gServerData.RoundMode), _, SOUND_FROM_PLAYER, SNDCHAN_STATIC);
	}
	
	float flInterval = gCvarList.SEFFECTS_MOAN.FloatValue;
	if (!flInterval)
	{
		return;
	}

	delete gClientData[client].MoanTimer;
	gClientData[client].MoanTimer = CreateTimer(flInterval, PlayerSoundsOnMoanRepeat, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * @brief Timer callback, repeats a moaning sound on zombies.
 * 
 * @param hTimer            The timer handle.
 * @param userID            The user id.
 **/
public Action PlayerSoundsOnMoanRepeat(Handle hTimer, int userID)
{
	int client = GetClientOfUserId(userID);

	if (client)
	{
		SEffectsEmitToAll(ClassGetSoundIdleID(gClientData[client].Class), _, client, SNDCHAN_STATIC);

		return Plugin_Continue;
	}

	gClientData[client].MoanTimer = null;
	
	return Plugin_Stop;
}

/**
 * @brief Client has been regenerating.
 * 
 * @param client            The client index.
 **/
void PlayerSoundsOnClientRegen(int client)
{
	SEffectsEmitToAll(ClassGetSoundRegenID(gClientData[client].Class), _, client, SNDCHAN_STATIC);
}

/**
 * @brief Client has been leap jumped.
 * 
 * @param client            The client index.
 **/
void PlayerSoundsOnClientJump(int client)
{
	SEffectsEmitToAll(ClassGetSoundJumpID(gClientData[client].Class), _, client, SNDCHAN_STATIC);
}

/**
 * @brief Client has been shoot.
 * 
 * @param client            The client index.
 * @param iD                The weapon id.
 * @return                  True or false.
 **/
bool PlayerSoundsOnClientShoot(int client, int iD)
{
	return SEffectsEmitToAll(WeaponsGetSoundID(iD), _, client, SNDCHAN_WEAPON);
}

/**
 * @brief Called when a sound is going to be emitted to one or more clients. NOTICE: all params can be overwritten to modify the default behaviour.
 *  
 * @param clients           Array of client indexes.
 * @param numClients        Number of clients in the array (modify this value ifyou add/remove elements from the client array).
 * @param sSample           Sound file name relative to the "sounds" folder.
 * @param entity            Entity emitting the sound.
 * @param iChannel          Channel emitting the sound.
 * @param flVolume          The sound volume.
 * @param iLevel            The sound level.
 * @param iPitch            The sound pitch.
 * @param iFrags            The sound flags.
 * @param sEntry            The game sound entry name.
 * @param iSeed             The sound seed.
 **/ 
public Action PlayerSoundsNormalHook(int clients[MAXPLAYERS], int &numClients, char sSample[PLATFORM_MAX_PATH], int &entity, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFrags, char sEntry[PLATFORM_MAX_PATH], int& iSeed)
{
	if (IsPlayerExist(entity))
	{
		if (gCvarList.SEFFECTS_FOOTSTEPS.BoolValue && StrContains(sSample, "footsteps", false) != -1)
		{
			float oVolume; int oLevel; int oFlags; int oPitch;
			if (SoundsGetSound(ClassGetSoundFootID(gClientData[entity].Class), _, sSample, oVolume, oLevel, oFlags, oPitch))
			{
				return Plugin_Changed; 
			}
		}
	}
	else if (IsValidEdict(entity))
	{
		static char sClassname[SMALL_LINE_LENGTH];
		GetEdictClassname(entity, sClassname, sizeof(sClassname));

		if (sClassname[0] == 'w' && sClassname[1] == 'e' && sClassname[6] == '_' && // weapon_
			(sClassname[7] == 'k' ||                          // knife
			(sClassname[7] == 'm' && sClassname[8] == 'e') || // melee
			(sClassname[7] == 'f' && sClassname[9] == 's')))  // fist
		{
			if (gCvarList.SEFFECTS_CLAWS.BoolValue && StrContains(sSample, "knife", false) != -1)
			{
				int client = ToolsGetOwner(entity);
				if (IsPlayerExist(client))
				{
					float oVolume; int oLevel; int oFlags; int oPitch;
					if (SoundsGetSound(ClassGetSoundAttackID(gClientData[client].Class), _, sSample, oVolume, oLevel, oFlags, oPitch))
					{
						return Plugin_Changed; 
					}
				}
			}
		}
		else
		{
			int iLen = strlen(sClassname) - 11;
			
			if (iLen > 0)
			{
				if (!strncmp(sClassname[iLen], "_proj", 5, false))
				{
					Action hResult;
					gForwardData._OnGrenadeSound(entity, ToolsGetCustomID(entity), hResult);
					return hResult;
				}
			}
		}
	}

	return Plugin_Continue;
}

/**
 * Cvar hook callback (zp_seffects_round_*)
 * @brief Load the sound variables.
 * 
 * @param hConVar           The cvar handle.
 * @param oldValue          The value before the attempted change.
 * @param newValue          The new value.
 **/
public void PlayerSoundsOnCvarHook(ConVar hConVar, char[] oldValue, char[] newValue)
{    
	if (!strcmp(oldValue, newValue, false))
	{
		return;
	}
	
	if (gServerData.MapLoaded)
	{
		PlayerSoundsOnOnLoad();
	}
}
