# CarPlay reference research

Updated 2026-11-01. This note records the real iPad/iPhone CarPlay options we found and the layout choices used by ETS2 CarPlay.

## Similar programs

| Program | What it actually does | Relevance to this project |
| --- | --- | --- |
| [CarCast / iCarCast](https://github.com/rPlayAI/carcast-public) | Receives an iPhone's actual CarPlay session on an iPad, iPhone, Mac, Windows PC, or Android screen. The iPad/iPhone app is currently documented as a public TestFlight beta; the project source is not public. | Best live reference for the genuine Apple CarPlay screen. It receives the iPhone's CarPlay session; it does not add ETS2 telemetry or provide source code to merge into this app. The iOS guide lists iPadOS 15 or later, a Wi-Fi network joined by the iPhone, and a travel router for an in-car setup; it says the iPhone's Personal Hotspot does not work for this connection. Current iPadOS 27 compatibility has not been independently confirmed here. |
| [Showcase](https://aminerostane.com/articles/showcase/) | A real wireless CarPlay receiver for a jailbroken iPad or iPhone. Its author describes a jailbreak-only Sileo/Cydia installation and documents tests on an iPad Air 1 with iOS 12.5.8 and iPhone 7 with iOS 15.8.4. | Useful technical reference, but it is not a normal App Store app and the documented device tests do not establish compatibility with this iPad Air on iPadOS 27. Its CarPlay receiver implementation is separate from our SwiftUI ETS2 app. |
| [Apple CarPlay Simulator](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator) | Apple's Mac development tool for testing CarPlay apps. It simulates a vehicle display and connects to an iPhone; it is part of the Xcode developer tools. | The official reference for checking how real CarPlay renders. It does not turn an iPad into a CarPlay receiver and does not run our iPad-only SwiftUI screen as a CarPlay app. |

## Why this app remains a SwiftUI replica

Apple's current CarPlay guidance says CarPlay apps run from iPhone, use Apple-provided templates, and that CarPlay is not supported on iPadOS. An iPad app cannot register itself as the vehicle display through the public CarPlay framework. This project therefore reproduces the screen as a standalone iPad interface and reads ETS2 data from the Windows bridge; it is not a genuine CarPlay receiver or CarPlay system app.

The closest genuine CarPlay receiver we found is CarCast/iCarCast. Its iPad app receives a CarPlay session sent by a separate iPhone and is not open source, so it cannot be combined with this project's ETS2 screens. Showcase also receives real CarPlay, but requires a jailbroken device. Neither is a drop-in foundation for the requested ETS2 application.

## Screen layout used here

The supplied reference screen measures about 8:3. Apple's CarPlay design guide includes a 1920×720 display (also 8:3), alongside 5:3 and 16:9 display sizes. The app now defaults to full iPad screen in either orientation and offers an optional 8:3 CarPlay-style canvas under **Settings → Display → Screen ratio**. It also supports adjustable in-app dashboard/media split view and iPadOS window resizing.

The launcher follows the reference's main proportions and interaction pattern:

- five app positions across and two rows;
- a narrow left status rail with time, recent apps, and the app-grid button;
- app icon artwork and labels sized against the actual display canvas;
- horizontal page swipes and a small page indicator when there is more than one page;
- short touch and app-switch animations that respect Reduce Motion.

This is a visual reconstruction from the supplied screenshot and public CarPlay guidance. iPadOS cannot render the private, system-managed CarPlay Home screen inside this app, so the SwiftUI recreation should be described as CarPlay-style rather than pixel-identical Apple CarPlay.

## Sources

- [Apple Human Interface Guidelines — CarPlay](https://developer.apple.com/design/human-interface-guidelines/carplay): app templates, supported platforms, and common display sizes.
- [Apple CarPlay developer page](https://developer.apple.com/carplay/): CarPlay framework, templates, and Mac simulator tools.
- [CarCast public project and platform status](https://github.com/rPlayAI/carcast-public).
- [CarCast iOS/iPadOS user guide](https://github.com/rPlayAI/carcast-public/blob/main/docs/ios.md).
- [Showcase technical article](https://aminerostane.com/articles/showcase/).
