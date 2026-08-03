import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/providers/app_providers.dart';
import '../domain/password_recovery.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final Future<List<RecoveryQuestion>> _questionsFuture;
  List<TextEditingController> _answerControllers = const [];
  List<bool> _showAnswers = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionsFuture = ref.read(localAuthServiceProvider).recoveryQuestions();
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).asData?.value;
    final isBusy = authState?.operation == AuthOperation.recoveringPassword;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<RecoveryQuestion>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageContent(
                message: 'Password recovery could not be loaded.',
                onBack: () => context.go(AppRoutes.login),
              );
            }

            final questions = snapshot.data ?? const <RecoveryQuestion>[];
            if (questions.length != RecoveryQuestionCatalog.requiredCount) {
              return _MessageContent(
                message:
                    'Password recovery has not been set up on this device.',
                onBack: () => context.go(AppRoutes.login),
              );
            }

            _ensureAnswerControllers(questions.length);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Answer your three questions, then choose a new password.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      for (
                        var index = 0;
                        index < questions.length;
                        index++
                      ) ...[
                        Text(
                          questions[index].prompt,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _answerControllers[index],
                          enabled: !isBusy,
                          obscureText: !_showAnswers[index],
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Answer ${index + 1}',
                            prefixIcon: const Icon(Icons.help_outline),
                            suffixIcon: IconButton(
                              tooltip: _showAnswers[index]
                                  ? 'Hide answer'
                                  : 'Show answer',
                              onPressed: isBusy
                                  ? null
                                  : () => setState(
                                      () => _showAnswers = [
                                        for (
                                          var i = 0;
                                          i < _showAnswers.length;
                                          i++
                                        )
                                          i == index
                                              ? !_showAnswers[i]
                                              : _showAnswers[i],
                                      ],
                                    ),
                              icon: Icon(
                                _showAnswers[index]
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Answer is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _newPasswordController,
                        enabled: !isBusy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (value) => value == null || value.length < 4
                            ? 'Password must be at least 4 characters.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !isBusy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) =>
                            value != _newPasswordController.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: isBusy ? null : () => _submit(questions),
                        icon: isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset),
                        label: Text(isBusy ? 'Resetting...' : 'Reset password'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isBusy
                            ? null
                            : () => context.go(AppRoutes.login),
                        child: const Text('Back to login'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit(List<RecoveryQuestion> questions) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .recoverPassword(
            recoveryAnswers: {
              for (var i = 0; i < questions.length; i++)
                questions[i].id: _answerControllers[i].text,
            },
            newPassword: _newPasswordController.text,
          );

      if (!mounted) return;
      switch (result.status) {
        case PasswordRecoveryStatus.success:
          context.go(AppRoutes.login);
        case PasswordRecoveryStatus.notConfigured:
          setState(
            () => _errorMessage =
                'Password recovery has not been set up on this device.',
          );
        case PasswordRecoveryStatus.invalidAnswers:
          setState(
            () =>
                _errorMessage = 'The answers did not match. Please try again.',
          );
        case PasswordRecoveryStatus.lockedOut:
          setState(
            () => _errorMessage =
                'Too many incorrect attempts. Try again in 15 minutes.',
          );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Password recovery failed. Please try again.',
        );
      }
    }
  }

  void _ensureAnswerControllers(int count) {
    if (_answerControllers.length == count) return;
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _answerControllers = List.generate(count, (_) => TextEditingController());
    _showAnswers = List<bool>.filled(count, false);
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
