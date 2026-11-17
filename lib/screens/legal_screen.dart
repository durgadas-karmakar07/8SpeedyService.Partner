import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/legal_content.dart';

/// Shows a legal document (Privacy Policy / Partner Terms) inside the app.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  Future<void> _openWeb(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(doc.url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open on website',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _openWeb(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            Text(
              doc.updated,
              style: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade500),
            ),
            const SizedBox(height: 8),
            for (final s in doc.sections) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                s.heading,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PartnerConstants.darkColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.body,
                style: TextStyle(fontSize: 14, height: 1.55, color: Colors.blueGrey.shade800),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _openWeb(context),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.public_rounded),
              label: const Text('View on website'),
            ),
            const SizedBox(height: 6),
            SelectableText(
              doc.url,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
