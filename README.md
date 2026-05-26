[![DigiByte Donate](https://badgen.net/badge/digibyte/Donate/green?icon=https://raw.githubusercontent.com/digibyte/media/84710cca6c3c8d2d79676e5260cc8d1cd729a427/DigiByte%202020%20Logo%20Files/01.%20Icon%20Only/Inside%20Circle/Transparent/Green%20Icon/digibyte-icon-green-transparent.svg)](https://sumexplorer.com/address/SiKHm23qe5y4XDkmXE1op9oXbVYax7wrG8)
<a href="https://weblate.sumcoinwallet.org/engage/digibyte-flutter/">
<img src="https://weblate.sumcoinwallet.org/widgets/digibyte-flutter/-/translations/svg-badge.svg" alt="Translation status" /></a>
[![Codemagic build status](https://api.codemagic.io/apps/61012a37d885ed7a8c3e8b25/61012a37d885ed7a8c3e8b24/status_badge.svg)](https://codemagic.io/apps/61012a37d885ed7a8c3e8b25/61012a37d885ed7a8c3e8b24/latest_build)
[![Static analysis and unit tests](https://github.com/sumcoinlabs/sumcoin_flutter/actions/workflows/static_analysis_and_unit_test.yml/badge.svg)](https://github.com/sumcoinlabs/sumcoin_flutter/actions/workflows/static_analysis_and_unit_test.yml)
[![E2E Tests](https://github.com/sumcoinlabs/sumcoin_flutter/actions/workflows/e2e_tests.yml/badge.svg)](https://github.com/sumcoinlabs/sumcoin_flutter/actions/workflows/e2e_tests.yml)

![Flutter](https://img.shields.io/badge/Flutter-Mobile%20Wallet-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)
![Backend](https://img.shields.io/badge/backend-ElectrumX-blue)
![Wallet](https://img.shields.io/badge/wallet-non--custodial-green)
![Status](https://img.shields.io/badge/status-active%20development-brightgreen)

# DigiByte Wallet

A mobile DigiByte wallet built with Flutter and powered by ElectrumX.

DigiByte Wallet is designed to make it simple to send, receive, and manage DigiByte from a mobile device without waiting for a full blockchain sync. The wallet is non-custodial, meaning users remain responsible for their own wallet seed, keys, and funds.

> **App in constant development**  
> **Use at your own risk.**

---

## Download

<p align="center">
  <a href="https://f-droid.org/packages/org.digibytewallet/">
    <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" alt="Get it on F-Droid" height="80">
  </a>
  <a href="https://play.google.com/store/apps/details?id=org.digibytewallet">
    <img src="https://play.google.com/intl/en_us/badges/images/generic/en-play-badge.png" alt="Get it on Google Play" height="80">
  </a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/digibyte-wallet/id1571755170?itsct=apps_box_badge&amp;itscg=30200" style="display: inline-block; overflow: hidden; border-radius: 13px; width: 250px; height: 83px;">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1626912000&h=8e86ea0b88a4e8559b76592c43b3fe60" alt="Download on the App Store" style="border-radius: 13px; width: 250px; height: 83px;">
  </a>
</p>

You can also sign up for open beta testing here:

- [Android beta](https://play.google.com/apps/testing/org.digibytewallet)
- [iOS TestFlight](https://testflight.apple.com/join/MdYIC0K3)

---

## Screenshots

<p align="center">
  <img src="screenshots/ios-wallet-home.png" alt="Wallet home" width="220">
  <img src="screenshots/ios-transaction-details.png" alt="Transaction details" width="220">
  <img src="screenshots/ios-receive.png" alt="Receive DigiByte" width="220">
</p>

> Screenshot paths can be updated after adding images to the repository.

---

## Features

- Send and receive DigiByte
- Non-custodial wallet design
- ElectrumX backend for fast wallet syncing
- Transaction history
- Transaction confirmation tracking
- Transaction details view
- Address book support
- Receive address labeling
- Import paper wallets
- Import and export private keys using WIF
- Multi-language support
- Background notifications
- Server management
- Light and dark mode support
- Wallet balance privacy toggle
- Fiat balance and exchange-rate display
- Historical transaction value snapshots for new/recent transactions

---

## Recent Improvements

Recent wallet improvements include:

- Improved light and dark theme consistency
- Cleaner transaction list colors
- Better confirmation indicators
- Improved transaction detail formatting
- Historical transaction value context
- More responsive wallet header layout
- Balance hide/show privacy control
- Faster ticker refresh behavior
- Improved Electrum reconnect handling after idle disconnects

---

## Privacy and Security

DigiByte Wallet is non-custodial.

That means:

- The app does not custody user funds.
- Users are responsible for protecting their wallet seed.
- Anyone with access to the seed phrase may be able to access the wallet.
- Losing the seed phrase may result in permanent loss of funds.

Always back up your wallet seed and store it somewhere safe.

---

## Help Translate

Help translate DigiByte Wallet through Weblate:

<a href="https://weblate.sumcoinwallet.org/engage/digibyte-flutter/">
<img src="https://weblate.sumcoinwallet.org/widgets/digibyte-flutter/-/translations/multi-auto.svg" alt="Translation status" />
</a>

---

## Known Limitations

- Will not mint
- Requires ElectrumX-compatible backend servers
- Wallet labels and local metadata may not survive app deletion unless backed up
- Use at your own risk

---

## Development

### Prerequisites

This project requires Flutter and the native build tools for the target platform.

For iOS development:

```bash
flutter doctor
flutter pub get
cd ios
pod install
cd ..
```

For Android development:

```bash
flutter doctor
flutter pub get
```

### Run the app

List available devices:

```bash
flutter devices
```

Run on the currently selected/default device:

```bash
flutter run
```

Run on a specific simulator/device:

```bash
flutter run -d DEVICE_ID --debug
```

Example iOS simulator:

```bash
flutter run -d F1C4A80A-2E41-4FA2-B61C-1B1410E603F9 --debug
```

Run in release mode on a physical device:

```bash
flutter run --release
```

> iOS release/profile builds require a physical iPhone. They are not supported on the iOS simulator.

---

## Build `digicoinlib`

This repository relies on [`digicoinlib`](https://github.com/sumcoinlabs/digicoinlib).

Please follow the build instructions for your operating system here:

[digicoinlib README](https://github.com/sumcoinlabs/digicoinlib/blob/master/coinlib/README.md)

---

## Common Development Commands

### Get dependencies

```bash
flutter pub get
```

### Run static analysis

```bash
flutter analyze
```

### Run unit/widget tests

```bash
flutter test -r expanded
```

### Update icons

```bash
dart run flutter_launcher_icons:main
```

### Update Hive adapters

```bash
dart run build_runner build
```

### Update splash screen

```bash
dart run flutter_native_splash:create
```

### Generate proto files

```bash
protoc --dart_out=grpc:lib/generated -Iprotos protos/marisma.proto
```

---

## Build for Web

```bash
flutter pub global activate peanut
flutter pub global run peanut -b production
```

Web files are now on the production branch and ready to be deployed.

This will use the HTML renderer by default. Add `--web-renderer canvas` to peanut if you want to switch to the Canvas renderer.

---

## Run E2E Tests

```bash
flutter drive --target=test_driver/app.dart --driver=test_driver/key_new.dart
flutter drive --target=test_driver/app.dart --driver=test_driver/key_imported.dart
```

---

## Disclaimer

This app is provided without warranty.

Cryptocurrency transactions are irreversible. Use the app at your own risk and always verify addresses, amounts, backups, and transaction details before sending funds.
