# Homebrew cask for FocusWell. This repository is its own tap.
cask "focuswell" do
  version "0.1.3"
  sha256 "af6d9bb8bb7fe9d3d6e7eaf2b5c23979268cd11647b5351e5470b00ebd0999ee"

  url "https://github.com/moetiker/FocusWell/releases/download/v#{version}/FocusWell-#{version}.zip"
  name "FocusWell"
  desc "Gives the window under the mouse the focus without raising it"
  homepage "https://github.com/moetiker/FocusWell"

  depends_on macos: :sonoma

  app "FocusWell.app"

  uninstall quit: "ch.oetiker.FocusWell"

  zap trash: "~/Library/Preferences/ch.oetiker.FocusWell.plist"

  caveats <<~EOS
    FocusWell needs Accessibility access. On the first start, allow it under
    System Settings > Privacy & Security > Accessibility. If FocusWell is not
    in the list, add #{appdir}/FocusWell.app with the plus button.
  EOS
end
