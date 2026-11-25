# Google Play declarations

What Shiori answers in Play Console > Policy and programs > App content, and in the store
settings. Checked against the code on 2026-11-25; change this file with the app.

## Store settings

| Field | Answer |
|---|---|
| App category | Books & Reference |
| Contact email | thibaut@polyforms.co |
| Website | https://shiori.polyforms.co |
| Privacy policy | https://shiori.polyforms.co/privacy.html |
| Account deletion URL | https://shiori.polyforms.co/delete-account.html |
| Listing text | `infra/play/listings/<locale>/` (fr-FR, en-US) |
| Icon, feature graphic | `infra/play/graphics/` (`swift scripts/play-graphics.swift`) |

## App access

Every feature sits behind sign-in. Instructions for review: "Sign in with any Google account
on the first screen. A new account starts empty: scan a book cover (or tap + to search a title)
to see the library, series and statistics. Premium is not needed to review the app."

## Ads

No ads. The advertising ID is not used: the manifest removes `AD_ID` and the AdServices
permissions that Firebase Analytics would add, and turns off its ad id collection.

## Content rating (IARC questionnaire)

Category "All other app types". No violence, fear, sexual content, gambling, drugs or crude
language in the app's own content. Users interact: yes, only with friends they invite (they see
each other's library; notes stay private). Shares location: no. Digital purchases: yes (Premium).

## Target audience

13 and over (13–15, 16–17, 18+). Not designed for children: choosing under 13 would bring the
Families policy, which the AI scan and the friend sharing are not built for.

## Data safety

Data is encrypted in transit (HTTPS only). Users can ask for deletion (in the app, Settings >
Profile > Delete my account, and the URL above). Nothing is sold, nothing is shared with third
parties: Google (Firebase, Gemini), Sentry and Anthropic act as service providers, which Play does
not count as sharing.

| Data type | Collected | Purpose | Optional |
|---|---|---|---|
| Name, email address | yes | Account management | name optional |
| User IDs (Firebase uid) | yes | Account management, app functionality | no |
| Photos (cover and shelf scans, stored covers, avatar) | yes | App functionality | yes |
| Other user-generated content (books, statuses, ratings, notes, wishlist) | yes | App functionality | yes |
| Purchase history (Premium entitlement) | yes | App functionality | yes |
| App interactions | yes | Analytics | no |
| Crash logs, diagnostics | yes | App functionality (stability) | no |
| Device or other IDs (FCM token, Firebase installation id) | yes | App functionality (alerts), analytics | alerts optional |
| Other info: Kindle and Audible sign-in tokens, encrypted at rest | yes | App functionality | yes |

Not collected: location, the address book (the contact picker only copies the one name the
reader picks into a book's "recommended by", stored as their own content, with no permission), financial or payment info (Google Play
bills), health, messages, audio, files, calendar, web history.
