// Zen prefs that survive a reinstall. Linked into the active profile by
// ./bootstrap, which resolves the profile directory from profiles.ini since
// its name is randomized per install.
//
// Nothing here is sensitive. Cookie/permission exceptions are not prefs and
// live in the profile's permissions.sqlite instead; `zen-sso-fix` applies them.

// --- Microsoft / Stanford SSO ------------------------------------------------
// Symptom this fixes: outlook.cloud.microsoft loads, its silent token renewal
// in the hidden login.microsoftonline.com iframe fails, and OWA reacts with a
// full logout ("You're signed out of your account. It's a good idea to close
// all browser windows.").
//
// Bounce Tracking Protection classifies login.microsoftonline.com as a bounce
// tracker, because a working SSO redirect passes through it without any user
// interaction, and purges its session cookies (ESTSAUTH, SignInStateCookie) on
// a timer. Persistent cookies like ESTSAUTHPERSISTENT survive, which is why the
// breakage looks intermittent rather than total.
// 0 = disabled, 1 = enabled, 2 = dry-run (logs only, purges nothing).
user_pref("privacy.bounceTrackingProtection.mode", 0);

// Storage-access grants are what let that login iframe reach its unpartitioned
// cookies under Total Cookie Protection. At the default expiry they lapse often
// enough to reintroduce the logout loop, so widen them. Seconds.
user_pref("privacy.restrict3rdpartystorage.expiration", 7776000);
user_pref("privacy.restrict3rdpartystorage.expiration_visited", 7776000);
user_pref("privacy.restrict3rdpartystorage.expiration_redirect", 7776000);
