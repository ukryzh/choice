import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const routeName = 'faq';
  static const routePath = '/faq';

  @override
  Widget build(BuildContext context) {
    final faqs = <(String, Widget)>[
      (
        'What is this app?',
        const Text(
          'This app is a menstrual cycle tracking application designed with privacy and data protection as first-class principles.\n\n'
          'It allows users to track cycles, symptoms, and related information without selling or sharing personal data with third parties.',
        ),
      ),
      (
        'Who is this app for?',
        const Text(
          'This app is for users who:\n'
          '- want control over their personal and health data\n'
          '- prefer transparency over convenience\n'
          '- are comfortable with a minimalistic, privacy-first approach',
        ),
      ),
      (
        'Do you sell my data?',
        const Text(
          'No. The app does not sell, rent, or share personal or health-related data with advertisers, data brokers, or third parties.',
        ),
      ),
      (
        'Where is my data stored?',
        const Text(
          'You can choose one of the following options:\n\n'
          'Local-only storage on your device\n'
          'Encrypted cloud backup (optional)\n\n'
          'Your data is never stored in plaintext on servers. It’s always encrypted and no third parties can read it.',
        ),
      ),
      (
        'Can the developer read my data?',
        const Text(
          'No. If cloud backup is enabled, all data is encrypted on your device before transmission. The encryption keys are not accessible to the developer.',
        ),
      ),
      (
        'What happens if I change my phone?',
        const Text(
          'If you use local-only storage, data may be lost when switching devices.\n\n'
          'If you enable encrypted backups, you can restore data on a new device.\n\n'
          'This choice is intentionally left to the user.',
        ),
      ),
      (
        'How does cloud backup work if I don’t manage encryption keys myself?',
        const Text(
          'Cloud backup is enabled only after you sign in with your Google account. Your data is encrypted on your device before being backed up. '
          'The encryption keys are securely linked to your account for recovery, but are not exposed to the developer or stored in plaintext.',
        ),
      ),
      (
        'Does the app use analytics or tracking tools?',
        const Text(
          'No third-party analytics, advertising SDKs, or tracking tools are used.',
        ),
      ),
      (
        'Is the app free?',
        const Text(
          'Yes. The app is free to use. There are no subscriptions, ads, or hidden monetization mechanisms.',
        ),
      ),
      (
        'Is this a medical app?',
        const Text(
          'No. This app is not a medical device and does not provide medical advice, diagnosis, or treatment. Predictions are informational only.',
        ),
      ),
      (
        'Why build an app like this?',
        const Text(
          'This project started as an experiment to explore whether modern AI tools allow individuals to build privacy-respecting software without relying on data monetization.',
        ),
      ),
      (
        'How can I support the project?',
        const Text(
          'At the moment, the best support is feedback. You can submit your feedback via Google Play or by email: choice.period@gmail.com',
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemBuilder: (context, index) {
          final (question, answer) = faqs[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium ??
                    const TextStyle(fontSize: 14),
                child: answer,
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 32),
        itemCount: faqs.length,
      ),
    );
  }
}




