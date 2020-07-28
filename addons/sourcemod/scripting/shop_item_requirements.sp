/*
Лог обновлений:
	v1.0.0
- релиз
	v1.0.1
- добавлены функции 'count' для Item_Finite
- добавлен пропуск по флагу
- оптимизация (всё сложено в один stock)
- добавлены логи
	v1.0.2
- переименнован ключ "To Equip" на "To Toggle On"
- добавлена поддержка "To Toggle Off", "To Sell", "To Transfer"
- добавлена поддержка секций инверсии "No Buyed" и "No Equipped"
- добавлена команда перезагрузки конфига "sm_reload_shop_requirements"
- добавлена поддержка требования кредитов
- добавлена поддержка '>=' и '<='
- добавлена поддержка "OnlyToVIPGroups"	(не проверял)
- добавлена поддержка "OnlyToAdminFlag"


Планы:
- выключать предмет если условие було нарушено (если снял какой-то предмет, то предмет, которому он требовался будет выключен)
- добавить API и сделать модуль для випки, что бы их скипало взависсимости от типа функции (To Buy, To Sell и тд)
- файл переводов, зачем??
- добавить ключ onlyVip (с указанием групп, any == всем) || onlyFlag		(работают вместе, или вип или флаг)
- добавлена поддержка указывания по количеству для предметов типа Item_Finite (пример по mining_farm есть в низу конфига)
- конвентировать конфиг в упрошённый конфиг
- блокировать отображение предмета если не был выполнен один из требований из "Buyed", "Equipped", ...
+ ключ "Credits", который задаёт количество кредитов +/- тоже включить сюда
+ добавить реверс, то-есть "не иметь" этих предметов
+ добавить команду на перезагрузку конфига
+ добавить функции для Item_Finite и Item_OlyBuy 
*/

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <shop>
#include <csgo_colors>
#undef REQUIRE_PLUGIN
#tryinclude <vip_core>
#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name		= "[SHOP] Item Requirements",
	author	  	= "ღ λŌK0ЌЭŦ ღ ™",
	description = "",
	version	 	= "1.0.2",
	url			= "iLoco#7631"
};

#define LOG(%1) LogToFile("addons/sourcemod/logs/Shop_Item_Requirements.log", %1) 

KeyValues kv;
bool gSkipComleted, gIsVipCoreReady;
int gSkipAdminFlag;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int max)
{
	MarkNativeAsOptional("VIP_IsClientVIP");
	MarkNativeAsOptional("VIP_GetClientVIPGroup");

	return APLRes_Success;
}

public void OnPluginStart()
{
	gIsVipCoreReady = LibraryExists("vip_core");
	RegAdminCmd("sm_reload_shop_requirements", CMD_ReloadCfg, ADMFLAG_RCON, "Перезагружает конфиг плагина shop_item_requirements");		
	LoadKv();
}

public Action CMD_ReloadCfg(int client, int args)
{
	LoadKv();
}

public void OnLibraryAdded(const char[] name)
{
	gIsVipCoreReady = (strcmp(name, "vip_core", false) == 0);
}

public void OnLibraryRemoved(const char[] name)
{
	gIsVipCoreReady = (strcmp(name, "vip_core", false) == 0);
}

public bool Shop_OnItemDescription(int client, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] description, char[] buffer, int maxlength)
{
	char buff[64];
	bool iHaveItem, iToggledOn, isChech;

	if((iHaveItem = Shop_IsClientHasItem(client, item_id)))
	{
		iToggledOn = Shop_IsClientItemToggled(client, item_id);
	}

	if(iHaveItem && !iToggledOn)
	{	
		isChech = !CheckClientRequrements(client, "To Toggle On", true, category_id, _, item_id, _, Shop_GetItemType(item_id));
		Format(buff, sizeof(buff), "включению");
	}
	else if(iToggledOn)
	{
		isChech = !CheckClientRequrements(client, "To Toggle Off", true, category_id, _, item_id, _, Shop_GetItemType(item_id));
		Format(buff, sizeof(buff), "выключению");
	}
	else if(iHaveItem)
	{
		isChech = !CheckClientRequrements(client, "To Sell", true, category_id, _, item_id, _, Shop_GetItemType(item_id));
		Format(buff, sizeof(buff), "продаже");
	}
	else if(menu_action == Menu_ItemTransfer)
	{
		isChech = !CheckClientRequrements(client, "To Transfer", true, category_id, _, item_id, _, Shop_GetItemType(item_id));
		Format(buff, sizeof(buff), "передаче");
	}
	else
	{
		isChech = !CheckClientRequrements(client, "To Buy", true, category_id, _, item_id, _, Shop_GetItemType(item_id));
		Format(buff, sizeof(buff), "покупке");
	}

	if(isChech)
	{
		Format(buffer, maxlength, "%sТребования к %s предмета вывеведены в чат и консоль!", strlen(buffer) ? "\n" : "", buff);	
		return true;
	}

	return false;
}

public void Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ToggleState toggle)
{
	static bool skip;

	if(skip)
		return;

	char category_copy[64], item_copy[64];
	Format(category_copy, sizeof(category_copy), category);
	Format(item_copy, sizeof(item_copy), item);

	if(!CheckClientRequrements(client, toggle == Toggle_Off ? "To Toggle Off" : "To Toggle On", false, category_id, category_copy, item_id, item_copy, Shop_GetItemType(item_id)))
	{
		skip = true;
		Shop_ToggleClientItem(client, item_id, toggle == Toggle_Off ? Toggle_On : Toggle_Off);
	}
}

public Action Shop_OnItemSell(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int &sell_price)
{
	char category_copy[64], item_copy[64];
	Format(category_copy, sizeof(category_copy), category);
	Format(item_copy, sizeof(item_copy), item);

	if(!CheckClientRequrements(client, "To Sell", false, category_id, category_copy, item_id, item_copy, type))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public bool Shop_OnItemTransfer(int client, int target, ItemId item_id)
{
	if(!CheckClientRequrements(client, "To Transfer", false, _, _, item_id, _, Shop_GetItemType(item_id)))
	{
		return false;
	}

	return true;
}

public Action Shop_OnItemBuy(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int &price, int &sell_price, int &value)
{
	char category_copy[64], item_copy[64];
	Format(category_copy, sizeof(category_copy), category);
	Format(item_copy, sizeof(item_copy), item);

	if(!CheckClientRequrements(client, "To Buy", false, category_id, category_copy, item_id, item_copy, type))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock bool CheckClientRequrements(int client, const char[] JumpTo, bool isPrint = false, CategoryId category_id = INVALID_CATEGORY, char category[64] = "", ItemId item_id, char item[64] = "", ItemType item_type)
{
	if(gSkipAdminFlag != -1 && GetUserFlagBits(client) & gSkipAdminFlag)
		return true;

	bool iBool, isCategoryEqupped, bRestrict = true, once, isReverse, isCreditsMode, isMore, isLess, isEquals, isVipOnlyMode, isAdminFlagOnlyMode;
	char exp[2][64], text[256], need_count[128];
	int count;
	ItemType itemtype;
	
	if(category_id == INVALID_CATEGORY)
		category_id = Shop_GetItemCategoryId(item_id);
	if(!category[0])
		Shop_GetCategoryById(category_id, category, sizeof(category));
	if(!item[0])
		Shop_GetItemById(item_id, item, sizeof(item));

	kv.Rewind();
	kv.ExportToFile("addons/shop_item_requirements.txt");

	if(kv.JumpToKey(category) && kv.JumpToKey(item) && kv.JumpToKey(JumpTo) && kv.GotoFirstSubKey())
	{
		do
		{
			kv.GetSectionName(category, sizeof(category));
			isCategoryEqupped = (StrContains(category, "Equipped", false) != -1);
			isReverse = (StrContains(category, "No", false) != -1);

			// if(item_type != Item_Togglable && kv.GotoFirstSubKey())
			// {
			// 	isCategoryEquppedMode = true;
			// 	iCount = Shop_GetClientItemCount(client, item_id) + 1;

			// 	do
			// 	{
			// 		kv.SavePosition();
			// 		kv.GetSectionName(category, sizeof(category));

			// 		isMore = (category[0] == '+');
			// 		isLess = (category[0] == '-');
			// 		count = StringToInt(category[(isMore || isLess) ? 1 : 0]);

			// 		if(isMore && iCount >= count)
			// 			break;
			// 		else if(isLess && iCount <= count)
			// 			break;
			// 		else if(iCount == count)
			// 			break;
			// 	}
			// 	while(kv.GotoNextKey());
			// }

			kv.SavePosition();

			if(kv.GotoFirstSubKey(false))
			{
				do
				{
					iBool = false;
					count = 0;
					need_count[0] = '\0';

					kv.GetString(NULL_STRING, item, sizeof(item));
					kv.GetSectionName(category, sizeof(category));

					isCreditsMode = (strcmp(category, "Credits", false) == 0);
					isVipOnlyMode = (strcmp(category, "OnlyToVIPGroups", false) == 0);
					isAdminFlagOnlyMode = (strcmp(category, "OnlyToAdminFlag", false) == 0);

					if(isAdminFlagOnlyMode)
					{
						int iFlags;
						if(!(iFlags = GetUserFlagBits(client)) && !isReverse)
							continue;

						int needFlags = ReadFlagString(item);
						
						iBool = view_as<bool>(needFlags & iFlags);
					}
					else if(isVipOnlyMode)
					{
						if(!gIsVipCoreReady || !item[0] || (!VIP_IsClientVIP(client) && !isReverse))
							continue;

						if(strcmp(item, "any", false) == 0)
						{
							iBool = true;
						}
						else
						{
							char exp2[16][32], iVipGroup[32];
							int cycle = ExplodeString(item, ";", exp2, sizeof(exp2), sizeof(exp2[]));

							VIP_GetClientVIPGroup(client, iVipGroup, sizeof(iVipGroup));

							for(int p = 0; p < cycle; p++)	if(strcmp(exp2[p], iVipGroup, false) == 0)
							{
								iBool = true;
								break;
							}
						}
					}
					else if(isCreditsMode)
					{
						isMore = (item[0] == '>');
						isLess = (item[0] == '<');
						isEquals = (item[1] == '=');
						count = StringToInt(item[(isMore || isLess) ? (isEquals ? 2 : 1) : 0]);

						if(isMore && isEquals)
						{
							Format(need_count, sizeof(need_count), "{OLIVE}%i{DEFAULT} и {GREEN}больше{DEFAULT}", count);
							iBool = (Shop_GetClientCredits(client) >= count);
						}
						else if(isLess && isEquals)
						{
							Format(need_count, sizeof(need_count), "{OLIVE}%i{DEFAULT} и {GREEN}меньше{DEFAULT}", count);
							iBool = (Shop_GetClientCredits(client) <= count);
						}
						else if(isMore)
						{
							Format(need_count, sizeof(need_count), "{GREEN}больше {OLIVE}%i{DEFAULT}", count);
							iBool = (Shop_GetClientCredits(client) > count);
						}
						else if(isLess)
						{
							Format(need_count, sizeof(need_count), "{GREEN}меньше {OLIVE}%i{DEFAULT}", count);
							iBool = (Shop_GetClientCredits(client) < count);
						}
						else
						{
							Format(need_count, sizeof(need_count), "{GREEN}ровно {OLIVE}%i{DEFAULT}", count);
							iBool = (Shop_GetClientCredits(client) == count);
						}
					}
					else
					{
						ExplodeString(item, ":", exp, sizeof(exp), sizeof(exp[]));
						Format(item, sizeof(item), exp[0]);

						if((category_id = Shop_GetCategoryId(category)) == INVALID_CATEGORY || !Shop_IsValidCategory(category_id))
						{
							LOG("Невалидная категория '%s' у предмета '%s'", category, item);
							continue;
						}

						if((item_id = Shop_GetItemId(category_id, item)) == INVALID_ITEM || !Shop_IsItemExists(item_id))
						{
							LOG("Невалидный предмет '%s' из категории '%s'", item, category);
							continue;
						}

						if(!isCategoryEqupped)
							iBool = Shop_IsClientHasItem(client, item_id);
						else
							iBool = (Shop_IsClientHasItem(client, item_id) && Shop_IsClientItemToggled(client, item_id));

						if((itemtype = Shop_GetItemType(item_id)) != Item_Togglable && isCategoryEqupped)
							continue;

						Shop_FormatItem(client, item_id, Menu_Buy, item, sizeof(item));
						Shop_GetCategoryNameById(category_id, category, sizeof(category));

						if(itemtype != Item_Togglable)
						{
							isMore = (exp[1][0] == '>');
							isLess = (exp[1][0] == '<');
							isEquals = (exp[1][1] == '=');
							count = StringToInt(exp[1][(isMore || isLess) ? (isEquals ? 2 : 1) : 0]);
							
							if(count)
							{
								if(isMore && isEquals)
								{
									Format(need_count, sizeof(need_count), "в количестве {OLIVE}%i{DEFAULT} и {GREEN}более {DEFAULT}штук", count);
									iBool = (Shop_GetClientItemCount(client, item_id) >= count);
								}
								else if(isLess && isEquals)
								{
									Format(need_count, sizeof(need_count), "в количестве {OLIVE}%i{DEFAULT} {GREEN}меньше {DEFAULT}штук", count);
									iBool = (Shop_GetClientItemCount(client, item_id) <= count);
								}
								else if(isMore)
								{
									Format(need_count, sizeof(need_count), "в количестве {GREEN}более {OLIVE}%i{DEFAULT} штук", count);
									iBool = (Shop_GetClientItemCount(client, item_id) > count);
								}
								else if(isLess)
								{
									Format(need_count, sizeof(need_count), "в количестве {GREEN}до {OLIVE}%i{DEFAULT} штук", count);
									iBool = (Shop_GetClientItemCount(client, item_id) < count);
								}
								else
								{
									Format(need_count, sizeof(need_count), "в количестве равным {OLIVE}%i{DEFAULT} штук", count);
									iBool = (Shop_GetClientItemCount(client, item_id) == count);
								}
							}
						}
					}

					// iBool = isCategoryEqupped ? !iBool : iBool;
					iBool =	isReverse ? !iBool : iBool;

					if(!bRestrict && iBool)
						bRestrict = iBool;

					if(gSkipComleted && iBool)
						continue;

					if(isPrint || isVipOnlyMode || isAdminFlagOnlyMode)
					{
						if(!once)
						{
							PrintToConsole(client, " ");
							CGOPrintToChat(client, " ");
							once = true;
						}

						if(isReverse)
						{
							if(isCreditsMode)
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s Нужно не иметь %s кредитов", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]" , need_count);
							else if(isVipOnlyMode)
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s Не нужно иметь VIP-статус", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]");
							else if(isAdminFlagOnlyMode)
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s Не нужно иметь флаги '{OLIVE}%s{DEFAULT}'", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]", item);
							else
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s {RED}%s {DEFAULT}'{OLIVE}%s{DEFAULT}' из категории '{OLIVE}%s{DEFAULT}' %s", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]", isCategoryEqupped ? "Выключенный" : "Не купленный", item, category, need_count);
						}
						else
						{
							if(isCreditsMode)
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s Нужно иметь %s кредитов", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]" , need_count);
							else if(isVipOnlyMode)
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s Нужно иметь VIP-статус", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]");
							else if(isAdminFlagOnlyMode)
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s Нужно иметь флаги '{OLIVE}%s{DEFAULT}'", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]", item);
							else
								Format(text, sizeof(text), "[{GREEN}SHOP{DEFAULT}] %s {GREEN}%s {DEFAULT}'{OLIVE}%s{DEFAULT}' из категории '{OLIVE}%s{DEFAULT}' %s", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]", isCategoryEqupped ? "Включить" : "Купить", item, category, need_count);
						}

						CGOPrintToChat(client, text);
						CGOReplaceColorSay(text, sizeof(text));
						PrintToConsole(client, text);
					}
				}
				while(kv.GotoNextKey(false));

				kv.GoBack();
			}
		}
		while(kv.GotoNextKey());
	}

	return bRestrict;
}

stock void LoadKv()
{
	char buff[256];
	BuildPath(Path_SM, buff, sizeof(buff), "configs/shop/item_requirements.txt");

	if(!FileExists(buff))
		SetFailState("Config file '%s' is not exists", buff);
	
	if(kv)
		delete kv;
	kv = new KeyValues("ItemRequiremets");
	// KeyValues kv_original = new KeyValues("ItemRequiremets");

	if(!kv.ImportFromFile(buff))
		SetFailState("Error reading config file '%s'. Check encoding, should be utf-8.", buff);

	gSkipComleted = view_as<bool>(kv.GetNum("skip completed", 0));

	kv.GetString("skip admin flag", buff, sizeof(buff));
	gSkipAdminFlag = buff[0] ? ReadFlagString(buff) : -1;

	// char category[64], item[64];
	// ItemId item_id;
	// CategoryId category_id;

	// if(kv_original.GotoFirstSubKey())
	// {
	// 	do
	// 	{
	// 		kv_original.GetSectionName(category, sizeof(category));

	// 		if(kv_original.GotoFirstSubKey())
	// 		{
	// 			do
	// 			{
	// 				kv_original.GetSectionName(item, sizeof(item));
					
	// 				if((category_id = Shop_GetCategoryId(category)) == INVALID_CATEGORY)
	// 				{
	// 					LOG("Невалидная категория '%s' у предмета '%s'", category, item);
	// 					continue;
	// 				}

	// 				if((item_id = Shop_GetItemId(category_id, item)) == INVALID_ITEM)
	// 				{
	// 					LOG("Невалидный предмет '%s' из категории '%s'", item, category);
	// 					continue;
	// 				}

	// 				Format(buff, sizeof(buff), "%i", item_id);
	// 				kv.JumpToKey(buff, true);
					
	// 				if(kv_original.GotoFirstSubKey())
	// 				{
	// 					do
	// 					{
	// 						kv_original.GetSectionName(category, sizeof(category));
	// 						kv.JumpToKey(category, true);

	// 						if(kv_original.GotoFirstSubKey())
	// 						{
	// 							do
	// 							{
	// 								kv_original.GetSectionName(category, sizeof(category));
	// 								kv.JumpToKey(category, true);

	// 								kv_original.SavePosition();

	// 								if(kv_original.GotoFirstSubKey(false))
	// 								{
	// 									do
	// 									{
	// 										kv_original.GetSectionName(category, sizeof(category));
	// 										kv_original.GetString(NULL_STRING, item, sizeof(item));

	// 										if((category_id = Shop_GetCategoryId(category)) == INVALID_CATEGORY)
	// 										{
	// 											// LOG("Невалидная категория '%s' у предмета '%s'", category, item);
	// 											// continue;
	// 										}

	// 										PrintToServer("category id: %i", category_id);

	// 										if((item_id = Shop_GetItemId(category_id, item)) == INVALID_ITEM || item_id == -1)
	// 										{
	// 											// LOG("Невалидный предмет '%s' из категории '%s'", item, category);
	// 											// continue;
	// 										}
	// 										PrintToServer("item id: %i", item_id);

	// 										Format(buff, sizeof(buff), "%i", item_id);
	// 										kv.SetString(buff, "1");
	// 									}
	// 									while(kv_original.GotoNextKey(false));

	// 									kv.GoBack();
	// 									kv_original.GoBack();
	// 								}
	// 							}
	// 							while(kv_original.GotoNextKey());
	// 						}
	// 					}
	// 					while(kv_original.GotoNextKey());
	// 				}
	// 			}
	// 			while(kv_original.GotoNextKey());
	// 		}
	// 	}
	// 	while(kv_original.GotoNextKey());
	// }

	// kv.Rewind();
	// kv.ExportToFile("addons/shop_item_requirements.txt");
}