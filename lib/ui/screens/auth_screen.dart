import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../l10n.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _nick = TextEditingController();
  bool _register = false;
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _nick]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<String?> Function(AppState s) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await action(context.read<AppState>());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err == null ? null : context.t(err);
    });
  }

  void _submit() => _run(
    (s) => _register
        ? s.register(_email.text, _password.text, _name.text, _nick.text)
        : s.login(_email.text, _password.text),
  );

  Future<void> _reset() async {
    final s = context.read<AppState>();
    final err = await s.resetPassword(_email.text);
    if (!mounted) return;
    setState(() => _error = context.t(err ?? 'resetSent'));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Logo(),
                  const SizedBox(height: 20),
                  Text(
                    context.t('welcomeTitle'),
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('welcomeText'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: context.t('name')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nick,
                      decoration: InputDecoration(
                        labelText: context.t('nick'),
                        prefixText: '@',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    key: const Key('email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: context.t('email')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('password'),
                    controller: _password,
                    obscureText: _hide,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: context.t('password'),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.t(_register ? 'register' : 'login')),
                  ),
                  if (!_register && context.read<AppState>().backend != null)
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: Text(context.t('forgotPassword')),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(context.t('or')),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run((s) => s.loginWithGoogle()),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    label: Text(context.t('withGoogle')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _register = !_register;
                      _error = null;
                    }),
                    child: Text(
                      context.t(_register ? 'haveAccount' : 'noAccount'),
                    ),
                  ),
                  if (_register)
                    Text(
                      context.t('ageNote'),
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    // Мини-календарь из квадратиков — логотип приложения.
    const cells = [1, 0, 1, 1, 0, 1, 0, 1, 1];
    return Center(
      child: SizedBox(
        width: 84,
        height: 84,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in cells)
              Container(
                decoration: BoxDecoration(
                  color: c == 1
                      ? AppColors.turquoise
                      : AppColors.turquoiseLight,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
