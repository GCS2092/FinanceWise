import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../services/api_service.dart';
import '../theme.dart';

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

      if (!mounted) return;

      if (response is Map<String, dynamic>) {
        if (response['_rate_limited'] == true) {
          setState(() {
            _error = response['message'];
            _parsing = false;
          });
          return;
        }

        // 202 Accepted → SMS en cours de traitement
        final smsData = response['sms'];
        if (smsData != null) {
          setState(() {
            _result = 'SMS envoyé au serveur (traitement en cours)';
            _parsing = false;
          });

          // Polling pour connaître le statut final
          _pollSmsStatus(smsData['id']);
        } else {
          setState(() {
            _result = response['message'] ?? 'SMS envoyé';
            _parsing = false;
          });
        }
      } else {
        setState(() {
          _error = 'Réponse inattendue du serveur';
          _parsing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion au serveur';
          _parsing = false;
        });
      }
    }
  }

  Future<void> _pollSmsStatus(dynamic smsId) async {
    // Attendre un peu puis vérifier le statut
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      final result = await _api.get('/sms/parse/$smsId');
      if (!mounted) return;

      if (result is Map<String, dynamic>) {
        final status = result['data']?['status'] ?? result['status'];
        if (status == 'processed') {
          setState(() => _result = 'Transaction créée avec succès depuis le SMS');
        } else if (status == 'failed') {
          final errorMsg = result['data']?['error_message'] ?? result['error_message'] ?? '';
          setState(() => _error = 'Échec du traitement : $errorMsg');
          setState(() => _result = null);
        } else if (status == 'pending') {
          setState(() => _result = 'Traitement en cours...');
          // Retry une fois de plus
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) _pollSmsStatus(smsId);
        }
      }
    } catch (_) {
      // Le polling est best-effort, pas critique
    }
  }

  Future<void> _parseBatch() async {
    if (!_formKey.currentState!.validate()) return;

    final lines = _contentCtrl.text.trim().split('\n---\n');
    if (lines.length <= 1) {
      setState(() => _error = 'Séparez les SMS par ---');
      return;
    }

    setState(() {
      _parsing = true;
      _error = null;
      _result = null;
    });

    try {
      final messages = lines
          .where((l) => l.trim().isNotEmpty)
          .map((l) => {'provider': _provider, 'raw_content': l.trim()})
          .toList();

      final response = await _api.post('/sms/batch', {'messages': messages});

      if (!mounted) return;

      if (response is Map<String, dynamic>) {
        setState(() {
          _result = response['message'] ?? '${messages.length} SMS envoyés';
          _parsing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion au serveur';
          _parsing = false;
        });
      }
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const Gap(12),
                      Text('Comment ça marche', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Gap(12),
                  Text(
                    'Collez votre SMS Wave ou Orange Money. Le serveur détectera automatiquement le montant, le type et la catégorie.',
                    style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const Gap(8),
                  Text(
                    'Pour envoyer plusieurs SMS, séparez-les par ---',
                    style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const Gap(16),
            DropdownButtonFormField<String>(
              value: _provider,
              decoration: InputDecoration(
                labelText: 'Fournisseur',
                prefixIcon: const Icon(Icons.phone_android),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'wave', child: Text('Wave')),
                DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
              ],
              onChanged: (v) => setState(() => _provider = v ?? 'wave'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentCtrl,
              decoration: InputDecoration(
                labelText: 'Contenu du SMS',
                prefixIcon: const Icon(Icons.sms),
                hintText: 'Collez ou entrez le contenu du SMS ici...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (v) => v == null || v.trim().isEmpty ? 'Contenu requis' : null,
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _parsing ? null : _parseSms,
                    icon: _parsing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_parsing ? 'Envoi...' : 'Analyser'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _parsing ? null : _parseBatch,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Batch'),
                  ),
                ),
              ],
            ),
            const Gap(24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                    const Gap(8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                  ],
                ),
              ),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.primary),
                    const Gap(8),
                    Expanded(child: Text(_result!, style: const TextStyle(color: AppTheme.primary))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
