# Tama's OpenCollar Release Notes

For older release notes, check the official repository.

## 7.1.3

- Added the "Isolation" App, which contains Deafener, Muffler/Renamer, and Blindfold functions.
  - All of these are functional only and do not have any visual appearance; they are currently designed to be used in combination with unscripted visual accessories.
  - The script is based on the old OpenMuzzle for OC 3.998 script.
- Usability improvements to # Folders:
  - The app will now (re-)show the actions menu after attaching or detaching folders or changing locks.
  - It will assume the attach or detach succeeded as far as calculating the state for the menu is concerned, but one can easily re-calculate by going out of the menu and back in.
  - This change helps with troubleshooting and helps mitigate lag and afk avatar issues.
- Usability improvements to Leash:
  - Added Stay, Unstay and Beckon to the Leash menu; previously these were only usable via chat commands.
  - Made Stay and Unstay messages better for vanilla avatars toggling stay on themselves.
  - Made Beckon work for anyone as long as the avatar is not leashed or following.

## 7.1.2

- Added the "Quote" App, which allows actors of an appropriate rank to set or erase the quote that's displayed in the Main Menu.
  - Owners can also choose if the Date should be recorded and displayed, if the Rank of the writer should be displayed, and if it should apply AutoLock to prevent others of a lower rank overriding it; as well as choose who can set it in the first place.
  - While this is probably overkill, much of this was done as an experiment to see what works nicely for permission systems.
- Added the "Toys" App. This is an experimental system which can communicate with appropriately scripted attachments and allow them to be attached, detached, locked, unlocked, and otherwise interacted with by others.
  - Only one actor can be interacting with any particular toy (attachment) at once. This is by design. Actors can take control from each other, provided that whoever currently has control is not of a higher rank, or that they left it accessible for others.
  - Currently each attachment must be in a folder with the same name as the object, inside a folder called ~oc_toys, inside #RLV. Once scripted, the attachment must be attached manually once to install it, after that it can be attached/detached via the Toys app.
  - Normally, if the controller is away from the wearer (not on the same region) for 15 minutes, control will return automatically to the wearer. An owner can make the toy "Permanent" to change this behaviour so that instead of automatically returning control, it automatically takes away control after this time period (in case someone temporarily granted "Amnesty") leaving the device locked.
  - Touching an attachment will communicate with the collar to establish the rank of the toucher; the attachment menu will then only appear if the toucher has control already (if not, it'll show a menu allowing them to take control, if they are able). You can also access the attachment menu through the Toys app, as well as get back to the collar from the attachment menu. This could be useful later on, if one has many attachments using this system, if some are hard to touch directly they can be reached by navigating through the menu from one of the others.
- Updated all the credit-related places (Help/About, Contact, info, version and news) to point to this GitHub repository not the official one, and make clear that we're unofficial. I *think* that's all the places updated now.

## 7.1.1

- Renamed "OwnSelf" to "Vanilla".
  - Changed the messages that are displayed when Vanilla is turned on or off to something a little more friendly.
  - Changed the output of "Access List" to not include the wearer in the owner list, and to print whether Vanilla is enabled on a separate line.
  - Changed the messages that are printed when you log in to not include the wearer in the owner list. I also removed the [serial comma](https://en.wikipedia.org/wiki/Serial_comma).
- Made the Main Menu look more like Wendy's "Peanut" release.
  - It will display the Locked/unlocked status, "Main Menu", "Tama's OpenCollar" and the version number, the prefix, channel and safeword, and a quote if one is set.
  - Currently there is no way to set the quote via menu or command (but I hope to add this soon). The only way to get a quote to show up at the moment is to be using a Wendy's Distribution collar, go to Settings > Print, copy the settings into your .settings notecard, then migrate to Tama's OpenCollar and load the settings. (Or enter the quote into your .settings manually, but this feature is primarily intended for those migrating from Wendy's Distribution.)
