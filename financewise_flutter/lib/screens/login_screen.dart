import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';
import '../theme.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  final BiometricService _bioService = BiometricService();
  bool _showBiometricButton = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final hasBio = await _bioService.hasBiometrics();
    final prefs = await SharedPreferences.getInstance();
    final biometricActivated = prefs.getBool('biometric_activated') ?? false;
    final savedEmail = prefs.getString('saved_email');

    if (hasBio && biometricActivated && savedEmail != null) {
      setState(() {
        _showBiometricButton = true;
        _emailCtrl.text = savedEmail;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AuthProvider>().login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );

    if (success && mounted) {
      // Save email and password for biometric login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', _emailCtrl.text.trim());
      await prefs.setString('saved_password', _passwordCtrl.text);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _biometricLogin() async {
    final authenticated = await _bioService.authenticate();
    if (authenticated && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');

      if (savedEmail != null && savedPassword != null) {
        final success = await context.read<AuthProvider>().login(
              savedEmail,
              savedPassword,
            );

        if (success) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo animé ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.strongShadow,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack)
                      .fadeIn(duration: 400.ms),
                  const Gap(24),

                  // ── Titre ──
                  Text(
                    'Bon retour !',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 400.ms),
                  const Gap(6),
                  Text(
                    'Connectez-vous pour gérer vos finances',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms),
                  const Gap(36),

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
                      .fadeIn(delay: 300.ms, duration: 400.ms)
                      .slideX(begin: -0.05, end: 0, delay: 300.ms, duration: 400.ms),
                  const Gap(16),

                  // ── Champ mot de passe ──
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
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
                    validator: (v) => v != null && v.length >= 6 ? null : 'Mot de passe trop court',
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms)
                      .slideX(begin: -0.05, end: 0, delay: 400.ms, duration: 400.ms),
                  const Gap(28),

                  // ── Bouton connexion ──
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
                                'Se connecter',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, delay: 500.ms, duration: 400.ms),
                  const Gap(12),

                  // ── Bouton biométrique ──
                  if (_showBiometricButton)
                    IconButton(
                      onPressed: _biometricLogin,
                      icon: const Icon(Icons.fingerprint, size: 48),
                      style: IconButton.styleFrom(
                        foregroundColor: cs.primary,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 400.ms)
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), delay: 600.ms, duration: 400.ms),
                  const Gap(20),

                  // ── Lien inscription ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pas encore de compte ? ',
                        style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        child: Text(
                          'S\'inscrire',
                          style: GoogleFonts.poppins(
                            color: cs.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms),

                  // ── Erreur ──
                  if (auth.error != null) ...[
                    const Gap(20),
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
                              style: GoogleFonts.inter(
                                color: AppTheme.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .shakeX(hz: 3, amount: 4, duration: 400.ms),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
