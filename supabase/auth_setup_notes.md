# Supabase Auth Setup Notes

These notes are for later setup of Phone, Google, and Apple sign-in.

## Current App Behavior

- Email/password sign-in works through Supabase Auth.
- Phone sign-in uses `signInWithOtp(phone: ...)`.
- Google sign-in uses `OAuthProvider.google`.
- Apple sign-in uses `OAuthProvider.apple`.
- After any successful sign-in, the app creates or updates a separate account row in `user_profiles`.
- Model profiles are separate from account profiles. A user can create multiple model questionnaires manually.

## Phone Sign-In With Twilio

In Supabase:

1. Open `Authentication -> Providers -> Phone`.
2. Enable phone sign-in.
3. Choose/configure Twilio as SMS provider.

Fields:

- `Twilio Account SID`
  - From Twilio Console, `Account Info -> Account SID`.
  - Usually starts with `AC...`.

- `Twilio Auth Token`
  - From Twilio Console, `Account Info -> Auth Token`.
  - Use `Reveal`, then copy the token.

- `Twilio Message Service SID`
  - Twilio Console -> `Messaging -> Services`.
  - Create or open a Messaging Service.
  - Copy the `Messaging Service SID`.
  - Usually starts with `MG...`.

Notes:

- The Messaging Service must have a sender/phone number attached.
- Check that Twilio can send SMS to the target countries and numbers.
- Phone numbers in the app should be entered in international format, for example `+79990000000`.

## Phone Sign-In With SMS Aero

Use this path when the built-in Supabase SMS providers do not deliver to the
target region. Supabase still generates and verifies the OTP. The custom hook
only sends the generated code through SMS Aero.

Function:

- `supabase/functions/send-sms-aero-otp/index.ts`
- JWT verification is disabled for this function in `supabase/config.toml`,
  because Supabase Auth calls it as an HTTP hook.

Secrets:

```text
SMSAERO_EMAIL=...
SMSAERO_API_KEY=...
SMSAERO_SIGN=PK Management
AUTH_HOOK_SECRET=...
```

Optional:

```text
SMSAERO_ENDPOINT=https://gate.smsaero.ru/v2/sms/send
```

Deploy:

```bash
supabase functions deploy send-sms-aero-otp
```

Set secrets:

```bash
supabase secrets set SMSAERO_EMAIL="..."
supabase secrets set SMSAERO_API_KEY="..."
supabase secrets set SMSAERO_SIGN="PK Management"
supabase secrets set AUTH_HOOK_SECRET="..."
```

In Supabase Dashboard:

1. Open `Authentication -> Hooks`.
2. Enable `Send SMS hook`.
3. Choose HTTP hook.
4. Use this endpoint:

```text
https://<project-ref>.supabase.co/functions/v1/send-sms-aero-otp
```

5. Set the same hook secret/header in the dashboard if the UI asks for one.
6. Open `Authentication -> Providers -> Phone` and enable phone sign-in.

Test:

1. Run the app.
2. Open phone sign-in.
3. Enter a phone in international format, for example `+79990000000`.
4. Supabase should call the hook, the hook should call SMS Aero, and the app
   should verify the OTP with `verifyOTP`.

If SMS Aero returns an error, check:

- API key and email are correct.
- Sender signature is approved in SMS Aero.
- Account balance is positive.
- The phone number is normalized without spaces or `+`.

## Google Sign-In

In Google Cloud:

1. Open `APIs & Services -> Credentials`.
2. Create `OAuth client ID`.
3. Use `Web application`.
4. Add this authorized redirect URI:

```text
https://rzlobdrknoajeidbz.supabase.co/auth/v1/callback
```

5. Copy the generated values.

In Supabase `Authentication -> Providers -> Google`:

- `Client IDs`
  - Paste the real Google OAuth Client ID.
  - It looks like:

```text
1234567890-abcxyz.apps.googleusercontent.com
```

- `Client Secret (for OAuth)`
  - Paste the Google OAuth Client Secret.

Do not enter the Google Cloud project name here. Supabase needs the OAuth client ID, not a project title.

## Apple Sign-In

Apple setup is more complex and can be done after Google/Phone.

In Apple Developer you need:

- `Team ID`
- `Key ID`
- `.p8` private key
- `Service ID` or app identifier

In Supabase `Authentication -> Providers -> Apple`:

- `Client IDs`
  - Use an Apple Service ID or App ID.
  - Usually formatted like:

```text
com.yourcompany.modelapp
```

or:

```text
com.yourcompany.modelapp.signin
```

- `Secret Key (for OAuth)`
  - Must be a JWT generated from Apple Developer credentials.
  - Do not paste a normal password or project name.

Recommended order:

1. Configure Google first.
2. Configure Phone after Twilio is ready.
3. Configure Apple last.

## Useful Supabase Docs

- Phone Login: https://supabase.com/docs/guides/auth/phone-login
- Google Login: https://supabase.com/docs/guides/auth/social-login/auth-google
- Apple Login: https://supabase.com/docs/guides/auth/social-login/auth-apple
