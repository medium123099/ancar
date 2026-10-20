import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Слишком много попыток. Подождите немного и повторите.';
    }
    if (m.contains('expired') || m.contains('invalid')) {
      return 'Неверный или просроченный код. Запросите новый.';
    }
    return 'Не получилось. Повторите попытку.';
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Введите корректную почту');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .signInWithOtp(email: email, shouldCreateUser: true);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendly(e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Не удалось отправить код. Проверьте интернет и повторите.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Введите код из письма');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailCtrl.text.trim(),
        token: code,
        type: OtpType.email,
      );
      // Дальше AuthGate сам покажет главный экран.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendly(e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось проверить код. Повторите попытку.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeEmail() {
    setState(() {
      _codeSent = false;
      _codeCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Ancar',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Мы отправили код на ${_emailCtrl.text.trim()}'
                        : 'Следите за ценами и наличием товаров. Войдите по почте.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (!_codeSent)
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _sendCode(),
                      decoration: const InputDecoration(
                        labelText: 'Электронная почта',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _verify(),
                      decoration: const InputDecoration(
                        labelText: 'Код из письма',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed:
                        _loading ? null : (_codeSent ? _verify : _sendCode),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_codeSent ? 'Войти' : 'Получить код'),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _loading ? null : _changeEmail,
                      child: const Text('Изменить почту'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
