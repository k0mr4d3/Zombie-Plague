/**
 * ============================================================================
 *
 *  Zombie Plague
 *
 *  File:          extraitems.sp
 *  Type:          Manager 
 *  Description:   API for loading extraitems specific variables.
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
 * @section Item native data indexes.
 **/
enum
{
	EXTRAITEMS_DATA_SECTION,
	EXTRAITEMS_DATA_NAME,
	EXTRAITEMS_DATA_INFO,
	EXTRAITEMS_DATA_WEAPON,
	EXTRAITEMS_DATA_COST,
	EXTRAITEMS_DATA_LEVEL,
	EXTRAITEMS_DATA_ONLINE,
	EXTRAITEMS_DATA_LIMIT,
	EXTRAITEMS_DATA_FLAGS,
	EXTRAITEMS_DATA_GROUP,
	EXTRAITEMS_DATA_CLASS
};
/**
 * @endsection
 **/
 
/**
 * @brief Prepare all extraitem data.
 **/
void ExtraItemsOnLoad(/*void*/)
{
	// Register config file
	ConfigRegisterConfig(File_ExtraItems, Structure_FlattenKeyValue, CONFIG_FILE_ALIAS_EXTRAITEMS);

	// If extraitems is disabled, then stop
	if (!gCvarList.EXTRAITEMS.BoolValue)
	{
		return;
	}

	// Gets extraitems config path
	static char sBuffer[PLATFORM_LINE_LENGTH];
	bool bExists = ConfigGetFullPath(CONFIG_FILE_ALIAS_EXTRAITEMS, sBuffer, sizeof(sBuffer));

	// If file doesn't exist, then log and stop
	if (!bExists)
	{
		// Log failure
		LogEvent(false, LogType_Fatal, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "Missing extraitems config file: \"%s\"", sBuffer);
		return;
	}

	// Sets path to the config file
	ConfigSetConfigPath(File_ExtraItems, sBuffer);

	// Load config from file and create array structure
	bool bSuccess = ConfigLoadConfig(File_ExtraItems, gServerData.ExtraItems);

	// Unexpected error, stop plugin
	if (!bSuccess)
	{
		LogEvent(false, LogType_Fatal, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "Unexpected error encountered loading: \"%s\"", sBuffer);
		return;
	}

	// Now copy data to array structure
	ExtraItemsOnCacheData();

	// Sets config data
	ConfigSetConfigLoaded(File_ExtraItems, true);
	ConfigSetConfigReloadFunc(File_ExtraItems, GetFunctionByName(GetMyHandle(), "ExtraItemsOnConfigReload"));
	ConfigSetConfigHandle(File_ExtraItems, gServerData.ExtraItems);
}

/**
 * @brief Caches extraitem data from file into arrays.
 **/
void ExtraItemsOnCacheData(/*void*/)
{
	// Gets config file path
	static char sBuffer[PLATFORM_LINE_LENGTH];
	ConfigGetConfigPath(File_ExtraItems, sBuffer, sizeof(sBuffer));

	// Opens config
	KeyValues kvExtraItems;
	bool bSuccess = ConfigOpenConfigFile(File_ExtraItems, kvExtraItems);

	// Validate config
	if (!bSuccess)
	{
		LogEvent(false, LogType_Fatal, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "Unexpected error caching data from extraitems config file: \"%s\"", sBuffer);
		return;
	}
	
	// If array hasn't been created, then create
	if (gServerData.Sections == null)
	{
		// Initialize a section list array
		gServerData.Sections = new ArrayList(SMALL_LINE_LENGTH);
	}
	else
	{
		// Clear out the array of all data
		gServerData.Sections.Clear();
	}
	
	// Validate size
	int iSize = gServerData.ExtraItems.Length;
	if (!iSize)
	{
		LogEvent(false, LogType_Fatal, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "No usable data found in extraitems config file: \"%s\"", sBuffer);
		return;
	}
	
	// i = array index
	for (int i = 0; i < iSize; i++)
	{
		// Gets section name
		ArrayList arrayExtraItem = gServerData.ExtraItems.Get(i);
		arrayExtraItem.Get(EXTRAITEMS_DATA_SECTION, sBuffer, sizeof(sBuffer));

		// Push section into separated array
		gServerData.Sections.PushString(sBuffer);
	}

	// Cleanup array for rebuilding
	arrayExtraItem.Clean(); /// we flattening everything

	// i = array index
	iSize = gServerData.Sections.Length;
	for (int i = 0; i < iSize; i++)
	{
		// General
		gServerData.Sections.GetString(i, sBuffer, sizeof(sBuffer));
		kvExtraItems.Rewind();
		if (!kvExtraItems.JumpToKey(sBuffer))
		{
			// Log extraitem fatal
			LogEvent(false, LogType_Fatal, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "Couldn't cache extraitem data for: \"%s\" (check extraitems config)", sBuffer);
			continue;
		}

		// Validate translation
		if (!TranslationIsPhraseExists(sBuffer))
		{
			// Log extraitem error
			LogEvent(false, LogType_Error, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "Couldn't cache extraitem section: \"%s\" (check translation file)", sBuffer);
			continue;
		}

		// Read keys in the file
		if (kvExtraItems.GotoFirstSubKey())
		{
			do
			{
				// Retrieves the sub section name
				kvExtraItems.GetSectionName(sBuffer, sizeof(sBuffer));
			
				// Validate translation
				if (!TranslationIsPhraseExists(sBuffer))
				{
					// Log menu error
					LogEvent(false, LogType_Error, LOG_CORE_EVENTS, LogModule_Menus, "Config Validation", "Couldn't cache extraitem name: \"%s\" (check translation file)", sBuffer);
					continue;
				}
				
								
				// Creates new array to store information
				ArrayList arrayExtraItem = new ArrayList(NORMAL_LINE_LENGTH);

				// Push data into array
				arrayExtraItem.Push(i);                                // Index: 0
				arrayExtraItem.PushString(sBuffer);                    // Index: 1
				kvExtraItems.GetString("info", sBuffer, sizeof(sBuffer), "");
				if (!TranslationIsPhraseExists(sBuffer) && hasLength(sBuffer))
				{
					// Log extraitem error
					LogEvent(false, LogType_Error, LOG_CORE_EVENTS, LogModule_ExtraItems, "Config Validation", "Couldn't cache extraitem info: \"%s\" (check translation file)", sBuffer);
				}
				arrayExtraItem.PushString(sBuffer);                    // Index: 2
				kvExtraItems.GetString("weapon", sBuffer, sizeof(sBuffer), ""); 
				arrayExtraItem.Push(WeaponsNameToIndex(sBuffer));      // Index: 3
				arrayExtraItem.Push(kvExtraItems.GetNum("cost", 0));   // Index: 4
				arrayExtraItem.Push(kvExtraItems.GetNum("level", 0));  // Index: 5
				arrayExtraItem.Push(kvExtraItems.GetNum("online", 0)); // Index: 6
				arrayExtraItem.Push(kvExtraItems.GetNum("limit", 0));  // Index: 7
				kvExtraItems.GetString("flags", sBuffer, sizeof(sBuffer), ""); 
				arrayExtraItem.Push(ReadFlagString(sBuffer));          // Index: 8
				kvExtraItems.GetString("group", sBuffer, sizeof(sBuffer), ""); 
				arrayExtraItem.PushString(sBuffer);                    // Index: 9
				kvExtraItems.GetString("class", sBuffer, sizeof(sBuffer), ""); 
				arrayExtraItem.PushString(sBuffer);                    // Index: 10
				
				// Store this handle in the main array
				gServerData.ExtraItems.Push(arrayConfigEntry);
			}
			while (kvExtraItems.GotoNextKey());
		}
	}

	// We're done with this file now, so we can close it
	delete kvExtraItems;
}

/**
 * @brief Called when configs are being reloaded.
 **/
public void ExtraItemsOnConfigReload(/*void*/)
{
	// Reloads extraitems config
	ExtraItemsOnLoad();
}

/**
 * @brief Creates commands for extra items module.
 **/
void ExtraItemsOnCommandInit(/*void*/)
{
	// Hook commands
	RegConsoleCmd("zitem", ExtraItemsOnCommandCatched, "Opens the extra items menu.");
}

/**
 * @brief Hook extra items cvar changes.
 **/
void ExtraItemsOnCvarInit(/*void*/)
{
	// Creates cvars
	gCvarList.EXTRAITEMS = FindConVar("zp_extraitems");
}

/**
 * Console command callback (zitem)
 * @brief Opens the extra items menu.
 * 
 * @param client            The client index.
 * @param iArguments        The number of arguments that were in the argument string.
 **/ 
public Action ExtraItemsOnCommandCatched(int client, int iArguments)
{
	ItemsMenu(client);
	return Plugin_Handled;
}

/**
 * @brief Fake client has been think.
 *
 * @param client            The client index.
 **/
void ExtraItemsOnFakeClientThink(int client)
{
	// Buying chance
	if (GetRandomInt(0, 10))
	{
		return
	} 
	
	// If mode already started, then stop
	if ((gServerData.RoundStart && !ModesIsExtraItem(gServerData.RoundMode) && !gClientData[client].Zombie) || gServerData.RoundEnd)
	{ 
		return;
	}
	
	// Get random item
	int iD = GetRandomInt(0, gServerData.ExtraItems.Length - 1);
	
	// Validate access
	if (!ItemsValidateClass(client, iD)) 
	{
		return;
	}
	
	// Call forward
	Action hResult;
	gForwardData._OnClientValidateExtraItem(client, iD, hResult);
	
	// Validate access
	if (hResult == Plugin_Stop || hResult == Plugin_Handled)
	{
		return;
	}
	
	// Gets extra item group
	static char sBuffer[SMALL_LINE_LENGTH];
	ItemsGetGroup(iD, sBuffer, sizeof(sBuffer));
	
	// Validate access
	if ((hasLength(sBuffer) && !IsPlayerInGroup(client, sBuffer)) || gClientData[client].Level < ItemsGetLevel(iD) || fnGetPlaying() < ItemsGetOnline(iD) || (ItemsGetLimit(iD) && ItemsGetLimit(iD) <= ItemsGetLimits(client, iD)) || (ItemsGetCost(iD) && gClientData[client].Money < ItemsGetCost(iD)))
	{
		return;
	}

	// Call forward
	gForwardData._OnClientBuyExtraItem(client, iD); /// Buy item

	// If item has a cost
	if (ItemsGetCost(iD))
	{
		// Remove money and store it for returning if player will be first zombie
		AccountSetClientCash(client, gClientData[client].Money - ItemsGetCost(iD));
		gClientData[client].LastPurchase += ItemsGetCost(iD);
	}
	
	// If item has a limit
	if (ItemsGetLimit(iD))
	{
		// Increment count
		ItemsSetLimits(client, iD, ItemsGetLimits(client, iD) + 1);
	}
	
	// If help messages enabled, then show info
	if (gCvarList.MESSAGES_ITEM_ALL.BoolValue)
	{
		// Gets client name
		static char sInfo[SMALL_LINE_LENGTH];
		GetClientName(client, sInfo, sizeof(sInfo));

		// Gets extra item name
		ItemsGetName(iD, sBuffer, sizeof(sBuffer));

		// Show item buying info
		TranslationPrintToChatAll("info buy", sInfo, sBuffer);
	}
}

/*
 * Extra items natives API.
 */

/**
 * @brief Sets up natives for library.
 **/
void ExtraItemsOnNativeInit(/*void*/)
{
	CreateNative("ZP_GiveClientExtraItem",     API_GiveClientExtraItem); 
	CreateNative("ZP_SetClientExtraItemLimit", API_SetClientExtraItemLimit); 
	CreateNative("ZP_GetClientExtraItemLimit", API_GetClientExtraItemLimit); 
	CreateNative("ZP_GetNumberExtraItem",      API_GetNumberExtraItem); 
	CreateNative("ZP_GetExtraItemNameID",      API_GetExtraItemNameID);
	CreateNative("ZP_GetExtraItemName",        API_GetExtraItemName); 
	CreateNative("ZP_GetExtraItemInfo",        API_GetExtraItemInfo); 
	CreateNative("ZP_GetExtraItemWeaponID",    API_GetExtraItemWeaponID); 
	CreateNative("ZP_GetExtraItemCost",        API_GetExtraItemCost); 
	CreateNative("ZP_GetExtraItemLevel",       API_GetExtraItemLevel); 
	CreateNative("ZP_GetExtraItemOnline",      API_GetExtraItemOnline); 
	CreateNative("ZP_GetExtraItemLimit",       API_GetExtraItemLimit); 
	CreateNative("ZP_GetExtraItemFlags",       API_GetExtraItemFlags); 
	CreateNative("ZP_GetExtraItemGroup",       API_GetExtraItemGroup); 
	CreateNative("ZP_GetExtraItemClass",       API_GetExtraItemClass);
}

/**
 * @brief Give the extra item to the client.
 *
 * @note native bool ZP_GiveClientExtraItem(client, iD);
 **/
public int API_GiveClientExtraItem(Handle hPlugin, int iNumParams)
{
	// Gets real player index from native cell 
	int client = GetNativeCell(1);
	
	// Validate client
	if (!IsPlayerExist(client, false))
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Player doens't exist (%d)", client);
		return -1;
	}
	
	// Gets item index from native cell
	int iD = GetNativeCell(2);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}

	// Call forward
	Action hResult;
	gForwardData._OnClientValidateExtraItem(client, iD, hResult);

	// Validate handle
	if (hResult == Plugin_Continue || hResult == Plugin_Changed)
	{
		// Call forward
		gForwardData._OnClientBuyExtraItem(client, iD); /// Buy item
		return true;
	}
	
	// Return on unsuccess
	return false;
}

/**
 * @brief Sets the buy limit of the current player item.
 *
 * @note native void ZP_SetClientExtraItemLimit(client, iD, limit);
 **/
public int API_SetClientExtraItemLimit(Handle hPlugin, int iNumParams)
{
	// Gets real player index from native cell 
	int client = GetNativeCell(1);
	
	// Validate client
	if (!IsPlayerExist(client, false))
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Player doens't exist (%d)", client);
		return -1;
	}
	
	// Gets item index from native cell
	int iD = GetNativeCell(2);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Sets buy limit of the current player item
	ItemsSetLimits(client, iD, GetNativeCell(3));
	
	// Return on success
	return iD;
}

/**
 * @brief Gets the buy limit of the current player item.
 *
 * @note native int ZP_GetClientExtraItemLimit(client, iD);
 **/
public int API_GetClientExtraItemLimit(Handle hPlugin, int iNumParams)
{
	// Gets real player index from native cell 
	int client = GetNativeCell(1);
	
	// Validate client
	if (!IsPlayerExist(client, false))
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Player doens't exist (%d)", client);
		return -1;
	}
	
	// Gets item index from native cell
	int iD = GetNativeCell(2);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return buy limit of the current player item
	return ItemsGetLimits(client, iD);
}

/**
 * @brief Gets the amount of all extra items.
 *
 * @note native int ZP_GetNumberExtraItem();
 **/
public int API_GetNumberExtraItem(Handle hPlugin, int iNumParams)
{
	return gServerData.ExtraItems.Length;
}

/**
 * @brief Gets the index of a extra item at a given name.
 *
 * @note native int ZP_GetExtraItemNameID(name);
 **/
public int API_GetExtraItemNameID(Handle hPlugin, int iNumParams)
{
	// Retrieves the string length from a native parameter string
	int maxLen;
	GetNativeStringLength(1, maxLen);

	// Validate size
	if (!maxLen)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Can't find item with an empty name");
		return -1;
	}
	
	// Gets native data
	static char sName[SMALL_LINE_LENGTH];

	// General
	GetNativeString(1, sName, sizeof(sName));

	// Return the value
	return ItemsNameToIndex(sName); 
}

/**
 * @brief Gets the name of a extra item at a given index.
 *
 * @note native void ZP_GetExtraItemName(iD, name, maxlen);
 **/
public int API_GetExtraItemName(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);

	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Gets string size from native cell
	int maxLen = GetNativeCell(3);

	// Validate size
	if (!maxLen)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "No buffer size");
		return -1;
	}
	
	// Initialize name char
	static char sName[SMALL_LINE_LENGTH];
	ItemsGetName(iD, sName, sizeof(sName));

	// Return on success
	return SetNativeString(2, sName, maxLen);
}

/**
 * @brief Gets the info of a extra item at a given index.
 *
 * @note native void ZP_GetExtraItemInfo(iD, info, maxlen);
 **/
public int API_GetExtraItemInfo(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);

	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Gets string size from native cell
	int maxLen = GetNativeCell(3);

	// Validate size
	if (!maxLen)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "No buffer size");
		return -1;
	}
	
	// Initialize info char
	static char sInfo[SMALL_LINE_LENGTH];
	ItemsGetInfo(iD, sInfo, sizeof(sInfo));

	// Return on success
	return SetNativeString(2, sInfo, maxLen);
}

/**
 * @brief Gets the weapon of a extra item at a given name.
 *
 * @note native int ZP_GetExtraItemWeaponID(iD);
 **/
public int API_GetExtraItemWeaponID(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);

	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return value
	return ItemsGetWeaponID(iD);
}

/**
 * @brief Gets the cost of the extra item.
 *
 * @note native int ZP_GetExtraItemCost(iD);
 **/
public int API_GetExtraItemCost(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return value
	return ItemsGetCost(iD);
}

/**
 * @brief Gets the level of the extra item.
 *
 * @note native int ZP_GetExtraItemLevel(iD);
 **/
public int API_GetExtraItemLevel(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return value
	return ItemsGetLevel(iD);
}

/**
 * @brief Gets the online of the extra item.
 *
 * @note native int ZP_GetExtraItemOnline(iD);
 **/
public int API_GetExtraItemOnline(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return value
	return ItemsGetOnline(iD);
}

/**
 * @brief Gets the limit of the extra item.
 *
 * @note native int ZP_GetExtraItemLimit(iD);
 **/
public int API_GetExtraItemLimit(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return value
	return ItemsGetLimit(iD);
}

/**
 * @brief Gets the flags of the extra item.
 *
 * @note native int ZP_GetExtraItemFlags(iD);
 **/
public int API_GetExtraItemFlags(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);
	
	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Return value
	return ItemsGetFlags(iD);
}

/**
 * @brief Gets the group of a extra item at a given index.
 *
 * @note native void ZP_GetExtraItemGroup(iD, group, maxlen);
 **/
public int API_GetExtraItemGroup(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);

	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Gets string size from native cell
	int maxLen = GetNativeCell(3);

	// Validate size
	if (!maxLen)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "No buffer size");
		return -1;
	}
	
	// Initialize group char
	static char sGroup[SMALL_LINE_LENGTH];
	ItemsGetGroup(iD, sGroup, sizeof(sGroup));

	// Return on success
	return SetNativeString(2, sGroup, maxLen);
}

/**
 * @brief Gets the class of a extra item at a given index.
 *
 * @note native void ZP_GetExtraItemClass(iD, class, maxlen);
 **/
public int API_GetExtraItemClass(Handle hPlugin, int iNumParams)
{
	// Gets item index from native cell
	int iD = GetNativeCell(1);

	// Validate index
	if (iD >= gServerData.ExtraItems.Length)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "Invalid the item index (%d)", iD);
		return -1;
	}
	
	// Gets string size from native cell
	int maxLen = GetNativeCell(3);

	// Validate size
	if (!maxLen)
	{
		LogEvent(false, LogType_Native, LOG_CORE_EVENTS, LogModule_ExtraItems, "Native Validation", "No buffer size");
		return -1;
	}
	
	// Initialize class char
	static char sClass[BIG_LINE_LENGTH];
	ItemsGetClass(iD, sClass, sizeof(sClass));

	// Return on success
	return SetNativeString(2, sClass, maxLen);
}

/*
 * Extra items data reading API.
 */
 
/**
 * @brief Gets the section of a item at a given index.
 *
 * @param iD                The item index.
 * @param sSection          The string to return section in.
 * @param iMaxLen           The lenght of string.
 **/
void ItemsGetSection(int iD, char[] sSection, int iMaxLen)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item section
	arrayExtraItem.GetString(EXTRAITEMS_DATA_SECTION, sSection, iMaxLen);
}

/**
 * @brief Gets the name of a item at a given index.
 *
 * @param iD                The item index.
 * @param sName             The string to return name in.
 * @param iMaxLen           The lenght of string.
 **/
void ItemsGetName(int iD, char[] sName, int iMaxLen)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item name
	arrayExtraItem.GetString(EXTRAITEMS_DATA_NAME, sName, iMaxLen);
}

/**
 * @brief Gets the info of a item at a given index.
 *
 * @param iD                The item index.
 * @param sInfo             The string to return info in.
 * @param iMaxLen           The lenght of string.
 **/
void ItemsGetInfo(int iD, char[] sInfo, int iMaxLen)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item info
	arrayExtraItem.GetString(EXTRAITEMS_DATA_INFO, sInfo, iMaxLen);
}

/**
 * @brief Gets the weapon for the item.
 *
 * @param iD                The item index.
 * @return                  The weapon id.    
 **/
int ItemsGetWeaponID(int iD)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item weapon
	return arrayExtraItem.Get(EXTRAITEMS_DATA_WEAPON);
}

/**
 * @brief Gets the cost for the item.
 *
 * @param iD                The item index.
 * @return                  The cost amount.    
 **/
int ItemsGetCost(int iD)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item cost
	return arrayExtraItem.Get(EXTRAITEMS_DATA_COST);
}

/**
 * @brief Gets the level for the item.
 *
 * @param iD                The item index.
 * @return                  The level value.    
 **/
int ItemsGetLevel(int iD)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item level
	return arrayExtraItem.Get(EXTRAITEMS_DATA_LEVEL);
}

/**
 * @brief Gets the online for the item.
 *
 * @param iD                The item index.
 * @return                  The online value.    
 **/
int ItemsGetOnline(int iD)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item online
	return arrayExtraItem.Get(EXTRAITEMS_DATA_ONLINE);
}

/**
 * @brief Gets the limit for the item.
 *
 * @param iD                The item index.
 * @return                  The limit value.    
 **/
int ItemsGetLimit(int iD)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item limit
	return arrayExtraItem.Get(EXTRAITEMS_DATA_LIMIT);
}

/**
 * @brief Remove the buy limit of the all client items.
 *
 * @param client            The client index.
 **/
void ItemsRemoveLimits(int client)
{
	// If array hasn't been created, then create
	if (gClientData[client].ItemLimit == null)
	{
		// Initialize a buy limit array
		gClientData[client].ItemLimit = new StringMap();
	}

	// Clear out the array of all data
	gClientData[client].ItemLimit.Clear();
}

/**
 * @brief Sets the buy limit of the current client item.
 *
 * @param client            The client index.
 * @param iD                The item index.
 * @param iLimit            The limit value.    
 **/
void ItemsSetLimits(int client, int iD, int iLimit)
{
	// If array hasn't been created, then create
	if (gClientData[client].ItemLimit == null)
	{
		// Initialize a buy limit array
		gClientData[client].ItemLimit = new StringMap();
	}

	// Initialize key char
	static char sKey[SMALL_LINE_LENGTH];
	IntToString(iD, sKey, sizeof(sKey));
	
	// Sets buy limit for the client
	gClientData[client].ItemLimit.SetValue(sKey, iLimit);
}

/**
 * @brief Gets the buy limit of the current client item.
 *
 * @param client            The client index.
 * @param iD                The item index.
 **/
int ItemsGetLimits(int client, int iD)
{
	// If array hasn't been created, then create
	if (gClientData[client].ItemLimit == null)
	{
		// Initialize a buy limit array
		gClientData[client].ItemLimit = new StringMap();
	}
	
	// Initialize key char
	static char sKey[SMALL_LINE_LENGTH];
	IntToString(iD, sKey, sizeof(sKey));
	
	// Gets buy limit for the client
	int iLimit; gClientData[client].ItemLimit.GetValue(sKey, iLimit);
	return iLimit;
}

/**
 * @brief Gets the flags for the item.
 *
 * @param iD                The item index.
 * @return                  The flags values.   
 **/
int ItemsGetFlags(int iD)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item flags
	return arrayExtraItem.Get(EXTRAITEMS_DATA_FLAGS);
}

/**
 * @brief Gets the group of a item at a given index.
 *
 * @param iD                The item index.
 * @param sGroup            The string to return group in.
 * @param iMaxLen           The lenght of string.
 **/
void ItemsGetGroup(int iD, char[] sGroup, int iMaxLen)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item group
	arrayExtraItem.GetString(EXTRAITEMS_DATA_GROUP, sGroup, iMaxLen);
}

/**
 * @brief Gets the class of a item at a given index.
 *
 * @param iD                The item index.
 * @param sClass            The string to return class in.
 * @param iMaxLen           The lenght of string.
 **/
void ItemsGetClass(int iD, char[] sClass, int iMaxLen)
{
	// Gets array handle of extra item at given index
	ArrayList arrayExtraItem = gServerData.ExtraItems.Get(iD);

	// Gets extra item class
	arrayExtraItem.GetString(EXTRAITEMS_DATA_CLASS, sClass, iMaxLen);
}

/*
 * Stocks extra items API.
 */

/**
 * @brief Find the index at which the extraitem name is at.
 * 
 * @param sName             The item name.
 * @return                  The array index containing the given item name.
 **/
int ItemsNameToIndex(char[] sName)
{
	// Initialize name char
	static char sItemName[SMALL_LINE_LENGTH];
	
	// i = item index
	int iSize = gServerData.ExtraItems.Length;
	for (int i = 0; i < iSize; i++)
	{
		// Gets item name 
		ItemsGetName(i, sItemName, sizeof(sItemName));
		
		// If names match, then return index
		if (!strcmp(sName, sItemName, false))
		{
			// Return this index
			return i;
		}
	}
	
	// Name doesn't exist
	return -1;
}

/**
 * @brief Returns true if the player has an access by the class to the item id, false if not.
 *
 * @param client            The client index.
 * @param iD                The item id.
 * @return                  True or false.    
 **/
bool ItemsValidateClass(int client, int iD)
{
	// Gets item class
	static char sClass[BIG_LINE_LENGTH];
	ItemsGetClass(iD, sClass, sizeof(sClass));
	
	// Validate length
	if (hasLength(sClass))
	{
		// Gets class type 
		static char sType[SMALL_LINE_LENGTH];
		ClassGetType(gClientData[client].Class, sType, sizeof(sType));
		
		// If class find, then return
		return (hasLength(sType) && StrContain(sType, sClass, ','));
	}
	
	// Return on success
	return true;
}

/*
 * Menu extra items API.
 */

/**
 * @brief Creates the extra items menu.
 *  
 * @param client            The client index.
 **/ 
void ItemsMenu(int client)
{
	// If module is disabled, then stop
	if (!gCvarList.EXTRAITEMS.BoolValue)
	{
		return;
	}
	
	// Validate client
	if (!IsPlayerExist(client))
	{
		return;
	}

	// If mode already started, then stop
	if (gServerData.RoundStart && !ModesIsExtraItem(gServerData.RoundMode) && !gClientData[client].Zombie)
	{
		// Show block info
		TranslationPrintHintText(client, "block buying round");     

		// Emit error sound
		EmitSoundToClient(client, SOUND_WEAPON_CANT_BUY, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);
		return;
	}

	// Initialize variables
	static char sBuffer[NORMAL_LINE_LENGTH];
	static char sName[SMALL_LINE_LENGTH];
	static char sInfo[SMALL_LINE_LENGTH];
	static char sLevel[SMALL_LINE_LENGTH];
	static char sLimit[SMALL_LINE_LENGTH];
	static char sOnline[SMALL_LINE_LENGTH];
	static char sGroup[SMALL_LINE_LENGTH];
	
	// Gets amount of total players
	int iPlaying = fnGetPlaying();

	// Creates extra items menu handle
	Menu hMenu = new Menu(ItemsMenuSlots);

	// Sets language to target
	SetGlobalTransTarget(client);
	
	// Sets title
	hMenu.SetTitle("%t", "buy extraitems");
	
	/*if (REDIRECT ON)*/
	{
		// Format some chars for showing in menu
		FormatEx(sBuffer, sizeof(sBuffer), "%t\n \n", "buy equipments");
		
		// Show add option
		hMenu.AddItem("-1", sBuffer);
	}
	
	// Initialize forward
	Action hResult;

	// i = extraitem index
	int iSize = gServerData.ExtraItems.Length; int iAmount;
	for (int i = 0; i < iSize; i++)
	{
		// Call forward
		gForwardData._OnClientValidateExtraItem(client, i, hResult);
		
		// Skip, if item is disabled
		if (hResult == Plugin_Stop)
		{
			continue;
		}
		
		// Skip some item, if class isn't equal
		if (!ItemsValidateClass(client, i)) 
		{
			continue;
		}
		
		// Gets extra item data
		ItemsGetName(i, sName, sizeof(sName));
		ItemsGetGroup(i, sGroup, sizeof(sGroup));

		// Format some chars for showing in menu
		FormatEx(sLevel, sizeof(sLevel), "%t", "level", ItemsGetLevel(i));
		FormatEx(sLimit, sizeof(sLimit), "%t", "limit", ItemsGetLimit(i));
		FormatEx(sOnline, sizeof(sOnline), "%t", "online", ItemsGetOnline(i));
		FormatEx(sBuffer, sizeof(sBuffer), (ItemsGetCost(i)) ? "%t  %s  %t" : "%t  %s", sName, (hasLength(sGroup) && !IsPlayerInGroup(client, sGroup)) ? sGroup : (gClientData[client].Level < ItemsGetLevel(i)) ? sLevel : (ItemsGetLimit(i) && ItemsGetLimit(i) <= ItemsGetLimits(client, i)) ? sLimit : (iPlaying < ItemsGetOnline(i)) ? sOnline :  "", "price", ItemsGetCost(i), "money");

		// Show option
		IntToString(i, sInfo, sizeof(sInfo));
		hMenu.AddItem(sInfo, sBuffer, MenusGetItemDraw((hResult == Plugin_Handled || (hasLength(sGroup) && !IsPlayerInGroup(client, sGroup)) || gClientData[client].Level < ItemsGetLevel(i) || iPlaying < ItemsGetOnline(i) || (ItemsGetLimit(i) && ItemsGetLimit(i) <= ItemsGetLimits(client, i)) || (ItemsGetCost(i) && gClientData[client].Money < ItemsGetCost(i))) ? false : true));
	
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
	hMenu.Display(client, MENU_TIME_FOREVER); 
}

/**
 * @brief Called when client selects option in the extra items menu, and handles it.
 *  
 * @param hMenu             The handle of the menu being used.
 * @param mAction           The action done on the menu (see menus.inc, enum MenuAction).
 * @param client            The client index.
 * @param mSlot             The slot index selected (starting from 0).
 **/ 
public int ItemsMenuSlots(Menu hMenu, MenuAction mAction, int client, int mSlot)
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
				int iD[2]; iD = MenusCommandToArray("zitem");
				if (iD[0] != -1) SubMenu(client, iD[0]);
			}
		}
		
		// Client selected an option
		case MenuAction_Select :
		{
			// Validate client
			if (!IsPlayerExist(client))
			{
				return 0;
			}
			
			// If mode already started, then stop
			if ((gServerData.RoundStart && !ModesIsExtraItem(gServerData.RoundMode) && !gClientData[client].Zombie) || gServerData.RoundEnd)
			{
				// Show block info
				TranslationPrintHintText(client, "block buying round");

				// Emit error sound
				EmitSoundToClient(client, SOUND_WEAPON_CANT_BUY, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);    
				return 0;
			}

			// Gets menu info
			static char sBuffer[SMALL_LINE_LENGTH];
			hMenu.GetItem(mSlot, sBuffer, sizeof(sBuffer));
			int iD = StringToInt(sBuffer);
			
			// Validate button info
			switch (iD)
			{
				// Client hit 'Redirect' button
				case -1 :
				{
					// Opens market menu
					ZMarketBuyMenu(client, _, "buy equipments"); 
				}
			
				// Client hit 'Item' button
				default :
				{
					// Gets extra item name
					ItemsGetName(iD, sBuffer, sizeof(sBuffer));
					
					// Call forward
					Action hResult;
					gForwardData._OnClientValidateExtraItem(client, iD, hResult);

					// Validate handle
					if (hResult == Plugin_Continue || hResult == Plugin_Changed)
					{
						// Validate access
						if (ItemsValidateClass(client, iD)) 
						{
							// Call forward
							gForwardData._OnClientBuyExtraItem(client, iD); /// Buy item
					
							// If item has a cost
							if (ItemsGetCost(iD))
							{
								// Remove money and store it for returning if player will be first zombie
								AccountSetClientCash(client, gClientData[client].Money - ItemsGetCost(iD));
								gClientData[client].LastPurchase += ItemsGetCost(iD);
							}
							
							// If item has a limit
							if (ItemsGetLimit(iD))
							{
								// Increment count
								ItemsSetLimits(client, iD, ItemsGetLimits(client, iD) + 1);
							}
							
							// If help messages enabled, then show info
							if (gCvarList.MESSAGES_ITEM_ALL.BoolValue)
							{
								// Gets client name
								static char sInfo[SMALL_LINE_LENGTH];
								GetClientName(client, sInfo, sizeof(sInfo));

								// Show item buying info
								TranslationPrintToChatAll("info buy", sInfo, sBuffer);
							}
						
							// If help messages enabled, then show info
							if (gCvarList.MESSAGES_ITEM_INFO.BoolValue)
							{
								// Gets item info
								ItemsGetInfo(iD, sBuffer, sizeof(sBuffer));
								
								// Show item personal info
								if (hasLength(sBuffer)) TranslationPrintHintText(client, sBuffer);
							}
							
							// Return on success
							return 0;
						}
					}

					// Show block info
					TranslationPrintHintText(client, "block buying item", sBuffer);
			
					// Emit error sound
					EmitSoundToClient(client, SOUND_WEAPON_CANT_BUY, SOUND_FROM_PLAYER, SNDCHAN_ITEM, SNDLEVEL_WHISPER);
				}
			}
		}
	}
	
	return 0;
}
