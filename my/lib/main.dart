import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SmartPCApp());
}

class SmartPCApp extends StatelessWidget {
  const SmartPCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPC Budget Advisor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _purpose = 'gaming';
  bool _loading = false;
  BuildResult? _result;

  // CHANGE THIS to your backend URL that calls GPT/OpenAI and price sources
  final String backendBaseUrl = 'http://192.168.1.1:3000';

  @override
  void dispose() {
    _budgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    final int budget = int.parse(_budgetController.text.trim());
    final String location = _locationController.text.trim();

    try {
      final response = await _callBackendRecommend(budget, 'PHP', location, _purpose);
      setState(() {
        _result = response;
      });
    } catch (e) {
      // For demo, fall back to mock response
      setState(() {
        _result = _mockResponse(budget, location, _purpose);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Using mock response (error: $e)')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<BuildResult> _callBackendRecommend(int budget, String currency, String location, String purpose) async {
    final Uri url = Uri.parse('$backendBaseUrl/api/recommend');
    final Map<String, dynamic> payload = {
      'budget': budget,
      'currency': currency,
      'location': location,
      'purpose': purpose,
    };

    final http.Response resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('Backend returned ${resp.statusCode}: ${resp.body}');
    }

    final Map<String, dynamic> data = jsonDecode(resp.body) as Map<String, dynamic>;
    return BuildResult.fromJson(data);
  }

  BuildResult _mockResponse(int budget, String location, String purpose) {
    final build = [
      Component(component: 'CPU', model: 'Intel Core i5-12400F', price: (budget * 0.22).round()),
      Component(component: 'GPU', model: 'GTX 1660 Super', price: (budget * 0.30).round()),
      Component(component: 'Motherboard', model: 'B660M', price: (budget * 0.10).round()),
      Component(component: 'RAM', model: '16GB DDR4 3200', price: (budget * 0.08).round()),
      Component(component: 'Storage', model: '500GB NVMe SSD', price: (budget * 0.07).round()),
      Component(component: 'PSU', model: '550W 80+ Bronze', price: (budget * 0.06).round()),
      Component(component: 'Case', model: 'MicroATX Case', price: (budget * 0.05).round()),
    ];

    final stores = [
      Store(name: 'PC Express', url: 'https://www.pcexpress.ph', distanceKm: 2.1),
      Store(name: 'DynaQuest', url: 'https://www.dynaquest.ph', distanceKm: 3.8),
    ];

    final int total = build.fold(0, (s, c) => s + c.price);

    return BuildResult(
      build: build,
      stores: stores,
      compatibilityOk: true,
      explanation: 'This mock build prioritizes value within your budget and common compatibility (LGA1700/B660).',
      estimatedTotal: total,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartPC Budget Advisor'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget (PHP)',
                      prefixText: '₱ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a budget';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 5000) return 'Enter a valid budget (>= 5000)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location (City, Country)',
                      hintText: 'e.g., Manila, PH',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your location' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Purpose: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _purpose,
                        items: const [
                          DropdownMenuItem(value: 'gaming', child: Text('Gaming')),
                          DropdownMenuItem(value: 'editing', child: Text('Content Editing')),
                          DropdownMenuItem(value: 'office', child: Text('Office / School')),
                          DropdownMenuItem(value: 'streaming', child: Text('Streaming')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _purpose = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _getRecommendation,
                      icon: const Icon(Icons.search),
                      label: _loading ? const Text('Finding best build...') : const Text('Find Best Build'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _result == null
                      ? const Center(child: Text('No recommendation yet. Enter inputs and press Find.'))
                      : RecommendationView(
                          result: _result!,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecommendationView extends StatelessWidget {
  final BuildResult result;
  const RecommendationView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated total: ₱ ${result.estimatedTotal}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Compatibility: ${result.compatibilityOk ? 'OK' : 'Issues found'}'),
                  const SizedBox(height: 6),
                  Text(result.explanation),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Recommended Parts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.build.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = result.build[index];
              return ListTile(
                leading: CircleAvatar(child: Text(c.component[0])),
                title: Text(c.model),
                subtitle: Text(c.component),
                trailing: Text('₱ ${c.price}'),
              );
            },
          ),
          const SizedBox(height: 12),
          Text('Stores Near You', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.stores.length,
            itemBuilder: (context, index) {
              final s = result.stores[index];
              return ListTile(
                leading: const Icon(Icons.store),
                title: Text(s.name),
                subtitle: Text('${s.distanceKm} km • ${s.url}'),
                onTap: () {
                  // Open external URL - left as exercise. Use url_launcher package.
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open: ${s.url}')));
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: implement export share / PDF generation
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export feature not implemented.')));
                },
                icon: const Icon(Icons.share),
                label: const Text('Export / Share'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Open compatibility details or run auto-fix suggestion
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compatibility details not implemented.')));
                },
                icon: const Icon(Icons.build),
                label: const Text('Compatibility Details'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- Models ---

class BuildResult {
  final List<Component> build;
  final List<Store> stores;
  final bool compatibilityOk;
  final String explanation;
  final int estimatedTotal;

  BuildResult({
    required this.build,
    required this.stores,
    required this.compatibilityOk,
    required this.explanation,
    required this.estimatedTotal,
  });

  factory BuildResult.fromJson(Map<String, dynamic> json) {
    final buildJson = (json['build'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final storesJson = (json['stores'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return BuildResult(
      build: buildJson.map((e) => Component.fromJson(e)).toList(),
      stores: storesJson.map((e) => Store.fromJson(e)).toList(),
      compatibilityOk: json['compatibility_ok'] == true,
      explanation: json['explanation'] ?? '',
      estimatedTotal: json['estimated_total'] ?? 0,
    );
  }
}

class Component {
  final String component;
  final String model;
  final int price;

  Component({required this.component, required this.model, required this.price});

  factory Component.fromJson(Map<String, dynamic> json) => Component(
        component: json['component'] ?? '',
        model: json['model'] ?? '',
        price: (json['price'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'component': component,
        'model': model,
        'price': price,
      };
}

class Store {
  final String name;
  final String url;
  final double distanceKm;

  Store({required this.name, required this.url, required this.distanceKm});

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        name: json['name'] ?? '',
        url: json['url'] ?? '',
        distanceKm: (json['distance_km'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'distance_km': distanceKm,
      };
}

/*
Backend / GPT integration notes (quick):

- Your backend should implement POST /api/recommend.
- Validate input (budget int, location string, purpose string).
- Gather prices from your price sources (Shopee, Lazada, PC Express). Store them in your DB.
- Create a prompt for GPT that includes:
  - The user's budget, purpose, and location
  - A short list of candidate parts with prices
  - Request GPT to return a JSON with build (component, model, price), stores, compatibility_ok, explanation, estimated_total

Example backend prompt (pseudocode):

"User budget: 25000 PHP. Purpose: gaming. Location: Manila, PH.
Candidate parts (with prices): [ {"model": "Ryzen 5 5600", "price": 8500}, ... ]
Please return a JSON object with keys: build (array), stores (array), compatibility_ok (bool), explanation (string), estimated_total (number). Only return JSON."

- The backend then calls OpenAI's Chat API, parses and returns the JSON to this Flutter app.

Security: don't call OpenAI directly from the Flutter app (that would expose your API key). Keep the key on the backend.

Optional next steps I can provide:
- Node.js + Express backend sample (with GPT prompt templates)
- Firestore schema for storing price sources and shops
- A more advanced Flutter UI with inline price editing, charts, and store filtering

*/
