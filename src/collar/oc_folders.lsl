// This file is part of OpenCollar.
// Copyright (c) 2008 - 2017 Satomi Ahn, Nandana Singh, Wendy Starfall,  
// Medea Destiny, Romka Swallowtail, littlemousy, Sumi Perl,        
// Garvin Twine et al. 
// Licensed under the GPLv2.  See LICENSE for full details. 


string g_sParentMenu = "RLV";

string g_sSubMenu = "# Folders";

//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
//integer CMD_SAFEWORD = 510;
//integer CMD_RELAY_SAFEWORD = 511;
//integer CMD_BLOCKED = 520;

integer NOTIFY = 1002;
//integer SAY = 1004;
integer REBOOT              = -1000;
integer LINK_DIALOG         = 3;
integer LINK_RLV            = 4;
integer LINK_SAVE           = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;


integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
//integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
//integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
//integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..
integer RLVA_VERSION = 6004; //RLV Plugins can recieve the used rl viewer version upon receiving this message..
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string PARENT = "⏎";
string ACTIONS_CURRENT = "Actions";

string UPMENU = "BACK";

// Folder actions

string ADD_ALL = "Add all";
string DETACH_ALL = "Detach all";
string ADD = "Add this";
string DETACH = "Detach this";
string LOCK_ATTACH_ALL = "Lock att. all";
string LOCK_DETACH_ALL = "Lock det. all";
string LOCK_ATTACH = "Lock att. this";
string LOCK_DETACH = "Lock det. this";

list g_lFolderLocks; // strided list: folder path, lock type (4 bits field)

string g_sRootFolder = "";

integer g_iTimeOut = 60;

integer g_iFolderRLV = 78467;
integer g_iRLVaOn = FALSE;

integer g_iPage = 0;

list    g_lMenuIDs;
integer g_iMenuStride = 3;

integer g_iListener;

// Asynchronous menu request. Alas still needed since some menus are triggered after an answer from the viewer.
key g_kAsyncMenuUser;
integer g_iAsyncMenuAuth;
integer g_iAsyncMenuRequested = FALSE;

string g_sFolderType; //what to do with those folders
string g_sCurrentFolder;

integer g_iQuickCount;
integer g_iQuickWorn;
list g_lQuickFolders;

integer g_iLastQuickCount;
integer g_iLastQuickTarget;
integer g_iLastQuickWorn;
list g_lLastQuickFolders;

list g_lToCheck; //stack of folders to check, used for subfolder tree search

list g_lSearchList; //list of folders to search

integer g_iLastFolderState;

key g_kWearer;
string g_sSettingToken = "rlvfolders_";
string g_sGlobalToken = "global_";

list g_lHistory;

integer g_iDebug = 0;

DebugFreeMem() {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+": "+(string)llGetFreeMemory()+" bytes free");
}

RlvSay(string sCmd) {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+" R> " + sCmd);
    llOwnerSay(sCmd);
}

RlvEcho(string sMsg) {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+" R< " + sMsg);
}

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenuID) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, sMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, sMenuID];
}

addToHistory(string folder) {
    if (!(~llListFindList(g_lHistory, [folder]))) g_lHistory+=[folder];
    g_lHistory = llList2List(g_lHistory, -10, -1);
}

ParentFolder() {
    g_iLastQuickCount = -1;
    list lFolders = llParseString2List(g_sCurrentFolder,["/"],[]);
    g_iPage = 0; // changing the folder also means going back to first page
    if (llGetListLength(lFolders)>1) {
        g_sCurrentFolder=llList2String(lFolders,0);
        integer i;
        for (i=1;i<llGetListLength(lFolders)-1;i++) g_sCurrentFolder+="/"+llList2String(lFolders,i);
    }
    else g_sCurrentFolder="";
}

QueryFolders(string sType) {
    g_sFolderType = sType;
    g_iFolderRLV = 9999 + llRound(llFrand(9999999.0));
    g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
    llSetTimerEvent(g_iTimeOut);
    RlvSay("@getinvworn:"+g_sCurrentFolder+"=" + (string)g_iFolderRLV);
}

string lockFolderButton(integer iLockState, integer iLockNum, integer iAuth) {
    string sOut;
    if ((iLockState >> (4 + iLockNum)) & 0x1) sOut = "☔";
    else if ((iLockState >> iLockNum) & 0x1) sOut = "✔";
    else sOut = "✘";
    if (iLockNum == 0) sOut += LOCK_ATTACH;
    else if (iLockNum == 1) sOut += LOCK_DETACH;
    else if (iLockNum == 2) sOut += LOCK_ATTACH_ALL;
    else if (iLockNum == 3) sOut += LOCK_DETACH_ALL;
    if (iAuth > CMD_GROUP) sOut = "("+sOut+")";
    return sOut;
}

string RelativeFolder() {
    if (g_sCurrentFolder == "" || g_sCurrentFolder == g_sRootFolder)
        return "root";
    if (g_sRootFolder != "" && !llSubStringIndex(g_sCurrentFolder, g_sRootFolder+"/"))
        return llGetSubString(g_sCurrentFolder, llStringLength(g_sRootFolder+"/"), -1);
    return g_sCurrentFolder;
}

HistoryMenu(key kAv, integer iAuth) {
    Dialog(kAv, "\nRecently worn #RLV folders:", g_lHistory, [UPMENU], 0, iAuth, "History");
}

FolderActionsMenu(integer iState, key kAv, integer iAuth) {
    integer iStateThis = iState / 10;
    integer iStateSub = iState % 10;
    integer iHaveBrowse = (g_sFolderType == "history");
    list lActions;
    
    g_sFolderType += "_actions";
    if (!iStateSub)
        g_sFolderType += "_sub";

    string sPrompt = "\n[RLV Folders]\n\nCurrent folder is " + RelativeFolder() + ".";
    if (g_sCurrentFolder != "") {
        integer iIndex = llListFindList(g_lFolderLocks, [g_sCurrentFolder]);
        integer iLock;
        if (~iIndex) iLock = llList2Integer(g_lFolderLocks, iIndex+1);

        if (iStateThis == 1 || iStateThis == 2) // there are items that can be added in current folder
            lActions += [ADD, lockFolderButton(iLock, 0, iAuth)];
        if (iStateThis == 2 || iStateThis == 3) // there are items that can be removed
            lActions += [DETACH, lockFolderButton(iLock, 1, iAuth)];
        if (iStateSub == 1 || iStateSub == 2) // there are items that can be added in descendant folder
            lActions += [ADD_ALL, lockFolderButton(iLock, 2, iAuth)];
        if (iStateSub == 2 || iStateSub == 3) // there are items that can be removed from descendant folders
            lActions += [DETACH_ALL, lockFolderButton(iLock, 3, iAuth)];
        if (g_iLastQuickCount == 1) {
            if (g_iLastQuickTarget == g_iLastQuickWorn)
                lActions += ["◀◀", "▶▶"];
            else
                lActions += ["▶◀", "-"];
            sPrompt += (string) [" [", g_iLastQuickTarget+1, "/", llGetListLength(g_lLastQuickFolders), "]"];
        }
    }
    sPrompt += "\n\nWhat do you want to do?";
    
    integer iIndex;
    integer iRows = llGetListLength(lActions) / 2;
    for (iIndex = 2; iIndex < iRows * 3 - 1; iIndex += 3) {
        string sInsert = "-";
        if (iRows == 5 && iIndex == 2) {
            sInsert = llList2String(lActions, -2);
        } else if (iRows == 5 && iIndex == 5) {
            sInsert = llList2String(lActions, -1);
        } else if (iHaveBrowse) {
            sInsert = "Browse";
            iHaveBrowse = FALSE;
        }
        lActions = llListInsertList(lActions, [sInsert], iIndex);
    }
    if (iRows == 5)
        lActions = llList2List(lActions, 0, 10);    
    if (iHaveBrowse)
        lActions += "Browse";

    Dialog(kAv, sPrompt, lActions, [UPMENU], 0, iAuth, "FolderActions");
}

QuickNavigate(string sMessage, key kAv) {
    if (sMessage == "◀◀") {
        g_iLastQuickTarget -= 1;
        if (g_iLastQuickTarget == -1) {
            g_iLastQuickTarget = llGetListLength(g_lLastQuickFolders) - 1;
        }
    } else if (sMessage == "▶▶") {
        g_iLastQuickTarget += 1;
        if (g_iLastQuickTarget == llGetListLength(g_lLastQuickFolders)) {
            g_iLastQuickTarget = 0;
        }
    }

    integer iTempCount = g_iLastQuickCount;
    ParentFolder();

    g_iLastQuickCount = iTempCount;
    g_iLastQuickWorn = g_iLastQuickTarget;
    g_iPage = g_iLastQuickWorn / 7; // number of items in a menu page (five are reserved: actions, parent, left, right, back)

    string sCommon = g_sCurrentFolder;
    string sButton = llList2String(g_lLastQuickFolders, g_iLastQuickWorn);
    g_iLastFolderState = StateFromButton(sButton);
    g_sCurrentFolder += "/" + FolderFromButton(sButton);

    string sRlvCmd = "@detachallthis:" + g_sCurrentFolder + "=n,detachall:" + sCommon + "=force,attachover:" + g_sCurrentFolder + "=force,detachallthis:" + g_sCurrentFolder + "=y";

    if (g_iLastFolderState >= 10)
        g_iLastFolderState = 30 + (g_iLastFolderState % 10);
    if (g_iLastFolderState % 10)
        g_iLastFolderState = 3 + ((g_iLastFolderState / 10) * 10);

    RlvSay(sRlvCmd);
    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Now switching to "+g_sCurrentFolder, kAv);
}

string folderIcon(integer iState) {
    string sOut = "";
    integer iStateThis = iState / 10;
    integer iStateSub = iState % 10;
    if  (iStateThis==0) sOut += "⬚";
    else if (iStateThis==1) sOut += "◻";
    else if (iStateThis==2) sOut += "◩";
    else if (iStateThis==3) sOut += "◼";
    else sOut += " ";
    if (iStateSub==0) sOut += "⬚";
    else if (iStateSub==1) sOut += "◻";
    else if (iStateSub==2) sOut += "◩";
    else if (iStateSub==3) sOut += "◼";
    else sOut += " ";
    return sOut;
}

integer StateFromButton(string sButton) {
    string sIconThis = llGetSubString(sButton, 0, 0);
    string sIconSub = llGetSubString(sButton, 1, 1);
    integer iState;
    if (sIconThis=="◻") iState = 1;
    else if (sIconThis=="◩") iState = 2;
    else if (sIconThis=="◼") iState = 3;
    iState *= 10;
    if (sIconSub=="◻") iState +=1;
    else if (sIconSub=="◩") iState +=2;
    else if (sIconSub=="◼") iState += 3;
    return iState;
}

string FolderFromButton(string sButton) {
    return llToLower(llGetSubString(sButton, 2, -1));
}

updateFolderLocks(string sFolder, integer iAdd, integer iRem) {
// adds and removes locks for sFolder, which implies saving to central settings and triggering a RLV command (dolockFolder)
    integer iLock;
    integer iIndex = llListFindList(g_lFolderLocks, [sFolder]);
    if (~iIndex) {
        iLock = ((llList2Integer(g_lFolderLocks, iIndex+1) | iAdd) & ~iRem);
        if (iLock) {
            g_lFolderLocks = llListReplaceList(g_lFolderLocks, [iLock], iIndex+1, iIndex+1);
            doLockFolder(iIndex);
        } else {
            g_lFolderLocks = llDeleteSubList(g_lFolderLocks, iIndex, iIndex+1);
            llMessageLinked(LINK_RLV,RLV_CMD,  "attachthis_except:"+sFolder+"=y,detachthis_except:"+sFolder+"=y,attachallthis_except:"+sFolder+"=y,detachallthis_except:"+sFolder+"=y,"+ "attachthis:"+sFolder+"=y,detachthis:"+sFolder+"=y,attachallthis:"+sFolder+"=y,detachallthis:"+sFolder+"=y", NULL_KEY);
        }
    } else {
        iLock = iAdd & ~iRem;
        g_lFolderLocks += [sFolder, iLock];
        iIndex = llGetListLength(g_lFolderLocks)-2;
        doLockFolder(iIndex);
    }
    if ([] != g_lFolderLocks) llMessageLinked(LINK_SAVE, LM_SETTING_SAVE,  g_sSettingToken + "Locks=" + llDumpList2String(g_lFolderLocks, ","), "");
    else llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,  g_sSettingToken + "Locks", "");
}

doLockFolder(integer iIndex) {
// sends command to the viewer to update all locks concerning folder #iIndex
    string sFolder = llList2String(g_lFolderLocks, iIndex);
    integer iLock = llList2Integer(g_lFolderLocks, iIndex + 1);
    string sRlvCom = "attachthis:"+sFolder+"=";
    if ((iLock >> 0) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachthis:"+sFolder+"=";
    if ((iLock >> 1) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",attachallthis:"+sFolder+"=";
    if ((iLock >> 2) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachallthis:"+sFolder+"=";
    if ((iLock >> 3) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",attachthis_except:"+sFolder+"=";
    if ((iLock >> 4) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachthis_except:"+sFolder+"=";
    if ((iLock >> 5) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",attachallthis_except:"+sFolder+"=";
    if ((iLock >> 6) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    sRlvCom += ",detachallthis_except:"+sFolder+"=";
    if ((iLock >> 7) & 1)  sRlvCom += "n"; else sRlvCom += "y";
    llMessageLinked(LINK_RLV,RLV_CMD,  sRlvCom, NULL_KEY);
}

// Browsing menu, called asynchronously only (after querying folder state). Queries user and auth from globals.
FolderBrowseMenu(string sStr) {
    g_iAsyncMenuRequested = FALSE;
    list lUtilityButtons = [UPMENU];
    string sPrompt = "\n[RLV Folders]\n\nCurrent folder is " + RelativeFolder() + ".\n";
    list sData = llParseStringKeepNulls(sStr, [","], []);
    string sFirst = llList2String(sData, 0);
    sData = llListSort(llList2List(sData, 1, -1), 1, 1);
    integer i;
    list lItem;
    integer iWorn;
    list lFolders = [];
    // now add the button for wearing all recursively when it makes sense
    if (g_sCurrentFolder != "" && g_sCurrentFolder != g_sRootFolder) {
        lItem=llParseString2List(sFirst,["|"],[]);
        iWorn=llList2Integer(lItem,0);
        g_iLastFolderState=iWorn;
        if (iWorn / 10 == 1 ) sPrompt += "It has wearable items";
        else if (iWorn / 10 == 2 ) sPrompt += "It has wearable and removable items";
        else if (iWorn / 10 == 3 ) sPrompt += "It has removable items";
        else if (iWorn / 10 == 0 ) sPrompt += "It does not directly have any wearable or removable item";
        sPrompt += ".\n";
        lUtilityButtons += [ACTIONS_CURRENT];
    }
    g_iQuickCount = 0;
    for (i=0; i < llGetListLength(sData); i++) {
        lItem = llParseString2List(llList2String(sData, i), ["|"], []);
        string sFolder = llList2String(lItem, 0);
        iWorn = llList2Integer(lItem, 1);
        if (iWorn != 0)
            lFolders += [folderIcon(iWorn) + sFolder];
        if (iWorn == 3 || iWorn == 30 || iWorn == 33) {
            g_iQuickCount += 1;
            g_iQuickWorn = i;
        }
    }
    if (g_iQuickCount != 1)
        g_iQuickWorn = -1;
    g_lQuickFolders = lFolders;
    sPrompt += "\n- Click "+ACTIONS_CURRENT+" to manage this folder content.\n- Click one of the subfolders to browse it.\n";
    if (g_sCurrentFolder != "" && g_sCurrentFolder != g_sRootFolder) {sPrompt += "- Click "+PARENT+" to browse parent folder.\n"; lUtilityButtons += [PARENT];}
    sPrompt += "- Click "+UPMENU+" to go back to "+g_sParentMenu+".\n";
    Dialog(g_kAsyncMenuUser, sPrompt, lFolders, lUtilityButtons, g_iPage, g_iAsyncMenuAuth, "FolderBrowse");
}

handleMultiSearch() {
    string sItem=llList2String(g_lSearchList,0);
    string pref1 = llGetSubString(sItem, 0, 0);
    string pref2 = llGetSubString(sItem, 0, 1);
    g_lSearchList=llDeleteSubList(g_lSearchList,0,0);

    if (pref1 == "+" || pref1 == "&") g_sFolderType = "searchattach";
    else if (pref1 == "-") g_sFolderType = "searchdetach";
    else jump next;  // operator was omitted, then repeat last action

    if (pref2 == "++" || pref2 == "--" || pref2 == "&&") {
        g_sFolderType += "all";
        sItem = llToLower(llGetSubString(sItem,2,-1));
    } else sItem = llToLower(llGetSubString(sItem,1,-1));
    if (pref1 == "&") g_sFolderType += "over";

    @next;

    searchSingle(sItem);
}

string g_sFirstsearch;
string g_sNextsearch;
string g_sBuildpath;

searchSingle(string sItem) {
    //open listener
    g_iFolderRLV = 9999 + llRound(llFrand(9999999.0));
    g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
    //start timer
    g_sFirstsearch="";
    g_sNextsearch="";
    g_sBuildpath="";
    if(~llSubStringIndex(sItem,"/")) {
        //we're doing a two-level search.
        list tlist=llParseString2List(sItem,["/"],[]);
        g_sFirstsearch=llList2String(tlist,0);
        g_sNextsearch=llList2String(tlist,1);
        sItem=g_sFirstsearch;
    }
    llSetTimerEvent(g_iTimeOut);
    if (g_iRLVaOn && g_sNextsearch == "")
        RlvSay("@findfolders:"+sItem+"="+(string)g_iFolderRLV); //use multiple folder matching from RLVa if we have it
    else
        RlvSay("@findfolder:"+sItem+"="+(string)g_iFolderRLV);
}

// set a dialog to be requested after the next viewer answer
SetAsyncMenu(key kAv, integer iAuth) {
    g_iAsyncMenuRequested = TRUE;
    g_kAsyncMenuUser = kAv;
    g_iAsyncMenuAuth = iAuth;
}

SetRoot(string sValue, integer iFromUser) {
    g_sRootFolder = llDumpList2String(llParseString2List(llToLower(llStringTrim(sValue, STRING_TRIM)), ["/"], []), "/");

    if (iFromUser) {
        if (g_sRootFolder)
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "RootFolder=" + g_sRootFolder, "");
        else
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken + "RootFolder", "");
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Root folder set to \"" + g_sRootFolder + "\".", g_kWearer);
    }
}

UserCommand(integer iNum, string sStr, key kID) {
    if (llToLower(sStr) == "folders" || llToLower(sStr) == "#rlv" || sStr == "menu # Folders") {
        g_iLastQuickCount = -1;
        g_sCurrentFolder = g_sRootFolder;
        QueryFolders("browse");
        SetAsyncMenu(kID, iNum);
    } else if (llToLower(sStr) == "history" || sStr == "menu ﹟RLV History") {
        g_iLastQuickCount = -1;
        HistoryMenu(kID, iNum);
    } else if (llToLower(llGetSubString(sStr, 0, 4)) == "#rlv ") {
        g_iLastQuickCount = -1;
        SetAsyncMenu(kID, iNum);
        g_sFolderType = "searchbrowse";
        string sPattern = llDeleteSubString(sStr,0, 4);
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Searching folder containing string \"" + sPattern + "\" for browsing.",g_kWearer);
        searchSingle(sPattern);
    } else if (kID == g_kWearer && !llSubStringIndex(sStr, "rootfolder ")) {
        SetRoot(llGetSubString(sStr, 11, -1), TRUE);
    } else if (kID == g_kWearer && sStr == "rootfolder") {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Root folder is \"" + g_sRootFolder + "\".", g_kWearer);
    } else if (llGetSubString(sStr,0,0)=="+"||llGetSubString(sStr,0,0)=="-"||llGetSubString(sStr,0,0)=="&") {
        g_kAsyncMenuUser = kID;
        g_lSearchList=llParseString2List(sStr,[","],[]);
        handleMultiSearch();
    }
}

default {
    on_rez(integer iParam) {
        llResetScript();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        DebugFreeMem();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum == RLV_CLEAR) { //this triggers for safeword as well
            g_lFolderLocks = [];
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,  g_sSettingToken + "Locks", NULL_KEY);
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == RLVA_VERSION) g_iRLVaOn = TRUE;
        else if (iNum == DIALOG_RESPONSE) {
integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                g_iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                if (sMenu == "History") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_RLV, iAuth, "menu " + g_sParentMenu, kAv);
                        return;
                    } else {
                        g_sCurrentFolder = sMessage;
                        g_iPage = 0;
                        SetAsyncMenu(kAv, iAuth);
                        QueryFolders("history");
                    }
                } else if (sMenu == "MultipleFoldersOnSearch") {
                    if (sMessage == UPMENU) {
                            g_sCurrentFolder = g_sRootFolder;
                            QueryFolders("browse");
                            return;
                    }
                    RlvSay("@"+llGetSubString(g_sFolderType,6,-1)+":"+sMessage+"=force");
                    addToHistory(sMessage);
                    llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now "+llGetSubString(g_sFolderType,6,11)+"ing "+sMessage,kAv);
                } else if (sMenu == "FolderBrowse") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_RLV, iAuth, "menu " + g_sParentMenu, kAv);
                        return;
                    } else if (sMessage == ACTIONS_CURRENT) {
                        FolderActionsMenu(g_iLastFolderState, kAv, iAuth);
                        return;
                    } else if (sMessage == PARENT) {
                        ParentFolder();
                    } else {
                        // a folder name was clicked
                        integer iState = StateFromButton(sMessage);
                        string folder = FolderFromButton(sMessage);
                        g_iLastFolderState = iState;
                        g_iLastQuickCount = g_iQuickCount;
                        g_iLastQuickTarget = llListFindList(g_lQuickFolders, [sMessage]);
                        g_iLastQuickWorn = g_iQuickWorn;
                        g_lLastQuickFolders = g_lQuickFolders;
                        if (g_sCurrentFolder == "")
                            g_sCurrentFolder = folder;
                        else
                            g_sCurrentFolder += "/" + folder;
                        if ((iState % 10) == 0) {
                            // open actions menu if requested folder does not have subfolders
                            FolderActionsMenu(iState, kAv, iAuth);
                            return;
                        }
                    }
                    g_iPage = 0;
                    SetAsyncMenu(kAv, iAuth);
                    QueryFolders("browse");
                } else if (sMenu == "FolderActions") {
                    integer iStateThis = g_iLastFolderState / 10;
                    integer iStateSub = g_iLastFolderState % 10;
                    if (sMessage == ADD) {
                        RlvSay("@attachover:" + g_sCurrentFolder + "=force");
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now adding "+g_sCurrentFolder,kAv);
                        if (~g_iLastQuickCount)
                            g_iLastQuickCount += 1;
                        iStateThis = 3;
                    } else if (sMessage == DETACH) {
                        RlvSay("@detach:" + g_sCurrentFolder + "=force");
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now detaching "+g_sCurrentFolder,kAv);
                        if (~g_iLastQuickCount)
                            g_iLastQuickCount -= 1;
                        iStateThis = 1;
                    } else if (sMessage == ADD_ALL) {
                        RlvSay("@attachallover:" + g_sCurrentFolder + "=force");
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now adding everything in "+g_sCurrentFolder,kAv);
                        if (~g_iLastQuickCount)
                            g_iLastQuickCount += 1;
                        iStateSub = 3;
                    } else if (sMessage == DETACH_ALL) {
                        RlvSay("@detachall:" + g_sCurrentFolder  + "=force");
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now detaching everything in "+g_sCurrentFolder,kAv);
                        if (~g_iLastQuickCount)
                            g_iLastQuickCount -= 1;
                        iStateSub = 1;
                    } else if (~llSubStringIndex("▶▶◀◀", sMessage)) {
                        QuickNavigate(sMessage, kAv);
                        iStateThis = g_iLastFolderState / 10;
                        iStateSub = g_iLastFolderState % 10;
                    } else if (sMessage == lockFolderButton(0x00, 0, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x01, 0x10);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now wearing "+g_sCurrentFolder+ " is forbidden (this overrides parent exceptions).",kAv);
                    } else if (sMessage == lockFolderButton(0x00,1, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x02, 0x20);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now removing "+g_sCurrentFolder+ " is forbidden (this overrides parent exceptions).",kAv);
                    } else if (sMessage == lockFolderButton(0x00, 2, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x04, 0x40);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now wearing "+g_sCurrentFolder+ " or its subfolders is forbidden (this overrides parent exceptions).",kAv);
                    } else if (sMessage == lockFolderButton(0x00, 3, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x08, 0x80);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now removing "+g_sCurrentFolder+ " or its subfolders is forbidden (this overrides parent exceptions).",kAv);
                    } else if (sMessage == lockFolderButton(0x0F, 0, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x10, 0x01);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now wearing "+g_sCurrentFolder+ " is exceptionally allowed (this overrides parent locks).",kAv);
                    } else if (sMessage == lockFolderButton(0x0F, 1, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x20, 0x02);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now removing "+g_sCurrentFolder+ " is exceptionally allowed (this overrides parent locks).",kAv);
                    } else if (sMessage == lockFolderButton(0x0F,2, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x40, 0x04);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now wearing "+g_sCurrentFolder+ " or its subfolders is exceptionally allowed (this overrides parent locks).",kAv);
                    } else if (sMessage == lockFolderButton(0x0F,3, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0x80, 0x08);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now removing "+g_sCurrentFolder+ " or its subfolders is exceptionally allowed (this overrides parent locks).",kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,0, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x11);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now there is no restriction or exception on wearing "+g_sCurrentFolder+ ".",kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,1, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x22);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now there is no restriction or exception on removing "+g_sCurrentFolder+ ".",kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,2, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x44);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now there is no restriction or exception on wearing "+g_sCurrentFolder+ " and its subfolders.",kAv);
                    } else if (sMessage == lockFolderButton(0xFFFF,3, 0)) {
                        updateFolderLocks(g_sCurrentFolder, 0, 0x88);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now there is no restriction or exception on removing "+g_sCurrentFolder+ " and its subfolders.",kAv);
                    } else if (llGetSubString(sMessage, 0, 0) == "(") {
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"%NOACCESS%",kAv);
                    }
                    if (sMessage != UPMENU) {
                        addToHistory(g_sCurrentFolder);
                        // redisplay folder actions menu
                        g_iLastFolderState = iStateThis * 10 + iStateSub;
                        FolderActionsMenu(g_iLastFolderState, kAv, iAuth);                        
                        return;
                    }
                    //Return to browse menu
                    if (llGetSubString(g_sFolderType, 0, 14) == "history_actions" && sMessage != "Browse") {
                        HistoryMenu(kAv, iAuth);
                        return;
                    }
                    if (llGetSubString(g_sFolderType, -4, -1) == "_sub")
                        ParentFolder();
                    SetAsyncMenu(kAv, iAuth);
                    QueryFolders("browse");
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "Locks") {
                    g_lFolderLocks = llParseString2List(sValue, [","], []);
                    integer iN = llGetListLength(g_lFolderLocks);
                    integer j;
                    for (j = 0; j < iN; j += 2) doLockFolder(j);
                } else if (sToken == "RootFolder") {
                    SetRoot(sValue, FALSE);
                }
            } else if (sToken == g_sGlobalToken+"debug") {
                g_iDebug = (integer) sValue;
                DebugFreeMem();
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    listen(integer iChan, string sName, key kID, string sMsg) {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        if (iChan == g_iFolderRLV) {   //we got a list of folders
            RlvEcho(sMsg);
            if (g_sFolderType=="browse") {
                if (sMsg == "") { // try again if the folder name was wrong (may happen if the inventory changed)
                    g_iLastQuickCount = -1;
                    g_sCurrentFolder = g_sRootFolder;
                    g_iPage = 0;
                    QueryFolders("browse");
                } else FolderBrowseMenu(sMsg);
            } else if (g_sFolderType=="history") {
                list sData = llParseStringKeepNulls(sMsg, [",", "|"], []);
                integer iState = llList2Integer(sData, 1);
                FolderActionsMenu(iState, g_kAsyncMenuUser, g_iAsyncMenuAuth);
            } else if (llGetSubString(g_sFolderType,0,5)=="search") {
                if (sMsg=="") llMessageLinked(LINK_DIALOG,NOTIFY,"0"+sMsg+"No folder found.",g_kAsyncMenuUser);
                else if (llGetSubString(g_sFolderType,6,-1)=="browse") {
                    g_iLastQuickCount = -1;
                    g_sCurrentFolder = sMsg;
                    QueryFolders("browse");
                } else {
                    if(g_sFirstsearch!="")
                    {
                        integer idx=llSubStringIndex(llToLower(sMsg),llToLower(g_sFirstsearch));
                        g_sBuildpath=llGetSubString(sMsg,0,idx);
                        sMsg=llDeleteSubString(sMsg,0,idx);
                        idx=llSubStringIndex(sMsg,"/");
                        g_sBuildpath+=llGetSubString(sMsg,0,idx);
                        g_sFirstsearch="";
                        g_iListener = llListen(g_iFolderRLV, "", llGetOwner(), "");
                        llSetTimerEvent(g_iTimeOut);
                        RlvSay("@getinv:"+g_sBuildpath+"="+(string)g_iFolderRLV);
                    } else {
                        if(g_sNextsearch!="") {
                            list tlist=llParseString2List(sMsg,[","],[]);
                            integer i=llGetListLength(tlist);
                            string found;
                            string test;
                            while(i) {
                                --i;
                                test=llList2String(tlist,i);
                                if(~llSubStringIndex(llToLower(test),llToLower(g_sNextsearch))) {
                                    i=0;
                                    found=test;
                                }
                            }
                            if(found=="") {
                                 llMessageLinked(LINK_DIALOG,NOTIFY,"0"+g_sNextsearch+" subfolder not found",g_kAsyncMenuUser);
                                 return;
                            } else sMsg=g_sBuildpath+"/"+found;
                            g_sNextsearch="";
                            g_sBuildpath="";
                        }
                        if ((llSubStringIndex(sMsg,",") >=0) && (g_iRLVaOn)) { //we have multiple results, bring up a menu
                            list lMultiFolders = llParseString2List(sMsg,[","],[]);
                            string sPrompt = "Multiple results found.  Please select an item\n";
                            sPrompt += "Current action is "+g_sFolderType+"\n";
                            Dialog(g_kAsyncMenuUser, sPrompt, lMultiFolders, [UPMENU], 0, iChan, "MultipleFoldersOnSearch");
                            return;
                        }
                        RlvSay("@"+llGetSubString(g_sFolderType,6,-1)+":"+sMsg+"=force");
                        addToHistory(sMsg);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Now "+llGetSubString(g_sFolderType,6,11)+"ing "+sMsg,g_kAsyncMenuUser);
                    }
                }
                if (g_lSearchList!=[]) handleMultiSearch();
            }
        }
    }

    timer() {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
    }
}
