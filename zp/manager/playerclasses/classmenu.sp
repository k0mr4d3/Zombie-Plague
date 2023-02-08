/**
 * ============================================================================
 *
 *  Zombie Plague
 *
 *  File:          classmenus.sp
 *  Type:          Module 
 *  Description:   Provides functions for managing class menus.
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
 * Menu duration of the instant change.
 **/
#define MENU_TIME_INSTANT 10 

/**
 * @brief Creates commands for classes module.
 **/
void ClassMenuOnCommandInit(/*void*/)
{
	// Create commands
	RegConsoleCmd("zhuman", ClassHumanOnCommandCatched, "Opens the human classes menu.");
	RegConsoleCmd("zzombie", ClassZombieOnCommandCatched, "Opens the zombie classes menu.");
	RegAdminCmd("zp_class_menu", ClassMenuOnCommandCatched, ADMFLAG_CONFIG, "Opens the classes menu.");
}

/**
 * Console command callback (zhuman)
 * @brief Opens the human classes menu.
 * 
 * @param client            The client index.
 * @param iArguments        The number of arguments that were in the argument string.
 **/ 
public Action ClassHumanOnCommandCatched(int client, int iArguments)
{
	ClassMenu(client, "choose humanclass", gServerData.Human, gClientData[client].HumanClassNext);
	return Plugin_Handled;
}

/**
 * Console command callback (zzombie)
 * @brief Opens the zombie classes menu.
 * 
 * @param client            The client index.
 * @param iArguments        The number of arguments that were in the argument string.
 **/ 
public Action ClassZombieOnCommandCatched(int client, int iArguments)
{
	ClassMenu(client, "choose zombieclass", gServerData.Zombie, gClientData[client].ZombieClassNext);
	return Plugin_Handled;
}

/**
 * Console command callback (zp_class_menu)
 * @brief Opens the classes menu.
 * 
 * @param client            The client index.
 * @param iArguments        The number of arguments that were in the argument string.
 **/ 
public Action ClassMenuOnCommandCatched(int client, int iArguments)
{
	ClassesMenu(client);
	return Plugin_Handled;
}

/*
 * Stocks class API.
 */

/**
 * @brief Validate zombie class for client availability.
 *
 * @param client            The client index.
 **/
void ZombieValidateClass(int client)
{
	// Validate class
	int iClass = ClassValidateIndex(client, gServerData.Zombie);
	switch (iClass)
	{
		case -2 : LogEvent(false, LogType_Error, LOG_CORE_EVENTS, LogModule_Classes, "Config Validation", "Couldn't cache any default \"zombie\" class");
		
		case -1 : { /* < empty statement > */ }
		
		default :
		{
			// Update zombie class
			gClientData[client].ZombieClassNext  = iClass;
			gClientData[client].Class = iClass;
			
			// Update class in the database
			DataBaseOnClientUpdate(client, ColumnType_Zombie);
		}
	}
}

/**
 * @brief Validate human class for client availability.
 *
 * @param client            The client index.
 **/
void HumanValidateClass(int client)
{
	// Validate class
	int iClass = ClassValidateIndex(client, gServerData.Human);
	switch (iClass)
	{
		case -2 : LogEvent(false, LogType_Error, LOG_CORE_EVENTS, LogModule_Classes, "Config Validation", "Couldn't cache any default \"human\" class");
		
		case -1 : { /* < empty statement > */ }
		
		default :
		{
			// Update human class
			gClientData[client].HumanClassNext  = iClass;
			gClientData[client].Class = iClass;
			
			// Update class in the database
			DataBaseOnClientUpdate(client, ColumnType_Human);
		}
	}
}

/**
 * @brief Validate class for client availability.
 *
 * @param client            The client index.
 * @param iType             The class type.
 * @return                  The class index. 
 **/
int ClassValidateIndex(int client, int iType)
{
	// Gets array size
	int iSize = gServerData.Classes.Length;

	// Choose random class for the bot
	if (IsFakeClient(client) || iSize <= gClientData[client].Class)
	{
		// Validate class index
		int iD = ClassTypeToRandomClassIndex(iType);
		if (iD == -1)
		{
			return -2;
		}
		
		// Update class
		gClientData[client].Class = iD;
	}
	
	// Gets class group
	static char sClassGroup[SMALL_LINE_LENGTH];
	ClassGetGroup(gClientData[client].Class, sClassGroup, sizeof(sClassGroup));

	// Find any accessable class 
	if ((hasLength(sClassGroup) && !IsPlayerInGroup(client, sClassGroup)) || ClassGetLevel(gClientData[client].Class) > gClientData[client].Level || ClassGetTypeID(gClientData[client].Class) != iType)
	{
		// Choose any accessable class
		for (int i = 0; i < iSize; i++)
		{
			// Skip some classes, if group isn't accessable
			ClassGetGroup(i, sClassGroup, sizeof(sClassGroup));
			if (hasLength(sClassGroup) && !IsPlayerInGroup(client, sClassGroup))
			{
				continue;
			}
			
			// Skip some classes, if types isn't equal
			if (ClassGetTypeID(i) != iType)
			{
				continue;
			}
			
			// Skip some classes, if level too low
			if (ClassGetLevel(i) > gClientData[client].Level)
			{
				continue;
			}
			
			// Return this index
			return i;
		}
	}
	// Client already had accessable class
	else return -1;
	
	// Class doesn't exist
	return -2;
}

/*
 * Menu classes API.
 */

/**
 * @brief Creates the class menu.
 *
 * @param client            The client index.
 * @param sTitle            The menu title.
 * @param iType             The class type.
 * @param iClass            The current class.
 * @param bInstant          (Optional) True to set the class instantly, false to set it on the next class change.
 **/
void ClassMenu(int client, char[] sTitle, int iType, int iClass, bool bInstant = false) 
{
	// Validate client
	if (!IsPlayerExist(client, false))
	{
		return;
	}

	// Initialize variables
	static char sBuffer[NORMAL_LINE_LENGTH];
	static char sName[SMALL_LINE_LENGTH];
	static char sInfo[SMALL_LINE_LENGTH];
	static char sLevel[SMALL_LINE_LENGTH];
	static char sGroup[SMALL_LINE_LENGTH];

	// Creates menu handle
	Menu hMenu = new Menu(iType == gServerData.Zombie ? (bInstant ? ClassZombieMenuSlots2 : ClassZombieMenuSlots1) : (bInstant ? ClassHumanMenuSlots2 : ClassHumanMenuSlots1));

	// Sets language to target
	SetGlobalTransTarget(client);
	
	// Sets title
	hMenu.SetTitle("%t", sTitle);
	
	// Initialize forward
	Action hResult;
	
	// i = class index
	int iSize = gServerData.Classes.Length; int iAmount;
	for (int i = 0; i < iSize; i++)
	{
		// Call forward
		gForwardData._OnClientValidateClass(client, i, hResult);
		
		// Skip, if class is disabled
		if (hResult == Plugin_Stop)
		{
			continue;
		}

		// Skip some classes, if types isn't equal
		if (ClassGetTypeID(i) != iType)
		{
			continue;
		}
	
		// Gets class type name
		gServerData.Types.GetString(iType, sName, sizeof(sName));
		
		// Gets general class data
		ClassGetName(i, sName, sizeof(sName));
		ClassGetGroup(i, sGroup, sizeof(sGroup));
		
		// Format some chars for showing in menu
		FormatEx(sLevel, sizeof(sLevel), "%t", "level", ClassGetLevel(i));
		FormatEx(sBuffer, sizeof(sBuffer), "%t  %s", sName, (hasLength(sGroup) && !IsPlayerInGroup(client, sGroup)) ? sGroup : (gClientData[client].Level < ClassGetLevel(i)) ? sLevel : "");

		// Show option
		IntToString(i, sInfo, sizeof(sInfo));
		hMenu.AddItem(sInfo, sBuffer, MenusGetItemDraw((hResult == Plugin_Handled || (hasLength(sGroup) && !IsPlayerInGroup(client, sGroup)) || gClientData[client].Level < ClassGetLevel(i) || iClass == i) ? false : true));
	
		// Increment amount
		iAmount++;
	}
	
	// If there are no cases, add an "(Empty)" line
	if (!iAmount)
	{
		// Format some chars for showing in menu
		FormatEx(sBuffer, sizeof(sBuffer), "%t", "empty");
		hMenu.AddItem("empty", sBuffer, ITEMDRAW_DISABLED);
	}

	// Sets exit and back button
	hMenu.ExitBackButton = true;

	// Sets options and display it
	hMenu.OptionFlags = MENUFLAG_BUTTON_EXIT | MENUFLAG_BUTTON_EXITBACK;
	hMenu.Display(client, bInstant ? MENU_TIME_INSTANT : MENU_TIME_FOREVER); 
}

/**
 * @brief Called when client selects option in the zombie class menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ClassZombieMenuSlots1(Menu hMenu, MenuAction mAction, int client, int mSlot)
{
   // Call menu
   return ClassMenuSlots(hMenu, mAction, "zzombie", client, mSlot);
}

/**
 * @brief Called when client selects option in the zombie class menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ClassZombieMenuSlots2(Menu hMenu, MenuAction mAction, int client, int mSlot)
{
   // Call menu
   return ClassMenuSlots(hMenu, mAction, "zzombie", client, mSlot, true);
}

/**
 * @brief Called when client selects option in the human class menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ClassHumanMenuSlots1(Menu hMenu, MenuAction mAction, int client, int mSlot)
{
   // Call menu
   return ClassMenuSlots(hMenu, mAction, "zhuman", client, mSlot);
}

/**
 * @brief Called when client selects option in the human class menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ClassHumanMenuSlots2(Menu hMenu, MenuAction mAction, int client, int mSlot)
{
   // Call menu
   return ClassMenuSlots(hMenu, mAction, "zhuman", client, mSlot, true);
}

/**
 * @brief Called when client selects option in the class menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param sCommand          The menu command.
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 * @param bInstant          (Optional) True to set the class instantly, false to set it on the next class change.
 **/ 
int ClassMenuSlots(Menu hMenu, MenuAction mAction, char[] sCommand, int client, int mSlot, bool bInstant = false)
{
	// Switch the menu action
	switch (mAction)
	{
		// Client hit 'Exit' button
		case MenuAction_End :
		{
			delete hMenu;
		}
		
		// Client hit 'Back' button
		case MenuAction_Cancel :
		{
			if (mSlot == MenuCancel_ExitBack)
			{
				// Opens menu back
				int iD[2]; iD = MenusCommandToArray(sCommand);
				if (iD[0] != -1) SubMenu(client, iD[0]);
			}
		}
		
		// Client selected an option
		case MenuAction_Select :
		{
			// Validate client
			if (!IsPlayerExist(client, false))
			{
				return 0;
			}

			// Gets menu info
			static char sBuffer[SMALL_LINE_LENGTH];
			hMenu.GetItem(mSlot, sBuffer, sizeof(sBuffer));
			int iD = StringToInt(sBuffer);
			
			// Call forward
			Action hResult;
			gForwardData._OnClientValidateClass(client, iD, hResult);

			// Validate handle
			if (hResult == Plugin_Continue || hResult == Plugin_Changed)
			{
				// Gets class type
				int iType = ClassGetTypeID(iD);
				
				// Validate human
				if (iType == gServerData.Human)
				{
					// Sets next human class
					gClientData[client].HumanClassNext = iD;
					
					// Update class in the database
					DataBaseOnClientUpdate(client, ColumnType_Human);
						
					// Validate instant change
					if (bInstant)
					{
						// Make human
						ApplyOnClientUpdate(client, _, gServerData.Human);
					}
				}
				// Validate zombie
				else if (iType == gServerData.Zombie)
				{
					// Sets next zombie class
					gClientData[client].ZombieClassNext = iD;
					
					// Update class in the database
					DataBaseOnClientUpdate(client, ColumnType_Zombie);
					
					// Validate instant change
					if (bInstant)
					{
						// Make zombie
						ApplyOnClientUpdate(client, _, gServerData.Zombie);
					}
				}
				else 
				{
					// Emit error sound
					EmitSoundToClient(client, SOUND_BUTTON_MENU_ERROR, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);
					return 0;
				}
				
				// Gets class name
				ClassGetName(iD, sBuffer, sizeof(sBuffer));
  
				// If help messages enabled, then show info
				if (gCvarList.MESSAGES_CLASS_CHOOSE.BoolValue) TranslationPrintToChat(client, "info class", sBuffer, ClassGetHealth(iD), ClassGetArmor(iD), ClassGetSpeed(iD));
			
				// If help messages enabled, then show info
				if (gCvarList.MESSAGES_CLASS_DUMP.BoolValue) 
				{
					// Print data into console
					ClassDump(client, iD);
					
					// Show message of dump info
					TranslationPrintToChat(client, "config dump class info");
				}
			}
		}
	}
	
	return 0;
}

/**
 * @brief Creates the classes menu. (admin)
 *
 * @param client            The client index.
 **/
void ClassesMenu(int client) 
{
	// Validate client
	if (!IsPlayerExist(client, false))
	{
		return;
	}

	// If mode doesn't started yet, then stop
	if (!gServerData.RoundStart)
	{
		// Show block info
		TranslationPrintHintText(client, "block classes round"); 

		// Emit error sound
		EmitSoundToClient(client, SOUND_BUTTON_MENU_ERROR, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);
		return;
	}
	
	// Initialize variables
	static char sBuffer[NORMAL_LINE_LENGTH];
	static char sType[SMALL_LINE_LENGTH];
	static char sInfo[SMALL_LINE_LENGTH];
	
	// Creates menu handle
	Menu hMenu = new Menu(ClassesMenuSlots);
	
	// Sets language to target
	SetGlobalTransTarget(client);

	// Sets title
	hMenu.SetTitle("%t", "classes menu");

	// i = client index
	int iAmount;
	for (int i = 1; i <= MaxClients; i++)
	{
		// Validate client
		if (!IsPlayerExist(i, false))
		{
			continue;
		}

		// Gets type name
		gServerData.Types.GetString(ClassGetTypeID(gClientData[i].Class), sType, sizeof(sType));
		
		// Format some chars for showing in menu
		FormatEx(sBuffer, sizeof(sBuffer), "%N [%t]", i, IsPlayerAlive(i) ? sType : "dead");

		// Show option
		IntToString(GetClientUserId(i), sInfo, sizeof(sInfo));
		hMenu.AddItem(sInfo, sBuffer);

		// Increment amount
		iAmount++;
	}
	
	// If there are no clients, add an "(Empty)" line
	if (!iAmount)
	{
		// Format some chars for showing in menu
		FormatEx(sBuffer, sizeof(sBuffer), "%t", "empty");
		hMenu.AddItem("empty", sBuffer, ITEMDRAW_DISABLED);
	}
	
	// Sets exit and back button
	hMenu.ExitBackButton = true;

	// Sets options and display it
	hMenu.OptionFlags = MENUFLAG_BUTTON_EXIT | MENUFLAG_BUTTON_EXITBACK;
	hMenu.Display(client, MENU_TIME_FOREVER); 
}

/**
 * @brief Called when client selects option in the classes menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ClassesMenuSlots(Menu hMenu, MenuAction mAction, int client, int mSlot)
{   
	// Switch the menu action
	switch (mAction)
	{
		// Client hit 'Exit' button
		case MenuAction_End :
		{
			delete hMenu;
		}
		
		// Client hit 'Back' button
		case MenuAction_Cancel :
		{
			if (mSlot == MenuCancel_ExitBack)
			{
				// Opens menu back
				int iD[2]; iD = MenusCommandToArray("zp_class_menu");
				if (iD[0] != -1) SubMenu(client, iD[0]);
			}
		}
		
		// Client selected an option
		case MenuAction_Select :
		{
			// Validate client
			if (!IsPlayerExist(client, false))
			{
				return 0;
			}
			
			// If mode doesn't started yet, then stop
			if (!gServerData.RoundStart)
			{
				// Show block info
				TranslationPrintHintText(client, "block using menu");
		
				// Emit error sound
				EmitSoundToClient(client, SOUND_BUTTON_MENU_ERROR, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);    
				return 0;
			}

			// Gets menu info
			static char sBuffer[SMALL_LINE_LENGTH];
			hMenu.GetItem(mSlot, sBuffer, sizeof(sBuffer));
			int target = GetClientOfUserId(StringToInt(sBuffer));
			
			// Validate target
			if (target)
			{
				// Validate dead
				if (!IsPlayerAlive(target))
				{
					// Force client to respawn
					ToolsForceToRespawn(target);
				}
				else
				{
					// Creates a option menu
					ClassesOptionMenu(client, target);
					return 0;
				}
			}
			else
			{
				// Show block info
				TranslationPrintHintText(client, "block selecting target");
					
				// Emit error sound
				EmitSoundToClient(client, SOUND_BUTTON_MENU_ERROR, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER); 
			}

			// Opens classes menu back
			ClassesMenu(client);
		}
	}
	
	return 0;
}

/**
 * @brief Creates a classes option menu.
 *
 * @param client            The client index.
 * @param target            The target index.
 **/
void ClassesOptionMenu(int client, int target)
{
	// Initialize variables
	static char sBuffer[NORMAL_LINE_LENGTH]; 
	static char sType[SMALL_LINE_LENGTH];
	static char sInfo[SMALL_LINE_LENGTH];
	
	// Creates menu handle
	Menu hMenu = new Menu(ClassesListMenuSlots);
	
	// Sets language to target
	SetGlobalTransTarget(client);
	
	// Sets title
	hMenu.SetTitle("%N", target);
	
	// i = array index
	int iSize = gServerData.Types.Length;
	for (int i = 0; i < iSize; i++)
	{
		// Gets type name
		gServerData.Types.GetString(i, sType, sizeof(sType));
		
		// Format some chars for showing in menu
		FormatEx(sBuffer, sizeof(sBuffer), "%t", sType);
		
		// Show option
		FormatEx(sInfo, sizeof(sInfo), "%d %d", i, GetClientUserId(target));
		hMenu.AddItem(sInfo, sBuffer);
	}
	
	// If there are no cases, add an "(Empty)" line
	if (!iSize)
	{
		// Format some chars for showing in menu
		FormatEx(sBuffer, sizeof(sBuffer), "%t", "empty");
		hMenu.AddItem("empty", sBuffer, ITEMDRAW_DISABLED);
	}
	
	// Sets exit and back button
	hMenu.ExitBackButton = true;

	// Sets options and display it
	hMenu.OptionFlags = MENUFLAG_BUTTON_EXIT | MENUFLAG_BUTTON_EXITBACK;
	hMenu.Display(client, MENU_TIME_FOREVER); 
}   

/**
 * @brief Called when client selects option in the classes option menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ClassesListMenuSlots(Menu hMenu, MenuAction mAction, int client, int mSlot)
{   
	// Switch the menu action
	switch (mAction)
	{
		// Client hit 'Exit' button
		case MenuAction_End :
		{
			delete hMenu;
		}
		
		// Client hit 'Back' button
		case MenuAction_Cancel :
		{
			if (mSlot == MenuCancel_ExitBack)
			{
				// Opens classes menu back
				ClassesMenu(client);
			}
		}
		
		// Client selected an option
		case MenuAction_Select :
		{
			// Validate client
			if (!IsPlayerExist(client, false))
			{
				return 0;
			}
			
			// If mode doesn't started yet, then stop
			if (!gServerData.RoundStart)
			{
				// Show block info
				TranslationPrintHintText(client, "block using menu");
		
				// Emit error sound
				EmitSoundToClient(client, SOUND_BUTTON_MENU_ERROR, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);    
				return 0;
			}

			// Gets menu info
			static char sBuffer[SMALL_LINE_LENGTH];
			hMenu.GetItem(mSlot, sBuffer, sizeof(sBuffer));
			static char sInfo[2][SMALL_LINE_LENGTH];
			ExplodeString(sBuffer, " ", sInfo, sizeof(sInfo), sizeof(sInfo[]));
			int iD = StringToInt(sInfo[0]); int target = GetClientOfUserId(StringToInt(sInfo[1]));

			// Validate target
			if (target && IsPlayerAlive(target))
			{
				// Force client to update
				ApplyOnClientUpdate(target, _, iD);
				
				// Gets type name
				gServerData.Types.GetString(iD, sBuffer, sizeof(sBuffer));
				
				// Log action to game events
				LogEvent(true, LogType_Normal, LOG_PLAYER_COMMANDS, LogModule_GameModes, "Command", "Admin \"%N\" changed a class for Player \"%N\" to \"%s\"", client, target, sBuffer);
			}
			else
			{
				// Show block info
				TranslationPrintHintText(client, "block selecting target");
					
				// Emit error sound
				EmitSoundToClient(client, SOUND_BUTTON_MENU_ERROR, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);  
			}
			
			// Opens classes menu back
			ClassesMenu(client);
		}
	}
	
	return 0;
}