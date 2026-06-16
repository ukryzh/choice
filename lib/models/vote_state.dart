import 'dart:convert';

class VoteState {
  VoteState({
    required this.question,
    required this.answer,
    required this.hasVoted,
  });

  factory VoteState.fromJson(Map<String, dynamic> json) {
    return VoteState(
      question: json['question'] as String,
      answer: json['answer'] as String,
      hasVoted: json['hasVoted'] as bool? ?? false,
    );
  }

  final String question;
  final String answer;
  final bool hasVoted;

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'hasVoted': hasVoted,
      };

  String encode() => jsonEncode(toJson());
}


