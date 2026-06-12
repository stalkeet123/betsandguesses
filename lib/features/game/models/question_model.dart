/// Question model
class Question {
  final String id;
  final String textTr;
  final String? textEn;
  final int answer;
  final String? answerUnit;
  final String? category;
  final int difficulty;
  final String? source;

  const Question({
    required this.id,
    required this.textTr,
    this.textEn,
    required this.answer,
    this.answerUnit,
    this.category,
    this.difficulty = 3,
    this.source,
  });

  /// Get localized question text
  String getText({String locale = 'tr'}) {
    if (locale == 'en' && textEn != null) return textEn!;
    return textTr;
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      textTr: json['text_tr'] as String,
      textEn: json['text_en'] as String?,
      answer: json['answer'] as int,
      answerUnit: json['answer_unit'] as String?,
      category: json['category'] as String?,
      difficulty: json['difficulty'] as int? ?? 3,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text_tr': textTr,
      'text_en': textEn,
      'answer': answer,
      'answer_unit': answerUnit,
      'category': category,
      'difficulty': difficulty,
      'source': source,
    };
  }
}
