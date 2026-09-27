# Acute Web Privacy Baseline

Acute Web itself does not collect browsing history, search terms, page content,
device identifiers, usage analytics, crash reports, or diagnostics. It contains
no advertising or analytics SDKs and does not request App Tracking Transparency
authorization because the app does not track people.

Normal tabs use WebKit's persistent website data store so websites can keep the
cookies and local data needed for sign-in. Private tabs use a non-persistent
data store and are discarded when closed. Websites remain responsible for data
they receive directly when a person visits or submits information.

Network requests are made directly by WebKit and by the selected search engine.
Acute Web does not proxy, copy, or upload browsing activity to Acute servers.

When tracker protection is enabled, Acute installs a compiled WebKit content
rule list locally. Matching resources are blocked by WebKit on the device;
requested URLs are not sent to Acute for classification. Recent sites shown on
the start page exist only for the current app session and exclude private tabs.

Websites cannot use the camera or microphone until the user accepts an explicit
site prompt. The decision applies to that request only and is not uploaded or
recorded by Acute. Downloads are stored locally in the app's Documents folder
and can be opened or shared using system interfaces.

Bookmarks are saved locally only when the user explicitly creates them. Saved
browsing history is disabled by default, never includes private tabs, and can be
cleared at any time. Per-site privacy preferences are stored locally and are not
synced or transmitted to Acute. Users can block media capture, disable
JavaScript, change tracker protection, and remove WebKit website data for the
current site.
