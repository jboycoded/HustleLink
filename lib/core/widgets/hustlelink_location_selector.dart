import 'package:flutter/material.dart';

/// Shared location selector for Worker profiles and gig listings.
///
/// Stored values remain a single readable string so existing gig/application
/// records and notification matching do not need a schema migration.
class HustleLinkLocationSelector extends StatefulWidget {
  const HustleLinkLocationSelector({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<HustleLinkLocationSelector> createState() =>
      _HustleLinkLocationSelectorState();
}

class _HustleLinkLocationSelectorState
    extends State<HustleLinkLocationSelector> {
  static const Map<String, String> _states = {
    'abia': 'Abia State',
    'adamawa': 'Adamawa State',
    'akwa ibom': 'Akwa Ibom State',
    'anambra': 'Anambra State',
    'bauchi': 'Bauchi State',
    'bayelsa': 'Bayelsa State',
    'benue': 'Benue State',
    'borno': 'Borno State',
    'cross river': 'Cross River State',
    'delta': 'Delta State',
    'ebonyi': 'Ebonyi State',
    'edo': 'Edo State',
    'ekiti': 'Ekiti State',
    'enugu': 'Enugu State',
    'gombe': 'Gombe State',
    'imo': 'Imo State',
    'jigawa': 'Jigawa State',
    'kaduna': 'Kaduna State',
    'kano': 'Kano State',
    'katsina': 'Katsina State',
    'kebbi': 'Kebbi State',
    'kogi': 'Kogi State',
    'kwara': 'Kwara State',
    'lagos': 'Lagos State',
    'nasarawa': 'Nasarawa State',
    'niger': 'Niger State',
    'ogun': 'Ogun State',
    'ondo': 'Ondo State',
    'osun': 'Osun State',
    'oyo': 'Oyo State',
    'plateau': 'Plateau State',
    'rivers': 'Rivers State',
    'sokoto': 'Sokoto State',
    'taraba': 'Taraba State',
    'yobe': 'Yobe State',
    'zamfara': 'Zamfara State',
    'fct': 'Federal Capital Territory (Abuja)',
  };

  static const List<String> _countries = [
    'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola',
    'Antigua and Barbuda', 'Argentina', 'Armenia', 'Australia', 'Austria',
    'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus',
    'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina',
    'Botswana', 'Brazil', 'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi',
    'Cabo Verde', 'Cambodia', 'Cameroon', 'Canada', 'Central African Republic',
    'Chad', 'Chile', 'China', 'Colombia', 'Comoros', 'Congo',
    'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czechia',
    'Democratic Republic of the Congo', 'Denmark', 'Djibouti', 'Dominica',
    'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador',
    'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia', 'Fiji',
    'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana',
    'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana',
    'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran',
    'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica', 'Japan', 'Jordan',
    'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan', 'Laos',
    'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein',
    'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives',
    'Mali', 'Malta', 'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico',
    'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Morocco',
    'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal', 'Netherlands',
    'New Zealand', 'Nicaragua', 'Niger', 'North Korea', 'North Macedonia',
    'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine', 'Panama',
    'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Poland',
    'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda', 'Saint Kitts and Nevis',
    'Saint Lucia', 'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
    'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
    'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands',
    'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain',
    'Sri Lanka', 'Sudan', 'Suriname', 'Sweden', 'Switzerland', 'Syria',
    'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand', 'Timor-Leste', 'Togo',
    'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan',
    'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom',
    'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City',
    'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
  ];

  late String _mode;
  late String _scope;
  String? _selectedState;
  String? _selectedCountry;
  String? _legacyLocation;

  @override
  void initState() {
    super.initState();
    _readInitialValue(widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant HustleLinkLocationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _readInitialValue(widget.initialValue);
    }
  }

  void _readInitialValue(String value) {
    final normalized = value.trim().toLowerCase();
    _mode = normalized == 'remote' || normalized.startsWith('remote ')
        ? 'remote'
        : 'physical';
    _scope = 'nigeria';
    _selectedState = null;
    _selectedCountry = null;
    _legacyLocation = null;

    if (_mode == 'remote' || normalized.isEmpty) return;

    if (RegExp(r'\\babuja\\b').hasMatch(normalized)) {
      _selectedState = 'fct';
      return;
    }
    for (final entry in _states.entries) {
      if (RegExp('\\\\b${RegExp.escape(entry.key)}\\\\b').hasMatch(normalized)) {
        _selectedState = entry.key;
        return;
      }
    }

    final countryAliases = <String, String>{
      'uk': 'United Kingdom',
      'u.k.': 'United Kingdom',
      'usa': 'United States',
      'us': 'United States',
      'u.s.': 'United States',
      'uae': 'United Arab Emirates',
    };
    for (final entry in countryAliases.entries) {
      if (normalized.contains(entry.key)) {
        _scope = 'country';
        _selectedCountry = entry.value;
        return;
      }
    }
    for (final country in _countries) {
      if (normalized.contains(country.toLowerCase())) {
        _scope = 'country';
        _selectedCountry = country;
        return;
      }
    }

    // Keep older free-text locations visible and unchanged until the user
    // chooses a new standardized option.
    _legacyLocation = value;
  }

  void _emitLocation() {
    if (_mode == 'remote') {
      widget.onChanged('Remote');
    } else if (_scope == 'nigeria' && _selectedState != null) {
      widget.onChanged('Physical · ${_states[_selectedState]}, Nigeria');
    } else if (_scope == 'country' && _selectedCountry != null) {
      widget.onChanged('Physical · $_selectedCountry');
    } else {
      widget.onChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Work location'),
          items: const [
            DropdownMenuItem(value: 'remote', child: Text('Remote')),
            DropdownMenuItem(value: 'physical', child: Text('Physical')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _mode = value;
              _scope = 'nigeria';
              _selectedState = null;
              _selectedCountry = null;
              _legacyLocation = null;
            });
            _emitLocation();
          },
        ),
        if (_mode == 'physical') ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            decoration: const InputDecoration(labelText: 'Physical location'),
            items: const [
              DropdownMenuItem(value: 'nigeria', child: Text('Nigeria')),
              DropdownMenuItem(
                value: 'country',
                child: Text('Another country'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _scope = value;
                _selectedState = null;
                _selectedCountry = null;
                _legacyLocation = null;
              });
              _emitLocation();
            },
          ),
          const SizedBox(height: 10),
          if (_scope == 'nigeria')
            DropdownButtonFormField<String>(
              initialValue: _selectedState,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'State / FCT'),
              items: _states.entries
                  .where((entry) => entry.key != 'abuja')
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedState = value;
                  _legacyLocation = null;
                });
                _emitLocation();
              },
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedCountry,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Country'),
              items: _countries
                  .where((country) => country != 'Nigeria')
                  .map((country) => DropdownMenuItem(
                        value: country,
                        child: Text(country),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                  _legacyLocation = null;
                });
                _emitLocation();
              },
            ),
          if (_legacyLocation != null) ...[
            const SizedBox(height: 6),
            Text(
              'Saved location: $_legacyLocation. Choose a state or country to standardize it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ],
    );
  }
}
