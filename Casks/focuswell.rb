# Homebrew cask for FocusWell. This repository is its own tap.
cask "focuswell" do
  version "0.1.0"
  sha256 "150988e21ae70287801238dc7c2bfada8d9b63407e90ac660096ce461591b485"

  url "https://github.com/moetiker/FocusWell/releases/download/v#{version}/FocusWell-#{version}.zip"
  name "FocusWell"
  desc "Gives the window under the mouse the focus without raising it"
  homepage "https://github.com/moetiker/FocusWell"

  depends_on macos: ">= :sonoma"

  app "FocusWell.app"

  uninstall quit: "ch.oetiker.FocusWell"

  zap trash: "~/Library/Preferences/ch.oetiker.FocusWell.plist"
end
