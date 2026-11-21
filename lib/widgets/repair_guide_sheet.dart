import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../models/models.dart';
import '../services/partner_service.dart';
import 'ai_feedback.dart';
import 'speedy_loader.dart';

/// Opens the AI repair guide for the active job: likely causes, a step-by-step
/// checklist, tools/parts to carry and safety notes.
Future<void> showRepairGuide(
  BuildContext context, {
  required PartnerService api,
  required String bookingId,
  required String vehicleName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _RepairGuide(
        api: api,
        bookingId: bookingId,
        vehicleName: vehicleName,
      ),
    ),
  );
}

class _RepairGuide extends StatefulWidget {
  const _RepairGuide({
    required this.api,
    required this.bookingId,
    required this.vehicleName,
  });

  final PartnerService api;
  final String bookingId;
  final String vehicleName;

  @override
  State<_RepairGuide> createState() => _RepairGuideState();
}

class _RepairGuideState extends State<_RepairGuide> {
  RepairGuide? _guide;
  String? _error;
  String _language = 'en';
  final Set<int> _done = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _guide = null;
      _error = null;
      _done.clear();
    });
    try {
      final g = await widget.api.getRepairGuide(
        widget.bookingId,
        language: _language,
      );
      if (mounted) setState(() => _guide = g);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHelper.friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _guide;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                color: PartnerConstants.primaryColor,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI repair guide',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'en', label: Text('EN')),
                  ButtonSegment<String>(value: 'hi', label: Text('हिं')),
                  ButtonSegment<String>(value: 'bn', label: Text('বাং')),
                ],
                selected: <String>{_language},
                onSelectionChanged: (s) {
                  setState(() => _language = s.first);
                  _load();
                },
              ),
            ],
          ),
          Text(
            widget.vehicleName,
            style: TextStyle(color: Colors.blueGrey.shade600),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : g == null
                ? const Center(child: WheelLoader(size: 48))
                : ListView(
                    children: <Widget>[
                      if (g.summary.isNotEmpty)
                        Text(
                          g.summary,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      if (g.causes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        const Text(
                          'Most likely',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        ...g.causes.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: <Widget>[
                                Expanded(child: Text(c.title)),
                                SizedBox(
                                  width: 90,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: c.probability / 100,
                                      minHeight: 8,
                                      color: PartnerConstants.primaryColor,
                                      backgroundColor: PartnerConstants
                                          .primaryColor
                                          .withValues(alpha: 0.12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${c.probability}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (g.steps.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        const Text(
                          'Checklist',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        ...List<Widget>.generate(g.steps.length, (i) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _done.contains(i),
                            title: Text(
                              g.steps[i],
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setState(
                                () =>
                                    v == true ? _done.add(i) : _done.remove(i),
                              );
                            },
                          );
                        }),
                      ],
                      if (g.tools.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        const Text(
                          'Tools & parts',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: g.tools
                              .map(
                                (t) => Chip(
                                  avatar: const Icon(
                                    Icons.handyman_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    t,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (g.costMax > 0) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          'Typical bill in Durgapur: ₹${g.costMin} – ₹${g.costMax}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                      if (g.safety.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        const Text(
                          'Safety',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        ...g.safety.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: PartnerConstants.warningColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(t)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (g.requestId.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        AiFeedbackBar(
                          key: ValueKey<String>(g.requestId),
                          onSubmit: (feedback, note) =>
                              widget.api.sendAiFeedback(
                                g.requestId,
                                feedback,
                                note: note,
                              ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        g.isAi
                            ? 'AI guidance — always confirm with your own inspection.'
                            : 'Expert checklist — always confirm with your own inspection.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
