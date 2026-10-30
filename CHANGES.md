# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
except that the first subsection is called `New` rather than `Added`. The release
workflow matches on `### New`; renaming it silently drops the section from the
release notes.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### New

### Changed

### Fixed

## 0.1.3 - 2026-10-30
### Changed
- After `brew install --cask focuswell`, Homebrew shows how to give FocusWell Accessibility access, and to add it with the plus button when it is missing from the list.

## 0.1.2 - 2026-10-30
### Fixed
- An untitled window of an app that never gets the focus, such as AssistiveControl, could still take the focus.

## 0.1.1 - 2026-10-30
### Fixed
- Moving the mouse right or down into an adjacent window took about 6 pixels more than moving left or up before that window got the focus.
- Web apps installed from Brave were not recognised as web apps, so their untitled windows did not get the focus.
- An app that stopped responding froze the balloon for about 6 seconds on every check. FocusWell now gives up on such an app after half a second.
- Revoking the Accessibility access left the balloon green. The balloon now turns red.

## 0.1.0 - 2026-10-30
### New
- First release: the window under the mouse gets the keyboard focus without coming to the front.
