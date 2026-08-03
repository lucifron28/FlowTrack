# Offline Password Recovery

FlowTrack supports password recovery without internet access, Supabase, email,
SMS, or an external account.

## Current Status

Implemented in the offline MVP.

- New owner setup requires three recovery questions and answers.
- The login screen has a Forgot password action.
- Recovery verifies all three answers locally.
- A successful recovery replaces the local password and returns to login.
- Five incorrect attempts trigger a 15-minute local lockout.
- Recovery questions can be updated from Settings after entering the current password.
- Existing owners without recovery questions can continue to log in and configure recovery from Settings.
- New owner setup and password reset require passwords of at least eight characters.
- Existing stored passwords remain verifiable for upgrade compatibility, including older shorter passwords.

## Questions

The owner chooses three questions from a short list:

- What nickname does your family call you?
- What was your first pet's name?
- Who was your childhood best friend?
- What was your favorite childhood snack?
- What was your first school called?
- What was the first product you sold?
- What home-cooked food do you remember most?
- What private word is easy for you to remember?

Answers are matched without regard to letter case and with accidental leading,
trailing, or repeated spaces ignored. Punctuation and the actual answer content
are otherwise preserved.

The app rejects the common weak answers `123`, `1234`, `password`, `answer`, and
`none` when recovery questions are created or changed. Owners should choose
answers that are personal and difficult for other people to know. A private
made-up answer is acceptable and can be easier to keep offline than a public
fact.

## Storage and Security

Recovery answers are never stored as plain text. Each answer receives its own
random salt and PBKDF2-HMAC-SHA256 hash. The recovery configuration and
lockout state are stored with `flutter_secure_storage`.

The configuration has an explicit supported version and each answer record
stores its KDF algorithm and iteration count. Verification uses the iteration
count stored with that answer. Unsupported or malformed configuration versions
are treated as unavailable rather than interpreted with current defaults.

Password credentials use a versioned secure-storage bundle. Existing legacy
password records are accepted only to migrate an older installation after a
successful login. New passwords and recovery answers never use raw SHA-256 by
itself. Drift, SQLite, business-data backups, and the local backup JSON payload
never contain passwords or recovery answers.

The recovery flow does not reveal whether an individual answer was correct. It
reports only a generic mismatch and applies the same attempt counter to the
whole recovery attempt.

All three answer hashes are evaluated before a mismatch is returned. This keeps
the result independent of which question was entered incorrectly. A five-attempt
lockout lasts 15 minutes; the lockout clock is local to the device.

During first-run setup, the password bundle is written last as the account
commit marker. A failed final write clears the owner name, recovery records,
password records, and lockout state so a partial account cannot block retry.

## Offline Limits

The device is the recovery boundary. If the app is uninstalled, secure storage
is cleared, or the phone is lost, the questions cannot recover the account.
The local business backup intentionally does not include authentication
secrets, so restoring a backup does not change owner login credentials.

Security questions are convenient but weaker than a high-entropy recovery
code. A future version may add a one-time printable emergency recovery code.
That code must be designed and approved before it is included in backups or
shown outside the device.

## QA Flow

1. Create a fresh owner account and select three personal questions.
2. Log out and verify the normal password still works.
3. Use Forgot password with answers that differ only by case and extra spaces.
4. Verify the old password fails and the new password succeeds.
5. Enter an incorrect answer five times and verify recovery is locked.
6. Log in normally, open Settings > Password recovery, and update the questions.
7. Verify the old questions no longer recover the password.
8. Create a backup and confirm restoring it does not change owner login.
9. Try a seven-character new password and a weak answer such as `1234`; both
   should be rejected before a reset or recovery-question update is saved.
10. On a fresh install, simulate a failed password-storage write and verify the
    setup can be retried without an orphaned owner account.
