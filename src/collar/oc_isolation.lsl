// This file is part of Tama's OpenCollar.
// Copyright (c) 2018 tamakohan
// Licensed under the GPLv2.

// Contains large portions of code from other OpenCollar scripts.
// Copyright (c) 2009 - 2017 Cleo Collins, Nandana Singh, Satomi Ahn,
// Joy Stipe, Wendy Starfall, Medea Destiny, littlemousy,
// Romka Swallowtail, Garvin Twine et al.
// Licensed under the GPLv2.  See LICENSE for full details.

// Contains large portions of code from the OpenMuzzle main control script for OC 3.998
// licensed under GPLv2 by WhiteFire Sondergaard of Lascivious Vulpine.

string g_sAppVersion = "1.0";

string g_sSubMenu = "Isolation";
string g_sParentMenu = "Apps";
list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

key g_kWearer;

integer g_iDebug = 0;

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
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

key BARK = "ab680371-f5fe-212a-b02f-15082b234eb8";
key PANT = "7de7ca8b-0582-0699-e0a1-e9ee72f23f8b";

string g_sGlobalToken = "global_";
string g_sSettingToken = "isolation_";

string g_sDeafenLevel = "Off";
string g_sMuffleLevel = "Off";
string g_sMuffleName = "";
integer g_iMuffleActive = 0;
integer g_iBlindBits = 0x1F5; // Default restrictions: Avatars, Feel, Clarity, Windlight, Location, Camming, Hovertext
integer g_iBlindActive = 0;

list g_lDeafenLevels = ["Off", "Hindered", "Muffled", "Faint", "Deaf"];
list g_lMuffleLevels = ["Off", "Moderate", "Severe", "Extreme", "Puppy", "Mute"];
list g_lBlindFlags = ["Avatars", "World", "Feel", "Emotes", "Clarity", "Windlight", "Location", "Camming", "Hovertext", "Names"];
list g_lBlindCommands = ["camavdist:2", "setcam_textures", "setcam_textures:91752e79-a556-787f-7cdb-8b7bb0de7a6c", "recvemote", "setdebug_renderresolutiondivisor:", "setenv_densitymultiplier:,setenv_distancemultiplier:,setenv_scenegamma:", "showloc,showminimap,showworldmap", "camunlock", "showhovertextworld,shownametags", "shownames"];

integer g_iDeafenListener;

integer g_iMuffleSpeechListener;
integer g_iMuffleEmoteListener;

integer g_iMuffleSpeechChannel = 300;
integer g_iMuffleEmoteChannel = 310;

DebugFreeMem() {
    if (g_iDebug)
        llOwnerSay(llGetScriptName()+": "+(string)llGetFreeMemory()+" bytes free");
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

string Partialbox(string sText, integer iPartial) {
    if (iPartial)
        return "◈ " + sText;
    else
        return "◇ " + sText;
}

//===============================================================================
//===============================================================================
// DEAFENER

// Send a gagged-speech version of a message to the open channel.
string MangleReceivedText(string message, string severity, float distance) {
    if (g_sDeafenLevel == "Off")
        return message;
    if (g_sDeafenLevel == "Deaf")
        return "...";
    
    float multiplier = (distance / 5.0); // + 1.0;

    float letterChance = 100.0 - (5.0 * multiplier);
    if (severity == "Muffled")
        letterChance -= (25.0 * multiplier);
    else if (severity == "Faint")
        letterChance -= (50.0 * multiplier);
    
    letterChance -= (distance * multiplier);
    if (letterChance < 0.0)
        letterChance = 0.0;
    
    string AlphaNumeric = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    
    integer index;
    string newMessage = "";
    integer dots = 0;
    
    for (index = 0; index < llStringLength(message); index++) {
        string char = llGetSubString(message, index, index);
        
        if (~llSubStringIndex(AlphaNumeric, char) && letterChance < llFrand(100.0)) {
            if (dots < 3) {
                newMessage += ".";
                dots++;
            }
        } else {
            newMessage += char;
            dots = 0;
        }
    }
    
    return newMessage; 
}

MangleReceivedSpeech(key id, string speaker, string mes, string severity) {
    if (g_sDeafenLevel == "Deaf")
        return;

    // Mangle the received message.
    mes = MangleReceivedText(mes, severity, llVecMag(llList2Vector(llGetObjectDetails(id, [OBJECT_POS]), 0) - llGetPos()));

    // Store current object name.
    string storeName = llGetObjectName();

    // Set object name to given name (so it speaks as if the wearer).
    // Replace conditionals so tags use dynamic values.
    llSetObjectName(speaker);
    
    // Broadcast the muffled speech on the chat channel.
    llOwnerSay(mes);

    // Restore object name.
    llSetObjectName(storeName);
}

MangleReceivedEmote(key id, string speaker, string mes, string severity) {
    string unparsedMessage = mes;
    string parsedMessage = "";
    float distance = llVecMag(llList2Vector(llGetObjectDetails(id, [OBJECT_POS]), 0) - llGetPos());
    integer quoteIndex = llSubStringIndex(unparsedMessage, "\"");
    
    while (~quoteIndex) {
        if (quoteIndex)
            parsedMessage += llGetSubString(unparsedMessage, 0, quoteIndex - 1);
        if (quoteIndex != llStringLength(unparsedMessage) - 1)
            unparsedMessage = llGetSubString(unparsedMessage, quoteIndex + 1, -1);
        else
            unparsedMessage = "";
        
        if (llStringLength(unparsedMessage)) {
            quoteIndex = llSubStringIndex(unparsedMessage, "\"");
            if (!quoteIndex) {
                parsedMessage += "\"\"";
                if (llStringLength(unparsedMessage) != 1)
                    unparsedMessage = llGetSubString(unparsedMessage, quoteIndex + 1, -1);
                else
                    unparsedMessage = "";
            } else if (~quoteIndex) {
                string speachText = llGetSubString(unparsedMessage, 0, quoteIndex - 1);
                parsedMessage += "\"" + MangleReceivedText(speachText, severity, distance) + "\"";
                
                if (quoteIndex != llStringLength(unparsedMessage) - 1)
                    unparsedMessage = llGetSubString(unparsedMessage, quoteIndex + 1, -1);
                else
                    unparsedMessage = "";
            } else {
                parsedMessage += "\"" + MangleReceivedText(unparsedMessage, severity, distance) + "\"";
                unparsedMessage = "";
            }
        }
        
        quoteIndex = llSubStringIndex(unparsedMessage, "\"");
    }
    parsedMessage += unparsedMessage;
    
    // Store current object name.
    string storeName = llGetObjectName();
    
    // Set object name to given name (so it speaks as if the wearer).
    // Replace conditionals so tags use dynamic values.
    llSetObjectName(speaker);
    
    // Broadcast the muffled speech on the chat channel.
    llOwnerSay("/me " + parsedMessage);

    // Restore object name.
    llSetObjectName(storeName);
}

//===============================================================================
//===============================================================================
// MUFFLER

// Send a gagged-speech version of a message to the open channel.
string MangleSendingText(string mes, string severity) {
    // Iterate through the speech, mushing up the wearer's diction.
    integer i;
    string sub = "";
    string rep = "";
        
    if (severity == "Off")
        return mes;
    if (severity == "Puppy")
        return "Woof!";
    if (severity == "Mute")
        return "...";
    
    string retval = "";
    for (i = 0; i < llStringLength(mes); i++) {
        sub = llGetSubString(mes, i, i);
        rep = "";
        
        if (severity == "Moderate") {
            if (sub == "l")
                rep = "w";
            else if (sub == "R" || sub == "L")
                rep = "W";
            else if (sub == "s")
                rep = "f";
            else if (sub == "S")
                rep = "F";
            else if (sub == "t")
                rep = "g";               
            else if (sub == "T")
                rep = "G";                
        } else if (severity == "Severe") {
            if (sub == "a" || sub == "b" || sub == "j" || sub == "s" || sub == "v" || sub == "z")
                rep = "r";
            else if (sub == "A" || sub == "B" || sub == "J" || sub == "S" || sub == "V" || sub == "Z")
                rep = "R";
            else if (sub == "d" || sub == "k" || sub == "l" || sub == "w")
                rep = "f";
            else if (sub == "D" || sub == "K" || sub == "L" || sub == "W")
                rep = "F";            
            else if (sub == "g" || sub == "x")
                rep = "n";
            else if (sub == "G" || sub == "x")
                rep = "N";                
            else if (sub == "h" || sub == "i" || sub == "m" || sub == "u")
                rep = "d";
            else if (sub == "H" || sub == "I" || sub == "M" || sub == "U")
                rep = "D";                
            else if (sub == "q")
                rep = "m";
            else if (sub == "Q")
                rep = "M";                
        } else if (severity == "Extreme") {
            if (sub =="B" || sub =="D" || sub =="K" || sub =="T" || sub =="V")
                rep = "Mph";
            if (sub =="b" || sub =="d" || sub =="k" || sub =="t" || sub =="M")
                rep = "m";
            if (sub =="D" || sub =="J" || sub =="L" || sub =="Q" || sub =="R")
                rep = "M";
            if (sub =="d" || sub =="j" || sub =="l" || sub =="q" || sub =="r")
                rep = "ph";
            if (sub =="S")
                rep = "H";
            if (sub =="s")
                rep = "m";
            if (sub =="C")
                rep = "Mf";
            if (sub =="c")
                rep = "m";
            if (sub =="A" || sub =="E" || sub =="I" || sub =="O" || sub =="U")
                rep = "Mph";
            if (sub =="a" || sub =="e" || sub =="i" || sub =="o" || sub =="u")
                rep = "m";
            if (sub =="C" || sub =="V" || sub =="N" || sub =="Y")
                rep = "Mh";
            if (sub =="c" || sub =="v" || sub =="n" || sub =="y")
                rep = "ph";
            if (sub =="W" || sub =="Y" || sub =="Z" || sub =="X")
                rep = "Mf";
            if (sub =="w" || sub =="y" || sub =="z" || sub =="x")
                rep = "f";
        } else {
            llOwnerSay("muffle '" +severity + "'");
        }
    
        // Replace character if necessary.        
        if (rep != "")
            retval += rep;
        else
            retval += sub;
    }
    
    return retval;
}

MangleSendingSpeech(string mes, string severity) {
    if (severity == "Mute")
        return;

    mes = MangleSendingText(mes, severity);

    // Store current object name.
    string storeName = llGetObjectName();

    // Set object name to given name (so it speaks as if the wearer).
    llSetObjectName(g_sMuffleName);
    
    // Broadcast the muffled speech on the chat channel.
    if (severity == "Puppy") {
        integer random = (integer) llFrand (12.0); // 0 <= random < 12
        if (random < 2) {
            llSay(0, "/me barks happily!");
            llPlaySound(BARK, 1.0);
        } else if (random < 4) {
            llSay(0, "/me sniffs at the floor before offering a forward bark!");
            llPlaySound(BARK, 1.0);
        } else if (random < 6) {
            llSay(0, "/me playfully barks!");
            llPlaySound(BARK, 1.0);
        } else if (random < 8) {
            llSay(0, "/me looks like they are going to say something, only to let out a loud bark!");
            llPlaySound(BARK, 1.0);
        } else if (random < 9) {
            llSay(0, "/me looks up like they are going to say something, only to pant contentedly.");
            llPlaySound(PANT, 1.0);
        } else if (random < 10) {
            llSay(0, "/me pants heavily.");
            llPlaySound(PANT, 1.0);
        } else if (random < 11) {
            llSay(0, "/me happily wags their tail and pants.");
            llPlaySound(PANT, 1.0);
        } else /* random < 12 */ {
            llSay(0, "/me lays down on the floor and pants.");
            llPlaySound(PANT, 1.0);
        }
    } else if (severity == "Off") {
         llSay(0, mes);
    } else {
         llSay(0, "/me mumbles \""+mes+"\"");
    }

    // Restore object name.
    llSetObjectName(storeName);
}

MangleSendingEmote(string mes, string severity) {
    string unparsedMessage = mes;
    string parsedMessage = "";
    integer quoteIndex = llSubStringIndex(unparsedMessage, "\"");
    
    while (~quoteIndex) {
        if (quoteIndex)
            parsedMessage += llGetSubString(unparsedMessage, 0, quoteIndex - 1);
        if (quoteIndex != llStringLength(unparsedMessage) - 1)
            unparsedMessage = llGetSubString(unparsedMessage, quoteIndex + 1, -1);
        else
            unparsedMessage = "";
        
        if (llStringLength(unparsedMessage)) {
            quoteIndex = llSubStringIndex(unparsedMessage, "\"");
            if (quoteIndex == 0) {
                parsedMessage += "\"\"";
                if (llStringLength(unparsedMessage) != 1)
                    unparsedMessage = llGetSubString(unparsedMessage, quoteIndex + 1, -1);
                else
                    unparsedMessage = "";
            } else if (quoteIndex != -1) {
                string speachText = llGetSubString(unparsedMessage, 0, quoteIndex - 1);
                parsedMessage += "\"" + MangleSendingText(speachText, severity) + "\"";
                
                if (quoteIndex != llStringLength(unparsedMessage) - 1)
                    unparsedMessage = llGetSubString(unparsedMessage, quoteIndex + 1, -1);
                else
                    unparsedMessage = "";
            } else {
                parsedMessage += "\"" + MangleSendingText(unparsedMessage, severity) + "\"";
                unparsedMessage = "";
            }
        }
        
        quoteIndex = llSubStringIndex(unparsedMessage, "\"");
    }
    parsedMessage += unparsedMessage;

    // Store current object name.
    string storeName = llGetObjectName();
    
    // Set object name to given name (so it speaks as if the wearer).
    llSetObjectName(g_sMuffleName);
    
    // Broadcast the muffled speech on the chat channel.
    llSay(0, parsedMessage);        

    // Restore object name.
    llSetObjectName(storeName);
}

//===============================================================================
//===============================================================================


RlvSay(string sCmd) {
    //if (g_iDebug)
    //    llOwnerSay(llGetScriptName()+" R> " + sCmd);
    //llOwnerSay(sCmd);
    llMessageLinked(LINK_RLV, RLV_CMD, llGetSubString(sCmd, 1, -1), NULL_KEY);
}

RlvUpdateDeafener() {
    // we use "secure" restrictions here, so that even text from avatars
    //   exceptionally allowed to communicate with us will be filtered
    // (i.e. owners & trusteds by default)
    if (g_sDeafenLevel != "Off") {
        // add deafen filter
        RlvSay("@recvchat_sec=n,recvemote_sec=n"); 
        g_iDeafenListener = llListen(PUBLIC_CHANNEL, "", NULL_KEY, "");
    } else {
        // remove deafen filter
        RlvSay("@recvchat_sec=y,recvemote_sec=y");
        llListenRemove(g_iDeafenListener);
    }
}

RlvUpdateMuffler() {
    if (g_iMuffleActive) {
        // add muffle filter
        RlvSay("@sendchat=n,redirchat:" + (string)g_iMuffleSpeechChannel 
            + "=add,rediremote:" + (string)g_iMuffleEmoteChannel + "=add,sendchannel:" + (string)g_iMuffleSpeechChannel 
            + "=add,sendchannel:" + (string)g_iMuffleEmoteChannel + "=add");
        g_iMuffleSpeechListener = llListen(g_iMuffleSpeechChannel, "", llGetOwner(), "");
        g_iMuffleEmoteListener = llListen(g_iMuffleEmoteChannel, "", llGetOwner(), "");
    } else {
        // remove muffle filter
        RlvSay("@sendchat=y,emote=rem,redirchat:" + (string)g_iMuffleSpeechChannel 
            + "=rem,rediremote:" + (string)g_iMuffleEmoteChannel + "=rem,sendchannel:" + (string)g_iMuffleSpeechChannel 
            + "=rem,sendchannel:" + (string)g_iMuffleEmoteChannel + "=rem");
        llListenRemove(g_iMuffleSpeechListener);
        llListenRemove(g_iMuffleEmoteListener);
    }
}

RlvUpdateBlindfold() {
    // add/remove all bits in g_iBlindBits
    list lCommands;
    integer iIndex = 0;
    integer iCount = llGetListLength(g_lBlindCommands);
    while (iIndex < iCount) {
        if (g_iBlindBits & (1 << iIndex))
            lCommands += RlvGetBlindfoldCommand(iIndex, g_iBlindActive);
        iIndex += 1;
    }
    if (llGetListLength(lCommands))
        RlvSay("@"+llDumpList2String(lCommands, ","));
}

RlvUpdateBlindfoldBit(integer iBit) {
    // add/remove single bit
    RlvSay("@"+RlvGetBlindfoldCommand(iBit, (g_iBlindBits & (1 << iBit))));
}

string RlvGetBlindfoldCommand(integer iBit, integer iRestrict) {
    string sCommand = llList2String(g_lBlindCommands, iBit);
    if (iRestrict && (iBit == 1 || iBit == 2)) {
        sCommand = RlvGetBlindfoldCommand(3 - iBit, FALSE) + "," + sCommand + "=n";
    } else if (iBit == 4) { // Clarity
        if (iRestrict)
            sCommand += "96=force";
        else
            sCommand += "1=force";
    } else if (iBit == 5) { // Windlight
        list lParts = llParseStringKeepNulls(sCommand, [","], []);
        if (iRestrict)
            sCommand = "setenv=n," + llList2String(lParts, 0) + "0.9=force," + llList2String(lParts, 1) + "100.0=force," + llList2String(lParts, 2) + "0.0=force";
        else
            sCommand = "setenv=y," + llList2String(lParts, 0) + "1.0=force," + llList2String(lParts, 1) + "1.0=force," + llList2String(lParts, 2) + "1.0=force";
    } else {
        if (iRestrict)
            sCommand = llDumpList2String(llParseStringKeepNulls(sCommand, [","], []), "=n,") + "=n";
        else
            sCommand = llDumpList2String(llParseStringKeepNulls(sCommand, [","], []), "=y,") + "=y";
    }
    return sCommand;
}

SetName(string sName) {
    sName = llStringTrim(sName, STRING_TRIM);
    if (sName == "")
        sName = llGetDisplayName(g_kWearer)+" ("+llGetUsername(g_kWearer)+")";
    g_sMuffleName = sName;
}

IsolationMenu(key kAv, integer iAuth, string sMenu, string sButton) {
    if (iAuth < CMD_OWNER || iAuth > CMD_GROUP) {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"%NOACCESS%", kAv);
        return;
    }

    if (sMenu == "rmisolation") {
        if (sButton == "Yes") {
            llMessageLinked(LINK_ROOT, MENUNAME_REMOVE , g_sParentMenu + "|" + g_sSubMenu, "");
            llMessageLinked(LINK_DIALOG, NOTIFY, "1"+g_sSubMenu+" App has been removed.", kAv);
            if (llGetInventoryType(llGetScriptName()) == INVENTORY_SCRIPT)
                llRemoveInventory(llGetScriptName());
        } else {
            llMessageLinked(LINK_DIALOG, NOTIFY, "0"+g_sSubMenu+" App remains installed.", kAv);
        }
        return;
    }

    string sPrompt = "\n[Isolation]\t"+g_sAppVersion;
    list lButtons = [];
    
    if (sButton == UPMENU) {
        if (sMenu == "") {
            llMessageLinked(LINK_ROOT, iAuth, "menu "+g_sParentMenu, kAv);
            return;
        }
        sMenu = "";
        sButton = "";
    }
    
    if (sMenu == "SetName") {
        SetName(sButton);
        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"mufflename="+sButton, "");
        sMenu = "";
        sButton = "";
    }
    
    if (sMenu == "") {
        if (sButton == "◇ Deafener" || sButton == "◈ Deafener") {
            sMenu = "Deafener";
            sButton = "";
        } else if (sButton == "◇ Muffler" || sButton == "◈ Muffler") {
            sMenu = "Muffler";
            sButton = "";
        } else if (sButton == "◇ Blindfold" || sButton == "◈ Blindfold") {
            sMenu = "Blindfold";
            sButton = "";
        }
    }
    
    string sSearch = llGetSubString(sButton, 2, -1);
    integer iActive = (llGetSubString(sButton, 0, 0) == "☐");
    
    if (sMenu == "Deafener") {
        sPrompt += "\n\nDeafener";
        if (g_sDeafenLevel != sSearch) {
            if (~llListFindList(g_lDeafenLevels, [sSearch])) {
                integer iUpdate = (g_sDeafenLevel == "Off" || sSearch == "Off");
                g_sDeafenLevel = sSearch;
                if (iUpdate)
                    RlvUpdateDeafener();
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"deafenlevel="+g_sDeafenLevel, "");
                llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Deafener has been set to "+llToUpper(g_sDeafenLevel)+".", kAv);
            }
        }
        
        integer iIndex = 0;
        integer iCount = llGetListLength(g_lDeafenLevels);
        while (iIndex < iCount) {
            string sLevel = llList2String(g_lDeafenLevels, iIndex);
            lButtons += Selectbox(sLevel, (sLevel == g_sDeafenLevel));
            iIndex += 1;
        }
    } else if (sMenu == "Muffler") {
        sPrompt += "\n\nMuffler for "+g_sMuffleName;
        if (g_sMuffleLevel != sSearch) {
            if (~llListFindList(g_lMuffleLevels, [sSearch])) {
                g_sMuffleLevel = sSearch;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"mufflelevel="+g_sMuffleLevel, "");
                if (g_iMuffleActive)
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Muffler has been set to "+llToUpper(g_sMuffleLevel)+".", kAv);
            }
        }
        if (sSearch == "Active") {
            if (g_iMuffleActive != iActive) {
                g_iMuffleActive = iActive;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"muffleactive="+(string)g_iMuffleActive, "");
                RlvUpdateMuffler();
                if (!g_iMuffleActive)
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Muffler is no longer active.", kAv);
                else if (g_sMuffleLevel != "Off")
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Muffler is now active and set to "+llToUpper(g_sMuffleLevel)+".", kAv);
                else
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Muffler is now active (for renaming only).", kAv);
            }
        } else if (sButton == "Set Name") {
            Dialog(kAv, sPrompt+"\n\nChoose a new name for the sub. Muffler must be active (but can be \"Off\") for this to take effect.", [], [], 0, iAuth, "SetName");
            return;
        }
        
        integer iIndex = 0;
        integer iCount = llGetListLength(g_lMuffleLevels);
        while (iIndex < iCount) {
            string sLevel = llList2String(g_lMuffleLevels, iIndex);
            lButtons += Selectbox(sLevel, (sLevel == g_sMuffleLevel));
            iIndex += 1;
        }
        
        lButtons += Checkbox("Active", g_iMuffleActive);
        lButtons += "Set Name";
    } else if (sMenu == "Blindfold") {
        sPrompt += "\n\nBlindfold";
        integer iBit = llListFindList(g_lBlindFlags, [sSearch]);
        if (~iBit) {
            integer iMask = 1 << iBit;
            iActive = !iActive; // blindfold flag checkboxes are inverted for display
            if (iActive == !(g_iBlindBits & iMask)) {
                if (iActive)
                    g_iBlindBits = g_iBlindBits | iMask;
                else
                    g_iBlindBits = g_iBlindBits &~ iMask;
                if (g_iBlindActive)
                    RlvUpdateBlindfoldBit(iBit);
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"blindbits="+(string)g_iBlindBits, "");
            }
        } else if (sSearch == "Active") {
            if (g_iBlindActive != iActive) {
                g_iBlindActive = iActive;
                RlvUpdateBlindfold();
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"blindactive="+(string)g_iBlindActive, "");
                if (!g_iBlindActive)
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Blindfold is no longer active.", kAv);
                else
                    llMessageLinked(LINK_DIALOG, NOTIFY, "1"+"Blindfold is now active.", kAv);
            }
        }
        
        integer iIndex = 0;
        integer iCount = llGetListLength(g_lBlindFlags);
        while (iIndex < iCount) {
            string sLevel = llList2String(g_lBlindFlags, iIndex);
            lButtons += Checkbox(sLevel, !(g_iBlindBits & (1 << iIndex))); // blindfold flag checkboxes are inverted for display
            
            // insert "Active" checkbox at bottom left instead of bottom center
            if (iIndex == 8)
                lButtons += Checkbox("Active", g_iBlindActive);
            
            iIndex += 1;
        }
    } else {
        lButtons += Partialbox("Deafener", (g_sDeafenLevel != "Off"));
        lButtons += Partialbox("Muffler", g_iMuffleActive);
        lButtons += Partialbox("Blindfold", g_iBlindActive);
    }
    
    Dialog(kAv, sPrompt, lButtons, [UPMENU], 0, iAuth, sMenu);
}

UserCommand(integer iNum, string sStr, key kID) { // here iNum: auth value, sStr: user command, kID: avatar id
    sStr = llToLower(sStr);
    if (sStr == "menu isolation" || sStr == "isolation") {
        IsolationMenu(kID, iNum, "", "");
    } else if (sStr == "rm isolation") {
        if (kID!=g_kWearer && iNum!=CMD_OWNER)
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        else
            Dialog(kID,"\nDo you really want to uninstall the "+g_sSubMenu+" App?", ["Yes","No","Cancel"], [], 0, iNum,"rmisolation");
    }
}

default {
    on_rez(integer param) {
        g_kWearer = llGetOwner();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        SetName("");
        DebugFreeMem();
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == PUBLIC_CHANNEL) {
            // Deafener

            if (!llSubStringIndex(message, "(("))
                return;
            
            string speaker;
            if (llGetAgentSize(id) == ZERO_VECTOR) {
                if (llGetOwnerKey(id) == g_kWearer && (name == llGetDisplayName(g_kWearer) || name == llKey2Name(g_kWearer)))
                    return;
                speaker = name;
            } else {
                if (id == g_kWearer)
                    return;
                speaker = llGetDisplayName(id);
                if (speaker == "" || speaker == "???")
                    speaker = llKey2Name(id);
            }
                
            if (!llSubStringIndex(message, "/me "))
                MangleReceivedEmote(id, speaker, llGetSubString(message, 4, llStringLength(message)), g_sDeafenLevel);
            else
                MangleReceivedSpeech(id, speaker, message, g_sDeafenLevel);
        } else if (channel == g_iMuffleSpeechChannel) {
            // Muffler
            MangleSendingSpeech(message, g_sMuffleLevel);
        } else if (channel == g_iMuffleEmoteChannel) {
            // Muffler
            MangleSendingEmote(message, g_sMuffleLevel);
        }       
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
                IsolationMenu(kAv, iAuth, sMenu, sMessage);
            }
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
                if (sToken == "deafenlevel") {
                    if (sValue != g_sDeafenLevel) {
                        if (~llListFindList(g_lDeafenLevels, [sValue])) {
                            integer iUpdate = (g_sDeafenLevel == "Off" || sValue == "Off");
                            g_sDeafenLevel = sValue;
                            if (iUpdate)
                                RlvUpdateDeafener();
                        }
                    }
                } else if (sToken == "mufflelevel") {
                    if (g_sMuffleLevel != sValue)
                        if (~llListFindList(g_lMuffleLevels, [sValue]))
                            g_sMuffleLevel = sValue;
                } else if (sToken == "mufflename") {
                    SetName(sValue);
                } else if (sToken == "muffleactive") {
                    integer iValue = (((integer) sValue) > 0);
                    if (g_iBlindActive != iValue) {
                        g_iMuffleActive = iValue;
                        RlvUpdateMuffler();
                    }
                } else if (sToken == "blindbits") {
                    integer iMask = (((integer) sValue) & ((1 << llGetListLength(g_lBlindFlags)) - 1));
                    if (g_iBlindActive) {
                        // tricky...
                        integer iRestrictMask = iMask &~ g_iBlindBits;
                        integer iFreeMask = g_iBlindBits &~ iMask;
                        g_iBlindActive = FALSE;
                        g_iBlindBits = iFreeMask;
                        RlvUpdateBlindfold();
                        g_iBlindActive = TRUE;
                        g_iBlindBits = iRestrictMask;
                        RlvUpdateBlindfold();
                    }
                    g_iBlindBits = iMask;
                } else if (sToken == "blindactive") {
                    integer iValue = (((integer) sValue) > 0);
                    if (g_iBlindActive != iValue) {
                        g_iBlindActive = iValue;
                        RlvUpdateBlindfold();
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
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER)
            llResetScript();
    }
}
