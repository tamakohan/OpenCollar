// This file is part of OpenCollar.
// Copyright (c) 2009 - 2016 Cleo Collins, Nandana Singh, Satomi Ahn,   
// Joy Stipe, Wendy Starfall, Medea Destiny, littlemousy,         
// Romka Swallowtail, Garvin Twine et al.  
// Licensed under the GPLv2.  See LICENSE for full details. 


string g_sAppVersion = "1.0";

string g_sSubMenu = "Quote";
string g_sParentMenu = "Apps";
list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

key g_kWearer;

//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
//integer CMD_SAFEWORD = 510;
integer CMD_BLOCKED = 520;
integer CMD_WEARERLOCKEDOUT = 521;

integer NOTIFY = 1002;
//integer NOTIFY_OWNERS = 1003;
integer SAY = 1004;

integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

// FIXME unofficial constant here, what's the process for choosing these?
integer QUOTE_BUILT = 2612;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

integer QUOTE_DATE = 1;
integer QUOTE_RANK = 2;
integer QUOTE_LOCK = 4;

string g_sQuoteText = "";
string g_sQuoteCredit = "";
string g_sQuoteDate = "";
integer g_iQuoteRank = CMD_EVERYONE;
integer g_iQuoteAllowRank = CMD_EVERYONE;
integer g_iQuoteExtra = QUOTE_LOCK;

key g_kGroup = NULL_KEY;

string g_sBuiltQuoteText = "";
string g_sGlobalToken = "global_";

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string iMenuType) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, iMenuType], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, iMenuType];
}

string RankText(integer iRank) {
    if (iRank <= CMD_OWNER)
        return "owner";
    else if (iRank == CMD_TRUSTED)
        return "trusted";
    else if (iRank == CMD_GROUP)
        return "group";
    else if (iRank == CMD_WEARER)
        return "wearer";
    else if (iRank == CMD_BLOCKED)
        return "blocked";
    else // >= CMD_EVERYONE
        return "public";
}

string PermText(integer iPerm) {
    if (iPerm <= CMD_OWNER)
        return "owners only";
    else if (iPerm == CMD_TRUSTED)
        return "owners and trusteds only";
    else if (iPerm == CMD_GROUP)
        return "owners, trusted and group";
    else if (iPerm == CMD_WEARER)
        return "owners and wearer only";
    else if (iPerm == CMD_WEARERLOCKEDOUT)
        return "anyone but the wearer";
    else // >= CMD_EVERYONE
        return "anyone";
}

BuildQuoteText() {
    g_sBuiltQuoteText = "";
    if (g_sQuoteText != "") {
        g_sBuiltQuoteText += "“ " + g_sQuoteText + " ”\n ― secondlife:///app/agent/"+g_sQuoteCredit+"/about";
        if (g_iQuoteExtra & QUOTE_DATE) {
            if (g_sQuoteDate == "")
                g_sBuiltQuoteText += " (unknown date)";
            else
                g_sBuiltQuoteText += " " + g_sQuoteDate;
        }
        if (g_iQuoteExtra & QUOTE_RANK)
            g_sBuiltQuoteText += " (" + RankText(g_iQuoteRank) + ")";
    }
    llMessageLinked(LINK_ROOT, QUOTE_BUILT, g_sBuiltQuoteText, "");
}

string Checkbox(string sText, integer iChecked) {
    if (iChecked)
        return "☑ " + sText;
    else
        return "☐ " + sText;
}

string Selectbox(string sText, integer iSelected) {
    if (iSelected)
        return "☒ " + sText;
    else
        return "☐ " + sText;
}

QuoteMenu(key kID, integer iAuth) {
    string sPrompt = "\n[Quote]\t"+g_sAppVersion+"\n\n";
    if (g_sBuiltQuoteText)
        sPrompt += g_sBuiltQuoteText;
    else
        sPrompt += "No quote is currently set.";
    integer iPerm = g_iQuoteAllowRank;
    if (g_sQuoteText != "" && (g_iQuoteExtra & QUOTE_LOCK))
        iPerm = g_iQuoteRank;
    sPrompt += "\n\nQuote can be set by "+PermText(iPerm)+".";
    list lButtons = ["Set", "Erase", "Permission",
        Checkbox("Date", g_iQuoteExtra & QUOTE_DATE),
        Checkbox("Rank", g_iQuoteExtra & QUOTE_RANK),
        Checkbox("AutoLock", g_iQuoteExtra & QUOTE_LOCK)];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Quote");
}

QuotePermissionMenu(key kID, integer iAuth) {
    // is this overkill? maybe.
    // was it fun to write? yes!
    string sPrompt = "\n[Quote]\t"+g_sAppVersion+"\n\nChange who can set and erase quotes.";
    list lButtons = [
        Selectbox("Owner", g_iQuoteAllowRank <= CMD_OWNER),
        Selectbox("Trusted", g_iQuoteAllowRank == CMD_TRUSTED),
        Selectbox("Group", g_iQuoteAllowRank == CMD_GROUP),
        Selectbox("Wearer", g_iQuoteAllowRank == CMD_WEARER),
        Selectbox("Others", g_iQuoteAllowRank == CMD_WEARERLOCKEDOUT),
        Selectbox("Public", g_iQuoteAllowRank == CMD_EVERYONE)
    ];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "QuotePermission");
}

integer QuoteCheckPerm(key kAv, integer iAuth) {
    iAuth = TweakAuth(kAv, iAuth);
    // use manually set perm level by default
    integer iPerm = g_iQuoteAllowRank;
    // if AutoLock is enabled and a quote is set by someone of a certain rank,
    // use Rank instead of AllowRank, so that only that rank or higher can replace it
    if (g_sQuoteText != "" && (g_iQuoteExtra & QUOTE_LOCK))
        iPerm = g_iQuoteRank;
    // WEARERLOCKEDOUT overrides even vanilla
    if (iPerm == CMD_WEARERLOCKEDOUT)
        return (kAv != g_kWearer);
    // check WEARER specially because we don't want to allow TRUSTED or GROUP in that case
    if (iPerm == CMD_WEARER)
        return (iAuth == CMD_OWNER || iAuth == CMD_WEARER);
    // otherwise normal check
    return (iAuth >= CMD_OWNER && iAuth <= iPerm);
}

integer TweakAuth(key kAv, integer iAuth) {
    // we override vanilla here
    if (kAv == g_kWearer)
        return CMD_WEARER;
    // if iAuth is not CMD_GROUP, we're done here
    if (iAuth != CMD_GROUP)
        return iAuth;
    // ok, now this could mean group OR public
    // so if group is enabled we need to check for ourselves if kAv is in the correct group
    if (g_kGroup)
        if (((string)llGetObjectDetails(kAv, [OBJECT_GROUP]) == (string)g_kGroup) || llSameGroup(kAv))
            return CMD_GROUP;
    return CMD_EVERYONE;
}

SetNewQuote(string sMessage, key kAv, integer iAuth) {
    iAuth = TweakAuth(kAv, iAuth);
    g_sQuoteText = sMessage;
    if (sMessage == "") {
        g_sQuoteCredit = "";
        g_sQuoteDate = "";
        g_iQuoteRank = CMD_EVERYONE;
    } else {
        g_sQuoteCredit = (string) kAv;
        if (g_iQuoteExtra & QUOTE_DATE)
            g_sQuoteDate = llGetDate();
        else
            g_sQuoteDate = "";
        g_iQuoteRank = iAuth;
    }
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sGlobalToken+"quote="+g_sQuoteText+g_sQuoteCredit+(string)g_iQuoteRank, "");
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sGlobalToken+"quote_extra="+g_sQuoteDate+","+(string)g_iQuoteAllowRank+","+(string)g_iQuoteExtra, "");
    BuildQuoteText();
}

SetQuotePermission(integer iPerm) {
    g_iQuoteAllowRank = iPerm;
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sGlobalToken+"quote_extra="+g_sQuoteDate+","+(string)g_iQuoteAllowRank+","+(string)g_iQuoteExtra, "");
}

UserCommand(integer iNum, string sStr, key kID) { // here iNum: auth value, sStr: user command, kID: avatar id
    sStr = llToLower(sStr);
    if (sStr == "menu quote" || sStr == "quote" || sStr == g_sSubMenu) {
        QuoteMenu(kID, iNum);
    } else if (llSubStringIndex(sStr, "quote")==0) {
        // we could add commands here like "quote set", "quote erase", "quote date on" etc. but eh... menu is fine :)
    } else if (sStr == "rm quote") {
        if (kID!=g_kWearer && iNum!=CMD_OWNER)
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else
            Dialog(kID,"\nDo you really want to uninstall the "+g_sSubMenu+" App?", ["Yes","No","Cancel"], [], 0, iNum,"rmquote");
    }
}

default {
    on_rez(integer param) {
        g_kWearer=llGetOwner();
    }

    state_entry() {
        g_kWearer=llGetOwner();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            UserCommand(iNum, sStr, kID);
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                // integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMenu == "Quote") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_ROOT, iAuth, "menu "+g_sParentMenu, kAv);
                        return;
                    } else {
                        if (sMessage == "Set" || sMessage == "Erase") {
                            if (QuoteCheckPerm(kAv,iAuth)) {
                                if (sMessage == "Set") {
                                    string sPrompt = "\n[Quote]\n\nEnter a new quote for %WEARERNAME%'s %DEVICETYPE%. Leave empty to go back without changing it. Your name";
                                    if (g_iQuoteExtra & QUOTE_DATE)
                                        sPrompt += ", today's date";
                                    sPrompt += " and your current rank ("+RankText(TweakAuth(kAv, iAuth))+") will be remembered alongside it!";
                                    if (iAuth == CMD_OWNER && !(g_iQuoteExtra & QUOTE_DATE))
                                        sPrompt += " If you want to keep today's date alongside your quote, enable "+Checkbox("Date", TRUE)+" first.";
                                    Dialog(kAv, sPrompt, [], [], 0, iAuth, "QuoteSet");
                                    return;
                                } else { // "Erase"
                                    Dialog(kAv, "\n[Quote]\n\n"+g_sBuiltQuoteText+"\n\nReally erase this quote without setting a new one?", ["Erase it!"], [UPMENU], 0, iAuth, "QuoteErase");
                                    return;
                                }
                            } else {
                                llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kAv);
                            }
                        } else if (iAuth == CMD_OWNER) {
                            if (sMessage == "Permission") {
                                QuotePermissionMenu(kAv,iAuth);
                                return;
                            } else if (sMessage == Checkbox("Date", TRUE)) {
                                g_iQuoteExtra = g_iQuoteExtra &~ QUOTE_DATE;
                            } else if (sMessage == Checkbox("Date", FALSE)) {
                                g_iQuoteExtra = g_iQuoteExtra | QUOTE_DATE;
                            } else if (sMessage == Checkbox("Rank", TRUE)) {
                                g_iQuoteExtra = g_iQuoteExtra &~ QUOTE_RANK;
                            } else if (sMessage == Checkbox("Rank", FALSE)) {
                                g_iQuoteExtra = g_iQuoteExtra | QUOTE_RANK;
                            } else if (sMessage == Checkbox("AutoLock", TRUE)) {
                                g_iQuoteExtra = g_iQuoteExtra &~ QUOTE_LOCK;
                            } else if (sMessage == Checkbox("AutoLock", FALSE)) {
                                g_iQuoteExtra = g_iQuoteExtra | QUOTE_LOCK;
                            }
                            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sGlobalToken+"quote_extra="+g_sQuoteDate+","+(string)g_iQuoteAllowRank+","+(string)g_iQuoteExtra, "");
                            BuildQuoteText();
                        } else {
                            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kAv);
                        }
                    }
                } else if (sMenu == "QuoteSet") {
                    if (QuoteCheckPerm(kAv,iAuth)) {
                        if (sMessage != "" && sMessage != " ")
                            SetNewQuote(sMessage,kAv,iAuth);
                    } else {
                        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kAv);
                    }
                } else if (sMenu == "QuoteErase") {
                    if (sMessage == "Erase it!")
                        SetNewQuote("",kAv,iAuth);
                } else if (sMenu == "QuotePermission") {
                    if (iAuth == CMD_OWNER) {
                        if (sMessage == Selectbox("Owner", FALSE))
                            SetQuotePermission(CMD_OWNER);
                        else if (sMessage == Selectbox("Trusted", FALSE))
                            SetQuotePermission(CMD_TRUSTED);
                        else if (sMessage == Selectbox("Group", FALSE))
                            SetQuotePermission(CMD_GROUP);
                        else if (sMessage == Selectbox("Wearer", FALSE))
                            SetQuotePermission(CMD_WEARER);
                        else if (sMessage == Selectbox("Others", FALSE))
                            SetQuotePermission(CMD_WEARERLOCKEDOUT);
                        else if (sMessage == Selectbox("Public", FALSE))
                            SetQuotePermission(CMD_EVERYONE);
                    } else {
                        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kAv);
                    }
                } else if (sMenu == "rmquote") {
                    if (sMessage == "Yes") {
                        llMessageLinked(LINK_ROOT, QUOTE_BUILT, g_sBuiltQuoteText, "");
                        llMessageLinked(LINK_ROOT, MENUNAME_REMOVE , g_sParentMenu + "|" + g_sSubMenu, "");
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+g_sSubMenu+" App has been removed.", kAv);
                        if (llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT)
                            llRemoveInventory(llGetScriptName());
                    } else {
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sSubMenu+" App remains installed.", kAv);
                    }
                    return;
                }
                QuoteMenu(kAv, iAuth);
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if (iNum == LM_SETTING_RESPONSE) {
            integer i = llSubStringIndex(sStr, "=");
            string sToken = llGetSubString(sStr, 0, i - 1);
            string sValue = llGetSubString(sStr, i + 1, -1);
            if (sToken == g_sGlobalToken+"quote") {
                if (llStringLength(sValue) >= 40) {
                    string t_sQuoteCredit = llGetSubString(sValue, -39, -4);
                    if ((key) t_sQuoteCredit) {
                        integer t_iQuoteRank = (integer) llGetSubString(sValue, -3, -1);
                        if (t_iQuoteRank >= CMD_OWNER && t_iQuoteRank <= CMD_BLOCKED) {
                            g_sQuoteText = llGetSubString(sValue, 0, -40);
                            g_sQuoteCredit = t_sQuoteCredit;
                            g_iQuoteRank = t_iQuoteRank;
                            BuildQuoteText();
                        }
                    }
                }
            } else if (sToken == g_sGlobalToken+"quote_extra") {
                list lParts = llParseStringKeepNulls(sValue, [","], []);
                integer t_iQuoteAllowRank = llList2Integer(lParts, 1);
                if (t_iQuoteAllowRank >= CMD_OWNER && t_iQuoteAllowRank <= CMD_WEARERLOCKEDOUT) {
                    g_sQuoteDate = llList2String(lParts, 0);
                    g_iQuoteAllowRank = t_iQuoteAllowRank;
                    g_iQuoteExtra = llList2Integer(lParts, 2);
                }
                BuildQuoteText();
            } else if (sToken == "auth_group") {
                g_kGroup = (key) sValue;
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        /*} else if (iNum == CMD_OWNER && sStr == "runaway") {
            llSleep(4);*/
        } else if (iNum == REBOOT && sStr == "reboot") {
            llResetScript();
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER)
            llResetScript();
    }
}
