/// In-app legal documents (shown even without internet hosting).
/// Keep in sync with legal-site/*.html.
library;

import 'constants.dart';

class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

class LegalDoc {
  const LegalDoc({
    required this.title,
    required this.updated,
    required this.url,
    required this.sections,
  });
  final String title;

  /// Same document on the public website (GitHub Pages).
  final String url;
  final String updated;
  final List<LegalSection> sections;
}

class LegalContent {
  LegalContent._();

  static const String contact =
      '8SpeedyService, Durgapur, West Bengal, India\n'
      'WhatsApp / Phone: +91 96352 97320';

  static const LegalDoc privacy = LegalDoc(
    title: 'Privacy Policy',
    updated: 'Last updated: 21 November 2026',
    url: PartnerConstants.privacyPolicyUrl,
    sections: <LegalSection>[
      LegalSection(
        'Who we are',
        '8SpeedyService ("we", "us") runs the 8SpeedyService customer app and the 8Speedy Partner mechanic app in Durgapur, India. We follow the Information Technology Act, 2000 and the Digital Personal Data Protection Act, 2023.',
      ),
      LegalSection(
        'Data we collect',
        '• Mobile number — to log you in with an SMS OTP and to connect you with your mechanic.\n'
            '• Name (optional) — shown to your mechanic during a job.\n'
            '• Precise location — your pickup point, only when you book or tap "Locate me".\n'
            '• Vehicle details — type, brand, model, and optional number plate and fuel. The number plate is shown to the mechanic only after they accept.\n'
            '• Booking details — issue, address, status, rating and review.\n'
            '• Voice note (optional) — a short recording describing the problem, only if the customer taps the microphone. Only partners who can see the request, and the one who accepts it, can play it.\n'
            '• Payment status — Razorpay order and payment IDs. Card, UPI and bank details are handled by Razorpay; we never see or store them.\n'
            '• AI features (optional) — the problem description, issue chips and vehicle model are processed by our AI provider Anthropic to create a diagnosis or repair checklist (never phone numbers or exact locations). Any AI answer can be rated or reported in the app; our team reviews reports.\n'
            '• Chat between the customer and the assigned partner — visible only to the two of them; links and payment IDs are blocked.\n'
            '• Repair bill — the amount and note the partner enters at the end of a job (customer\'s bill, partner\'s earnings).\n'
            'Partners: name, phone, shop details, vehicle types repaired, and live location while Online or on a job (also in the background, with a visible notification).',
      ),
      LegalSection(
        'How we share data',
        '• With your assigned mechanic during an active job: name, phone, pickup address and vehicle. You see the mechanic\'s first name, phone and live location.\n'
            '• With service providers: Supabase (database and login, servers in Mumbai), the SMS provider for OTPs, Razorpay (payments and refunds), Anthropic (AI answers, only when AI features are used), and OpenStreetMap (map images).\n'
            '• When required by Indian law.\n'
            'We do not sell your data and we do not show ads.',
      ),
      LegalSection(
        'How long we keep data',
        'Account data is kept while your account is active. Voice notes are deleted 30 days after the booking ends; chats, AI questions and security logs are deleted after 180 days. When you delete your account, your name, phone number, saved vehicles, saved places, voice notes, chats, AI questions, partner profile and exact locations are deleted or anonymised immediately. Booking and payment records are kept without your identity for up to 8 years for tax and accounting.',
      ),
      LegalSection(
        'Your rights',
        'You can edit your name in the app and delete your account at any time from Menu → Account & Privacy → Delete my account. You can also contact us to access, correct or erase your data, or to withdraw consent.',
      ),
      LegalSection(
        'Security',
        'All data is encrypted in transit (HTTPS). Database rules let each user see only their own data, payments are verified only on our servers, and the start OTP is never shown to mechanics.',
      ),
      LegalSection(
        'Children',
        'The apps are meant for people aged 18 and above.',
      ),
      LegalSection(
        'Contact & grievance officer',
        'Grievance Officer: 8SpeedyService Support Team\n$contact\nWe reply within 7 days and resolve complaints within 30 days.',
      ),
    ],
  );

  static const LegalDoc partnerTerms = LegalDoc(
    title: 'Partner Terms',
    updated: 'Last updated: 18 November 2026',
    url: PartnerConstants.partnerTermsUrl,
    sections: <LegalSection>[
      LegalSection(
        'Relationship',
        'You are an independent service provider, not an employee of 8SpeedyService. You decide when to go Online. We do not guarantee any number of jobs.',
      ),
      LegalSection(
        'Verification',
        'You must give true identity and shop details. We may verify documents (for example Aadhaar and a shop photo) by call or in person before activating your account, and may suspend accounts that give false details.',
      ),
      LegalSection(
        'Doing jobs',
        '• Accept only jobs you can reach and repair. Release a job immediately if you cannot go.\n'
            '• Never start work without the customer\'s Start OTP.\n'
            '• Charge fair prices and agree on the price before starting. Charge the minimum visit charge only after you reach the customer.\n'
            '• Be respectful. Harassment, fraud, overcharging or repeatedly releasing jobs can lead to suspension.',
      ),
      LegalSection(
        'Location',
        'While you are Online or on a job, the app shares your live location — also in the background, with a visible notification — so you receive nearby requests and the customer can track you. Go Offline to stop sharing.',
      ),
      LegalSection(
        'Payments',
        'Customers pay repair charges directly to you. Any platform commission will be announced in the app in advance.',
      ),
      LegalSection(
        'Deleting your account',
        'Menu → Account & Privacy → Delete my account.',
      ),
      LegalSection(
        'Governing law',
        'These terms are governed by the laws of India. Courts at Durgapur, West Bengal have jurisdiction.',
      ),
      LegalSection('Contact', contact),
    ],
  );
}
