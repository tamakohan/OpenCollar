// This file is part of Tama's OpenCollar.
// Copyright (c) 2018 tamakohan
// Licensed under the GPLv2.

// Contains large portions of code from other OpenCollar scripts.
// Copyright (c) 2009 - 2016 Cleo Collins, Nandana Singh, Satomi Ahn,   
// Joy Stipe, Wendy Starfall, Medea Destiny, littlemousy,         
// Romka Swallowtail, Garvin Twine et al.  
// Licensed under the GPLv2.  See LICENSE for full details. 


string g_sAppVersion = "1.0";

string g_sSubMenu = "Toys";
string g_sParentMenu = "Apps";
list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

key g_kWearer;

integer g_iDebug = 0;

integer g_iChangeAttachedTimeout = 10;
integer g_iGraceInterval = 60;
integer g_iGraceThreshold = 15;

//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
//integer CMD_RLV_RELAY = 507;
//integer CMD_SAFEWORD = 510;
//integer CMD_BLOCKED = 520;
//integer CMD_WEARERLOCKEDOUT = 521;

integer NOTIFY = 1002;
//integer NOTIFY_OWNERS = 1003;
integer SAY = 1004;

integer REBOOT = -1000;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

// FIXME unofficial constant here, what's the process for choosing these?
integer CMD_TOY = 420;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

string g_sGlobalToken = "global_";
string g_sSettingToken = "toys_";

list g_lToys; // [sToy, iFlags, kObj, sParams, kHandler, iHandlerRank]
integer g_iToysStride = 6;
// for now sParams is sRlvPath+"|"+sTouchText

integer FLAG_PERM_ANYONE = 0;
integer FLAG_PERM_TRUSTED = 1;
integer FLAG_PERM_OWNER = 2;
integer FLAG_PERM_MASK = 3;

integer FLAG_LEFT_NONE = 0;
integer FLAG_LEFT_EXCLUSIVE = 4;
integer FLAG_LEFT_SHARED = 8;
integer FLAG_LEFT_PLAYFUL = 12;
integer FLAG_LEFT_MASK = 12;

integer FLAG_ATTACHED = 16;
integer FLAG_WANT_ATTACHED = 32;
integer FLAG_AMNESTY = 64;
integer FLAG_PERMANENT = 128;

integer FLAG_GRACE_UNIT = 256; // takes four bits so it can count 0..15

integer g_iNumAttaching = 0;
integer g_iNumDetaching = 0;
integer g_iNumControlled = 0;

integer RCF_ATTACH = 1; // If not set, we're detaching something. If set, we're attaching it.
integer RCF_PARTTWO = 2; // If not set, this is the first LinkMessage. If set, it's the second.
integer RCF_OVERRIDE = 4; // If not set, don't temporarily override Dress restriction. If set, do.
integer RCF_TOYLOCKED = 8; // If not set, toy is not locked. If set, it is.

integer g_iWearerRank = 0;
integer g_iBootState = 0;

DebugFreeMem() {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+": "+(string)llGetFreeMemory()+" bytes free");
}

CoreComm(key kTarget, string sMessage) {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+" C> " + sMessage);
    integer iCoreChan = -llAbs((integer)("0x" + llGetSubString(g_kWearer,30,-1)));
    llRegionSayTo(kTarget, iCoreChan^1, sMessage);
}

CoreEcho(string sMessage) {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+" C< " + sMessage);
}

/*
Debug(string sMessage) {
    llOwnerSay(llGetScriptName()+" -- "+sMessage);
}

RlvSay(string sCmd) {
    llOwnerSay(llGetScriptName()+" R> " + sCmd);
    llOwnerSay(sCmd);
}

RlvEcho(string sMsg) {
    llOwnerSay(llGetScriptName()+" R< " + sMsg);
}
*/

Notify(list lSpec, key kActor) {
    llMessageLinked(LINK_THIS, CMD_TOY+1, llList2CSV(lSpec), kActor);
}

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string iMenuType) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, iMenuType], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, iMenuType];
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

ToysMenu(key kActor, integer iAuth) {
    string sPrompt = "\n[Toys]\t"+g_sAppVersion;
    list lButtons = [];
    integer iIndex = 0;
    integer iLength = llGetListLength(g_lToys);
    while (iIndex < iLength) {
        lButtons += ToyMenu(kActor, iAuth, iIndex, "-");
        iIndex += g_iToysStride;
    }
    Dialog(kActor, sPrompt, lButtons, [UPMENU], 0, iAuth, "Toys");
}

string ToyMenu(key kActor, integer iAuth, integer iIndex, string sButton) {
    // [sToy, iFlags, kObj, sParams, kHandler, iHandlerRank]
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    //key kObj = llList2Key(g_lToys, iIndex+2);
    list lParams = llParseStringKeepNulls(llList2String(g_lToys, iIndex+3), ["|"], []);
    key kHandler = llList2Key(g_lToys, iIndex+4);
    integer iHandlerRank = llList2Integer(g_lToys, iIndex+5);
    
    integer iPermanent = (iFlags & FLAG_PERMANENT);
    integer iAmnesty = (iFlags & FLAG_AMNESTY);
    
    key kToucher = kHandler;
    if (iFlags & FLAG_LEFT_MASK)
        kToucher = NULL_KEY;
    else if (iAmnesty)
        kToucher = g_kWearer;

    key kController = kToucher;
    if (kController == g_kWearer && iPermanent && !iAmnesty)
        kController = NULL_KEY;
    
    integer iCanAttach = (kActor == kController);
    integer iCanTouch = (kActor == kToucher);
    
    integer iCanTakeControl;
    if (kActor == kHandler) {
        iCanTakeControl = (iFlags & (FLAG_LEFT_MASK | FLAG_AMNESTY));
    } else if ((!(iFlags & FLAG_ATTACHED)) != (!(iFlags & FLAG_WANT_ATTACHED))) {
        iCanTakeControl = FALSE;
    } else if (iAuth == CMD_OWNER) {
        iCanTakeControl = TRUE;
    } else if (iAuth == CMD_WEARER) {
        iCanTakeControl = FALSE;
    } else if ((iFlags & FLAG_LEFT_MASK) == FLAG_LEFT_PLAYFUL) {
        iCanTakeControl = TRUE;
    } else if ((iFlags & FLAG_PERM_MASK) && iAuth > CMD_TRUSTED) {
        iCanTakeControl = FALSE;
    } else if ((iFlags & FLAG_PERM_MASK) == FLAG_PERM_OWNER) {
        iCanTakeControl = (iAuth == CMD_TRUSTED && (iFlags & FLAG_LEFT_MASK) == FLAG_LEFT_SHARED);
    } else if (kHandler == g_kWearer || kHandler == NULL_KEY) {
        iCanTakeControl = TRUE;
    } else if (!(iFlags & FLAG_LEFT_MASK)) {
        iCanTakeControl = (iAuth <= iHandlerRank);
    } else {
        integer iTemp = iHandlerRank;
        if (iTemp == CMD_OWNER)
            iTemp = CMD_TRUSTED;
        if ((iFlags & FLAG_LEFT_MASK) == FLAG_LEFT_EXCLUSIVE)
            iCanTakeControl = (iAuth < iTemp);
        else /* FLAG_LEFT_SHARED */
            iCanTakeControl = (iAuth <= iTemp);
    }
    
    if (sButton == "-") {
        if (!(iCanTouch || iCanTakeControl))
            return "🚫 "+sToy;
        if (iFlags & FLAG_LEFT_MASK)
            return "✋ "+sToy;
        if (iFlags & FLAG_AMNESTY)
            return "🔓 "+sToy;
        if (kActor == kHandler && kActor != g_kWearer)
            return "🔑 "+sToy;
        if (iFlags & FLAG_PERMANENT)
            return "🔒 "+sToy;
        return sToy;
    }
    
    // Need to remember this for when we pop the menu back up on RCF_PARTTWO
    if (kActor == g_kWearer)
        g_iWearerRank = iAuth;
    
    list lButtons = [];
    
    if (iCanAttach) {
        if (iFlags & FLAG_ATTACHED) {
            if (iFlags & FLAG_WANT_ATTACHED) {
                if (sButton == "Detach") {
                    ChangeAttached(iIndex, 0);
                    return "1";
                }
                lButtons += "Detach";
            } else {
                lButtons += "(Detaching)";
            }
        } else {
            if (iFlags & FLAG_WANT_ATTACHED) {
                lButtons += "(Attaching)";
            } else {
                if (sButton == "Attach") {
                    ChangeAttached(iIndex, RCF_ATTACH);
                    return "1";
                }
                lButtons += "Attach";
            }
        }
    }
    
    if (iCanTouch && (iFlags & FLAG_ATTACHED) && (iFlags & FLAG_WANT_ATTACHED)) {
        string sTouchText = "";
        if (llGetListLength(lParams) > 1)
            sTouchText = llList2String(lParams, 1);
        if (sTouchText) {
            if (sButton == sTouchText || sButton == "Touch") {
                key kObj = llList2Key(g_lToys, iIndex+2);
                CoreComm(kObj, "touch|"+(string)kActor+"|"+(string)iAuth);
                return "1";
            }
            lButtons += sTouchText;
        }
    }

    if (kActor == kController && kActor != g_kWearer) {
        if (sButton == "LeaveLocked") {
            DoLeaveLocked(kActor, iAuth, iIndex, "");
            return "1";
        }
        lButtons += "LeaveLocked";
    }

    if ((iPermanent && !iAmnesty) && (kActor == kController || (kHandler == g_kWearer && kActor == g_kWearer && iAuth == CMD_OWNER))) {
        if (sButton == "Amnesty") {
            DoAmnesty(kActor, iAuth, iIndex);
            return "1";
        }
        lButtons += "Amnesty";
    }
    
    if (iCanTakeControl) {
        if (sButton == "Take Control") {
            DoTakeControl(kActor, iAuth, iIndex);
            return "1";
        }
        lButtons += "Take Control";
    }
    
    if (kHandler != g_kWearer && (iCanAttach || iCanTakeControl)) {
        // Additional check - if kActor wouldn't normally have access (and
        //   only has access because of a temporary wider permission from
        //   LeaveLocked), don't allow kActor to revoke that wider permission
        //   by releasing
        if (!(((iFlags & FLAG_PERM_MASK) == FLAG_PERM_OWNER && iAuth != CMD_OWNER) || ((iFlags & FLAG_PERM_MASK) && iAuth > CMD_TRUSTED))) {
            if (sButton == "Release") {
                DoRelease(kActor, iAuth, iIndex);
                return "1";
            }
            lButtons += "Release";
        }
    }
    
    if (iAuth == CMD_OWNER) {
        if (sButton == Checkbox("Permanent", iFlags & FLAG_PERMANENT)) {
            DoPermanent(kActor, iAuth, iIndex);
            return "1";
        }
        lButtons += Checkbox("Permanent", iFlags & FLAG_PERMANENT);
        if (sButton == "Permission") {
            DoPermission(kActor, iAuth, iIndex, "");
            return "1";
        }
        lButtons += "Permission";
    }
    
    if (!llGetListLength(lButtons))
        return "";

    string sPrompt = "\n[Toys]\t"+g_sAppVersion+"\n\n"+sToy;
    Dialog(kActor, sPrompt, lButtons, [UPMENU], 0, iAuth, "Toy "+sToy);
    return "1";
}

ChangeAttached(integer iIndex, integer iRlvCmdFlags) {
    // [sToy, iFlags, kObj, sParams, kHandler, iHandlerRank]
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    key kObj = llList2Key(g_lToys, iIndex+2);
    list lParams = llParseStringKeepNulls(llList2String(g_lToys, iIndex+3), ["|"], []);
    key kHandler = llList2Key(g_lToys, iIndex+4);
    integer iHandlerRank = llList2Integer(g_lToys, iIndex+5);

    // iHandlerRank is always CMD_EVERYONE if (kHandler == g_kWearer).
    // So we need to override it with the correct auth level when popping the menu back up during RCF_PARTTWO.
    if (kHandler == g_kWearer)
        iHandlerRank = g_iWearerRank;

    if (((kHandler != g_kWearer) || (iFlags & FLAG_PERMANENT)) && !(iFlags & FLAG_AMNESTY))
        iRlvCmdFlags = iRlvCmdFlags | RCF_TOYLOCKED;

    integer iPopMenu = FALSE;
    if (iRlvCmdFlags & RCF_ATTACH) {
        if (iRlvCmdFlags & RCF_PARTTWO) {
            iPopMenu = (iFlags & FLAG_WANT_ATTACHED);
            if (iPopMenu)
                g_iNumAttaching -= 1;
            iFlags = iFlags | FLAG_ATTACHED | FLAG_WANT_ATTACHED;
        }
        if (g_iNumAttaching == 0)
            iRlvCmdFlags = iRlvCmdFlags | RCF_OVERRIDE;
        if (!(iRlvCmdFlags & RCF_PARTTWO)) {
            g_iNumAttaching += 1;
            iFlags = iFlags | FLAG_WANT_ATTACHED;
        }
    } else {
        if (iRlvCmdFlags & RCF_PARTTWO) {
            iPopMenu = !(iFlags & FLAG_WANT_ATTACHED);
            if (iPopMenu)
                g_iNumDetaching -= 1;
            iFlags = iFlags &~ (FLAG_ATTACHED | FLAG_WANT_ATTACHED);
        }
        if (g_iNumDetaching == 0)
            iRlvCmdFlags = iRlvCmdFlags | RCF_OVERRIDE;
        if (!(iRlvCmdFlags & RCF_PARTTWO)) {
            g_iNumDetaching += 1;
            iFlags = iFlags &~ FLAG_WANT_ATTACHED;
        }
    }
    g_lToys = llListReplaceList(g_lToys, [iFlags], iIndex+1, iIndex+1);
    
    string sRlvPath = "";
    if (llGetListLength(lParams) > 0)
        sRlvPath = llList2String(lParams, 0);
    llMessageLinked(LINK_RLV, CMD_TOY, llList2CSV([iRlvCmdFlags, kObj, sRlvPath]), kHandler);

    if (iRlvCmdFlags & RCF_PARTTWO) {
        if (iFlags & FLAG_ATTACHED)
            Notify([2, sToy], kHandler);
        else
            Notify([1, sToy], kHandler);
        if (iPopMenu && !(iFlags & FLAG_LEFT_MASK)) {
            if (iFlags & FLAG_AMNESTY)
                ToyMenu(g_kWearer, iHandlerRank, iIndex, "");
            else if (kHandler != g_kWearer || !(iFlags & FLAG_PERMANENT))
                ToyMenu(kHandler, iHandlerRank, iIndex, "");
        }
    }
    
    SetTimer();
}

CancelAllChangeAttached() {
    g_iNumAttaching = 0;
    g_iNumDetaching = 0;
    integer iIndex = 0;
    integer iLength = llGetListLength(g_lToys);
    while (iIndex < iLength) {
        string sToy = llList2String(g_lToys, iIndex);
        integer iFlags = llList2Integer(g_lToys, iIndex+1);
        key kHandler = llList2Key(g_lToys, iIndex+4);
        if ((iFlags & FLAG_ATTACHED) && !(iFlags & FLAG_WANT_ATTACHED)) {
            g_lToys = llListReplaceList(g_lToys, [iFlags | FLAG_WANT_ATTACHED], iIndex+1, iIndex+1);
            Notify([3, sToy], kHandler);
        } else if ((iFlags & FLAG_WANT_ATTACHED) && !(iFlags & FLAG_ATTACHED)) {
            g_lToys = llListReplaceList(g_lToys, [iFlags &~ FLAG_WANT_ATTACHED], iIndex+1, iIndex+1);
            Notify([4, sToy], kHandler);
        }
        iIndex += g_iToysStride;
    }

    llMessageLinked(LINK_RLV, CMD_TOY, "cancel", g_kWearer);
    
    SetTimer();
}

CheckHandlerPresence() {
    integer iIndex = 0;
    integer iLength = llGetListLength(g_lToys);
    while (g_iNumControlled && iIndex < iLength) {
        integer iFlags = llList2Integer(g_lToys, iIndex+1);
        key kHandler = llList2Key(g_lToys, iIndex+4);
        integer iHandlerRank = llList2Integer(g_lToys, iIndex+5);
        
        if (kHandler != g_kWearer && !(iFlags & FLAG_LEFT_MASK)) {
            // additional check (see comment by the same check for the Release button)
            if (!(((iFlags & FLAG_PERM_MASK) == FLAG_PERM_OWNER && iHandlerRank != CMD_OWNER) || ((iFlags & FLAG_PERM_MASK) && iHandlerRank > CMD_TRUSTED))) {
                integer iUnlock = FALSE;
                integer iLock = FALSE;
                integer iAttach = FALSE;
                
                list lDetails = llGetObjectDetails(kHandler, [OBJECT_POS]);
                // we could change this to actually do a distance check, that's why we got OBJECT_POS
                // for now though, we only really care if they're away from the region
                if (llGetListLength(lDetails) > 0) {
                    // handler is present, reset count
                    iFlags = iFlags &~ (15 * FLAG_GRACE_UNIT);
                } else {
                    // handler is not present, increment count
                    iFlags += FLAG_GRACE_UNIT;
                    if ((iFlags & (15 * FLAG_GRACE_UNIT)) >= g_iGraceThreshold * FLAG_GRACE_UNIT) {
                        // reset handler
                        iFlags = iFlags &~ FLAG_AMNESTY;
                        g_lToys = llListReplaceList(g_lToys, [g_kWearer, CMD_EVERYONE], iIndex+4, iIndex+5);
                        g_iNumControlled -= 1;
                        
                        if (iFlags & FLAG_PERMANENT) {
                            if (iFlags & FLAG_AMNESTY)
                                iLock = TRUE;
                            if (!(iFlags & FLAG_ATTACHED))
                                iAttach = TRUE;
                        } else {
                            iUnlock = TRUE;
                        }   
                    }
                }
                g_lToys = llListReplaceList(g_lToys, [iFlags], iIndex+1, iIndex+1);
                string sToy = llList2String(g_lToys, iIndex);
                if (iUnlock)
                    Notify([5, sToy], kHandler);
                else if (iLock || iAttach)
                    Notify([6, sToy], kHandler);
                if (iUnlock)
                    SetLocked(iIndex, FALSE);
                else if (iLock)
                    SetLocked(iIndex, TRUE);
                if (iAttach)
                    ChangeAttached(iIndex, RCF_ATTACH);
            }
        }

        iIndex += g_iToysStride;
    }

    SetTimer();
}

UpdateNumControlled() {
    g_iNumControlled = 0;
    integer iIndex = 0;
    integer iLength = llGetListLength(g_lToys);
    while (iIndex < iLength) {
        integer iFlags = llList2Integer(g_lToys, iIndex+1);
        key kHandler = llList2Key(g_lToys, iIndex+4);
        
        if (kHandler != g_kWearer && !(iFlags & FLAG_LEFT_MASK))
            g_iNumControlled += 1;

        iIndex += g_iToysStride;
    }
    
    SetTimer();
}

SetTimer() {
    if (g_iNumAttaching || g_iNumDetaching)
        llSetTimerEvent(g_iChangeAttachedTimeout);
    else if (g_iNumControlled)
        llSetTimerEvent(g_iGraceInterval);
    else
        llSetTimerEvent(0);
}

DoLeaveLocked(key kActor, integer iAuth, integer iIndex, string sButton) {
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    
    if (sButton == "Exclusive") {
        iFlags = iFlags | FLAG_LEFT_EXCLUSIVE;
        Notify([20, sToy], kActor);
    } else if (sButton == "Shared") {
        iFlags = iFlags | FLAG_LEFT_SHARED;
        Notify([21, sToy], kActor);
    } else if (sButton == "Playful") {
        iFlags = iFlags | FLAG_LEFT_PLAYFUL;
        Notify([22, sToy], kActor);
    } else if (sButton != UPMENU) {
        string sPrompt = "\n[Toys]\t"+g_sAppVersion+"\n\n"+sToy+"\n\nWhich lock style do you want?\n\n";
        if (iAuth == CMD_OWNER) {
            sPrompt += "Styles are different for Owners:\n"+
                "• Exclusive - owners only\n"+
                "• Shared - owners and trusteds only\n"+
                "• Playful - remains the same as below\n\nThe usual meanings are:\n";
        }
        sPrompt +=
            "• Exclusive - only you, or someone of a higher rank, can override the lock\n"+
            "• Shared - only those of your rank or above can override the lock\n"+
            "• Playful - anyone with access to the collar can override the lock (except the wearer)";
        list lButtons = ["Exclusive", "Shared", "Playful"];
        Dialog(kActor, sPrompt, lButtons, [UPMENU], 0, iAuth, "LeaveLocked "+sToy);
        return;
    }
    
    g_lToys = llListReplaceList(g_lToys, [iFlags], iIndex+1, iIndex+1);

    UpdateNumControlled();

    ToyMenu(kActor, iAuth, iIndex, "");
}

DoAmnesty(key kActor, integer iAuth, integer iIndex) {
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);

    g_lToys = llListReplaceList(g_lToys, [iFlags | FLAG_AMNESTY], iIndex+1, iIndex+1);
    
    SetLocked(iIndex, FALSE);
    
    Notify([19, sToy], kActor);
    
    ToyMenu(kActor, iAuth, iIndex, "");
}

DoTakeControl(key kActor, integer iAuth, integer iIndex) {
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    key kHandler = llList2Key(g_lToys, iIndex+4);
    
    integer iLockedBefore = ((kHandler != g_kWearer) || (iFlags & FLAG_PERMANENT)) && !(iFlags & FLAG_AMNESTY);
    integer iLockedAfter = (kActor != g_kWearer) || (iFlags & FLAG_PERMANENT);
    
    kHandler = kActor;
    integer iHandlerRank = iAuth;
    
    if (kHandler == g_kWearer)
        iHandlerRank = CMD_EVERYONE;

    g_lToys = llListReplaceList(g_lToys, [iFlags &~ (FLAG_LEFT_MASK | FLAG_AMNESTY)], iIndex+1, iIndex+1);
    g_lToys = llListReplaceList(g_lToys, [kHandler, iHandlerRank], iIndex+4, iIndex+5);
    
    if (iLockedAfter && !iLockedBefore)
        SetLocked(iIndex, TRUE);
    else if (iLockedBefore && !iLockedAfter)
        SetLocked(iIndex, FALSE);

    Notify([18, sToy], kActor);

    UpdateNumControlled();
    
    ToyMenu(kActor, iAuth, iIndex, "");
}

DoRelease(key kActor, integer iAuth, integer iIndex) {
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    
    g_lToys = llListReplaceList(g_lToys, [iFlags &~ (FLAG_LEFT_MASK | FLAG_AMNESTY)], iIndex+1, iIndex+1);
    g_lToys = llListReplaceList(g_lToys, [g_kWearer, CMD_EVERYONE], iIndex+4, iIndex+5);

    if (iFlags & FLAG_PERMANENT) {
        if (iFlags & FLAG_AMNESTY)
            SetLocked(iIndex, TRUE);
        if (!(iFlags & FLAG_ATTACHED))
            ChangeAttached(iIndex, RCF_ATTACH);
        Notify([17, sToy], kActor);
    } else {
        SetLocked(iIndex, FALSE);
        Notify([16, sToy], kActor);
    }

    UpdateNumControlled();

    ToyMenu(kActor, iAuth, iIndex, "");
}

SetLocked(integer iIndex, integer iLocked) {
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    
    if (iFlags & FLAG_ATTACHED) {
        key kObj = llList2Key(g_lToys, iIndex+2);
        if (iLocked)
            CoreComm(kObj, "lock");
        else
            CoreComm(kObj, "unlock");
    } else {
        string sYN = "y";
        if (iLocked)
            sYN = "n";
        list lParams = llParseStringKeepNulls(llList2String(g_lToys, iIndex+3), ["|"], []);
        string sRlvPath = "";
        if (llGetListLength(lParams) > 0)
            sRlvPath = llList2String(lParams, 0);
        llMessageLinked(LINK_RLV, RLV_CMD, "attachthis:"+sRlvPath+"="+sYN, NULL_KEY);
    }
}

DoPermanent(key kActor, integer iAuth, integer iIndex) {
    // [sToy, iFlags, kObj, sParams, kHandler, iHandlerRank]
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    //key kObj = llList2Key(g_lToys, iIndex+2);
    //list lParams = llParseStringKeepNulls(llList2String(g_lToys, iIndex+3), ["|"], []);
    key kHandler = llList2Key(g_lToys, iIndex+4);
    //integer iHandlerRank = llList2Integer(g_lToys, iIndex+5);

    // we have an extra check here to make sure the actor (who must be an owner) takes control first
    // this is because owners can always see the Permanent checkbox in the menu
    // (they should not have to take control just to see what it is currently set to)
    if (kActor != kHandler || (iFlags & (FLAG_LEFT_MASK | FLAG_AMNESTY))) {
        Notify([10], kActor);
        return;
    }
    
    g_lToys = llListReplaceList(g_lToys, [iFlags ^ FLAG_PERMANENT], iIndex+1, iIndex+1);
    
    integer iPopMenu = TRUE;
    if (kActor == g_kWearer) {
        if (iFlags & FLAG_PERMANENT) {
            SetLocked(iIndex, FALSE);
        } else {
            SetLocked(iIndex, TRUE);
            if (!(iFlags & FLAG_ATTACHED)) {
                ChangeAttached(iIndex, RCF_ATTACH);
                iPopMenu = FALSE;
            }
        }
    }
    
    SaveToys();
    
    if (iFlags & FLAG_PERMANENT)
        Notify([12, sToy], kActor);
    else
        Notify([11, sToy], kActor);

    if (iPopMenu)
        ToyMenu(kActor, iAuth, iIndex, "");
}

DoPermission(key kActor, integer iAuth, integer iIndex, string sButton) {
    string sToy = llList2String(g_lToys, iIndex);
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    
    if (sButton == Selectbox("Owner", FALSE)) {
        iFlags = (iFlags &~ FLAG_PERM_MASK) | FLAG_PERM_OWNER;
        Notify([13, sToy], kActor);
    } else if (sButton == Selectbox("Trusted", FALSE)) {
        iFlags = (iFlags &~ FLAG_PERM_MASK) | FLAG_PERM_TRUSTED;
        Notify([14, sToy], kActor);
    } else if (sButton == Selectbox("Anyone", FALSE)) {
        iFlags = (iFlags &~ FLAG_PERM_MASK) | FLAG_PERM_ANYONE;
        Notify([15, sToy], kActor);
    } else if (sButton == UPMENU) {
        ToyMenu(kActor, iAuth, iIndex, "");
        return;
    }
    
    g_lToys = llListReplaceList(g_lToys, [iFlags], iIndex+1, iIndex+1);
    
    SaveToys();
    
    string sPrompt = "\n[Toys]\t"+g_sAppVersion+"\n\nChoose who can take control of \""+sToy+"\".\n\n"+
        "• \"Anyone\" means anyone who can access the collar.\n"+
        "• LeaveLocked can override this setting temporarily using Shared or Playful.";
    list lButtons = [
        Selectbox("Owner", ((iFlags & FLAG_PERM_MASK) == FLAG_PERM_OWNER)),
        Selectbox("Trusted", ((iFlags & FLAG_PERM_MASK) == FLAG_PERM_TRUSTED)),
        Selectbox("Anyone", ((iFlags & FLAG_PERM_MASK) == FLAG_PERM_ANYONE))];
    Dialog(kActor, sPrompt, lButtons, [UPMENU], 0, iAuth, "Permission "+sToy);
}

HandleAttached(key kObj, string sParams) {
    integer iIndex = llListFindList(g_lToys, [kObj]);
    if (~iIndex) {
        // we already know about this object
        if (sParams != "")
            g_lToys = llListReplaceList(g_lToys, [sParams], iIndex+3, iIndex+3);
        return;
    }
    
    string sObjName = llList2String(llGetObjectDetails(kObj, [OBJECT_NAME]), 0);
    
    list lParts = llParseStringKeepNulls(llList2String(llGetObjectDetails(kObj, [OBJECT_DESC]), 0), ["~"], []);
    integer iIndex2 = llListFindList(lParts, ["oc_toy"]);
    if (iIndex2 == -1 || iIndex2 == llGetListLength(lParts)-1) {
        Notify([7, sObjName], NULL_KEY);
        return;
    }
    
    string sToy = llList2String(lParts, iIndex2+1);
    if (llStringLength(sToy) < 1 || llStringLength(sToy) > 12) {
        Notify([7, sObjName], NULL_KEY);
        return;
    }
    
    iIndex = llListFindList(g_lToys, [sToy]);
    
    if (~iIndex) {
        // the object may be newly attached, or may have changed key (e.g. on relog)
        // check that the old key isn't also attached somehow
        key kOldObj = llList2Key(g_lToys, iIndex+2);
        if (~llListFindList(llGetAttachedList(g_kWearer), [kOldObj])) {
            string sOldObjName = llList2String(llGetObjectDetails(kOldObj, [OBJECT_NAME]), 0);
            Notify([8, sObjName, sOldObjName], NULL_KEY);
            return;
        }

        string sOldParams = llList2String(g_lToys, iIndex+3);
        if (sParams == "")
            sParams = sOldParams;
        g_lToys = llListReplaceList(g_lToys, [kObj, sParams], iIndex+2, iIndex+3);
        ChangeAttached(iIndex, RCF_ATTACH | RCF_PARTTWO);
    } else {
        g_lToys += [sToy, FLAG_WANT_ATTACHED | FLAG_ATTACHED /*iFlags*/, kObj, sParams, g_kWearer /*kHandler*/, CMD_EVERYONE /*iHandlerRank*/];
        DebugFreeMem();
        Notify([9, sToy, sObjName], NULL_KEY);
        Notify([2, sToy], g_kWearer);
    }
}

UserCommand(integer iAuth, string sMsg, key kActor) {
    sMsg = llToLower(sMsg);
    if (sMsg == "menu toys" || sMsg == "toys" || sMsg == g_sSubMenu) {
        ToysMenu(kActor, iAuth);
    } else if (!llSubStringIndex(sMsg, "toy ")) {
        CoreEcho(sMsg);
        key kObj;
        string sButton;
        if (!llSubStringIndex(sMsg, "toy touch ")) {
            kObj = (key)llGetSubString(sMsg, 10, -1);
            sButton = "Touch";
        } else if (!llSubStringIndex(sMsg, "toy menu ")) {
            kObj = (key)llGetSubString(sMsg, 9, -1);
            sButton = "";
        }
        if (kObj) {
            HandleAttached(kObj, "");
            integer iIndex = llListFindList(g_lToys, [kObj]);
            if (~iIndex) {
                iIndex -= 2;
                if (ToyMenu(kActor, iAuth, iIndex, sButton) == "")
                    llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kActor);
            }
        }
    } else if (sMsg == "rm toys") {
        if (kActor != g_kWearer && iAuth != CMD_OWNER)
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kActor);
        else
            Dialog(kActor, "\nDo you really want to uninstall the "+g_sSubMenu+" App?", ["Yes", "No", "Cancel"], [], 0, iAuth, "rmtoys");
    }
}

SaveToys() {
    list lParts = [2];
    integer iSaveFlagMask = (FLAG_PERM_MASK | FLAG_PERMANENT);
    
    integer iIndex = 0;
    integer iLength = llGetListLength(g_lToys);
    while (iIndex < iLength) {
        integer iFlags = llList2Integer(g_lToys, iIndex+1) & iSaveFlagMask;
        
        if (iFlags) {
            string sToy = llList2String(g_lToys, iIndex);
            lParts += [sToy, iFlags];
        }
        
        iIndex += g_iToysStride;
    }
    
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken + "toys=" + llList2CSV(lParts), "");
}

LoadSetPermanent(integer iIndex) {
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    key kHandler = llList2Key(g_lToys, iIndex+4);
    if (kHandler == g_kWearer) {
        SetLocked(iIndex, TRUE);
        if (!(iFlags & FLAG_ATTACHED))
            ChangeAttached(iIndex, RCF_ATTACH);
    }
}

LoadUnsetPermanent(integer iIndex) {
    integer iFlags = llList2Integer(g_lToys, iIndex+1);
    key kHandler = llList2Key(g_lToys, iIndex+4);
    if (iFlags & FLAG_AMNESTY)
        g_lToys = llListReplaceList(g_lToys, [iFlags &~ FLAG_AMNESTY], iIndex+1, iIndex+1);
    else if (kHandler == g_kWearer)
        SetLocked(iIndex, FALSE);
}

default {
    on_rez(integer param) {
        g_kWearer = llGetOwner();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        if (llGetAttached()) {
            DebugFreeMem();
            g_iBootState = 1;
            CoreComm(g_kWearer, "collect"); // state_entry
        }
    }
    
    attach(key kId) {
        if (kId) {
            if (g_iBootState) {
                g_iBootState = 2;
                llSetTimerEvent(10);
            } else {
                DebugFreeMem();
                g_iBootState = 1;
                CoreComm(g_kWearer, "collect"); // attach
            }
        } else {
            g_iBootState = 0;
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER)
            llResetScript();
    }
    
    timer() {
        if (g_iBootState == 2) {
            DebugFreeMem();
            g_iBootState = 1;
            CoreComm(g_kWearer, "collect"); // relog
        }
        if (g_iNumAttaching || g_iNumDetaching) {
            CancelAllChangeAttached();
        } else if (g_iNumControlled) {
            CheckHandlerPresence();
        } else {
            llSetTimerEvent(0);
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);  //remove stride from g_lMenuIDs
        } else if (iNum == LM_SETTING_RESPONSE) {
            integer i = llSubStringIndex(sStr, "=");
            string sToken = llGetSubString(sStr, 0, i - 1);
            string sValue = llGetSubString(sStr, i + 1, -1);
            i = llSubStringIndex(sToken, "_");
            if (llGetSubString(sToken, 0, i) == g_sSettingToken) {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "toys") {
                    list lParts = llCSV2List(sValue);
                    integer iLoadStride = llList2Integer(lParts, 0);
                    if (iLoadStride > 0) {
                        list lSetPermanent = [];
                        list lUnsetPermanent = [];
                        integer iLength = llGetListLength(lParts);
                        list lOldToys = g_lToys;
                        g_lToys = [];
                        i = 1;
                        while (i < iLength) {
                            string sLoadToy = llList2String(lParts, i);
                            integer iLoadFlags = 0;
                            integer iLoadFlagMask = (FLAG_PERM_MASK | FLAG_PERMANENT);
                            if (iLoadStride > 1)
                                iLoadFlags = llList2Integer(lParts, i+1) & iLoadFlagMask;
                            integer iOldIndex = llListFindList(lOldToys, [sLoadToy]);
                            integer iOldFlags = 0;
                            if (~iOldIndex) {
                                // copy from lOldToys
                                iOldFlags = llList2Integer(lOldToys, iOldIndex+1);
                                iLoadFlags = iLoadFlags | (iOldFlags &~ iLoadFlagMask);
                                lOldToys = llListReplaceList(lOldToys, [iLoadFlags], iOldIndex+1, iOldIndex+1);
                                if ((iLoadFlags & FLAG_PERMANENT) && !(iOldFlags & FLAG_PERMANENT))
                                    lSetPermanent += llGetListLength(g_lToys);
                                else if ((iOldFlags & FLAG_PERMANENT) && !(iLoadFlags & FLAG_PERMANENT))
                                    lUnsetPermanent += llGetListLength(g_lToys);
                                g_lToys += llList2List(lOldToys, iOldIndex, iOldIndex+g_iToysStride-1);
                            } else {
                                // add toy
                                g_lToys += [sLoadToy, iLoadFlags, NULL_KEY, "", g_kWearer, CMD_EVERYONE];
                            }
                            i += iLoadStride;
                        }
                        i = 0;
                        iLength = llGetListLength(lSetPermanent);
                        while (i < iLength) {
                            LoadSetPermanent(llList2Integer(lSetPermanent, i));
                            i += 1;
                        }
                        i = 0;
                        iLength = llGetListLength(lUnsetPermanent);
                        while (i < iLength) {
                            LoadUnsetPermanent(llList2Integer(lUnsetPermanent, i));
                            i += 1;
                        }
                        DebugFreeMem();
                        if (g_iBootState == 3)
                            g_iBootState = 1;
                        if (g_iBootState == 1)
                            CoreComm(g_kWearer, "collect"); // load
                    }
                } else if (sToken == "timeout") {
                    i = (integer) sValue;
                    if (i) {
                        if (i < 2)
                            i = 2;
                        if (i > 60)
                            i = 60;
                        g_iChangeAttachedTimeout = i;
                    }
                } else if (sToken == "grace") {
                    i = (integer) sValue;
                    if (i) {
                        if (i < 1)
                            i = 1;
                        if (i > 15)
                            i = 15;
                        g_iGraceThreshold = i;
                    }
                }
            } else if (sToken == g_sGlobalToken+"debug") {
                g_iDebug = (integer) sValue;
                DebugFreeMem();
            }
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        /*} else if (iNum == CMD_OWNER && sStr == "runaway") {
            llSleep(4);*/
        } else if (iNum == REBOOT && sStr == "reboot") {
            llResetScript();
        } else if (g_iBootState != 1) {
            // do nothing (prevents executing anything past here when we're not attached or are relogging)
        } else if (iNum == CMD_TOY) {
            CoreEcho(sStr);
            list lParts = llParseStringKeepNulls(sStr, ["|"], []);
            key kObj = llList2Key(lParts, 0);
            string sMsg = llList2String(lParts, 1);
            if (sMsg == "attach") {
                string sParams = "";
                if (llGetListLength(lParts) > 2)
                    sParams = llGetSubString(sStr, llSubStringIndex(sStr, "|")+llStringLength(sMsg)+2, -1);
                HandleAttached(kObj, sParams);
            } else if (sMsg == "detach") {
                integer iIndex = llListFindList(g_lToys, [kObj]);
                if (~iIndex) {
                    iIndex -= 2;
                    g_lToys = llListReplaceList(g_lToys, [NULL_KEY], iIndex+2, iIndex+2);
                    ChangeAttached(iIndex, RCF_PARTTWO);
                }
            }
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            UserCommand(iNum, sStr, kID);
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kActor = llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                // integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMenu == "Toys") {
                    if (sMessage == UPMENU) {
                        llMessageLinked(LINK_ROOT, iAuth, "menu "+g_sParentMenu, kActor);
                        return;
                    } else {
                        // remove prefixes
                        list lPrefixes = ["🚫 ", "✋ ", "🔑 ", "🔒 ", "🔓 "];
                        integer iIndex = 5;
                        while (iIndex > 0) {
                            iIndex -= 1;
                            string sPrefix = llList2String(lPrefixes, iIndex);
                            if (!llSubStringIndex(sMessage, sPrefix))
                                sMessage = llGetSubString(sMessage, llStringLength(sPrefix), -1);
                        }
                        iIndex = llListFindList(g_lToys, [sMessage]);
                        if (~iIndex) {
                            if (ToyMenu(kActor, iAuth, iIndex, ""))
                                return;
                            else
                                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kActor);
                        }
                    }
                } else if (!llSubStringIndex(sMenu, "Toy ")) {
                    if (sMessage != UPMENU) {
                        string sToy = llGetSubString(sMenu, 4, -1);
                        integer iIndex = llListFindList(g_lToys, [sToy]);
                        if (~iIndex) {
                            if (ToyMenu(kActor, iAuth, iIndex, sMessage))
                                return;
                            else
                                llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kActor);
                        }
                    }
                } else if (!llSubStringIndex(sMenu, "LeaveLocked ")) {
                    string sToy = llGetSubString(sMenu, 12, -1);
                    integer iIndex = llListFindList(g_lToys, [sToy]);
                    if (~iIndex) {
                        DoLeaveLocked(kActor, iAuth, iIndex, sMessage);
                        return;
                    }
                } else if (!llSubStringIndex(sMenu, "Permission ")) {
                    string sToy = llGetSubString(sMenu, 11, -1);
                    integer iIndex = llListFindList(g_lToys, [sToy]);
                    if (~iIndex) {
                        DoPermission(kActor, iAuth, iIndex, sMessage);
                        return;
                    }
                } else if (sMenu == "rmtoys") {
                    if (sMessage == "Yes") {
                        llMessageLinked(LINK_ROOT, MENUNAME_REMOVE , g_sParentMenu + "|" + g_sSubMenu, "");
                        llMessageLinked(LINK_DIALOG, NOTIFY, "1"+g_sSubMenu+" App has been removed.", kActor);
                        if (llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT)
                            llRemoveInventory(llGetScriptName());
                    } else {
                        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sSubMenu+" App remains installed.", kActor);
                    }
                    return;
                }
                ToysMenu(kActor, iAuth);
            }
        }
    }
}
