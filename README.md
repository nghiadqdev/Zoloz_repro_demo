# zoloz_repro_demo

Minimal Flutter repro project for ZOLOZ iOS scan issue investigation.

## Environment

- Flutter: stable
- Dart: compatible with Flutter stable
- iOS: 15+
- ZOLOZ Flutter SDK: 1.2.6

## Project Setup

1. Open this folder in terminal.
2. Run `flutter pub get`.
3. Run `cd ios && pod install && cd ..`.
4. Run on real iPhone: `flutter run`.

## Configure API Constants

Before running, edit constants in [lib/main.dart](lib/main.dart):

1. `kZolozApiBaseUrl`
2. `kZolozInitPath`
3. `kZolozBearerToken`
4. `kZolozHeaders`
5. `kZolozUserAddress`
6. `kZolozDocType`
7. `kZolozCountryCode`

## How to Reproduce

1. Tap `Load MetaInfo` and verify SDK returns a non-empty string.
2. Tap `Start ZOLOZ` to call init API (`/zoloz/zoloz/idrecognition/initialize`) and fetch `clientCfg` + `transactionId`.
3. (Optional) Fill transaction override if you want to force another transactionId.
4. Tap `Start ZOLOZ`.
5. Follow on-screen scan flow until issue occurs.

## What This Demo Logs

- `metaInfo` fetch result
- init API status code and parsed payload summary
- `start` bizCfg keys sent to SDK
- `onInterrupted` retCode + extInfo
- `onCompleted` retCode + extInfo

## Notes For ZOLOZ Team

- iOS Podfile includes private source:
	- `https://github.com/zoloz-pte-ltd/zoloz-demo-ios`
- No custom native crash guard/swizzling is included in this demo.
- This project intentionally keeps integration minimal to isolate SDK behavior.
