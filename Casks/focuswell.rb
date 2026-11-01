# Homebrew cask for FocusWell. This repository is its own tap.
cask "focuswell" do
  version "0.2.0"
  sha256 "eca4dab6b04076e4f09f13b1036444f98f07d2266537b4c934bb3bdebbaf1725"

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
