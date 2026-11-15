import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:science_signal_trivia_app/main.dart';

void main() {
  testWidgets(
    'plays a round, reviews answers, simulates submission and replays',
    (tester) async {
      var fetchCount = 0;
      Future<http.Response> fetchQuestions(Uri uri) async {
        fetchCount++;
        expect(
          uri.toString(),
          'https://opentdb.com/api.php?amount=5&category=17'
          '&difficulty=medium&type=boolean&encode=url3986',
        );
        return http.Response(jsonEncode(_apiResponse()), 200);
      }

      await tester.pumpWidget(
        ScienceSignalApp(questionFetcher: fetchQuestions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 5'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continue'),
            )
            .onPressed,
        isNull,
      );

      for (var index = 0; index < 5; index++) {
        final correctAnswer = index == 1 ? 'False' : 'True';
        final selectedAnswer = index == 1 ? 'True' : 'True';
        await tester.tap(find.text(selectedAnswer).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(correctAnswer).first);
        await tester.pumpAndSettle();

        expect(
          find.text(index == 1 ? 'Incorrect' : 'Correct!'),
          findsOneWidget,
        );
        if (index == 1) {
          expect(find.text('Correct answer: False'), findsOneWidget);
        }

        await tester.tap(find.text(index == 4 ? 'View Results' : 'Continue'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Quiz Complete'), findsOneWidget);
      expect(find.text('Score: 4 / 5'), findsOneWidget);
      expect(find.text('Your Answer: True ❌'), findsOneWidget);
      expect(find.text('Correct Answer: False ✅'), findsOneWidget);

      await tester.ensureVisible(find.text('Submit Score (Simulation)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Score (Simulation)'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('Simulation Complete'), findsOneWidget);
      expect(find.textContaining('"score": 4'), findsOneWidget);
      expect(find.textContaining('"total": 5'), findsOneWidget);
      expect(
        find.textContaining('"category": "Science & Nature"'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No backend request was sent.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Play Again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Again'));
      await tester.pumpAndSettle();
      expect(fetchCount, 2);
      expect(find.text('Question 1 of 5'), findsOneWidget);
    },
  );
}

Map<String, Object> _apiResponse() {
  return {
    'response_code': 0,
    'results': List.generate(5, (index) {
      final correctAnswer = index == 1 ? 'False' : 'True';
      final incorrectAnswer = correctAnswer == 'True' ? 'False' : 'True';
      return {
        'question': Uri.encodeComponent('Question ${index + 1}?'),
        'correct_answer': correctAnswer,
        'incorrect_answers': [incorrectAnswer],
      };
    }),
  };
}
