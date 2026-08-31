// Zen prefs that survive a reinstall. Linked into the active profile by
// ./bootstrap, which resolves the profile directory from profiles.ini since
// its name is randomized per install.
//
// Nothing here is sensitive. Cookie/permission exceptions are not prefs and
// live in the profile's permissions.sqlite instead.

// --- Microsoft / Stanford SSO ------------------------------------------------
// These only widen the margins around Outlook's auth flow. None of them fixes
// the "You're signed out of your account" loop, whose cause is unconfirmed; see
// `bin/zen-sso-fix` for what is actually known and how to recover.
//
// Storage-access grants are what let Outlook's login.microsoftonline.com iframe
// reach its unpartitioned cookies under Total Cookie Protection. At the default
// expiry they lapse while a mail tab sits open for a workday, so widen them to
// 90 days. Seconds.
user_pref("privacy.restrict3rdpartystorage.expiration", 7776000);
user_pref("privacy.restrict3rdpartystorage.expiration_visited", 7776000);
user_pref("privacy.restrict3rdpartystorage.expiration_redirect", 7776000);

// Bounce Tracking Protection can purge session cookies for domains it decides
// are bounce trackers, which a working SSO redirector looks exactly like.
// It is already inert here (microsoftonline.com is recorded as user-activated),
// but pin it off so a Zen default change cannot reintroduce the failure.
// 0 = disabled, 1 = enabled, 2 = dry-run (logs only, purges nothing).
user_pref("privacy.bounceTrackingProtection.mode", 0);
