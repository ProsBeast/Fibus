import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/commuter/widgets/route_strip.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/core/widgets/fibus_wordmark.dart';
import 'package:fibus/services/auth_service.dart';

/// Commuter sign-in: says what Fibus does, shows a preview of the answer it
/// gives, and offers one action.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final authService = context.read<AuthService>();
      final credential = await authService.signInWithGoogle();
      if (credential == null) {
        // Null with an error set means it failed; null alone means the
        // commuter closed the Google picker.
        if (authService.errorMessage != null) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Could not sign in. Check your connection '
                  'and try again')));
        }
        return;
      }
      if (!mounted) return;

      final commuteProvider = context.read<CommuteProvider>();
      await commuteProvider.initForUser(credential.uid);
      if (!mounted) return;

      if (!commuteProvider.hasHomePin) {
        context.go('/home-pin');
      } else if (!commuteProvider.isCommuteSelected) {
        context.go('/choose-commute');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not sign in. ${_short(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  String _short(Object e) {
    final s = e.toString();
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                FibusSpace.page, FibusSpace.s24, FibusSpace.page, FibusSpace.s24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FibusWordmark(),
                  const SizedBox(height: FibusSpace.s48),
                  Text('Leave home just in time for your bus',
                      style: t.headlineMedium),
                  const SizedBox(height: FibusSpace.s12),
                  Text(
                    'Fibus follows the bus on its route and your ride to the '
                    'stop, then tells you when to go',
                    style: t.bodyLarge?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: FibusSpace.s32),
                  const _AnswerPreview(),
                  const SizedBox(height: FibusSpace.s40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                      child: _isSigningIn
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: c.textMuted),
                            )
                          : const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: FibusSpace.s16),
                  Text(
                    'Your home pin stays private and is only used to time your trip',
                    style: t.bodySmall?.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sample of the dashboard answer, so the first screen shows the product.
class _AnswerPreview extends StatelessWidget {
  const _AnswerPreview();

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    return ExcludeSemantics(
      child: FibCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave by', style: t.labelMedium),
            const SizedBox(height: FibusSpace.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const ClockFigure('7:41', size: 44),
                const SizedBox(width: FibusSpace.s8),
                Text('am',
                    style: FibusType.figure(context, size: 16, color: c.textSecondary)),
              ],
            ),
            const SizedBox(height: FibusSpace.s8),
            Text('Bus 9 reaches Lingampally at 7:59 am, 12 min by scooter',
                style: t.bodySmall),
            const SizedBox(height: FibusSpace.s16),
            Divider(color: c.hairline),
            const SizedBox(height: FibusSpace.s12),
            const RouteStrip(
              stopNames: [
                'Isnapur', 'Patancheru', 'R C Puram', 'Lingampally',
                'Nallagandla', 'Gopanpally', 'V N Pally', 'MGIT',
              ],
              stopFractions: [0, 0.17, 0.32, 0.41, 0.5, 0.63, 0.79, 1],
              boardingIndex: 3,
              busFraction: 0.12,
              busIsLive: true,
            ),
          ],
        ),
      ),
    );
  }
}
