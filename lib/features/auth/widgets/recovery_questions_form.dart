import 'package:flutter/material.dart';

import '../domain/password_recovery.dart';

class RecoveryQuestionsForm extends StatefulWidget {
  const RecoveryQuestionsForm({
    super.key,
    this.initialQuestionIds,
    this.enabled = true,
    this.title = 'Recovery questions',
    this.subtitle =
        'Choose three easy questions. Use answers that are personal and difficult for other people to guess. A private made-up answer is okay.',
  });

  final List<String>? initialQuestionIds;
  final bool enabled;
  final String title;
  final String subtitle;

  @override
  RecoveryQuestionsFormState createState() => RecoveryQuestionsFormState();
}

class RecoveryQuestionsFormState extends State<RecoveryQuestionsForm> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _answerControllers;
  late List<String> _selectedQuestionIds;
  List<bool> _showAnswers = const [false, false, false];

  @override
  void initState() {
    super.initState();
    final defaults = RecoveryQuestionCatalog.all
        .take(RecoveryQuestionCatalog.requiredCount)
        .map((question) => question.id)
        .toList(growable: false);
    final initial = widget.initialQuestionIds;
    _selectedQuestionIds =
        initial != null &&
            initial.length == RecoveryQuestionCatalog.requiredCount &&
            initial.toSet().length == RecoveryQuestionCatalog.requiredCount &&
            initial.every(_isKnownQuestion)
        ? List<String>.from(initial)
        : defaults.toList();
    _answerControllers = List.generate(
      RecoveryQuestionCatalog.requiredCount,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> get answers => {
    for (var i = 0; i < _selectedQuestionIds.length; i++)
      _selectedQuestionIds[i]: _answerControllers[i].text,
  };

  bool validate() => _formKey.currentState?.validate() ?? false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          for (
            var index = 0;
            index < RecoveryQuestionCatalog.requiredCount;
            index++
          ) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedQuestionIds[index],
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Question ${index + 1}',
                prefixIcon: const Icon(Icons.help_outline),
              ),
              items: _questionItemsFor(index),
              onChanged: widget.enabled
                  ? (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedQuestionIds[index] = value;
                        _answerControllers[index].clear();
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _answerControllers[index],
              enabled: widget.enabled,
              obscureText: !_showAnswers[index],
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Answer ${index + 1}',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _showAnswers[index] ? 'Hide answer' : 'Show answer',
                  onPressed: widget.enabled
                      ? () => setState(
                          () => _showAnswers = [
                            for (var i = 0; i < _showAnswers.length; i++)
                              i == index ? !_showAnswers[i] : _showAnswers[i],
                          ],
                        )
                      : null,
                  icon: Icon(
                    _showAnswers[index]
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Answer is required.';
                }
                if (RecoveryQuestionCatalog.isWeakAnswer(value)) {
                  return 'Choose a more personal answer.';
                }
                return null;
              },
            ),
            if (index < RecoveryQuestionCatalog.requiredCount - 1)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _questionItemsFor(int currentIndex) {
    return RecoveryQuestionCatalog.all
        .where(
          (question) =>
              question.id == _selectedQuestionIds[currentIndex] ||
              !_selectedQuestionIds.contains(question.id),
        )
        .map(
          (question) => DropdownMenuItem<String>(
            value: question.id,
            child: Text(
              question.prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  bool _isKnownQuestion(String id) {
    return RecoveryQuestionCatalog.all.any((question) => question.id == id);
  }
}
