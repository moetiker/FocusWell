# Testing in a clean macOS VM

`scripts/test-vm` installs FocusWell in a throwaway macOS VM without Accessibility
entries and checks what a new user gets. It needs [Tart](https://tart.run) and
[Packer](https://developer.hashicorp.com/packer).

    scripts/test-vm setup           # once: build the clean image focuswell-clean
    scripts/test-vm run             # test the released cask
    scripts/test-vm run --local     # test the zip from make zip
    scripts/test-vm clean           # delete copies a killed run left behind

`--show` opens the VM window. The exit code of `run` is the number of failed checks.

## The clean image

`setup` builds `focuswell-clean` once, in about an hour, most of it the 17 GB IPSW:

1. `tart create --from-ipsw latest` installs the macOS the Mac runs.
2. On the first boot Tart's provisioning creates the user `admin` (password `admin`)
   with automatic login and SSH.
3. Over SSH: passwordless sudo, no sleep or screen lock, English with a US keyboard
   for Recovery (`nvram prev-lang:kbd=en-US:0`), the Command Line Tools and Homebrew.
4. `Tests/vm/disable-sip.pkr.hcl` boots Recovery through Packer and types
   `csrutil disable`.
5. A normal boot checks `csrutil status`, then the image is renamed to
   `focuswell-clean`.

A failed `setup` resumes after its last finished step; the step is kept in
`build/test-vm/focuswell-clean-building.stage`. A run never starts the clean image
itself. `tart delete focuswell-clean` removes it.

## A run with --local

On the Mac:

1. `swiftc` builds `Tests/vm/focus-check.swift` into `build/focus-check`.
2. `make zip` builds and signs FocusWell into `build/FocusWell-<version>.zip`.
3. `tart clone` makes the copy `focuswell-test-<date-time>`. From here on, every exit
   deletes the copy: a finished run, a failure or Ctrl-C.
4. The copy boots without a window and the script waits for SSH.
5. `scp` copies `check.sh`, `focus-check` and the zip to `~/focuswell-test/`.
6. SSH runs `check.sh local <zip>`. The output also goes to
   `build/test-vm/<vm>.check.log`.

In the VM, `Tests/vm/check.sh`:

7. Unpacks the zip into `/Applications`.
   Check: FocusWell.app is in /Applications.
8. Starts FocusWell, which asks for Accessibility access.
   Checks: FocusWell runs; the prompt added it to the Accessibility list (a row in
   TCC.db, not yet allowed). The prompt dialog is then closed.
9. Grants Accessibility to FocusWell, `focus-check` and `sshd-keygen-wrapper` (SSH
   runs the commands) by writing the system TCC.db with each program's code
   requirement, and restarts FocusWell. This needs SIP off.
10. Opens TextEdit with a text file and Calculator. `focus-check` then:
    - places TextEdit, made narrower, on the left and Calculator on the right edge,
      and fails if they overlap;
    - brings TextEdit to the front and moves the mouse into it.
      Check: TextEdit has the focus and is in front;
    - moves the mouse to Calculator.
      Checks: Calculator has the focus; its window was not raised above TextEdit;
    - moves the mouse back to TextEdit.
      Check: TextEdit has the focus again;
    - types a, b, c into TextEdit and makes Calculator active through Accessibility,
      without a click or a shortcut.
      Check: TextEdit has the focus again after 2 seconds;
    - presses Command-Tab.
      Check: Calculator has the focus and keeps it.

    `lsappinfo` reports the front process, the window list reports the order.
11. Prints an `ok:` or `FAIL:` line per check and `== N failure(s)`, and exits with N.

Back on the Mac the copy is stopped and deleted. A run takes about 1 to 1½ minutes.

## A run of the released cask

`scripts/test-vm run` without `--local` installs the way the README says:
`brew tap`, `brew trust`, `brew install --cask focuswell`, and adds these checks:

- `brew install` prints no warning.
- Gatekeeper accepts the app as notarized. The quarantine flag is removed afterwards,
  since nothing can click the "downloaded from the Internet" dialog.
- After the focus test, `brew uninstall --zap` quits FocusWell and removes the app
  and `~/Library/Preferences/ch.oetiker.FocusWell.plist`. The test writes that file
  first, since FocusWell writes it only when the balloon is switched.

## Limits

- SIP is off in the image, unlike on a user's Mac. A script cannot grant
  Accessibility otherwise.
- The "downloaded from the Internet" dialog is not tested.
- The VM screen is 1024 pixels wide and has no second display, so rules for several
  screens are not tested.
