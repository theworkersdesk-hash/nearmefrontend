import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/vibe_button.dart';
import '../../widgets/common/vibe_text_field.dart';

/// Pre-filled edit form for the current user's profile.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _bio;
  String? _gender;
  late Set<String> _interests;

  static const _genders = ['male', 'female', 'non-binary', 'prefer_not_to_say'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name = TextEditingController(text: user?.fullName ?? '');
    _age = TextEditingController(text: user?.age?.toString() ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _gender = user?.gender;
    _interests = {...?user?.interests};
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_interests.length < AppConstants.minInterests) {
      _snack('Select at least ${AppConstants.minInterests} interests');
      return;
    }
    final ok = await ref.read(authProvider.notifier).updateProfile(
          fullName: _name.text.trim(),
          age: int.parse(_age.text.trim()),
          gender: _gender,
          interests: _interests.toList(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    } else {
      _snack(ref.read(authProvider).error ?? 'Could not save');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider.select((s) => s.isLoading));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VibeTextField(
                  label: 'Full Name',
                  controller: _name,
                  validator: (v) => Validators.required(v, 'Full name'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: VibeTextField(
                        label: 'Age',
                        controller: _age,
                        keyboardType: TextInputType.number,
                        validator: Validators.age,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gender',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            isExpanded: true, // prevents label overflow
                            items: _genders
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            selectedItemBuilder: (context) => _genders
                                .map((g) => Text(g,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis))
                                .toList(),
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Interests',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.interestTags.map((tag) {
                    final selected = _interests.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (v) => setState(() =>
                          v ? _interests.add(tag) : _interests.remove(tag)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                VibeTextField(
                  label: 'Bio',
                  controller: _bio,
                  maxLines: 4,
                  maxLength: AppConstants.maxBioLength,
                ),
                const SizedBox(height: 24),
                VibeButton(label: 'Save', isLoading: loading, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
