# Novyn profile QR and invite links

## In-app profile QR

Profile QR codes encode the app-specific URI:

```text
novyn://user/<username>
```

The Android manifest registers the `novyn` scheme with the `user` host.
The Flutter deep-link service validates the username and opens the matching
public profile inside Novyn. The Android activity supports both cold starts
and new intents while the app is already running.

## Shareable invite links

Mobile invite actions share the GitHub Pages promotional URL with the inviter's
username in the query string:

```text
https://itssatyam27.github.io/novyn-chat/?invite=<username>
```

On Android, the landing-page script attempts to open an Android `intent://`
link addressed to package `com.example.novyn`. The intent resolves to
`novyn://user/<username>`, which the app routes to the inviter's profile.
When Novyn is not installed, Android Chrome uses the intent's
`browser_fallback_url` to return to the same promotional site with
`appOpen=0`; the page then displays the inviter's handle and an APK download
button without retrying the app launch. A visible **Open Novyn** button is
also provided in case the browser blocks automatic app launching.

## Verification boundary

This is an Android intent-based deep link with a website fallback, **not** a
verified Android App Link. The promotional URL is a GitHub Pages project site
under `/novyn-chat/`; verified App Links would require a Digital Asset Links
file at the domain root (`/.well-known/assetlinks.json`) and the SHA-256
fingerprint of the production APK signing certificate. Do not claim verified
App Links until that root-host file is available and Android reports the
domain as verified.

Test both cases on an Android device:
1. With Novyn installed, open an invite URL and confirm the app opens the
   inviter's profile.
2. Without Novyn installed, open the same URL and confirm the promotional
   website stays open with the inviter handle and ARM64 APK download action.

The promotional website is:
https://itssatyam27.github.io/novyn-chat/
