<p align="center">
  <img src="https://github.com/jqyDee/WindowSwitcher9000/blob/main/IconWindowSwitcher_Exports/IconWindowSwitcher-macOS-ClearDark-512x512%401x.png" width="200"/>
<!p>

<h1 align="center">WindowSwitcher9000</h1>

![](https://github.com/jqyDee/WindowSwitcher9000/blob/main/GithubAssets/thumbnail.png)

# Description
This is a small but fast and I hope reliable window switcher (basically an alternative to `<ALT | CMD> + TAB`). 
Text based and not program bound. So way faster than you tapping away at your native `CMD + TAB` on plain MacOS.

It uses a simple [Fzy](https://github.com/jhawthorn/fzy) like fuzzy search algorithm to search through your open windows first 
and then also your installed applications!
(So basically a window switcher and application launcher in one?!)

The Preview functionality needs Screen Capture Permissions. 
This can also be disabled in the Menu Bar if not needed. 
So far this program has been working somewhat realiable on MacOS 15.5. 
*This is also the only MacOS version this program got tested on!*

# Limitations
*Unfortunately this program is only possible through [yabai](https://github.com/koekeishiya/yabai), a tiling window manager. 
This is because MacOS does not find it necessary to make ALL windows across ALL spaces accessible to the (power-)user!*

Sometimes the window titles that yabai spit out are somewhat verbose (e.g. "Personal - 'github url' 'name of repo' ...").
I would like to add a dynamic filtering that can be set by the user through a GUI Filter Settings Panel for each program idividually.

# Setup
The Setup is really simple (If you have [yabai](https://github.com/koekeishiya/yabai) ;)). Only thing that you might have to do, is change the internal programs path to yabai. 
After changing this to your yabai path, just build the project in XCode (Menu Bar: `Product -> Build`) and open the build folder (Menu Bar: `Product -> Open Build Folder in Finder`).
Then just drag the created Application file (`WindowSwitcher.app`) out of the Release folder into your Application folder. Start the application and go to step [Usage](Usage).
Goodluck!

# Usage
On first startup the Program launches with a Menu Bar icon. This can be disabled later if wanted. 

The Program then asks for Accessibility Permissions which you should grant in the System Settings
(Either through the pop-up or in `System Settings -> Privacy & Security -> Accessibility`).

In the Menu Bar menu you can either open the Panel through clicking on `Toggle Switcher` or with the Keyboard Shortcut `CMD + O`.
*Note that this Keyboard Shortcut only works while the Menu Bar menu is open!*

What you probably want to do is set a global Hotkey to open the Switcher. 
This is done in the `Menu Bar menu -> Set Hotkey -> Open Switcher -> Record Shortcut`.

Now the Switcher Opens through the Hotkey. If the Preview functionality is not disabled previously in the Menu Bar
menu (`Preview` unchecked), the switcher will ask for Screen Recording Permissions
(Either through the pop-up or in `System Settings -> Privacy & Security -> Screen & System Audio Recording`)
to take snapshots of the open windows and provide you with a screenshot of the window in the Preview Panel on the right.

Without any filter text your currently open windows should
be visible. You can filter these open windows by just starting to type. 

It is also possible to start currently not running applications. These are only visible when there is a filter text. This is chosen
by design to make the list a bit less distracting. The title of all applications that can be opened starts
with `Open <application name>`.

To move the selection up the list use `<SHIFT + TAB | ARROW_UP>`. To move it down use `<TAB | ARROW_DOWN>`. To focus the selected window
press `RETURN`!

# Commands
There is a small set of commands available. They are basically providing similar functionality as the Menu Bar menu. To look up the commands
type `/help/` in the filter and press enter. The output of each command will be displayed in the footer of the panel. 

*This is basically so there is a way to unhide the Menu Bar Item again to change some settings. The command set is really unfinished but should
get you out of the sticky situation where you disabled the Menu Bar Item and are wondering how to get it back ;).*

# Footer
*I want to make it clear that this has been my first experience writing in Swift and SwiftUI. This is my first MacOS specific
application and to be honest ChatGPT helped me a lot to create this in about 1-2 weeks. If you find weird things in this Codebase 
create a pull request and I am definitely going to have a look*

© Matti Fischbach 2025
