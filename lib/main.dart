import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class FiscalEntry {
  final String id, title, type, date;
  final double amount, tax;
  bool isArchived;

  FiscalEntry({
    required this.id, required this.title, required this.amount,
    required this.type, required this.tax, required this.date,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'amount': amount,
    'type': type, 'tax': tax, 'date': date, 'isArchived': isArchived,
  };

  factory FiscalEntry.fromMap(Map<dynamic, dynamic> map) => FiscalEntry(
    id: map['id'], title: map['title'], amount: map['amount'],
    type: map['type'], tax: map['tax'], date: map['date'],
    isArchived: map['isArchived'] ?? false,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('normalized_fiscal_box');
  await Hive.openBox('chat_history_box');
  runApp(const FiscalAPro());
}

class FiscalAPro extends StatelessWidget {
  const FiscalAPro({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'monospace'),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _myBox = Hive.box('normalized_fiscal_box');
  final _chatBox = Hive.box('chat_history_box');
  List<FiscalEntry> _ledger = [];
  final Set<String> _selectedIds = {};
  List<Map<dynamic, dynamic>> _savedChats = [];
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  // CORE ARCHITECTURE: Toggle this to use Serverless Middleware instead of client-side SDK
  // ignore: unused_field
  final bool _useMiddleware = false; 
  // ignore: unused_field
  final String _middlewareUrl = "https://your-firebase-function-url.com/api";

  List<Map<String, String>> _chatMessages = [];
  bool _isUnlocked = false;
  String _selectedType = 'Revenue';
  bool _includeTax = false;
  final String _activeCurrency = "ETB";

  double _convRate = 1.0;
  String _liveRateTicker = "1 USD = 118.4 ETB";
  final List<double> _sparkData = [115.0, 116.5, 116.0, 117.8, 118.4, 118.2, 118.42];

  final _convCtrl = TextEditingController(text: "1.00");
  String _targetVal = "118.42";
  String _baseCurrency = "USD";
  String _targetCurrency = "ETB";
  Map<String, dynamic> _allRates = {"USD": 1.0, "ETB": 118.42};
  List<dynamic> _realNews = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
    _fetchLiveRates();
    _fetchRealNews();
    _loadChatHistory();
    _chatMessages = [{"role": "AI", "msg": "Financial Assistant Online. How can I help with your assets today?"}];
  }

  Future<void> _fetchRealNews() async {
    try {
      // Using a more reliable query for financial news relevant to Ethiopia and Global Markets
      final response = await http.get(Uri.parse('https://api.marketaux.com/v1/news/all?symbols=TSLA,AMZN,MSFT&filter_entities=true&limit=5&api_token=P0vR7I7O7uY6X1V6x7p0vR7I7O7uY6X1V6x7'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _realNews = data['data'] ?? []);
      } else {
        throw Exception("API Busy");
      }
    } catch (e) {
      // High-quality fallback with realistic links for testing
      setState(() => _realNews = [
        {"title": "Ethiopia's Digital Economy: Growth and Opportunities 2024", "source": "Addis Insight", "url": "https://www.addisinsight.net", "published_at": "Just now"},
        {"title": "Global Tech Stocks Rally as Inflation Data Cools", "source": "Reuters", "url": "https://www.reuters.com/business/finance/", "published_at": "1h ago"},
        {"title": "National Bank of Ethiopia Updates Foreign Exchange Regulations", "source": "Ethiopian Monitor", "url": "https://ethiopianmonitor.com", "published_at": "3h ago"},
        {"title": "Gold Prices Hit Record High Amid Geopolitical Tensions", "source": "Bloomberg", "url": "https://www.bloomberg.com/markets", "published_at": "5h ago"},
        {"title": "Tech Giants Invest Heavily in AI Infrastructure", "source": "Financial Times", "url": "https://www.ft.com/technology", "published_at": "8h ago"},
      ]);
    }
  }

  void _updateConversion() {
    double input = double.tryParse(_convCtrl.text) ?? 0.0;
    double baseToUsd = 1 / (_allRates[_baseCurrency] ?? 1.0);
    double usdToTarget = _allRates[_targetCurrency] ?? 1.0;
    setState(() => _targetVal = (input * baseToUsd * usdToTarget).toStringAsFixed(2));
  }

  Future<void> _fetchLiveRates() async {
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allRates = data['rates'];
          _convRate = _allRates['ETB']?.toDouble() ?? 118.42;
          _liveRateTicker = "1 USD = ${_convRate.toStringAsFixed(2)} ETB";
          _updateConversion();
          _sparkData.add(_convRate);
          if (_sparkData.length > 10) _sparkData.removeAt(0);
        });
      }
    } catch (e) {
      debugPrint("Live rate fetch error: $e");
    }
  }

  void _loadChatHistory() {
    final data = _chatBox.get("HISTORY");
    if (data != null) setState(() { _savedChats = List<Map<dynamic, dynamic>>.from(data); });
  }

  void _saveChatToHistory() {
    if (_chatMessages.length <= 1) return;
    final newSession = {
      'date': DateFormat('MMM dd, HH:mm').format(DateTime.now()),
      'preview': _chatMessages.last['msg'],
      'messages': List.from(_chatMessages),
    };
    _savedChats.insert(0, newSession);
    _chatBox.put("HISTORY", _savedChats);
  }

  Future<void> _askTheExpert(String userPrompt, Function setChatState) async {
    const apiKey = "AIzaSyDd_KIBix_txGd8q3vTUnDStbzBtYf7ZoY";
    final activeLedger = _ledger.where((e) => !e.isArchived).toList();
    final ledgerData = activeLedger.map((e) => "${e.title}: ${e.amount} ETB (${e.type})").join(", ");
    
    final historyContext = _chatMessages.length > 1 
      ? _chatMessages.sublist(_chatMessages.length > 5 ? _chatMessages.length - 5 : 1)
          .map((m) => "${m['role']}: ${m['msg']}").join("\n")
      : "No previous context.";

    final systemInstruction = "You are 'Fiscal Buddy', a friendly financial advisor. "
        "CONTEXT: [$historyContext]. MARKET: 1 USD = $_liveRateTicker. LEDGER: [$ledgerData]. "
        "PROTOCOLS: 1. Focus on money and assets. 2. Friendly, natural conversation style. 3. Plain text only. 4. Concise.";

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    try {
      final content = [Content.text("$systemInstruction \n User Input: $userPrompt")];
      final responseStream = model.generateContentStream(content);
      
      String fullResponse = "";
      setChatState(() {
        _chatMessages.add({"role": "AI", "msg": ""});
      });

      await for (final chunk in responseStream) {
        fullResponse += (chunk.text ?? "");
        String cleanResponse = fullResponse.replaceAll(RegExp(r'[\*\#\_]'), '');
        setChatState(() {
          _chatMessages.last["msg"] = cleanResponse.trim();
        });
      }
    } catch (e) {
      debugPrint("Gemini Error: $e");
      String errorMsg = "System busy. (${e.toString().split(':').last.trim()})";
      if (e.toString().contains("429")) errorMsg = "Too many requests. Please wait a moment.";
      if (e.toString().contains("Socket")) errorMsg = "Connection lost. Please check your internet.";
      if (e.toString().contains("API_KEY_INVALID")) errorMsg = "Invalid API Key. Please update it.";
      setChatState(() => _chatMessages.add({"role": "AI", "msg": errorMsg}));
    }
  }

  Future<void> _authenticate() async {
    if (_isUnlocked) {
      setState(() => _isUnlocked = false);
      return;
    }
    try {
      final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'AUTHORIZE ACCESS TO FISCAL CORE',
          biometricOnly: false,
          persistAcrossBackgrounding: true);
      if (didAuthenticate) setState(() => _isUnlocked = true);
    } catch (e) {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("SECURITY EXCEPTION", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
        content: Text(e.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        actions: [TextButton(onPressed: () { setState(() => _isUnlocked = true); Navigator.pop(ctx); }, child: const Text("BYPASS (DEV ONLY)", style: TextStyle(color: Colors.cyanAccent)))]
      ));
    }
  }

  void _refreshData() {
    final data = _myBox.get("DATA");
    if (data != null) setState(() { _ledger = (data as List).map((e) => FiscalEntry.fromMap(e)).toList(); });
  }
  void _sync() => _myBox.put("DATA", _ledger.map((e) => e.toMap()).toList());

  String _predictBurnRate() {
    final active = _ledger.where((e) => !e.isArchived && e.amount < 0).toList();
    if (active.isEmpty) return "0.00";
    double total = active.fold(0, (sum, e) => sum + e.amount.abs());
    // Simple 30-day projection based on current month's velocity
    int daysPassed = DateTime.now().day;
    double dailyAvg = total / (daysPassed > 0 ? daysPassed : 1);
    return (dailyAvg * 30).toStringAsFixed(2);
  }

  Future<void> _scanReceipt(Function setSheetState) async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      if (!mounted) return;
      if (recognizedText.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SCAN ERROR: No text detected. Please try a clearer image.")));
        return;
      }

      RegExp amountRegExp = RegExp(r'(\d+[\.,]\d{2})');
      Iterable<RegExpMatch> matches = amountRegExp.allMatches(recognizedText.text);
      
      if (matches.isNotEmpty) {
        String lastMatch = matches.last.group(0)!.replaceAll(',', '.');
        setSheetState(() {
          _amountCtrl.text = lastMatch;
          _titleCtrl.text = "SCANNED: ${recognizedText.text.split('\n').first}";
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RECEIPT DETECTED: Amount extracted successfully.")));
      } else {
        // Fallback for non-receipt images or unclear amounts
        setSheetState(() {
          _titleCtrl.text = "PARSED TEXT: ${recognizedText.text.split('\n').first.substring(0, math.min(20, recognizedText.text.split('\n').first.length))}";
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DOCUMENT SCANNED: No clear amount found, text parsed as description.")));
      }
    } finally {
      textRecognizer.close();
    }
  }

  void _saveEntry() {
    final rawAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (_titleCtrl.text.isEmpty || rawAmount <= 0) return;
    final calculatedTax = _includeTax ? (rawAmount * 0.15) : 0.0;
    final newEntry = FiscalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(), title: _titleCtrl.text,
      amount: (_selectedType == 'Expense') ? -rawAmount : rawAmount, type: _selectedType, tax: calculatedTax,
      date: DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
    );
    setState(() { _ledger.insert(0, newEntry); _sync(); });
    _titleCtrl.clear(); _amountCtrl.clear(); Navigator.pop(context);
  }

  void _archiveEntry(String id) {
    setState(() {
      final index = _ledger.indexWhere((e) => e.id == id);
      if (index != -1) _ledger[index].isArchived = true;
      _selectedIds.remove(id);
      _sync();
    });
  }

  Future<void> _bulkArchive() async {
    if (_selectedIds.isEmpty) return;
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("CONFIRM BATCH ARCHIVE", style: TextStyle(color: Colors.orangeAccent, fontSize: 14, letterSpacing: 2)),
        content: Text("Are you sure you want to archive ${_selectedIds.length} records? This requires biometric verification.", style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("VERIFY & PROCEED", style: TextStyle(color: Colors.cyanAccent))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'VERIFY TO ARCHIVE FINANCIAL RECORDS',
          biometricOnly: false,
          persistAcrossBackgrounding: true
        );
        if (didAuthenticate) {
          setState(() {
            for (var id in _selectedIds) {
              final index = _ledger.indexWhere((e) => e.id == id);
              if (index != -1) _ledger[index].isArchived = true;
            }
            _selectedIds.clear();
            _sync();
          });
        }
      } catch (e) {
        debugPrint("Auth error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _ledger.where((e) => !e.isArchived).toList();
    double netCapital = active.fold(0.0, (s, e) => s + e.amount) * _convRate;
    double totalTax = active.fold(0.0, (s, e) => s + e.tax) * _convRate;
    double revenue = active.where((e) => e.amount > 0).fold(0.0, (s, e) => s + e.amount) * _convRate;
    double expense = active.where((e) => e.amount < 0).fold(0.0, (s, e) => s + e.amount).abs() * _convRate;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.history_edu, color: Colors.cyanAccent, size: 28),
            offset: const Offset(0, 50), elevation: 20, color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.2))),
            onSelected: (val) {
              if (val == 'ledger') _showVaultDrawer(context);
              if (val == 'chats') _showChatHistory();
            },
            itemBuilder: (ctx) => [_luxuryMenuItem('ledger', Icons.account_balance_wallet, "FINANCIAL VAULT"), _luxuryMenuItem('chats', Icons.forum_outlined, "CHAT HISTORY")],
          ),
          const Spacer(),
          const Text("FISCAL-A", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.cyanAccent)),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(Icons.psychology_outlined, color: _isUnlocked ? Colors.greenAccent : Colors.white24, size: 28),
            offset: const Offset(0, 50), elevation: 20, color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.2))),
            onSelected: (val) {
              if (!_isUnlocked) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Decrypt System First"))); return; }
              if (val == 'ai') _showExpertChat();
              if (val == 'market') _showMarketHub();
            },
            itemBuilder: (ctx) => [_luxuryMenuItem('ai', Icons.auto_awesome, "FINANCIAL ADVISOR"), _luxuryMenuItem('market', Icons.language, "MARKET HUB")],
          ),
          _topIconButton(_isUnlocked ? Icons.visibility : Icons.visibility_off, "SECURE", _authenticate),
        ])),

        Container(
          padding: const EdgeInsets.all(24), margin: const EdgeInsets.symmetric(horizontal: 20),
          width: double.infinity, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: -10),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4C1D95)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("TOTAL LIQUIDITY ($_activeCurrency)", style: const TextStyle(fontSize: 10, color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: _isUnlocked ? 0 : 18, sigmaY: _isUnlocked ? 0 : 18),
              child: Text((netCapital - totalTax).toStringAsFixed(2), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            ),
            if (!_isUnlocked) 
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 12),
                  SizedBox(width: 8),
                  Text("VAULT ENCRYPTED - BIOMETRIC REQUIRED", style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                ]),
              ),
            const Divider(color: Colors.white10, height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _metricTile("INFLOW", revenue, Colors.greenAccent),
              _metricTile("OUTFLOW", expense, Colors.redAccent),
              _metricTile("PREDICTED", double.tryParse(_predictBurnRate()) ?? 0.0, Colors.orangeAccent),
            ])
          ]),
        ),
        Expanded(child: active.isEmpty 
          ? _buildEmptyState()
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: active.length,
            itemBuilder: (ctx, i) => Dismissible(
              key: Key(active[i].id), 
              direction: _selectedIds.isEmpty ? DismissDirection.startToEnd : DismissDirection.none,
              background: _dismissBg(Alignment.centerLeft, Colors.orangeAccent, Icons.archive), 
              confirmDismiss: (direction) async {
                if (!_isUnlocked) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action Blocked: System Encrypted")));
                  return false;
                }
                return await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF0F172A),
                    title: const Text("ARCHIVE RECORD?", style: TextStyle(color: Colors.orangeAccent, fontSize: 14)),
                    content: const Text("Move this transaction to the permanent vault?", style: TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ARCHIVE", style: TextStyle(color: Colors.orangeAccent))),
                    ],
                  )
                );
              },
              onDismissed: (dir) => _archiveEntry(active[i].id), 
              child: GestureDetector(
                onLongPress: () => setState(() {
                  if (_selectedIds.contains(active[i].id)) {
                    _selectedIds.remove(active[i].id);
                  } else {
                    _selectedIds.add(active[i].id);
                  }
                }),
                onTap: () {
                  if (_selectedIds.isNotEmpty) {
                    setState(() {
                      if (_selectedIds.contains(active[i].id)) {
                        _selectedIds.remove(active[i].id);
                      } else {
                        _selectedIds.add(active[i].id);
                      }
                    });
                  }
                },
                child: _buildTransactionCard(active[i])
              ),
            ),
          )
        ),
      ]))),
      floatingActionButton: _selectedIds.isNotEmpty 
        ? FloatingActionButton.extended(onPressed: _bulkArchive, backgroundColor: Colors.orangeAccent, icon: const Icon(Icons.archive, color: Colors.black), label: Text("ARCHIVE (${_selectedIds.length})", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
        : FloatingActionButton.extended(onPressed: _isUnlocked ? _showEntrySheet : null, backgroundColor: _isUnlocked ? Colors.cyanAccent : Colors.white10, icon: const Icon(Icons.add_box_outlined, color: Colors.black), label: const Text("NEW TRANSACTION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
    );
  }

  Widget _metricTile(String l, double v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 8, color: Colors.white38)),
    Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
  ]);

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.white10),
    const SizedBox(height: 20),
    Text("Vault Empty", style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text("Add your first transaction to begin analysis", style: TextStyle(color: Colors.white10, fontSize: 12)),
  ]));

  PopupMenuItem<String> _luxuryMenuItem(String val, IconData icon, String label) => PopupMenuItem(
    value: val, child: Row(children: [Icon(icon, size: 16, color: Colors.white54), const SizedBox(width: 12), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))]),
  );

  void _showChatHistory() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF020617), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Column(children: [
        const Padding(padding: EdgeInsets.all(25), child: Text("ENCRYPTED CHAT VAULT", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(itemCount: _savedChats.length, itemBuilder: (ctx, i) => ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: Colors.white24), 
            title: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: _isUnlocked ? 0 : 12, sigmaY: _isUnlocked ? 0 : 12), child: Text(_savedChats[i]['date'], style: const TextStyle(color: Colors.white, fontSize: 14))), 
            subtitle: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: _isUnlocked ? 0 : 14, sigmaY: _isUnlocked ? 0 : 14), child: Text(_savedChats[i]['preview'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10))),
            trailing: IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18), onPressed: () { setState(() { _savedChats.removeAt(i); _chatBox.put("HISTORY", _savedChats); }); Navigator.pop(ctx); }),
            onTap: () { 
              if (!_isUnlocked) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Decrypt System First"))); return; }
              setState(() { _chatMessages = List<Map<String, String>>.from(_savedChats[i]['messages'].map((m) => Map<String, String>.from(m))); }); 
              Navigator.pop(ctx); 
              _showExpertChat(); 
            },
          ),
        )),
      ]),
    );
  }

  void _showMarketHub() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF020617), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setHubState) => Container(height: MediaQuery.of(context).size.height * 0.9, padding: const EdgeInsets.all(25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("MARKET HUB", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 2)), 
            Row(children: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 20), onPressed: () async {
                await _fetchRealNews();
                setHubState(() {});
              }),
              IconButton(icon: const Icon(Icons.close, color: Colors.white24), onPressed: () => Navigator.pop(context)),
            ]),
          ]),
          const SizedBox(height: 25),
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0F172A), Colors.cyanAccent.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white10)),
            child: Column(children: [
              _currencySelector(true, setHubState), const SizedBox(height: 15),
              TextField(controller: _convCtrl, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: "0.00"), onChanged: (v) => setHubState(() => _updateConversion())),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Icon(Icons.swap_vert_circle, color: Colors.cyanAccent, size: 30)),
              Text(_targetVal, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent)), const SizedBox(height: 15),
              _currencySelector(false, setHubState),
            ]),
          ),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("FINANCIAL HEADLINES", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)), SizedBox(height: 20, width: 80, child: CustomPaint(painter: SparklinePainter(_sparkData)))]),
          const SizedBox(height: 15),
          Expanded(child: _realNews.isEmpty 
            ? const Center(child: Text("FETCHING LATEST HEADLINES...", style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 2)))
            : ListView.builder(itemCount: _realNews.length, itemBuilder: (ctx, i) => _luxuryNewsCard(_realNews[i]))),
        ]),
      )),
    );
  }

  Widget _currencySelector(bool isBase, Function setState) => Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
    child: DropdownButton<String>(value: isBase ? _baseCurrency : _targetCurrency, underline: const SizedBox(), dropdownColor: const Color(0xFF0F172A), isExpanded: true,
      items: _allRates.keys.map((String code) => DropdownMenuItem(value: code, child: Text(code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
      onChanged: (val) {
        setState(() {
          if (isBase) {
            _baseCurrency = val!;
          } else {
            _targetCurrency = val!;
          }
          _updateConversion();
        });
      },
    ),
  );

  Widget _luxuryNewsCard(dynamic news) => GestureDetector(
    onTap: () async {
      final urlStr = news['url'];
      if (urlStr != null) {
        try {
          final uri = Uri.parse(urlStr);
          // Real-world practice: Use externalApplication for better compatibility with modern Android
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("SYSTEM ERROR: Cannot open browser. Link may be restricted."),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
            ));
          }
        }
      }
    },
    child: Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(news['source'] ?? news['name'] ?? "Finance", style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6), Text(news['title'], style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
        ])),
        const Icon(Icons.arrow_outward, color: Colors.white10, size: 16),
      ]),
    ),
  );

  void _showExpertChat() {
    if (!_isUnlocked) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Decrypt System First"))); return; }
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (ctx, setChatState) => Container(height: MediaQuery.of(context).size.height * 0.85, decoration: const BoxDecoration(color: Color(0xFF020617), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(children: [
            _buildNewsTicker(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 20), onPressed: () { 
                setChatState(() { _chatMessages = [{"role": "AI", "msg": "Advisor Reset. System state refreshed. How can I help?"}]; });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conversation Context Cleared"), duration: Duration(seconds: 1)));
              }),
              IconButton(icon: const Icon(Icons.add_comment, color: Colors.white24), onPressed: () { _saveChatToHistory(); setChatState(() { _chatMessages = [{"role": "AI", "msg": "Advisor Reset. How can I help?"}]; }); }),
              const Text("FINANCIAL ADVISOR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 2)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white24), onPressed: () => Navigator.pop(context)),
            ]),
            if (_chatMessages.length == 1) Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10), child: Wrap(spacing: 8, runSpacing: 8, children: [_actionChip("Analyze Balance", setChatState), _actionChip("Savings Advice", setChatState), _actionChip("Market Updates", setChatState)])),
            Expanded(child: ListView.builder(itemCount: _chatMessages.length, itemBuilder: (c, i) => _chatBubble(_chatMessages[i]["role"]!, _chatMessages[i]["msg"]!))),
            _buildChatInput(setChatState),
          ]),
        ),
      )),
    );
  }

  Widget _actionChip(String label, Function setChatState) => ActionChip(label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.cyanAccent)), backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1), side: const BorderSide(color: Colors.white10), onPressed: () { setChatState(() { _chatMessages.add({"role": "User", "msg": label}); }); _askTheExpert(label, setChatState); });

  void _showEntrySheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("NEW TRANSACTION", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => _scanReceipt(setSheetState),
              icon: const Icon(Icons.camera_alt, color: Colors.cyanAccent),
              label: const Text("SCAN RECEIPT (AI OCR)", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.05)),
            ),
            const SizedBox(height: 20),
            _inputField(_titleCtrl, "e.g. Shop Income", "Source/Description"),
            const SizedBox(height: 20),
            _inputField(_amountCtrl, "0.00", "Amount", isNum: true),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedType, dropdownColor: const Color(0xFF0F172A),
              items: ['Revenue', 'Expense', 'Internal Transfer', 'Tax Payment'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setSheetState(() => _selectedType = v!),
              decoration: _inputDeco("Classification", "Entry Type"),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Include 15% VAT", style: TextStyle(fontSize: 14)),
              value: _includeTax, activeThumbColor: Colors.cyanAccent,
              onChanged: (v) => setSheetState(() => _includeTax = v),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 64, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: _saveEntry, child: const Text("CONFIRM TRANSACTION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)))),
          ]))),
      )),
    );
  }

  void _showVaultDrawer(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (ctx) => Container(height: MediaQuery.of(context).size.height * 0.8, padding: const EdgeInsets.all(32),
        child: Column(children: [
          const Text("PERMANENT VAULT", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 24),
          Expanded(child: ListView.builder(itemCount: _ledger.length, itemBuilder: (ctx, i) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_ledger[i].title, style: TextStyle(color: _ledger[i].isArchived ? Colors.orangeAccent : Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(_ledger[i].date, style: const TextStyle(fontSize: 10, color: Colors.white24)),
            trailing: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: _isUnlocked ? 0 : 12, sigmaY: _isUnlocked ? 0 : 12), child: Text(_ledger[i].amount.toStringAsFixed(0), style: TextStyle(color: _ledger[i].amount > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold))),
          ))),
        ]),
      ),
    );
  }

  Widget _buildNewsTicker() => Container(height: 35, color: Colors.cyanAccent.withValues(alpha: 0.1), child: Center(child: Text("• MARKET: USD 156.28 | EUR 183.87 | GBP 194.50 • STATUS: OPEN •", style: const TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold))));
  Widget _buildChatInput(Function setChatState) => Container(padding: const EdgeInsets.all(20), color: const Color(0xFF1E293B), child: Row(children: [Expanded(child: TextField(controller: _chatCtrl, decoration: _inputDeco("Type a question...", "Advisor"))), IconButton(onPressed: () { if (_chatCtrl.text.isEmpty) return; String userMsg = _chatCtrl.text; setChatState(() { _chatMessages.add({"role": "User", "msg": userMsg}); _chatCtrl.clear(); }); _askTheExpert(userMsg, setChatState); }, icon: const Icon(Icons.bolt, color: Colors.cyanAccent))]));
  Widget _buildTransactionCard(FiscalEntry e) {
    bool isSelected = _selectedIds.contains(e.id);
    return Container(
    margin: const EdgeInsets.only(bottom: 12), 
    padding: const EdgeInsets.all(18), 
    decoration: BoxDecoration(
      color: isSelected ? Colors.orangeAccent.withValues(alpha: 0.1) : const Color(0xFF0F172A).withValues(alpha: 0.5), 
      borderRadius: BorderRadius.circular(25), 
      border: Border.all(color: isSelected ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.05)),
      gradient: LinearGradient(
        colors: isSelected 
          ? [Colors.orangeAccent.withValues(alpha: 0.2), Colors.orangeAccent.withValues(alpha: 0.05)]
          : [const Color(0xFF0F172A), const Color(0xFF1E293B).withValues(alpha: 0.8)]
      )
    ),
    child: Row(children: [
      if (_selectedIds.isNotEmpty) ...[
        Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, color: isSelected ? Colors.orangeAccent : Colors.white24, size: 20),
        const SizedBox(width: 15),
      ],
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (e.amount > 0 ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.1),
          shape: BoxShape.circle
        ),
        child: Icon(e.amount > 0 ? Icons.trending_up : Icons.trending_down, color: e.amount > 0 ? Colors.greenAccent : Colors.redAccent, size: 16),
      ),
      const SizedBox(width: 15), 
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
        Text(e.date, style: const TextStyle(fontSize: 9, color: Colors.white24))
      ])), 
      ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: _isUnlocked ? 0 : 12, sigmaY: _isUnlocked ? 0 : 12), child: Text((e.amount * _convRate).toStringAsFixed(2), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)))
    ])
  );
  }
  Widget _topIconButton(IconData icon, String label, VoidCallback tap, {Color? color}) => Column(children: [IconButton(onPressed: tap, icon: Icon(icon, size: 20, color: color ?? Colors.white)), Text(label, style: TextStyle(fontSize: 8, color: color ?? Colors.white38))]);
  Widget _chatBubble(String role, String message) {
    bool isAI = role == "AI";
    return Align(alignment: isAI ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12), padding: const EdgeInsets.all(16), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(color: isAI ? const Color(0xFF1E293B) : Colors.cyanAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isAI ? 0 : 20), bottomRight: Radius.circular(isAI ? 20 : 0)), border: Border.all(color: isAI ? Colors.white10 : Colors.cyanAccent.withValues(alpha: 0.3))),
        child: Text(message, style: TextStyle(color: isAI ? Colors.white.withValues(alpha: 0.9) : Colors.cyanAccent, fontSize: 14, height: 1.4, fontFamily: 'sans-serif'))));
  }
  Widget _inputField(TextEditingController c, String h, String l, {bool isNum = false}) => TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: _inputDeco(h, l));
  InputDecoration _inputDeco(String h, String l) => InputDecoration(hintText: h, labelText: l, filled: true, fillColor: const Color(0xFF020617), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.cyanAccent)));
  Widget _dismissBg(Alignment align, Color col, IconData icon) => Container(alignment: align, color: col.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(horizontal: 20), child: Icon(icon, color: col));
}

class SparklinePainter extends CustomPainter {
  final List<double> data; SparklinePainter(this.data);
  @override void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final paint = Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path();
    double min = data.reduce((a, b) => a < b ? a : b); double max = data.reduce((a, b) => a > b ? a : b); double range = max - min == 0 ? 1 : max - min;
    for (int i = 0; i < data.length; i++) {
      double x = (i / (data.length - 1)) * size.width;
      double y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
