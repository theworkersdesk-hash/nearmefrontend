import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/event_provider.dart';
import '../../services/maps_service.dart';
import '../../utils/validators.dart';
import '../../widgets/common/hloppl_button.dart';
import '../../widgets/common/hloppl_text_field.dart';
import '../../widgets/maps/location_picker.dart';

/// Create-event form. Offline events require location + address; online
/// events require a meeting link — mirrors the backend validation.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  final _link = TextEditingController();
  final _maxParticipants = TextEditingController();

  // Coordinates for offline events, set via the Google Maps location picker.
  double? _lat;
  double? _lng;

  bool _online = false;
  String _category = _offlineCategories.first;
  DateTime? _eventDate;

  static const _offlineCategories = [
    'marathon',
    'yoga',
    'kirtan',
    'meetup',
    'workshop',
    'sports',
    'hiking',
    'volunteering',
    'food_fest',
    'art',
  ];
  static const _onlineCategories = [
    'gaming',
    'music_jam',
    'movie_watch',
    'quiz',
    'book_club',
    'coding',
    'meditation',
    'language_exchange',
    'debate',
    'webinar',
  ];

  List<String> get _categories =>
      _online ? _onlineCategories : _offlineCategories;

  @override
  void dispose() {
    for (final c in [_title, _desc, _address, _link, _maxParticipants]) {
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

    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'mode': _online ? 'online' : 'offline',
      'category': _category,
      'eventDate': _eventDate!.toUtc().toIso8601String(),
      if (_maxParticipants.text.isNotEmpty)
        'maxParticipants': int.parse(_maxParticipants.text),
      if (_online) 'meetingLink': _link.text.trim(),
      if (!_online) ...{
        'latitude': _lat,
        'longitude': _lng,
        'address': _address.text.trim(),
      },
    };

    final ok = await ref.read(eventsProvider.notifier).createEvent(body);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      _snack(ref.read(eventsProvider).error ?? 'Could not create event');
    }
  }

  void _onLocationPicked(GeoPoint p) {
    setState(() {
      _lat = p.lat;
      _lng = p.lng;
      // Prefill the address from the resolved place; the user can still refine.
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
                HlopplTextField(
                  label: 'Title',
                  controller: _title,
                  validator: (v) => Validators.minLength(v, 3, 'Title'),
                ),
                const SizedBox(height: 16),
                HlopplTextField(
                  label: 'Description',
                  controller: _desc,
                  maxLines: 3,
                  validator: (v) => Validators.minLength(v, 10, 'Description'),
                ),
                const SizedBox(height: 16),
                Row(
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
                ),
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
                    decoration: const InputDecoration(labelText: 'Date & Time'),
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
                    label: 'Meeting Link',
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
                ],
                const SizedBox(height: 16),
                HlopplTextField(
                  label: 'Max Participants (optional)',
                  controller: _maxParticipants,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
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
}
