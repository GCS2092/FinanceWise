import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AuthProvider>().register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.onSurface),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(8),
                // ── Icône ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.mediumShadow,
                  ),
                  child: const Icon(Icons.person_add_rounded, size: 32, color: Colors.white),
                )
                    .animate()
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 400.ms),
                const Gap(20),

                // ── Titre ──
                Text(
                  'Créer un compte',
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: cs.onSurface),
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideX(begin: -0.05, end: 0, delay: 100.ms, duration: 400.ms),
                const Gap(4),
                Text(
                  'Rejoignez FinanceWise pour gérer vos finances',
                  style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),
                const Gap(32),

                // ── Champ nom ──
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom complet',
                    hintText: 'Votre nom',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: cs.primary, size: 20),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => v != null && v.isNotEmpty ? null : 'Nom requis',
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 400.ms)
                    .slideX(begin: -0.05, end: 0, delay: 250.ms, duration: 400.ms),
                const Gap(16),

                // ── Champ email ──
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'votre@email.com',
                    prefixIcon: Icon(Icons.email_outlined, color: cs.primary, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v != null && v.contains('@') ? null : 'Email invalide',
                )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 400.ms)
                    .slideX(begin: -0.05, end: 0, delay: 350.ms, duration: 400.ms),
                const Gap(16),

                // ── Champ mot de passe ──
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    hintText: '6 caractères minimum',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: cs.primary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => v != null && v.length >= 6 ? null : '6 caractères minimum',
                )
                    .animate()
                    .fadeIn(delay: 450.ms, duration: 400.ms)
                    .slideX(begin: -0.05, end: 0, delay: 450.ms, duration: 400.ms),
                const Gap(28),

                // ── Erreur ──
                if (auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Text(
                            auth.error!,
                            style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .shakeX(hz: 3, amount: 4, duration: 400.ms),
                  const Gap(16),
                ],

                // ── Bouton inscription ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: auth.isLoading ? null : AppTheme.primaryGradient,
                      color: auth.isLoading ? cs.surfaceContainerHighest : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: auth.isLoading ? [] : AppTheme.mediumShadow,
                    ),
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              'Créer mon compte',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 550.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, delay: 550.ms, duration: 400.ms),
                const Gap(32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
