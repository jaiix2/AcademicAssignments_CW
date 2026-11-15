import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

typedef QuestionFetcher = Future<http.Response> Function(Uri uri);

void main() {
  runApp(const ScienceSignalApp());
}

class ScienceSignalApp extends StatelessWidget {
  const ScienceSignalApp({super.key, this.questionFetcher});

  final QuestionFetcher? questionFetcher;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science Signal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ScienceQuizScreen(questionFetcher: questionFetcher),
    );
  }
}

class ScienceQuestion {
  const ScienceQuestion({required this.text, required this.correctAnswer});

  final String text;
  final String correctAnswer;

  factory ScienceQuestion.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['question'] is! String ||
        value['correct_answer'] is! String ||
        value['incorrect_answers'] is! List) {
      throw const FormatException('Invalid question data.');
    }

    final text = Uri.decodeComponent(value['question'] as String);
    final correctAnswer = Uri.decodeComponent(
      value['correct_answer'] as String,
    );
    final incorrectAnswers = value['incorrect_answers'] as List;
    if (text.trim().isEmpty ||
        (correctAnswer != 'True' && correctAnswer != 'False') ||
        incorrectAnswers.length != 1 ||
        incorrectAnswers.first is! String) {
      throw const FormatException('Invalid true-or-false question.');
    }

    final incorrectAnswer = Uri.decodeComponent(
      incorrectAnswers.first as String,
    );
    if ((incorrectAnswer != 'True' && incorrectAnswer != 'False') ||
        incorrectAnswer == correctAnswer) {
      throw const FormatException('Invalid true-or-false answers.');
    }

    return ScienceQuestion(text: text, correctAnswer: correctAnswer);
  }
}

class ScienceQuizScreen extends StatefulWidget {
  const ScienceQuizScreen({super.key, this.questionFetcher});

  final QuestionFetcher? questionFetcher;

  @override
  State<ScienceQuizScreen> createState() => _ScienceQuizScreenState();
}

class _ScienceQuizScreenState extends State<ScienceQuizScreen> {
  static const _questionCount = 5;
  static final _questionUri = Uri.https('opentdb.com', '/api.php', {
    'amount': '5',
    'category': '17',
    'difficulty': 'medium',
    'type': 'boolean',
    'encode': 'url3986',
  });

  List<ScienceQuestion> _questions = [];
  List<String?> _userAnswers = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _loading = true;
  bool _answered = false;
  bool _isSubmitting = false;
  bool _simulationComplete = false;
  String? _selectedAnswer;
  String? _error;
  Map<String, Object>? _submissionPayload;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions({bool resetRound = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (resetRound) {
        _questions = [];
        _userAnswers = [];
        _currentQuestionIndex = 0;
        _score = 0;
        _answered = false;
        _selectedAnswer = null;
        _isSubmitting = false;
        _simulationComplete = false;
        _submissionPayload = null;
      }
    });

    try {
      final response =
          await (widget.questionFetcher?.call(_questionUri) ??
                  http.get(_questionUri))
              .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw FormatException(
          'The server returned HTTP ${response.statusCode}.',
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['response_code'] != 0) {
        final responseCode = data is Map ? data['response_code'] : null;
        throw FormatException(
          'The trivia API returned response code ${responseCode ?? 'unknown'}.',
        );
      }

      final results = data['results'];
      if (results is! List || results.length != _questionCount) {
        throw const FormatException(
          'The trivia API did not return exactly five questions.',
        );
      }
      final questions = results.map(ScienceQuestion.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _userAnswers = List<String?>.filled(questions.length, null);
        _loading = false;
      });
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } on http.ClientException catch (error) {
      _showError('The request failed: ${error.message}');
    } on FormatException catch (error) {
      _showError('Could not load questions: ${error.message}');
    } on ArgumentError catch (error) {
      _showError('Could not decode the questions: ${error.message}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _selectAnswer(String answer) {
    if (_answered || _loading) return;

    final question = _questions[_currentQuestionIndex];
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _userAnswers[_currentQuestionIndex] = answer;
      if (answer == question.correctAnswer) {
        _score++;
      }
    });
  }

  void _continue() {
    if (!_answered) return;

    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _answered = false;
    });
  }

  Future<void> _submitScore() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _simulationComplete = false;
      _submissionPayload = null;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _submissionPayload = {
        'score': _score,
        'total': _questions.length,
        'category': 'Science & Nature',
      };
      _isSubmitting = false;
      _simulationComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Science Signal')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _questions.isNotEmpty &&
                  _currentQuestionIndex >= _questions.length
            ? _buildResults()
            : _buildQuestion(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadQuestions(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswer == question.correctAnswer;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    question.text,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _answered ? null : () => _selectAnswer('True'),
                child: const Text('True'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _answered ? null : () => _selectAnswer('False'),
                child: const Text('False'),
              ),
              if (_answered) ...[
                const SizedBox(height: 16),
                Text(
                  isCorrect ? 'Correct!' : 'Incorrect',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isCorrect ? Colors.green.shade700 : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!isCorrect) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Correct answer: ${question.correctAnswer}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _answered ? _continue : null,
                child: Text(
                  _currentQuestionIndex == _questions.length - 1
                      ? 'View Results'
                      : 'Continue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quiz Complete',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Score: $_score / ${_questions.length}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < _questions.length; index++)
            _buildReviewCard(index),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitScore,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Score (Simulation)'),
          ),
          if (_simulationComplete) ...[
            const SizedBox(height: 16),
            const Text(
              'Simulation Complete\nNo backend request was sent.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_submissionPayload != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(_submissionPayload),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : () => _loadQuestions(resetRound: true),
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(int index) {
    final question = _questions[index];
    final userAnswer = _userAnswers[index];
    final isCorrect = userAnswer == question.correctAnswer;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question: ${question.text}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your Answer: ${userAnswer ?? 'Not answered'} '
              '${isCorrect ? '✅' : '❌'}',
            ),
            Text('Correct Answer: ${question.correctAnswer} ✅'),
            const SizedBox(height: 4),
            Text(
              isCorrect ? 'Correct' : 'Incorrect',
              style: TextStyle(
                color: isCorrect ? Colors.green.shade700 : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
