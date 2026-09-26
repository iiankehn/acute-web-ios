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

