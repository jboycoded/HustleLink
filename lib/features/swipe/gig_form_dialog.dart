import 'package:flutter/material.dart';

import '../../data/models/gig.dart';
import '../../core/constants/hustlelink_categories.dart';

class GigFormData {
  const GigFormData({
    required this.title,
    required this.description,
    required this.category,
    required this.pay,
    required this.location,
    required this.when,
    required this.proofVideoRequired,
  });

  final String title;
  final String description;
  final String category;
  final int pay;
  final String location;
  final String when;
  final bool proofVideoRequired;
}

class GigFormDialog extends StatefulWidget {
  const GigFormDialog({super.key, this.gig});

  final Gig? gig;

  @override
  State<GigFormDialog> createState() => _GigFormDialogState();
}

class _GigFormDialogState extends State<GigFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  String? _selectedCategory;
  late final TextEditingController _pay;
  late final TextEditingController _location;
  late final TextEditingController _when;

  late bool _proofVideoRequired;

  @override
  void initState() {
    super.initState();
    final gig = widget.gig;

    _title = TextEditingController(text: gig?.title ?? '');
    _description = TextEditingController(text: gig?.description ?? '');
    final savedCategory = gig?.category;
    _selectedCategory = savedCategory == null || savedCategory.trim().isEmpty
        ? null
        : HustleLinkCategories.canonicalize(savedCategory);
    _pay = TextEditingController(
      text: gig == null ? '' : gig.pay.toString(),
    );
    _location = TextEditingController(text: gig?.location ?? '');
    _when = TextEditingController(text: gig?.when ?? '');
    _proofVideoRequired = gig?.proofVideoRequired ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _pay.dispose();
    _location.dispose();
    _when.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      GigFormData(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _selectedCategory!,
        pay: int.parse(_pay.text.replaceAll(',', '').trim()),
        location: _location.text.trim(),
        when: _when.text.trim(),
        proofVideoRequired: _proofVideoRequired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //final theme = Theme.of(context);
    //final scheme = theme.colorScheme;

    return AlertDialog(
      title: Text(widget.gig == null ? 'Post a gig' : 'Edit gig'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Gig title',
                    hintText: 'e.g. Design a birthday flyer',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the work and expectations',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: HustleLinkCategories.all.contains(_selectedCategory)
                      ? _selectedCategory
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'Select the type of work',
                  ),
                  items: HustleLinkCategories.all
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                  validator: (value) =>
                      value == null ? 'Please select a category.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pay,
                  decoration: const InputDecoration(
                    labelText: 'Payment (₦)',
                    hintText: 'e.g. 8000',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final amount = int.tryParse(
                      (value ?? '').replaceAll(',', '').trim(),
                    );
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount above zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g. Yaba, Lagos',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _when,
                  decoration: const InputDecoration(
                    labelText: 'When is the gig needed?',
                    hintText: 'e.g. Today 2pm, Urgent',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require 30-second proof video'),
                  value: _proofVideoRequired,
                  onChanged: (value) {
                    setState(() => _proofVideoRequired = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.gig == null ? 'Post gig' : 'Save changes'),
        ),
      ],
    );
  }
}
