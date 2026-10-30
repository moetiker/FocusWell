# FocusWell

FocusWell gives the window under the mouse the keyboard focus without bringing it to
the front. Point at a window and type: the keys go there, and the window stays where it
is in the stack.

It sits in the menu bar as a small balloon. Green means the focus follows the mouse, red
means it is off. Click the balloon to switch it on or off, right-click it for the menu
with Quit. Hold Control to pause it while moving the mouse.

It needs macOS 14 or later and runs on Apple silicon and Intel Macs.

## Install

    brew tap moetiker/FocusWell https://github.com/moetiker/FocusWell
    brew install --cask focuswell

Open FocusWell from the Applications folder. On the first start macOS asks for
Accessibility access: allow it under System Settings > Privacy & Security >
Accessibility. The balloon turns green as soon as access is granted.

## Build

    make app        # build/FocusWell.app
    make install    # into /Applications
    make test

The build signs with the first Developer ID Application certificate in the keychain,
and ad hoc without one. `SIGN_IDENTITY` names another identity, `-` forces ad hoc.

A release is signed and notarized:

    xcrun notarytool store-credentials FocusWell --apple-id <apple id> --team-id <team id>
    make clean
    make notarize cask

This leaves build/FocusWell-<version>.zip for the GitHub release `v<version>` and points
Casks/focuswell.rb at it.

## Troubleshooting

To see what FocusWell decides, start it from a terminal with logging:

    FOCUSWELL_VERBOSE=1 /Applications/FocusWell.app/Contents/MacOS/FocusWell

After a rebuild signed ad hoc, macOS no longer recognises the app. `make install` resets
its Accessibility entry, and macOS asks for access again on the next start. When FocusWell
is missing from the Accessibility list or stays red while switched on, add
/Applications/FocusWell.app with the plus button.

## Credits

FocusWell started as a fork of [AutoRaise](https://github.com/sbmpost/AutoRaise) by
sbmpost, reduced to focusing without raising. Focusing without raising uses the method
of [yabai](https://github.com/koekeishiya/yabai). Like AutoRaise, FocusWell is licensed
under the GNU General Public License, version 3 (LICENSE.md).
