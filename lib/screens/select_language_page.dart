import 'package:flutter/material.dart';

class SelectLanguagePage extends StatefulWidget {
  const SelectLanguagePage({super.key});

  @override
  State<SelectLanguagePage> createState() => _SelectLanguagePageState();
}

class _SelectLanguagePageState extends State<SelectLanguagePage> {
  static const Color kAccent = Color(0xFFFFAA07);

  // languages: code -> display + asset
  final List<Map<String, String>> _languages = const [
    {'code': 'en', 'label': 'English', 'asset': 'assets/us_flag.png'},
    {'code': 'fr', 'label': 'Français', 'asset': 'assets/france_flag.png'},
    {'code': 'sw', 'label': 'Swahili', 'asset': 'assets/kenya_flag.png'},
  ];

  String? _selectedCode = 'en';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final logo = Image.asset(
      'assets/buja_fasta_logo_title.png',
      height: 72,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Text(
        'Buja Fasta',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: mq.size.height - mq.padding.vertical - kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.center, child: logo),
                  const SizedBox(height: 20),
                  Text(
                    'Choose Your Language',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a language to continue',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Dropdown field container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ), // increased vertical padding for a taller field
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromRGBO(255, 255, 255, 0.02)
                          : const Color.fromRGBO(0, 0, 0, 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.08),
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCode,
                      icon: const Icon(Icons.arrow_drop_down),
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      items: _languages.map((l) {
                        return DropdownMenuItem<String>(
                          value: l['code'],
                          child: Row(
                            children: [
                              Image.asset(
                                l['asset'] ?? '',
                                width: 28,
                                height: 18,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox(width: 28, height: 18),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l['label'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCode = v),
                    ),
                  ),

                  const Spacer(),

                  // Continue button — removed navigation to LoginPage; show a SnackBar instead
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectedCode == null
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Language selected (UI-only)'),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _selectedCode == null ? 0 : 2,
                        shadowColor: Colors.black12,
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          color: _selectedCode == null
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
