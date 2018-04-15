// This file is part of OpenCollar.
// Copyright (c) 2008 - 2017 Nandana Singh, Garvin Twine, Cleo Collins,  
// Satomi Ahn, Joy Stipe, Wendy Starfall, littlemousy, Romka Swallowtail, 
// Sumi Perl et al.   
// Licensed under the GPLv2.  See LICENSE for full details. 

// a sample script to put in your toys.
// should be customised to replace the SampleMenu with something relevant, OR have it LinkMessage another script, OR remove the "|Menu" from got_path altogether if the object doesn't have a menu.

// You will need to put ~oc_toy~ToyName~ in the prim description, ToyName can be up to 12 characters and will show in the Toys menu.

list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

key g_kWearer;
integer g_iCoreChan;
integer g_iCoreListener;

integer g_iRlvChan = 954264;
integer g_iRlvListener;

string g_sAttachMsg = "attach";

integer g_iTimerFunction = 0;
integer TIMER_NONE = 0;
integer TIMER_LOGIN = 1;
integer TIMER_GETPATH = 2;

integer LINK_DIALOG = LINK_THIS;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

debug(string sMessage) {
    llOwnerSay(" :: " + sMessage);
}

RlvSay(string sCmd) {
    //llOwnerSay(" :: " + sCmd);
    llOwnerSay(sCmd);
}

RlvEcho(string sMsg) {
    //llOwnerSay(" => " + sMsg);
}

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string iMenuType) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, iMenuType], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, iMenuType];
}

SampleMenu(key kActor, integer iAuth) {
    string sPrompt = "Sample menu";
    list lButtons = ["Button"];
    Dialog(kActor, sPrompt, lButtons, [UPMENU], 0, iAuth, "Sample");
}

integer check_perms() {
    integer ok = TRUE;
    
    if (!(llGetObjectPermMask(MASK_OWNER) & PERM_MODIFY)) {
        llOwnerSay("You have been given a no-modify OpenCollar object.  This could break future updates.  Please ask the provider to make the object modifiable.");
        ok = FALSE;
    }

    if (!(llGetObjectPermMask(MASK_NEXT) & PERM_MODIFY)) {
        llOwnerSay("You have put an OpenCollar script into an object that the next user cannot modify.  This could break future updates.  Please leave your OpenCollar objects modifiable.");
        ok = FALSE;
    }

    integer FULL_PERMS = PERM_COPY | PERM_MODIFY | PERM_TRANSFER;

    string sScript = llGetScriptName();
    if (llGetInventoryType(sScript) == INVENTORY_SCRIPT) {
        if (!((llGetInventoryPermMask(sScript,MASK_OWNER) & FULL_PERMS) == FULL_PERMS)) {
            llOwnerSay("The " + sScript + " script is not mod/copy/trans.  This is a violation of the OpenCollar license.  Please ask the person who gave you this script for a full-perms replacement.");
            ok = FALSE;
        }

        if (!((llGetInventoryPermMask(sScript,MASK_NEXT) & FULL_PERMS) == FULL_PERMS)) {
            llOwnerSay("You have removed mod/copy/trans permissions for the next owner of the " + sScript + " script.  This is a violation of the OpenCollar license.  Please make the script full perms again.");
            ok = FALSE;
        }
    }
    
    return ok;
}

set_active() {
    set_inactive();
    if (!check_perms())
        return;
    g_kWearer = llGetOwner();
    g_iCoreChan = -llAbs((integer)("0x" + llGetSubString(g_kWearer,30,-1)));
    g_iCoreListener = llListen(g_iCoreChan^1, "", NULL_KEY, "");
    g_iRlvListener = llListen(g_iRlvChan, "", llGetOwner(), "");
    g_iTimerFunction = TIMER_GETPATH;
    llSetTimerEvent(10);
    RlvSay("@getpathnew="+(string)g_iRlvChan);
    //debug("set_active called");
}

set_inactive() {
    if (g_iCoreListener) {
        llListenRemove(g_iCoreListener);
        core_comm("detach");
    }
    g_iCoreChan = 0;
    g_iCoreListener = 0;
    //debug("set_inactive called");
}

core_comm(string sMessage) {
    if (g_iCoreChan) {
        llRegionSayTo(g_kWearer, g_iCoreChan, "oc_toy|"+sMessage);
        //llOwnerSay(" >> "+sMessage);
    } else {
        //debug("not sent "+sMessage);
    }
}

got_path(string sRlvPath) {
    llListenRemove(g_iRlvListener);
    g_iRlvListener = 0;
    // sadly Firestorm doesn't send us the path if it only contains a link to the object, not the object itself
    // so for now we'll ignore the response and just send a fixed path based on the prim name
    sRlvPath = "~oc_toys/"+llGetObjectName();
    //if (sRlvPath == "")
    //    Debug("Warning: This toy can't be force-attached. Please place it in exactly one shared folder, then re-attach it.");
    g_sAttachMsg = "attach|"+sRlvPath+"|Menu";
    core_comm(g_sAttachMsg);
}

default {
    state_entry() {
        if (llGetAttached())
            set_active();
        else
            set_inactive();
    }
    
    on_rez(integer iTimes) {
        set_inactive();
    }
    
    attach(key kId) {
        if (kId) {
            if (g_iCoreListener) {
                set_inactive();
                g_iTimerFunction = TIMER_LOGIN;
                llSetTimerEvent(10);
            } else {
                set_active();
            }
        } else {
            set_inactive();
        }
    }
    
    timer() {
        llSetTimerEvent(0);
        integer iTimerFunction = g_iTimerFunction;
        g_iTimerFunction = TIMER_NONE;
        
        if (iTimerFunction == TIMER_LOGIN)
            set_active();
        else if (iTimerFunction == TIMER_GETPATH)
            got_path("");
    }
    
    listen(integer iChan, string sName, key kId, string sMessage) {
        //debug(llList2CSV([iChan, sName, kId, sMessage]));
        if (iChan == g_iRlvChan && kId == llGetOwner()) {
            llSetTimerEvent(0);
            g_iTimerFunction = TIMER_NONE;
            RlvEcho(sMessage);
            if (!~llSubStringIndex(sMessage, ","))
                got_path(sMessage);
            else
                got_path("");
        } else if (iChan == g_iCoreChan^1 && llGetOwnerKey(kId) == llGetOwner()) {
            if (sMessage == "collect") {
                core_comm(g_sAttachMsg);
            } else if (sMessage == "lock") {
                RlvSay("@detach=n");
            } else if (sMessage == "unlock") {
                RlvSay("@detach=y");
            } else if (sMessage == "detach") {
                RlvSay("@clear,detachme=force");
            } else if (!llSubStringIndex(sMessage, "touch|")) {
                list lParts = llParseStringKeepNulls(sMessage, ["|"], []);
                if (llGetListLength(lParts) >= 3) {
                    key kActor = llList2Key(lParts, 1);
                    integer iAuth = llList2Integer(lParts, 2);
                    SampleMenu(kActor, iAuth);
                }
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kActor = llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                // integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMenu == "Sample") {
                    if (sMessage == UPMENU) {
                        core_comm("user|"+(string)kActor+"|menu");
                        return;
                    }
                }
                SampleMenu(kActor, iAuth);
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER)
            llResetScript();
        if ((iChange & CHANGED_INVENTORY) && !llGetStartParameter()) {
            if (!check_perms())
                set_inactive();
            else if ((!g_iCoreListener) && llGetAttached())
                set_active();
        }
    }

    touch_start(integer iTot) {
        integer iNum = 0;
        while (iNum < iTot) {
            key kAv = llDetectedKey(iNum);
            core_comm("user|"+(string)kAv+"|touch");
            iNum += 1;
        }
    }
}
