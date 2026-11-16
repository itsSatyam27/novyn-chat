# Novyn profile QR links

Novyn does not currently have a public profile website or a verified HTTPS
domain. Profile QR codes therefore encode the app-specific URI:

```text
novyn://user/<username>
```

The Android manifest registers the `novyn` scheme with the `user` host.
The Flutter deep-link service validates the username and routes the scanned
profile into the app. The in-app QR scanner uses the same URI format.

For invitations that need to help a new person find or install Novyn, share
the GitHub repository instead:

https://github.com/itsSatyam27/novyn-chat

Do not generate `https://novyn.app` profile links or configure Android HTTPS
App Links until a real public domain is owned, hosted, and configured with
Digital Asset Links for the production signing certificate.
