# Homebrew cask for FocusWell. This repository is its own tap.
cask "focuswell" do
  version "0.1.1"
  sha256 "6c772bfc776622a8252ed4f53ed1ec6ea3c107d076cc4f2b8f8aec9e4bda5a45"

  url "https://github.com/moetiker/FocusWell/releases/download/v#{version}/FocusWell-#{version}.zip"
  name "FocusWell"
  desc "Gives the window under the mouse the focus without raising it"
  homepage "https://github.com/moetiker/FocusWell"

  depends_on macos: :sonoma

  app "FocusWell.app"

  uninstall quit: "ch.oetiker.FocusWell"

  zap trash: "~/Library/Preferences/ch.oetiker.FocusWell.plist"
end
