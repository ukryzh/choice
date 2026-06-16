import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const routeName = 'privacy_policy';
  static const routePath = '/privacy-policy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: const PrivacyPolicyContent(),
    );
  }
}

class PrivacyPolicyContent extends StatelessWidget {
  const PrivacyPolicyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Last updated: 21/01/2026'),
            SizedBox(height: 24),

            Text(
              '1. Introduction',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This Privacy Policy explains how your data is handled when you use the application (the “App”). '
              'The App is designed with a privacy-first architecture, minimizing data collection and eliminating '
              'third-party data sharing.',
            ),
            SizedBox(height: 16),

            Text(
              '2. Data We Collect',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Personal and Health Data\n\n'
              'The App may store the following data only if you choose to enter it:\n'
              '- menstrual cycle dates\n'
              '- symptoms\n\n'
              'This data is stored either:\n'
              '- locally on your device, or\n'
              '- encrypted and backed up to the cloud (optional)',
            ),
            SizedBox(height: 16),

            Text(
              '3. Data We Do NOT Collect',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We do not collect:\n'
              '- advertising identifiers\n'
              '- location data\n'
              '- contact lists\n'
              '- browsing behavior\n'
              '- data for profiling or marketing purposes',
            ),
            SizedBox(height: 16),

            Text(
              '4. Data Storage and Security',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Local Storage\n'
              'By default, data is stored locally on your device.\n\n'
              'Cloud Backup (Optional)\n'
              'If enabled:\n'
              '- data is encrypted on your device\n'
              '- encrypted data is transmitted to the server\n'
              '- servers store only encrypted data\n'
              '- encryption keys are not stored on the server\n\n'
              'Even in case of a server breach, stored data cannot be decrypted.',
            ),
            SizedBox(height: 16),

            Text(
              '5. Third-Party Services',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'The App may rely on infrastructure providers (e.g. cloud hosting) solely for technical operation.\n\n'
              'These providers:\n'
              '- do not receive access to decrypted data\n'
              '- do not use data for their own purposes\n\n'
              'No advertising, analytics, or tracking SDKs are used.',
            ),
            SizedBox(height: 16),

            Text(
              '6. Cloud Backup and Authentication',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Cloud backup is available only after user authentication via a Google account. Authentication is used '
              'solely to associate encrypted backup data with the user account and enable data recovery across devices.\n\n'
              'Encryption keys are generated and handled on the user’s device and are not stored or accessible in plaintext '
              'by the developer. Google authentication does not provide Google or the developer access to decrypted user data.',
            ),
            SizedBox(height: 16),

            Text(
              '7. Data Sharing',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your data is never shared, sold, or transferred to:\n'
              '- advertisers\n'
              '- data brokers\n'
              '- analytics companies\n'
              '- social media platforms',
            ),
            SizedBox(height: 16),

            Text(
              '8. User Control',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You can:\n'
              '- delete your data at any time\n'
              '- disable cloud backups\n'
              '- remove the App and all local data\n'
              '- save and download your data\n\n'
              'There are no penalties or feature restrictions for choosing maximum privacy.',
            ),
            SizedBox(height: 16),

            Text(
              '9. Legal Basis (GDPR)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Where applicable, data processing is based on:\n'
              '- explicit user consent\n'
              '- legitimate interest limited strictly to app functionality\n\n'
              'Sensitive health data is processed only with user action and intent.',
            ),
            SizedBox(height: 16),

            Text(
              '10. Changes to This Policy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This Privacy Policy will not be changed retroactively to allow data sharing. Any future changes will be '
              'published clearly and transparently.',
            ),
            SizedBox(height: 16),

            Text(
              '11. Contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'If you have questions about privacy or data handling, you can contact the developer via email: '
              'choice.period@gmail.com',
            ),
          ],
        ),
      ),
    );
  }
}


