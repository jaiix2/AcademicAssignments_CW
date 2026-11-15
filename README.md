# science_signal_trivia_app
## Flutter Quiz App


## Overview
Science Signal is a simple Flutter quiz app that retrieves Science & Nature true/false questions from the Open Trivia Database API. Users answer five questions, receive feedback, and view their final results.

## Features
- Retrieves 5 random Science & Nature questions
- True/False answer selection
- Correct and incorrect answer feedback
- Tracks quiz progress and score
- Final results screen with answer review
- Replay option for a new set of questions
- Loading, error, and retry functionality
- Simulated score submission

## Technologies Used
- Flutter / Dart
- Open Trivia Database REST API
- HTTP requests and JSON decoding

## How to Run
1. Clone the repository.
2. Open the Flutter project in VS Code.
3. Run `flutter pub get`.
4. Start an emulator and run `flutter run`.

## Notes
The app requires an internet connection to retrieve questions. Score submission is simulated because no backend was provided, meaning scores are not actually saved to a server.