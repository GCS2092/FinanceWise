import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class SmsParserScreen extends StatefulWidget {
  const SmsParserScreen({super.key});

  @override
  State<SmsParserScreen> createState() => _SmsParserScreenState();
}

class _SmsParserScreenState extends State<SmsParserScreen> {
  final ApiService _api = ApiService();
  final _contentCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _provider = 'wave';
  bool _parsing = false;
  String? _result;
  String? _error;

  Future<void> _parseSms() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _parsing = true;
      _error = null;
      _result = null;
    });
    try {
      final response = await _api.post('/sms/parse', {
        'provider': _provider,
        'raw_content': _contentCtrl.text.trim(),
      });
      setState(() {
        _result = response['message'] ?? 'SMS traité';
        _parsing = false;
      });
      
      // Notification de succès
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'SMS Parsé',
        body: _result ?? 'SMS traité avec succès',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_result!)));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _parsing = false;
      });
    }
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text?.isNotEmpty == true) {
      _contentCtrl.text = clipboardData!.text!;
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parser SMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            onPressed: _pasteFromClipboard,
            tooltip: 'Coller depuis presse-papier',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Exemples de SMS', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Wave: "Vous avez reçu 50000 FCFA de ..."', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('Orange Money: "Transfert effectué: 25000 FCFA à ..."', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _provider,
              decoration: const InputDecoration(labelText: 'Fournisseur', prefixIcon: Icon(Icons.phone_android)),
              items: const [
                DropdownMenuItem(value: 'wave', child: Text('Wave')),
                DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
              ],
              onChanged: (v) => setState(() => _provider = v ?? 'wave'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: 'Contenu du SMS',
                prefixIcon: Icon(Icons.sms),
                hintText: 'Collez ou entrez le contenu du SMS ici...',
              ),
              maxLines: 6,
              validator: (v) => v == null || v.trim().isEmpty ? 'Contenu requis' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _parsing ? null : _parseSms,
                icon: _parsing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                label: Text(_parsing ? 'Analyse en cours...' : 'Analyser le SMS'),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_result!, style: const TextStyle(color: Colors.green))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
