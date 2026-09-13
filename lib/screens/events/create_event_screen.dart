import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../providers/event_provider.dart';
import '../../providers/providers.dart';
import '../../services/maps_service.dart';
import '../../utils/validators.dart';
import '../../widgets/common/hloppl_button.dart';
import '../../widgets/common/hloppl_text_field.dart';
import '../../widgets/events/premium_plans_sheet.dart';
import '../../widgets/maps/location_picker.dart';

/// Create-event form implementing the event workflow: name (≤30) + short
/// description (≤150), banner, GPS/typed location, free/paid, optional tickets,
/// and a visibility radius (2/5/10/25 km free · 50 km premium). Free hosts are
/// capped at 50 tickets and 25 km; the 50 km tier opens the premium paywall.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

/// Visibility tiers in metres, with a human label. 50 km is premium-only.
const _visibilityTiers = <({int metres, String label})>[
  (metres: 2000, label: '2 km'),
  (metres: 5000, label: '5 km'),
  (metres: 10000, label: '10 km'),
  (metres: 25000, label: '25 km'),
  (metres: 50000, label: '50 km'),
];
const _freeMaxVisibilityM = 25000;
const _freeTicketCap = 50;

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  final _link = TextEditingController();
  final _tickets = TextEditingController();
  final _price = TextEditingController();

  // Coordinates for offline events, set via the Google Maps location picker.
  double? _lat;
  double? _lng;

  bool _online = false;
  bool _isPaid = false;
  String _category = _offlineCategories.first;
  DateTime? _eventDate;
  int _visibilityM = 5000;

  // Banner state.
  String? _bannerUrl;
  bool _bannerUploading = false;
  final _picker = ImagePicker();

  static const _offlineCategories = [
    'marathon', 'yoga', 'kirtan', 'meetup', 'workshop',
    'sports', 'hiking', 'volunteering', 'food_fest', 'art',
  ];
  static const _onlineCategories = [
    'gaming', 'music_jam', 'movie_watch', 'quiz', 'book_club',
    'coding', 'meditation', 'language_exchange', 'debate', 'webinar',
  ];

  List<String> get _categories =>
      _online ? _onlineCategories : _offlineCategories;

  @override
  void dispose() {
    for (final c in [_title, _desc, _address, _link, _tickets, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _eventDate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickBanner() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _bannerUploading = true);
    try {
      final url = await ref.read(eventServiceProvider).uploadBanner(picked.path);
      if (!mounted) return;
      setState(() {
        _bannerUrl = url;
        _bannerUploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _bannerUploading = false);
      _snack('Could not upload the banner. Try again.');
    }
  }

  bool get _isPremium =>
      ref.read(eventQuotaProvider).asData?.value.isPremium ?? false;

  Future<void> _onVisibilityTap(int metres) async {
    if (metres > _freeMaxVisibilityM && !_isPremium) {
      final upgraded = await showPremiumPlansSheet(context,
          reason: '${metres ~/ 1000} km visibility is a premium feature.');
      if (!upgraded) return; // stay on the previous tier
    }
    setState(() => _visibilityM = metres);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) return _snack('Pick an event date & time');
    if (!_online) {
      if (_lat == null || _lng == null) {
        return _snack('Pick the event location on the map');
      }
      if (_address.text.trim().isEmpty) {
        return _snack('Add an address for the event');
      }
    } else if (_link.text.trim().isEmpty) {
      return _snack('Online events need a meeting link');
    }

    final tickets = _tickets.text.isNotEmpty ? int.tryParse(_tickets.text) : null;
    if (tickets != null && tickets < 1) return _snack('Tickets must be at least 1');
    if (tickets != null && tickets > _freeTicketCap && !_isPremium) {
      final upgraded = await showPremiumPlansSheet(context,
          reason: 'Free hosting is limited to $_freeTicketCap tickets.');
      if (!upgraded || !mounted) return;
    }

    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'mode': _online ? 'online' : 'offline',
      'category': _category,
      'eventDate': _eventDate!.toUtc().toIso8601String(),
      'isPaid': _isPaid,
      if (_isPaid) 'price': int.tryParse(_price.text) ?? 0,
      if (tickets != null) 'maxParticipants': tickets,
      if (_bannerUrl != null) 'coverImageUrl': _bannerUrl,
      if (_online) 'meetingLink': _link.text.trim(),
      if (!_online) ...{
        'latitude': _lat,
        'longitude': _lng,
        'address': _address.text.trim(),
        'visibilityRadiusM': _visibilityM,
      },
    };

    final ok = await ref.read(eventsProvider.notifier).createEvent(body);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(eventQuotaProvider);
      Navigator.of(context).pop(true);
    } else {
      _snack(ref.read(eventsProvider).error ?? 'Could not create event');
    }
  }

  void _onLocationPicked(GeoPoint p) {
    setState(() {
      _lat = p.lat;
      _lng = p.lng;
      if (p.formattedAddress != null && p.formattedAddress!.isNotEmpty) {
        _address.text = p.formattedAddress!;
      }
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(eventsProvider.select((s) => s.isLoading));

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bannerPicker(),
                const SizedBox(height: 20),
                HlopplTextField(
                  label: 'Event name',
                  controller: _title,
                  maxLength: 30,
                  validator: (v) => Validators.minLength(v, 3, 'Event name'),
                ),
                const SizedBox(height: 8),
                HlopplTextField(
                  label: "What's it about?",
                  hint: 'Short description',
                  controller: _desc,
                  maxLines: 3,
                  maxLength: 150,
                  validator: (v) => Validators.minLength(v, 10, 'Description'),
                ),
                const SizedBox(height: 16),
                _modeSelector(),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date & time'),
                    child: Text(
                      _eventDate == null
                          ? 'Select date & time'
                          : _eventDate!.toLocal().toString().substring(0, 16),
                      style: TextStyle(
                          color: _eventDate == null
                              ? AppColors.mutedText
                              : AppColors.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_online)
                  HlopplTextField(
                    label: 'Meeting link',
                    controller: _link,
                    hint: 'https://…',
                    keyboardType: TextInputType.url,
                    validator: Validators.url,
                  )
                else ...[
                  LocationPicker(
                    initial: (_lat != null && _lng != null)
                        ? GeoPoint(lat: _lat!, lng: _lng!)
                        : null,
                    onChanged: _onLocationPicked,
                  ),
                  const SizedBox(height: 16),
                  HlopplTextField(
                    label: 'Address',
                    controller: _address,
                    hint: 'Venue name or address details',
                    validator: (v) => Validators.required(v, 'Address'),
                  ),
                  const SizedBox(height: 20),
                  _visibilitySelector(),
                ],
                const SizedBox(height: 20),
                _priceSelector(),
                const SizedBox(height: 16),
                HlopplTextField(
                  label: 'No. of tickets (optional)',
                  hint: _isPremium ? 'Unlimited on premium' : 'Up to $_freeTicketCap on free',
                  controller: _tickets,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 28),
                HlopplButton(
                    label: 'Create Event',
                    isLoading: loading,
                    onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerPicker() {
    return InkWell(
      onTap: _bannerUploading ? null : _pickBanner,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.tertiary,
          borderRadius: BorderRadius.circular(16),
          image: _bannerUrl != null
              ? DecorationImage(
                  image: NetworkImage(_bannerUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: _bannerUploading
            ? const Center(child: CircularProgressIndicator())
            : _bannerUrl != null
                ? const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Chip(
                        avatar: Icon(Icons.edit, size: 16),
                        label: Text('Change'),
                        backgroundColor: AppColors.surface,
                      ),
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 36, color: AppColors.primaryDark),
                      SizedBox(height: 6),
                      Text('Add a banner',
                          style: TextStyle(color: AppColors.primaryDark)),
                    ],
                  ),
      ),
    );
  }

  Widget _modeSelector() {
    return Row(
      children: [
        const Text('Mode:'),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('Offline'),
          selected: !_online,
          onSelected: (_) => setState(() {
            _online = false;
            _category = _categories.first;
          }),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Online'),
          selected: _online,
          onSelected: (_) => setState(() {
            _online = true;
            _category = _categories.first;
          }),
        ),
      ],
    );
  }

  Widget _priceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<bool>(
          initialValue: _isPaid,
          decoration: const InputDecoration(labelText: 'Entry'),
          items: const [
            DropdownMenuItem(value: false, child: Text('Free event')),
            DropdownMenuItem(value: true, child: Text('Paid event')),
          ],
          onChanged: (v) => setState(() => _isPaid = v ?? false),
        ),
        if (_isPaid) ...[
          const SizedBox(height: 16),
          HlopplTextField(
            label: 'Price (₹)',
            controller: _price,
            keyboardType: TextInputType.number,
            inputPrefixText: '₹ ',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid price';
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _visibilitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Visibility',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('— how far away people can find it',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final tier in _visibilityTiers)
              _visibilityChip(tier.metres, tier.label),
          ],
        ),
      ],
    );
  }

  Widget _visibilityChip(int metres, String label) {
    final premiumOnly = metres > _freeMaxVisibilityM;
    final locked = premiumOnly && !_isPremium;
    return ChoiceChip(
      selected: _visibilityM == metres,
      onSelected: (_) => _onVisibilityTap(metres),
      avatar: locked
          ? const Icon(Icons.lock, size: 14, color: AppColors.primaryDark)
          : null,
      label: Text(label),
    );
  }
}
