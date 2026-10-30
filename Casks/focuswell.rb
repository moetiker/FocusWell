# Homebrew cask for FocusWell. This repository is its own tap.
cask "focuswell" do
  version "0.1.3"
  sha256 "402677ebf7f489284b73be321c58bc6b6048076a6242a9c428706326071861cd"

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
