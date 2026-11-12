import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/widgets/fibus_wordmark.dart';
import 'package:fibus/services/auth_service.dart';

/// Tracker sign-in for the person who rides the bus and shares its position.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      final auth = context.read<AuthService>();
      final credential = await auth.signInWithGoogle();
      if (!mounted) return;
      if (credential != null) {
        context.go('/buses');
      } else if (auth.errorMessage != null) {
        // Null with an error set means it failed, not that it was cancelled.
        setState(
          () => _errorMessage =
              'Could not sign in. Check your connection and try again',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not sign in. Check your connection and try again',
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;

    return Scaffold(
      body: SafeArea(
        // Fills the screen when it fits, scrolls when text is very large.
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FibusSpace.page,
              FibusSpace.s24,
              FibusSpace.page,
              FibusSpace.s24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FibusWordmark(suffix: 'Tracker'),
                    const Spacer(flex: 2),
                    Text(
                      'Share your bus with the people waiting for it',
                      style: t.headlineMedium,
                    ),
                    const SizedBox(height: FibusSpace.s12),
                    Text(
                      'Tap Start tracking when the trip begins. Riders see where the '
                      'bus is and when it reaches their stop',
                      style: t.bodyLarge?.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: FibusSpace.s32),
                    _Step(
                      n: '1',
                      text: 'Sign in with the account your admin assigned',
                    ),
                    _Step(n: '2', text: 'Pick your bus and start tracking'),
                    _Step(
                      n: '3',
                      text: 'Keep the phone on you until the last stop',
                    ),
                    const SizedBox(height: FibusSpace.s24),
                    const Spacer(flex: 3),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: t.bodySmall?.copyWith(color: c.negative),
                      ),
                      const SizedBox(height: FibusSpace.s12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSigningIn ? null : _handleSignIn,
                        child: _isSigningIn
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.textMuted,
                                ),
                              )
                            : const Text('Continue with Google'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Padding(
      padding: const EdgeInsets.only(bottom: FibusSpace.s12),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.hairline),
              color: c.surface,
            ),
            child: Text(
              n,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: FibusSpace.s12),
          Expanded(child: Text(text, style: context.type.bodyMedium)),
        ],
      ),
    );
  }
}
