# Homebrew cask for FocusWell. This repository is its own tap.
cask "focuswell" do
  version "0.1.2"
  sha256 "3d3e89fad40ee66297483d32d5649e2c0d364af397a26d356fce5c5091fbd5d7"

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
