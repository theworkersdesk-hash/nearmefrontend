import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/event_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/vibe_button.dart';
import '../../widgets/common/vibe_text_field.dart';

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
  final _lat = TextEditingController();
  final _lng = TextEditingController();

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
    for (final c in [
      _title,
      _desc,
      _address,
      _link,
      _maxParticipants,
      _lat,
      _lng
    ]) {
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
      if (_lat.text.isEmpty ||
          _lng.text.isEmpty ||
          _address.text.trim().isEmpty) {
        return _snack('Offline events need latitude, longitude, and address');
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
        'latitude': double.parse(_lat.text),
        'longitude': double.parse(_lng.text),
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
                VibeTextField(
                  label: 'Title',
                  controller: _title,
                  validator: (v) => Validators.minLength(v, 3, 'Title'),
                ),
                const SizedBox(height: 16),
                VibeTextField(
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
                  VibeTextField(
                    label: 'Meeting Link',
                    controller: _link,
                    hint: 'https://…',
                    keyboardType: TextInputType.url,
                    validator: Validators.url,
                  )
                else ...[
                  VibeTextField(
                    label: 'Address',
                    controller: _address,
                    validator: (v) => Validators.required(v, 'Address'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: VibeTextField(
                          label: 'Latitude',
                          controller: _lat,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: Validators.latitude,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VibeTextField(
                          label: 'Longitude',
                          controller: _lng,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: Validators.longitude,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                VibeTextField(
                  label: 'Max Participants (optional)',
                  controller: _maxParticipants,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                VibeButton(
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
