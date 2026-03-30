# Privacy Policy for FairShare

**Last updated:** March 30, 2026

FairShare ("the App") is a bill-splitting application developed by Malek Almousle ("we", "us", "our"). This privacy policy explains how we collect, use, and protect your information.

## Information We Collect

### Account Information
- **Email address** — used for authentication and account recovery
- **Display name** — shown to other household members
- **Phone number** (optional) — used for phone-based authentication only

### Financial Data
- **Bill amounts, categories, and dates** — entered by you for expense tracking
- **Settlement records** — payments between household members
- **Recurring bill details** — amounts, frequencies, and due dates

This data is stored to provide the core bill-splitting functionality. We do not sell, share, or use your financial data for advertising.

### Receipt Photos
- **Receipt images** (optional) — captured or uploaded by you for bill entry
- Photos are stored in your household's private cloud storage and are only accessible to household members.

### Device Information
- **Device token** — used to deliver push notifications
- **Device identifier** — used to coordinate data sync across your devices

### Third-Party Authentication
If you sign in with Google or Apple, we receive only your name and email from those providers. We do not access your contacts, calendar, or other account data.

## How We Use Your Information

- **Provide the service** — store and sync your bills, settlements, and household data
- **Authentication** — verify your identity when you sign in
- **Notifications** — send push notifications for settlement requests and household activity
- **Receipt scanning** — process receipt photos to extract bill items (on-device or via your own API key)

## Third-Party Services

The App uses the following third-party services:

| Service | Purpose | Data shared |
|---------|---------|-------------|
| **Supabase** | Cloud database, authentication, file storage | Account info, bills, receipts |
| **Firebase (Google)** | Push notifications, crash reporting | Device token, crash logs |
| **Google Sign-In** | Optional social login | Email, name (from Google) |
| **Apple Sign-In** | Optional social login | Email, name (from Apple) |
| **Groq API** (optional, BYOK) | AI-powered receipt scanning | Receipt photo (only if you provide your own API key) |

Each service has its own privacy policy. We recommend reviewing them.

## Data Storage and Security

- Your data is stored on Supabase servers (cloud-hosted PostgreSQL) with row-level security policies ensuring only household members can access household data.
- Local data is stored on your device in an encrypted SQLite database.
- Authentication tokens are managed by Supabase Auth with industry-standard security.
- API keys you provide (e.g., Groq) are stored in your device's secure storage (Android Keystore) and are never transmitted to our servers.

## Data Retention

- Your data is retained as long as your account is active.
- You can delete your account and all associated data by contacting us.
- Household data is retained until the household admin deletes it.

## Your Rights

You have the right to:
- **Access** your data through the App at any time
- **Export** your bill data as CSV from the Insights screen
- **Delete** your account and associated data by contacting us
- **Withdraw consent** by uninstalling the App and requesting account deletion

## Children's Privacy

The App is not intended for children under 13. We do not knowingly collect information from children under 13.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted within the App or on our website. Continued use of the App after changes constitutes acceptance.

## Contact Us

If you have questions about this privacy policy or want to request data deletion:

- **Email:** malek23almously@gmail.com

---

*This privacy policy applies to the FairShare Android application.*
