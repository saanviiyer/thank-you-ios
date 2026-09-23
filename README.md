# thank you for iOS

thank you is a native SwiftUI social app for sharing kindness and sending thanks.

This repo is the iOS client. The sibling repo [thank-you-app](https://github.com/saanviiyer/thank-you-app) is the web client of the same product.

## Features

Version 1.2 is a complete local-first mobile app.

- Accounts: sign-up and sign-in with unique usernames and emails, strong-password checks, salted password hashes, Keychain storage, persistent sessions, sign-out and account deletion.
- Profiles: photo, display name, username, 160-character bio, location, website, live story, thanks and following counts, and profile editing.
- Feed: a persistent kindness feed with For You and Following modes. You can post stories with an optional photo and geotag, pick a category, send thanks, reply, share, open the author profile and delete your own stories.
- Discover: search, suggested people, follow and unfollow, public profile pages, and saved activity with unread badges.
- Storage: thanks, follows and activity are kept for each account over a shared on-device feed. The app migrates the original v1 state and writes to protected files atomically.
- Platform: bounded photo processing, clear storage and permission errors, a complete App Store icon, and an Apple privacy manifest that declares no tracking and no data collection.

The app works fully on one device and supports more than one local account. The iOS Keychain holds the credentials. Profiles, stories, attached photos, replies, thanks, activity and follows persist across launches.

A public multi-device launch still needs a hosted authentication and database service. You must connect `AuthStore` and `KindnessStore` to that service so that accounts and feeds sync between devices.

## Run it

Requirements: iOS 17 or later, Xcode. The app uses SwiftUI and has no third-party dependencies.

```bash
git clone https://github.com/saanviiyer/thank-you-ios
cd thank-you-ios
open ThankYou.xcodeproj
```

In Xcode, select an iPhone simulator and press Run.

## Test

Strict compile check with no simulator:

```bash
sdk_path=$(xcrun --sdk iphoneos --show-sdk-path)
mkdir -p /tmp/thankyou-module-cache
xcrun --sdk iphoneos swiftc -typecheck -warnings-as-errors \
  -target arm64-apple-ios17.0 -sdk "$sdk_path" \
  -module-cache-path /tmp/thankyou-module-cache \
  -strict-concurrency=complete \
  -module-name ThankYou ThankYou/*.swift
```

Validation checks with no dependencies:

```bash
xcrun swiftc ThankYou/Validation.swift Tests/AccountValidationTests.swift \
  -o /tmp/thankyou-validation-tests
/tmp/thankyou-validation-tests
```

## Release

To archive for the App Store, select a development team in Signing & Capabilities. The app includes the required privacy manifest and a 1024×1024 opaque icon. The project targets iOS 17, marketing version 1.2, build 3.

## Environment variables

None.

## Layout

```
ThankYou.xcodeproj/         Xcode project
ThankYou/
  ThankYouApp.swift         app entry
  Authentication.swift      AuthStore: accounts, password hashes, Keychain
  AuthViews.swift           welcome, sign-up and sign-in screens
  ContentView.swift         home feed and post cards
  SecondaryViews.swift      composer, discover, activity and profile screens
  Models.swift              posts, people, comments, activity, KindnessStore
  ImageProcessor.swift      photo processing
  LocationManager.swift     geotags
  Validation.swift          account field checks
  PrivacyInfo.xcprivacy     Apple privacy manifest
  Assets.xcassets/          app icon and accent color
Tests/
  AccountValidationTests.swift
```
