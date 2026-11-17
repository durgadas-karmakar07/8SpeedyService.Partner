import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/vehicle_view.dart';
import '../models/models.dart';
import '../services/partner_service.dart';
import 'login_screen.dart';
import '../widgets/speedy_loader.dart';

/// Stats (today / week / total / rating) and past jobs with customer reviews.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.profile});

  final MechanicProfile profile;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final PartnerService _api = PartnerService();
  PartnerStats? _stats;
  List<JobHistoryItem> _items = const <JobHistoryItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _api.getStats(),
        _api.getHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as PartnerStats;
        _items = results[1] as List<JobHistoryItem>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHelper.friendly(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('My Jobs')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: PartnerConstants.primaryColor,
                  child: Icon(Icons.engineering_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(p.fullName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                        [if (p.shopName != null) p.shopName!, p.phone].join(' • '),
                        style: TextStyle(color: Colors.blueGrey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...<Widget>[
              ErrorBox(message: _error!),
              const SizedBox(height: 12),
            ],
            if (_loading && _stats == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: const Center(child: RoadLoader(messages: <String>['Loading your jobs…'])),
              ),
            if (_stats != null) _statsGrid(_stats!),
            const SizedBox(height: 20),
            const Text('Recent jobs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (!_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No jobs yet. Go online to get your first job!',
                    textAlign: TextAlign.center),
              ),
            ..._items.map(_historyTile),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(PartnerStats s) {
    Widget tile(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            tile('Aaj', '${s.todayCompleted}', Icons.today_rounded, PartnerConstants.primaryColor),
            const SizedBox(width: 10),
            tile('7 din', '${s.weekCompleted}', Icons.date_range_rounded, Colors.indigo),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            tile('Total jobs', '${s.totalCompleted}', Icons.task_alt_rounded,
                PartnerConstants.successColor),
            const SizedBox(width: 10),
            tile('Rating (${s.ratingCount})', s.rating.toStringAsFixed(1), Icons.star_rounded,
                Colors.amber.shade700),
          ],
        ),
      ],
    );
  }

  Widget _historyTile(JobHistoryItem j) {
    final vehicle = PartnerConstants.vehicleFor(j.vehicleType);
    final cancelled = !j.isCompleted;
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: SizedBox(
          width: 56,
          child: VehicleImage(category: j.vehicleType, bodyType: j.vehicleBodyType, height: 34),
        ),
        title: Text(
          j.vehicleLabel != null
              ? vehicleName(j.vehicleLabel, j.vehicleType)
              : (j.issueTags.isEmpty ? vehicle.title : j.issueTags.join(', ')),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(j.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(Fmt.dateTime(j.when), style: const TextStyle(fontSize: 12)),
            if (j.reviewText != null)
              Text('“${j.reviewText}”',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5)),
          ],
        ),
        trailing: cancelled
            ? const Text('Cancelled',
                style: TextStyle(color: PartnerConstants.dangerColor, fontWeight: FontWeight.w700))
            : j.rating != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${j.rating}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 18),
                    ],
                  )
                : const Icon(Icons.check_circle_rounded, color: PartnerConstants.successColor),
      ),
    );
  }
}
