/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

// This file contains branding-specific prefs.

// Number of usages of the web console.
// If this is less than 5, then pasting code into the web console is disabled
pref("devtools.selfxss.count", 5);

// https://firefox.settings.services.mozilla.com/v1
pref("services.settings.server", "data:,#remote-settings-dummy/v1");

// https://developer.mozilla.org/docs/Web/HTTP/Content_negotiation/List_of_default_Accept_values
// > netwerk/protocol/http/nsHttpHandler.cpp
pref("image.http.accept", "image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5");
pref("network.http.accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");

pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
pref("general.config.filename", "snowfox.cfg");
pref("general.config.vendor", "snowfox");
pref("media.cubeb.force_sample_rate", 0);
pref("pdfjs.externalLinkTarget", 2); // 0 NONE 1 SELF 2 BLANK 3 PARENT 4 TOP
pref("privacy.fingerprintingProtection.overrides", "+AllTargets,-CSSPrefersColorScheme");
pref("privacy.resistFingerprinting.letterboxing", false);

pref("browser.preferences.policiesNotice", false);
pref("browser.tabs.hoverPreview.titleLineClamp", 0); // 6
pref("image.avif.force-loop", true);
pref("image.rgbx-mode", 0); // 0 black 1 white
pref("media.eme.showBrowserMessage", true);
pref("snowfox.console.logging_disabled", false);
pref("snowfox.debugger.force_detach", false);
