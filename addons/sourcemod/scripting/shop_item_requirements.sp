/*
Лог обновлений:
	v1.0.0
- релиз
	v1.0.1
- добавлены функции 'count' для Item_Finite
- добавлен пропуск по флагу
- оптимизация (всё сложено в один stock)
- добавлены логи


Планы:
- выключать предмет если условие було нарушено (если снял какой-то предмет, то предмет, которому он требовался будет выключен)
- ключ "Credits", который задаёт количество кредитов +/- тоже включить сюда
- файл переводов, зачем??
- добавить API и сделать модуль для випки, что бы их скипало взависсимости от типа функции (To Buy, To Sell и тд)
- добавить функции к другим forward'aм (передачи предмета, продаже и тд)
*/

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <shop>
#include <csgo_colors>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name		= "[SHOP] Item Requirements",
	author	  	= "ღ λŌK0ЌЭŦ ღ ™",
	description = "",
	version	 	= "1.0.1",
	url			= "iLoco#7631"
};

#define LOG(%1) LogToFile("addons/sourcemod/logs/Shop_Item_Requirements.log", %1) 

KeyValues kv;
bool gSkipComleted;
int gSkipAdminFlag;

public void OnPluginStart()
{
	LoadKv();
}

public bool Shop_OnItemDescription(int client, ShopMenu menu_action, CategoryId category_id, ItemId item_id, const char[] description, char[] buffer, int maxlength)
{
	bool iHaveItem;
	if(CheckClientRequrements(client, _, true, category_id, _, item_id, _, iHaveItem))
	{
		Format(buffer, maxlength, "%sТребования к %s предмета вывеведены в чат и консоль!", strlen(buffer) ? "\n" : "", iHaveItem ? "включению" : "покупке");	
		return true;
	}

	return false;
}

public Action Shop_OnItemBuy(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int &price, int &sell_price, int &value)
{
	char category_copy[64], item_copy[64];
	Format(category_copy, sizeof(category_copy), category);
	Format(item_copy, sizeof(item_copy), item);

	if(CheckClientRequrements(client, _, false, category_id, category_copy, item_id, item_copy, _))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void Shop_OnItemToggled(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ToggleState toggle)
{
	static bool skip;

	if(skip || toggle != Toggle_On)
		return;

	char category_copy[64], item_copy[64];
	Format(category_copy, sizeof(category_copy), category);
	Format(item_copy, sizeof(item_copy), item);

	if(CheckClientRequrements(client, _, false, category_id, category_copy, item_id, item_copy, _))
	{
		skip = true;
		Shop_ToggleClientItem(client, item_id, Toggle_Off);
	}
}

stock bool CheckClientRequrements(int client, const char[] JumpTo = "", bool isPrint = false, CategoryId category_id, char category[64] = "", ItemId item_id, char item[64] = "", bool &iHaveItem = false)
{
	if(gSkipAdminFlag != -1 && GetUserFlagBits(client) & gSkipAdminFlag)
		return false;

	if(Shop_IsClientItemToggled(client, item_id))
		return false;

	bool iBool, isEquipped, bRestrict = false, once;
	char exp[2][64], need_count[128];
	int count;
	ItemType itemtype;

	if(!category[0])
		Shop_GetCategoryById(category_id, category, sizeof(category));
	if(!item[0])
		Shop_GetItemById(item_id, item, sizeof(item));

	kv.Rewind();

	if(kv.JumpToKey(category) && kv.JumpToKey(item))
	{
		if(kv.JumpToKey(JumpTo[0] ? JumpTo : (iHaveItem = Shop_IsClientHasItem(client, item_id)) ? "To Equip" : "To Buy"))
		{
			if(kv.GotoFirstSubKey())
			{
				do
				{
					kv.GetSectionName(category, sizeof(category));
					isEquipped = (strcmp(category, "Equipped", false) == 0);

					kv.SavePosition();

					if(kv.GotoFirstSubKey(false))
					{
						do
						{
							kv.GetString(NULL_STRING, item, sizeof(item));
							kv.GetSectionName(category, sizeof(category));

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

							if(!isEquipped && (iBool = Shop_IsClientHasItem(client, item_id)) && gSkipComleted)
								continue;

							if(isEquipped && (iBool = Shop_IsClientItemToggled(client, item_id)) && gSkipComleted)
								continue;

							if((itemtype = Shop_GetItemType(item_id)) != Item_Togglable && isEquipped)
								continue;
							
							Shop_FormatItem(client, item_id, Menu_Buy, item, sizeof(item));
							Shop_GetCategoryNameById(category_id, category, sizeof(category));

							need_count[0] = '\0';
							if(itemtype != Item_Togglable)
							{
								bool isPlusOrMinus = (exp[1][0] == '>' || exp[1][0] == '<');
								count = StringToInt(exp[1][isPlusOrMinus ? 1 : 0]);
								
								if(isPlusOrMinus && exp[1][0] == '>')
								{
									Format(need_count, sizeof(need_count), "в количестве {GREEN}более {OLIVE}%i{DEFAULT} штук", count);
									iBool = (Shop_GetClientItemCount(client, item_id) > count);
								}
								else if(isPlusOrMinus)
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
							
							if(!bRestrict && iBool)
								bRestrict = iBool;

							if(isPrint)
							{
								if(!once)
								{
									PrintToConsole(client, " ");
									CGOPrintToChat(client, " ");
									once = true;
								}
								CGOPrintToChat(client, "[{GREEN}SHOP{DEFAULT}] %s %s '{OLIVE}%s{DEFAULT}' из категории '{OLIVE}%s{DEFAULT}' %s", iBool ? "[ {GREEN}+ {DEFAULT}]" : "[ {RED}- {DEFAULT}]", isEquipped ? "Включить" : "Купить", item, category, need_count);
								CGOReplaceColorSay(need_count, sizeof(need_count));
								PrintToConsole(client, "[SHOP] %s %s '%s' из категории '%s' %s", iBool ? "[ + ]" : "[ + ]", isEquipped ? "Включить" : "Купить", item, category, need_count);
							}
						}
						while(kv.GotoNextKey(false));

						kv.GoBack();
					}
				}
				while(kv.GotoNextKey());
			}
		}
	}

	return bRestrict;
}

stock void LoadKv()
{
	char buff[256];
	BuildPath(Path_SM, buff, sizeof(buff), "configs/shop/item_requirements.txt");

	if(!FileExists(buff))
		SetFailState("Config file '%s' is not exists", buff);

	kv = new KeyValues("ItemRequiremets");
	if(!kv.ImportFromFile(buff))
		SetFailState("Error reading config file '%s'. Check encoding, should be utf-8.", buff);

	gSkipComleted = view_as<bool>(kv.GetNum("skip completed", 0));

	kv.GetString("skip admin flag", buff, sizeof(buff));
	gSkipAdminFlag = buff[0] ? ReadFlagString(buff) : -1;
}