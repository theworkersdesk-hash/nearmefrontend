import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/common/avatar_uploader.dart';
import '../../widgets/common/hloppl_button.dart';
import '../../widgets/common/hloppl_text_field.dart';

/// Step 3 of 3 — collects name, age, gender, interests (3+), bio.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _bio = TextEditingController();
  String? _gender;
  final Set<String> _interests = {};

  static const _genders = ['male', 'female', 'non-binary', 'prefer_not_to_say'];

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      _snack('Please select your gender');
      return;
    }
    if (_interests.length < AppConstants.minInterests) {
      _snack('Select at least ${AppConstants.minInterests} interests');
      return;
    }

    final ok = await ref.read(authProvider.notifier).completeProfile(
          fullName: _name.text.trim(),
          age: int.parse(_age.text.trim()),
          gender: _gender!,
          interests: _interests.toList(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        );
    if (!mounted) return;
    if (!ok) _snack(ref.read(authProvider).error ?? 'Could not save profile');
    // On success the router redirects to home.
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));

    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about you')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Help the community get to know you.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                const Center(
                  child: Column(
                    children: [
                      AvatarUploader(radius: 44),
                      SizedBox(height: 8),
                      Text('Upload Photo',
                          style: TextStyle(color: AppColors.mutedText)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                HlopplTextField(
                  label: 'Full Name',
                  controller: _name,
                  validator: (v) => Validators.required(v, 'Full name'),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: HlopplTextField(
                        label: 'Age',
                        controller: _age,
                        keyboardType: TextInputType.number,
                        validator: Validators.age,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _genderDropdown(context)),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Interests (select ${AppConstants.minInterests}+)',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      AppConstants.interestTags.map(_interestChip).toList(),
                ),
                const SizedBox(height: 18),
                HlopplTextField(
                  label: 'Bio',
                  hint: 'Tell us about yourself…',
                  controller: _bio,
                  maxLines: 4,
                  maxLength: AppConstants.maxBioLength,
                ),
                const SizedBox(height: 12),
                HlopplButton(
                  label: 'Finish',
                  trailingIcon: Icons.check,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text('Step 3 of 3',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          isExpanded: true, // fill the Expanded slot; prevents label overflow
          hint: const Text('Select'),
          items: _genders
              .map((g) => DropdownMenuItem(value: g, child: Text(_label(g))))
              .toList(),
          selectedItemBuilder: (context) => _genders
              .map((g) => Text(_label(g),
                  maxLines: 1, overflow: TextOverflow.ellipsis))
              .toList(),
          onChanged: (v) => setState(() => _gender = v),
        ),
      ],
    );
  }

  Widget _interestChip(String tag) {
    final selected = _interests.contains(tag);
    return FilterChip(
      label: Text(tag),
      selected: selected,
      onSelected: (v) =>
          setState(() => v ? _interests.add(tag) : _interests.remove(tag)),
      labelStyle: TextStyle(
          color: selected ? AppColors.onPrimary : AppColors.onSurface),
    );
  }

  String _label(String g) => switch (g) {
        'male' => 'Male',
        'female' => 'Female',
        'non-binary' => 'Non-binary',
        _ => 'Prefer not to say',
      };
}
