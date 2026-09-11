// Zen prefs that survive a reinstall. Linked into the active profile by
// ./bootstrap, which resolves the profile directory from profiles.ini since
// its name is randomized per install.
//
// Nothing here is sensitive. Cookie/permission exceptions are not prefs and
// live in the profile's permissions.sqlite instead (applied by bin/zen-sso-fix).
// Dark Reader site exclusions live in storage-sync (applied by bin/zen-sso-harden).

// --- Microsoft / Stanford SSO ------------------------------------------------
// 2026-09-08 experiments: the logout loop is OWA calling AAD logoutRedirect()
// after Duo because MSAL fails to establish tokens on the Outlook origin.
// That failure was tied to extension interference (Dark Reader / uBlock) on
// Firefox's multi-host Microsoft auth path — not "Zen is broken" (clean
// profile and extension-off main profile both work; Brave never failed).
//
// Prefs below only widen margins. Permanent pin: zen-sso-harden (Dark Reader
// disabledFor on SSO hosts) + uBlock exceptions in zen/ublock-outlook-exceptions.txt.
// Emergency recovery: zen-outlook --recover. Details: zen/outlook-sso-findings.txt.
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

// Total Cookie Protection (cookieBehavior=5, ETP Standard) partitions third-party
// cookies and breaks Microsoft's multi-host ESTSAUTH/MSAL chain across
// login.microsoftonline.com ↔ outlook.* ↔ *.cloud.microsoft. Chromium/Brave
// do not partition the same way — that is why Brave never hit the logout loop.
// 0 = accept all cookies (ETP Custom with Cookies unchecked). Community fix for
// the Firefox Outlook "Logging you out" redirect.
//
// category MUST be "custom": with "standard", Firefox re-applies cookieBehavior=5
// after user.js on every startup and the pin below is silently undone.
user_pref("browser.contentblocking.category", "custom");
user_pref("network.cookie.cookieBehavior", 0);
user_pref("network.cookie.cookieBehavior.pbmode", 0);
// Firefox 109+ still partitions localStorage/IndexedDB/BroadcastChannel for
// third parties even after Storage Access — that breaks MSAL iframe/silent
// paths used by Outlook Web. Disable to match Chromium/Brave behavior.
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage", false);
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage.exempt_sessionstorage", true);

// Session restore was replaying tabs with stale OAuth #code= fragments and
// login.microsoftonline.com/.../logout + owa logoff.aspx URLs. Auth codes are
// one-time; restoring them (or a parallel logout tab) makes MSAL fail and
// sets ESTSSSOTILES — private windows work because they have no session
// restore. Prefer homepage on startup; still resume after crashes.
user_pref("browser.startup.page", 1);
user_pref("browser.sessionstore.restore_on_demand", true);
user_pref("browser.sessionstore.max_resumed_crashes", 0);
