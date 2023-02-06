/**
 * ============================================================================
 *
 *  Zombie Plague
 *
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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombieplague>

#pragma newdecls required
#pragma semicolon 1

/**
 * @brief Record plugin info.
 **/
public Plugin myinfo =
{
	name            = "[ZP] Weapon: Balrog XI",
	author          = "qubka (Nikita Ushakov)",
	description     = "Addon of custom weapon",
	version         = "2.0",
	url             = "https://forums.alliedmods.net/showthread.php?t=290657"
}

/**
 * @section Information about the weapon.
 **/
#define WEAPON_ATTACK_TIME 1.0
/**
 * @endsection
 **/
 
// Animation sequences
enum
{
	ANIM_IDLE,
	ANIM_SHOOT,
	ANIM_START_RELOAD,
	ANIM_INSERT,
	ANIM_AFTER_RELOAD,
	ANIM_DRAW,
	ANIM_SHOOT_BSC1,
	ANIM_SHOOT_BSC2
};

// Decal index
int gTrail;

// Weapon index
int gWeapon;

// Sound index
int gSound;

// Cvars
ConVar hCvarBalrogDamage;
ConVar hCvarBalrogRadius;
ConVar hCvarBalrogSpeed;
ConVar hCvarBalrogCounter;
ConVar hCvarBalrogLife;
ConVar hCvarBalrogTrail;
ConVar hCvarBalrogExp;

/**
 * @brief Called when the plugin is fully initialized and all known external references are resolved. 
 *        This is only called once in the lifetime of the plugin, and is paired with OnPluginEnd().
 **/
public void OnPluginStart()
{
	// Initialize cvars
	hCvarBalrogDamage  = CreateConVar("zp_weapon_balrog11_damage", "200.0", "Explosion damage", 0, true, 0.0);
	hCvarBalrogRadius  = CreateConVar("zp_weapon_balrog11_radius", "50.0", "Explosion radius", 0, true, 0.0);
	hCvarBalrogSpeed   = CreateConVar("zp_weapon_balrog11_speed", "1000.0", "Projectile speed", 0, true, 0.0);
	hCvarBalrogCounter = CreateConVar("zp_weapon_balrog11_counter", "4", "Amount of bullets shoot to gain 1 fire bullet", 0, true, 0.0);
	hCvarBalrogLife    = CreateConVar("zp_weapon_balrog11_life", "0.5", "Duration of life", 0, true, 0.0);
	hCvarBalrogTrail   = CreateConVar("zp_weapon_balrog11_trail", "flaregun_trail_crit_red", "Particle effect for the trail (''-default)");
	hCvarBalrogExp     = CreateConVar("zp_weapon_balrog11_explosion", "projectile_fireball_crit_red", "Particle effect for the explosion (''-default)");

	// Generate config
	AutoExecConfig(true, "zp_weapon_balrog11", "sourcemod/zombieplague");
}

/**
 * @brief Called after a library is added that the current plugin references optionally. 
 *        A library is either a plugin name or extension name, as exposed via its include file.
 **/
public void OnLibraryAdded(const char[] sLibrary)
{
	// Validate library
	if (!strcmp(sLibrary, "zombieplague", false))
	{
		// If map loaded, then run custom forward
		if (ZP_IsMapLoaded())
		{
			// Execute it
			ZP_OnEngineExecute();
		}
	}
}

/**
 * @brief Called after a zombie core is loaded.
 **/
public void ZP_OnEngineExecute(/*void*/)
{
	// Weapons
	gWeapon = ZP_GetWeaponNameID("balrog11");
	//if (gWeapon == -1) SetFailState("[ZP] Custom weapon ID from name : \"balrog11\" wasn't find");

	// Sounds
	gSound = ZP_GetSoundKeyID("BALROGXI2_SHOOT_SOUNDS");
	if (gSound == -1) SetFailState("[ZP] Custom sound key ID from name : \"BALROGXI2_SHOOT_SOUNDS\" wasn't find");
}

/**
 * @brief The map is starting.
 **/
public void OnMapStart(/*void*/)
{
	// Models
	gTrail = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	PrecacheModel("materials/sprites/xfireball3.vmt", true); /// for env_explosion
}

//*********************************************************************
//*          Don't modify the code below this line unless             *
//*             you know _exactly_ what you are doing!!!              *
//*********************************************************************

void Weapon_OnDeploy(int client, int weapon, int iCounter, int iAmmo, float flCurrentTime)
{
	
	// Sets draw animation
	ZP_SetWeaponAnimation(client, ANIM_DRAW); 
	
	// Sets shots count
	SetEntProp(client, Prop_Send, "m_iShotsFired", 0);
}

void Weapon_OnShoot(int client, int weapon, int iCounter, int iAmmo, float flCurrentTime)
{
	
	// Validate ammo
	if (!GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
	{
		return;
	}
	
	// Validate counter
	if (iCounter > hCvarBalrogCounter.IntValue)
	{
		// Validate clip
		if (iAmmo < ZP_GetWeaponClip(gWeapon))
		{
			// Sets clip count
			SetEntProp(weapon, Prop_Data, "m_iMaxHealth", iAmmo + 1);
		 
			// Play sound
			ZP_EmitSoundToAll(gSound, 2, client, SNDCHAN_WEAPON, SNDLEVEL_HOME);
			
			// Sets shots counter
			iCounter = -1;
		}
	}

	// Sets shots count
	SetEntProp(weapon, Prop_Data, "m_iHealth", iCounter + 1);
}

void Weapon_OnSecondaryAttack(int client, int weapon, int iCounter, int iAmmo, float flCurrentTime)
{
	// Validate reload
	int iAnim = ZP_GetWeaponAnimation(client);
	if (iAnim == ANIM_START_RELOAD || iAnim == ANIM_INSERT)
	{
		return;
	}
	
	// Validate ammo
	if (iAmmo <= 0)
	{
		return;
	}

	// Validate animation delay
	if (GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") > flCurrentTime)
	{
		return;
	}
	
	// Validate water
	if (GetEntProp(client, Prop_Data, "m_nWaterLevel") == WLEVEL_CSGO_FULL)
	{
		return;
	}

	// Sets next idle time
	SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", flCurrentTime + WEAPON_ATTACK_TIME);
	
	// Adds the delay to the game tick
	flCurrentTime += ZP_GetWeaponShoot(gWeapon);
	
	// Sets next attack time
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", flCurrentTime);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", flCurrentTime);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", flCurrentTime);

	// Substract ammo
	iAmmo -= 1; SetEntProp(weapon, Prop_Data, "m_iMaxHealth", iAmmo); 
	
	// Sets shots count
	SetEntProp(client, Prop_Send, "m_iShotsFired", GetEntProp(client, Prop_Send, "m_iShotsFired") + 1);
 
	// Play sound
	ZP_EmitSoundToAll(gSound, 1, client, SNDCHAN_WEAPON, SNDLEVEL_HOME);
	
	// Sets attack animation
	ZP_SetWeaponAnimationPair(client, weapon, { ANIM_SHOOT_BSC1, ANIM_SHOOT_BSC2 });
	
	// Initialize vectors
	static float vPosition[5][3];

	// Gets weapon position
	ZP_GetPlayerEyePosition(client, 50.0, 60.0, -10.0, vPosition[0]);
	ZP_GetPlayerEyePosition(client, 50.0, 30.0, -10.0, vPosition[1]);
	ZP_GetPlayerEyePosition(client, 50.0, 0.0, -10.0, vPosition[2]);
	ZP_GetPlayerEyePosition(client, 50.0, -30.0, -10.0, vPosition[3]);
	ZP_GetPlayerEyePosition(client, 50.0, -60.0, -10.0, vPosition[4]);

	// i - fire index
	for (int i = 0; i < 5; i++)
	{
		// Create a fire
		Weapon_OnCreateFire(client, weapon, vPosition[i]);
	}

	// Initialize variables
	static float vVelocity[3]; int iFlags = GetEntityFlags(client);
	float vKickback[] = { /*upBase = */10.5, /* lateralBase = */7.45, /* upMod = */0.225, /* lateralMod = */0.05, /* upMax = */10.5, /* lateralMax = */7.5, /* directionChange = */7.0 };
	
	// Gets client velocity
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);

	// Apply kick back
	if (GetVectorLength(vVelocity) <= 0.0)
	{
	}
	else if (!(iFlags & FL_ONGROUND))
	{
		for (int i = 0; i < sizeof(vKickback); i++) vKickback[i] *= 1.3;
	}
	else if (iFlags & FL_DUCKING)
	{
		for (int i = 0; i < sizeof(vKickback); i++) vKickback[i] *= 0.75;
	}
	else
	{
		for (int i = 0; i < sizeof(vKickback); i++) vKickback[i] *= 1.15;
	}
	ZP_CreateWeaponKickBack(client, vKickback[0], vKickback[1], vKickback[2], vKickback[3], vKickback[4], vKickback[5], RoundFloat(vKickback[6]));
	
	// Initialize name char
	static char sName[NORMAL_LINE_LENGTH];
	
	// Gets viewmodel index
	int view = ZP_GetClientViewModel(client, true);
	
	// Create a muzzle
	ZP_GetWeaponModelMuzzle(gWeapon, sName, sizeof(sName));
	UTIL_CreateParticle(view, _, _, "1", sName, 0.1);
	
	// Create a shell
	ZP_GetWeaponModelShell(gWeapon, sName, sizeof(sName));
	UTIL_CreateParticle(view, _, _, "2", sName, 0.1);
}

void Weapon_OnCreateFire(int client, int weapon, float vPosition[3])
{
	// Initialize vectors
	static float vAngle[3]; static float vVelocity[3]; static float vEndVelocity[3];

	// Gets client eye angle
	GetClientEyeAngles(client, vAngle);

	// Gets client velocity
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	
	// Create a rocket entity
	int entity = UTIL_CreateProjectile(vPosition, vAngle);

	// Validate entity
	if (entity != -1)
	{
		// Sets grenade model scale
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 10.0);
		
		// Returns vectors in the direction of an angle
		GetAngleVectors(vAngle, vEndVelocity, NULL_VECTOR, NULL_VECTOR);

		// Normalize the vector (equal magnitude at varying distances)
		NormalizeVector(vEndVelocity, vEndVelocity);

		// Apply the magnitude by scaling the vector
		ScaleVector(vEndVelocity, hCvarBalrogSpeed.FloatValue);

		// Adds two vectors
		AddVectors(vEndVelocity, vVelocity, vEndVelocity);

		// Push the fire
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vEndVelocity);
		
		// Sets an entity color
		UTIL_SetRenderColor(entity, Color_Alpha, 0);
		AcceptEntityInput(entity, "DisableShadow"); /// Prevents the entity from receiving shadows
		
		// Sets parent for the entity
		SetEntPropEnt(entity, Prop_Data, "m_pParent", client); 
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
		SetEntPropEnt(entity, Prop_Data, "m_hThrower", client);

		// Sets gravity
		SetEntPropFloat(entity, Prop_Data, "m_flGravity", 0.01); 

		// Create touch hook
		SDKHook(entity, SDKHook_Touch, FireTouchHook);
		
		// Gets fire life
		float flDuration = hCvarBalrogLife.FloatValue;
		
		// Gets particle name
		static char sEffect[SMALL_LINE_LENGTH];
		hCvarBalrogTrail.GetString(sEffect, sizeof(sEffect));

		// Validate effect
		if (hasLength(sEffect))
		{
			// Create an effect
			UTIL_CreateParticle(entity, vPosition, _, _, sEffect, flDuration);
		}
		else
		{
			// Create an trail effect
			TE_SetupBeamFollow(entity, gTrail, 0, flDuration, 10.0, 10.0, 5, {227, 66, 52, 200});
			TE_SendToAll();	
		}
		
		// Kill after some duration
		UTIL_RemoveEntity(entity, flDuration);
	}
}
	
//**********************************************
//* Item (weapon) hooks.                       *
//**********************************************

#define _call.%0(%1,%2)         \
								\
	Weapon_On%0                 \
	(                           \
		%1,                     \
		%2,                     \
								\
		GetEntProp(%2, Prop_Data, "m_iHealth"), \
								\
		GetEntProp(%2, Prop_Data, "m_iMaxHealth"), \
								\
		GetGameTime()           \
	)    

/**
 * @brief Called after a custom weapon is created.
 *
 * @param client            The client index.
 * @param weapon            The weapon index.
 * @param weaponID          The weapon id.
 **/
public void ZP_OnWeaponCreated(int client, int weapon, int weaponID)
{
	// Validate custom weapon
	if (weaponID == gWeapon)
	{
		// Resets variables
		SetEntProp(weapon, Prop_Data, "m_iMaxHealth", 0);
		SetEntProp(weapon, Prop_Data, "m_iHealth", 0);
	}
}

/**
 * @brief Called on deploy of a weapon.
 *
 * @param client            The client index.
 * @param weapon            The weapon index.
 * @param weaponID          The weapon id.
 **/
public void ZP_OnWeaponDeploy(int client, int weapon, int weaponID) 
{
	// Validate custom weapon
	if (weaponID == gWeapon)
	{
		// Call event
		_call.Deploy(client, weapon);
	}
}
	
/**
 * @brief Called on each frame of a weapon holding.
 *
 * @param client            The client index.
 * @param iButtons          The buttons buffer.
 * @param iLastButtons      The last buttons buffer.
 * @param weapon            The weapon index.
 * @param weaponID          The weapon id.
 *
 * @return                  Plugin_Continue to allow buttons. Anything else 
 *                                (like Plugin_Changed) to change buttons.
 **/
public Action ZP_OnWeaponRunCmd(int client, int &iButtons, int iLastButtons, int weapon, int weaponID)
{
	// Validate custom weapon
	if (weaponID == gWeapon)
	{
		// Button secondary attack press
		if (!(iButtons & IN_ATTACK) && iButtons & IN_ATTACK2)
		{
			// Call event
			_call.SecondaryAttack(client, weapon);
			iButtons &= (~IN_ATTACK2); //! Bugfix
			return Plugin_Changed;
		}
	}
	
	// Allow button
	return Plugin_Continue;
}

/**
 * @brief Called on shoot of a weapon.
 *
 * @param client            The client index.
 * @param weapon            The weapon index.
 * @param weaponID          The weapon id.
 **/
public void ZP_OnWeaponShoot(int client, int weapon, int weaponID)
{
	// Validate custom weapon
	if (weaponID == gWeapon)
	{
		// Call event
		_call.Shoot(client, weapon);
	}
}

//**********************************************
//* Item (fire) hooks.                         *
//**********************************************

/**
 * @brief Fire touch hook.
 * 
 * @param entity            The entity index.        
 * @param target            The target index.               
 **/
public Action FireTouchHook(int entity, int target)
{
	// Validate target
	if (IsValidEdict(target))
	{
		// Gets thrower index
		int thrower = GetEntPropEnt(entity, Prop_Data, "m_hThrower");

		// Validate thrower
		if (thrower == target)
		{
			// Return on the unsuccess
			return Plugin_Continue;
		}

		// Gets entity position
		static float vPosition[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPosition);

		// Gets particle name
		static char sEffect[SMALL_LINE_LENGTH];
		hCvarBalrogExp.GetString(sEffect, sizeof(sEffect));

		// Initialze exp flag
		int iFlags = EXP_NOSOUND;

		// Validate effect
		if (hasLength(sEffect))
		{
			// Create an explosion effect
			UTIL_CreateParticle(_, vPosition, _, _, sEffect, 2.0);
			iFlags |= EXP_NOFIREBALL; /// remove effect sprite
		}		

		// Create an explosion
		UTIL_CreateExplosion(vPosition, iFlags, _, hCvarBalrogDamage.FloatValue, hCvarBalrogRadius.FloatValue, "balrog11", thrower, entity);
		
		// Play sound
		ZP_EmitSoundToAll(gSound, 2, entity, SNDCHAN_STATIC, SNDLEVEL_FRIDGE);
		
		// Remove the entity from the world
		AcceptEntityInput(entity, "Kill");
	}

	// Return on the success
	return Plugin_Continue;
}

/**
 * @brief Called before a grenade sound is emitted.
 *
 * @param grenade           The grenade index.
 * @param weaponID          The weapon id.
 *
 * @return                  Plugin_Continue to allow sounds. Anything else
 *                              (like Plugin_Stop) to block sounds.
 **/
public Action ZP_OnGrenadeSound(int grenade, int weaponID)
{
	// Validate custom grenade
	if (weaponID == gWeapon)
	{
		// Block sounds
		return Plugin_Stop; 
	}
	
	// Allow sounds
	return Plugin_Continue;
}
