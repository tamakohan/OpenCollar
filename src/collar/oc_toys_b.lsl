// This file is part of Tama's OpenCollar.
// Copyright (c) 2018 tamakohan
// Licensed under the GPLv2.

// Contains large portions of code from other OpenCollar scripts.
// Copyright (c) 2009 - 2016 Cleo Collins, Nandana Singh, Satomi Ahn,   
// Joy Stipe, Wendy Starfall, Medea Destiny, littlemousy,         
// Romka Swallowtail, Garvin Twine et al.  
// Licensed under the GPLv2.  See LICENSE for full details. 

// This is a separate script from oc_toys because we were running out of script memory...

integer NOTIFY = 1002;

integer LINK_DIALOG = 3;
integer LINK_UPDATE = -10;

// FIXME etc.
integer CMD_TOY = 420;

string Replace(string sHaystack, string sNeedle, string sReplacement) {
    return llDumpList2String(llParseStringKeepNulls(sHaystack, [sNeedle], []), sReplacement);
}

string NameURI(key kID) {
    return "secondlife:///app/agent/"+(string)kID+"/about";
}

Notify2(key kWearer, key kActor, key kTarget, list lSpec, string sMessage) {
    integer iIndex = 1;
    integer iLength = llGetListLength(lSpec);
    if (iLength > 10)
        iLength = 10;
    while (iIndex < iLength) {
        sMessage = Replace(sMessage, "%"+(string)iIndex, llList2String(lSpec, iIndex));
        iIndex += 1;
    }
    sMessage = Replace(sMessage, "%A", NameURI(kActor));
    sMessage = Replace(sMessage, "%W", NameURI(kWearer));
    
    llMessageLinked(LINK_DIALOG, NOTIFY, "0"+sMessage, kTarget);
}

default {
    link_message(integer iSender, integer iNum, string sSpec, key kActor) {
        if (iNum == CMD_TOY+1) {
            //llOwnerSay(" ?? " + sSpec);
            list lSpec = llCSV2List(sSpec);
            integer iTextNum = llList2Integer(lSpec, 0);
            key kWearer = llGetOwner();
            
            // notify actor
            if (kActor != NULL_KEY) {
                list lText = [
                    /* 0 */ "Unknown message #%1.",
                    /* 1 */ "\"%1\" has been detached.",
                    /* 2 */ "\"%1\" has been attached.",
                    /* 3 */ "\"%1\" detaching timed out.",
                    /* 4 */ "\"%1\" attaching timed out.",
                    /* 5 */ "\"%1\" has been automatically released because you have been away from the region for too long.",
                    /* 6 */ "\"%1\" amnesty has automatically ended because you have been away from the region for too long.",
                    /* 7 */ "",
                    /* 8 */ "",
                    /* 9 */ "",
                    /* 10 */ "Please \"Take Control\" before changing the Permanent setting.",
                    /* 11 */ "\"%1\" has been set to Permanent. It will always be locked unless Amnesty is granted and will automatically be re-attached and re-locked when released or when the handler is away from the region for too long.",
                    /* 12 */ "\"%1\" is no longer set to Permanent. From now on it will be unlocked when released or when the handler is away from the region for too long.",
                    /* 13 */ "Now only Owners can take control of \"%1\".",
                    /* 14 */ "Now only Owners and Trusteds can take control of \"%1\".",
                    /* 15 */ "Now anyone with collar access can take control of \"%1\".",
                    /* 16 */ "You have released control of \"%1\" back to %W.",
                    /* 17 */ "You have released control of \"%1\". It has been re-attached and re-locked automatically.",
                    /* 18 */ "You have taken control of \"%1\".",
                    /* 19 */ "You have granted Amnesty to %W for \"%1\". It has been unlocked, but will be re-attached and re-locked automatically if you are away from the region for too long.",
                    /* 20 */ "\"%1\" has been Left Locked in Exclusive mode by %A.",
                    /* 21 */ "\"%1\" has been Left Locked in Shared mode by %A.",
                    /* 22 */ "\"%1\" has been Left Locked in Playful mode by %A.",
                    ""];
                if (iTextNum < 1 || iTextNum >= llGetListLength(lText))
                    lSpec = [0, iTextNum];
                string sMessage = llList2String(lText, iTextNum);
                if (sMessage)
                    Notify2(kWearer, kActor, kActor, lSpec, sMessage);
            }
                    
            // notify wearer
            if (kActor != kWearer) {
                list lText = [
                    /* 0 */ "",
                    /* 1 */ "\"%1\" has been detached by %A.",
                    /* 2 */ "\"%1\" has been attached by %A.",
                    /* 3 */ "\"%1\" detaching by %A timed out.",
                    /* 4 */ "\"%1\" attaching by %A timed out.",
                    /* 5 */ "\"%1\" has been automatically released because %A has been away from the region for too long.",
                    /* 6 */ "\"%1\" amnesty has automatically ended because %A has been away from the region for too long.",
                    /* 7 */ "\"%1\" doesn't seem to be a compatible toy.",
                    /* 8 */ "\"%1\" is trying to duplicate \"%2\". Please detach one of them.",
                    /* 9 */ "\"%1\" has been installed by \"%2\".",
                    /* 10 */ "",
                    /* 11 */ "\"%1\" has been set to Permanent by %A. It will always be locked unless Amnesty is granted and will automatically be re-attached and re-locked when released or when the handler is away from the region for too long.",
                    /* 12 */ "\"%1\" is no longer set to Permanent by %A. From now on it will be unlocked when released or when the handler is away from the region for too long.",
                    /* 13 */ "Permission of \"%1\" has been set to Owner by %A.",
                    /* 14 */ "Permission of \"%1\" has been set to Trusted by %A.",
                    /* 15 */ "Permission of \"%1\" has been set to Anyone by %A.",
                    /* 16 */ "%A has released control of \"%1\" back to you.",
                    /* 17 */ "%A has released control of \"%1\". It has been re-attached and re-locked automatically.",
                    /* 18 */ "%A has taken control of \"%1\".",
                    /* 19 */ "%A has granted you Amnesty for \"%1\". It has been unlocked, but will be re-attached and re-locked automatically if they are away from the region for too long.",
                    /* 20 */ "You have Left \"%1\" Locked in Exclusive mode.",
                    /* 21 */ "You have Left \"%1\" Locked in Shared mode.",
                    /* 22 */ "You have Left \"%1\" Locked in Playful mode.",
                    ""];
                if (iTextNum < 1 || iTextNum >= llGetListLength(lText))
                    lSpec = [0, iTextNum];
                string sMessage = llList2String(lText, iTextNum);
                if (sMessage)
                    Notify2(kWearer, kActor, kWearer, lSpec, sMessage);
            }
        } else if (iNum == LINK_UPDATE) {
            if (sSpec == "LINK_DIALOG")
                LINK_DIALOG = iSender;
        }
    }
}
