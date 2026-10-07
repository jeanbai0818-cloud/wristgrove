# Privacy policy

**Status: development draft, last updated 2026-10-06.** This policy describes the current product design; verify it against each shipped build before distribution.

WristGrove reads requested Apple Health values—heart-rate variability (SDNN), heart rate, resting heart rate, step count and sleep analysis—only to show the user's own readings and trends. Reading access is optional. The app does not write to Health, diagnose illness, measure psychological stress or give medical advice.

Raw health samples stay in Apple Health on the user's devices. WristGrove computes a small snapshot and personal HRV distribution on-device, and sends that summary between the user's paired phone and Watch through Apple's WatchConnectivity service. Local snapshots are stored on each device in its protected application storage. Demo data uses a separate snapshot. No data goes to a WristGrove server: the app has no account, backend, advertising, analytics SDK or cloud-health upload.

The application does not have an account to delete. Users can stop Health access in iOS Settings > Privacy & Security > Health > WristGrove. The app's Settings screen can delete its local summaries; this does not delete Apple Health's original samples. A future App Store release must host this policy at an accessible public URL and have its privacy labels match the submitted build.

The included Apple privacy manifest declares the app-group UserDefaults use for mode/settings sharing and app-private fallback preferences. It declares no tracking domains and no collected data.

Contact: open a privacy issue at https://github.com/jeanbai0818-cloud/wristgrove/issues.
