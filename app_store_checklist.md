use this checklist to review my Flutter iOS app before App Store submission. For each item, mark PASS, WARN, or FAIL and add short notes and file references.

**Overall instructions for Codex**

1. Work through every section of this checklist.
2. For each item
   a. Say PASS if it is clearly satisfied
   b. Say WARN if it looks ok but needs human confirmation
   c. Say FAIL if it is missing or non compliant
3. Wherever possible, point to the exact file and line range, or Xcode setting, so it is easy to fix.

---

**1. Project setup and build configuration**

1. Confirm the iOS target is at least the minimum Apple currently requires for App Store submission.
2. Confirm the app builds in Release mode with no errors and no asserts, using both
   a. `flutter build ipa`
   b. An Xcode archive build for release.
3. Check that the app is not using any debug or development flags in release, for example
   a. No `debugShowCheckedModeBanner` set to true
   b. No dev menus or hidden gesture triggers that expose debug tools
   c. No test keys or sandbox endpoints hard coded.
4. Verify bundle identifier and provisioning
   a. `CFBundleIdentifier` matches the identifier configured in App Store Connect
   b. Release build uses the correct distribution signing settings and provisioning profiles.
5. Check versioning
   a. `CFBundleShortVersionString` is a human readable version such as 1.0.3
   b. `CFBundleVersion` is an incrementing build number
   c. These match what is planned for App Store Connect.

---

**2. Stability and performance**

1. Run automated tests or at least `flutter test` and report failures.
2. Build and run the release build on
   a. At least one recent iPhone device
   b. At least one iPad simulator or device if supported.
3. Confirm
   a. No crashes or fatal errors during normal usage
   b. No obvious memory leaks, for example it does not become noticeably slower or unresponsive during simple navigation
   c. No long blank screens or frozen states during startup.
4. Check launch time
   a. App launches to first useful screen within a reasonable time, ideally a few seconds on a real device.
5. Confirm that the app behaves sensibly offline if it claims offline capability, or fails gracefully with clear messages if network is required.

---

**3. User experience and content**

1. Verify the main flow works from first launch
   a. Onboarding
   b. Login or guest mode if present
   c. Core user journey through the main features
   d. Logout or exit flow.
2. Confirm the app content matches its name, icon and description, so nothing feels misleading.
3. Check there are no obvious placeholder elements
   a. “Lorem ipsum” text
   b. Placeholder images
   c. Test or sample data labeled as such.
4. Confirm navigation is clear and not confusing
   a. No dead ends
   b. Back navigation always returns to an expected screen
   c. No buttons with no response.
5. Check all links and buttons work, including
   a. Settings entries
   b. Help or support links
   c. External website links, which should open in an appropriate way.

---

**4. Permissions, privacy and data collection**

1. Inspect Info.plist and Dart code for all platform permissions used
   a. Camera
   b. Photos or media library
   c. Microphone
   d. Location
   e. Contacts
   f. Push notifications
   g. Bluetooth
   h. Calendars or reminders
   i. Tracking or advertising identifiers.
2. Confirm that
   a. Every permission used has a clear, human readable reason string in Info.plist
   b. The actual code paths only request permission when needed
   c. The text matches real usage.
3. Privacy manifest
   a. Check that `PrivacyInfo.xcprivacy` exists in the iOS project and is included in the app target
   b. Confirm it declares any required reason APIs and data types, consistent with the app behaviour and third party SDKs
   c. If there are third party iOS SDKs, verify that they include their own privacy manifest, or that their data use is declared in the app manifest. ([Apple Developer][1])
4. App privacy information
   a. From code inspection, list all categories of user data collected, stored, or transmitted off device
   b. Mark how each category is used, for example analytics, personalisation, advertising, account management
   c. This list should be suitable to copy into the App Store privacy questionnaire and must not contradict the app privacy labels. ([arXiv][2])
5. Tracking and IDFA
   a. Detect whether any code or SDK uses the advertising identifier or cross app tracking
   b. If yes, confirm the project includes the AppTrackingTransparency flow and only accesses IDFA after user consent
   c. If no, confirm there is no unused tracking or ad SDK bringing in tracking code.

---

**5. Accounts, authentication and user rights**

1. Check whether the app supports account creation or login. If yes
   a. Confirm there is a clear way to view and change profile information
   b. Confirm users can log out.
2. Account deletion requirement
   a. If the app supports account creation, confirm there is a clear and working flow that lets users initiate deletion of their account from inside the app, typically in account settings
   b. Confirm the flow either completes deletion in app, or clearly leads to a deletion endpoint that actually works
   c. Deletion must remove the account and associated personal data except what is legally required to keep. ([Apple Developer][3])
3. Social and third party logins
   a. List any social or third party login providers in use
   b. If such logins exist, confirm support for Sign in with Apple, or an equivalent privacy focused login that meets Apple rules
   c. Confirm that tokens and sessions are handled securely and revoked on account deletion. ([9to5Mac][4])

---

**6. Payments, subscriptions and monetisation**

1. Detect any purchase flows in the app
   a. One time purchases for digital content or features
   b. Subscriptions
   c. Credits, coins, or internal currency
   d. External purchase links.
2. Confirm that any purchase of digital content or features that the user accesses in the app uses Apple in app purchase, not external payment systems, except where clearly allowed by Apple rules.
3. Verify that price texts and benefit descriptions are honest and match the actual behaviour.
4. For subscriptions
   a. Check there is a clear description of the subscription, price, and renewal period
   b. Confirm there is an obvious link or instructions for managing and cancelling subscriptions via the system subscription management.
5. Confirm that the app does not attempt to encourage users to bypass Apple in app purchase in ways that conflict with App Store guidelines.

---

**7. Content, safety and legal**

1. Check all content for
   a. Hate speech, harassment, or discrimination
   b. Excessive violence or explicit content
   c. Illegal content or promotion of illegal activity.
2. If the app contains user generated content, confirm there is
   a. A way to report abusive or inappropriate content
   b. A way to block or report abusive users
   c. A moderation approach, even if manual, described in the code comments or documentation.
3. Confirm there are no obvious violations of copyright or trademark
   a. App name and icon are not confusingly similar to well known brands
   b. No unlicensed images, logos, or content where ownership is unclear.
4. Age rating
   a. Based on the content and features, suggest an age rating that matches Apple age rating categories
   b. Check for any content that would raise the rating, for example unrestricted web access, gambling like features or contests. ([Apple Developer][5])

---

**8. App Store assets and metadata support**

Codex cannot see App Store Connect, but it can prepare what is needed.

1. Confirm there is a concise summary description of the app, either in a README or a separate metadata file, that
   a. Explains the main value of the app in simple terms
   b. Matches the actual behaviour.
2. Suggest a list of up to three key marketing points as bullet points for the App Store description.
3. From the app code, propose
   a. A list of relevant keywords
   b. A list of supported languages
   c. Any required disclaimers, for example medical or financial.
4. Check that the app has obvious screens suitable for App Store screenshots in portrait and landscape if needed, and list which screens to capture.

---

**9. Flutter and platform specific checks**

1. Confirm the Flutter version and iOS platform are up to date enough to avoid App Store rejection for obsolete SDK usage.
2. Verify there are no platform views or plugins that rely on private iOS APIs.
3. Inspect iOS specific code in `ios/Runner`
   a. App delegate or scene delegate integration with Flutter is standard
   b. No private URL schemes or hidden behaviours that would conflict with App Store rules.
4. Confirm that any third party Flutter plugins used in the pubspec are still maintained or at least compatible with current iOS requirements, especially around privacy manifests and tracking. ([capgo.app][6])

---

**10. Final review readiness**

1. Prepare a test account for Apple review if the app requires login, with credentials and any special instructions in a separate reviewer notes file.
2. List any feature flags, environment switches or configuration values that must be set for the review build, and confirm they are correctly set for production.
3. Confirm there are no references in the UI to beta status, test servers, or internal development tools.
4. Summarise all WARN or FAIL items with recommended fixes in priority order, so they can be addressed before submission.

If you like, I can next help you turn this into a Codex preset prompt for Cursor, for example a reusable “App Store pre flight check” command that you can run on any Flutter repo.

[1]: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk?utm_source=chatgpt.com "Adding a privacy manifest to your app or third-party SDK"
[2]: https://arxiv.org/abs/2206.02658?utm_source=chatgpt.com "Longitudinal Analysis of Privacy Labels in the Apple App Store"
[3]: https://developer.apple.com/support/offering-account-deletion-in-your-app/?utm_source=chatgpt.com "Offering account deletion in your app - Support"
[4]: https://9to5mac.com/2024/01/27/sign-in-with-apple-rules-app-store/?utm_source=chatgpt.com "Apple (sort of) removes its requirement that apps offer 'Sign ..."
[5]: https://developer.apple.com/news/?utm_source=chatgpt.com "Latest News"
[6]: https://capgo.app/blog/privacy-manifest-for-ios-apps/?utm_source=chatgpt.com "Privacy Manifest for iOS Apps"
