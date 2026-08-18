# thank you for iOS

A native SwiftUI social app for sharing kindness and sending thanks.

This is the native iOS client of the same **thank you** product implemented for
the web in `thank-you-app/`.

Version 1.2 is a complete local-first mobile application rather than a static
prototype. Features include:

- Account creation and sign-in with unique usernames/emails, strong-password
  validation, salted password hashes, Keychain storage, persistent sessions,
  sign-out, and account deletion.
- Full profiles with a photo, display name, username, 160-character bio,
  location, website, dynamic story/thanks/following counts, and profile editing.
- A persistent kindness feed with For You and Following modes, story creation,
  optional photo and geotag attachments, categories, thanks, replies, sharing,
  author profile navigation, and deletion of your own stories.
- Discover search, suggested people, follow/unfollow, public profile pages, and
  persisted activity with unread badges.
- Per-account thanks, follows, and activity over a shared on-device feed, with
  migration from the original v1 state and atomic protected-file persistence.
- Bounded photo processing, explicit storage and permission failures, a complete
  App Store icon, and an Apple privacy manifest declaring no tracking or data
  collection.

The app is fully usable on one device and supports multiple locally created
accounts. Credentials are stored in the iOS Keychain; profiles, stories,
attached photos, replies, thanks, activity, and follow relationships persist
across launches. A public multi-device social launch still requires connecting
`AuthStore` and `KindnessStore` to a hosted authentication/database service so
accounts and feeds sync between devices.

## Run

Open `ThankYou.xcodeproj` in Xcode, select an iPhone simulator, and press Run.

- iOS 17+
- SwiftUI
- No third-party dependencies

## Verification

Run a strict Swift compile check without a simulator:

```bash
sdk_path=$(xcrun --sdk iphoneos --show-sdk-path)
mkdir -p /tmp/thankyou-module-cache
xcrun --sdk iphoneos swiftc -typecheck -warnings-as-errors \
  -target arm64-apple-ios17.0 -sdk "$sdk_path" \
  -module-cache-path /tmp/thankyou-module-cache \
  -strict-concurrency=complete \
  -module-name ThankYou ThankYou/*.swift
```

Run the dependency-free validation checks:

```bash
xcrun swiftc ThankYou/Validation.swift Tests/AccountValidationTests.swift \
  -o /tmp/thankyou-validation-tests
/tmp/thankyou-validation-tests
```

For App Store archiving, select a development team in Signing & Capabilities.
The app contains the required privacy manifest and a 1024×1024 opaque icon.

The project targets iOS 17, marketing version 1.2, build 3.
