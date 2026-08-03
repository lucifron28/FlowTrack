import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/password_recovery.dart';
import '../widgets/recovery_questions_form.dart';

class PasswordRecoverySettingsScreen extends ConsumerStatefulWidget {
  const PasswordRecoverySettingsScreen({super.key});

  @override
  ConsumerState<PasswordRecoverySettingsScreen> createState() =>
      _PasswordRecoverySettingsScreenState();
}

class _PasswordRecoverySettingsScreenState
    extends ConsumerState<PasswordRecoverySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _recoveryFormKey = GlobalKey<RecoveryQuestionsFormState>();
  late final Future<List<RecoveryQuestion>> _questionsFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionsFuture = ref.read(localAuthServiceProvider).recoveryQuestions();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).asData?.value;
    final isBusy =
        authState?.operation == AuthOperation.updatingRecoveryQuestions;

    return Scaffold(
      appBar: AppBar(title: const Text('Password recovery')),
      body: SafeArea(
        child: FutureBuilder<List<RecoveryQuestion>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Recovery settings could not be loaded.'),
              );
            }

            final questionIds = (snapshot.data ?? const <RecoveryQuestion>[])
                .map((question) => question.id)
                .toList(growable: false);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Update the questions used for offline password recovery.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentPasswordController,
                      enabled: !isBusy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Current password is required.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    RecoveryQuestionsForm(
                      key: _recoveryFormKey,
                      initialQuestionIds:
                          questionIds.length ==
                              RecoveryQuestionCatalog.requiredCount
                          ? questionIds
                          : null,
                      enabled: !isBusy,
                      title: 'New recovery questions',
                      subtitle:
                          'Use answers that are personal and easy for you to remember.',
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
                      onPressed: isBusy ? null : _submit,
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        isBusy ? 'Saving...' : 'Save recovery questions',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate() ||
        !_recoveryFormKey.currentState!.validate()) {
      return;
    }

    final saved = await ref
        .read(authControllerProvider.notifier)
        .updateRecoveryQuestions(
          currentPassword: _currentPasswordController.text,
          recoveryAnswers: _recoveryFormKey.currentState!.answers,
        );
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password recovery questions saved.')),
      );
      Navigator.of(context).pop();
      return;
    }
    setState(
      () => _errorMessage =
          ref.read(authControllerProvider).asData?.value.errorMessage ??
          'Recovery questions could not be saved.',
    );
  }
}
