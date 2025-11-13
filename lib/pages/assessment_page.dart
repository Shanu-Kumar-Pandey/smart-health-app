  import 'package:flutter/material.dart';

class AssessmentPage extends StatelessWidget {
  const AssessmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Assessments'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Container(
        color: theme.colorScheme.background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _AssessmentCard(
              title: 'Lifestyle Assessment',
              description: 'Answer questions about your sleep, diet, exercise and stress levels.',
              icon: Icons.self_improvement,
              color: Color(0xFFE8F5E9),
              assessmentType: AssessmentType.lifestyle,
            ),
            SizedBox(height: 12),
            _AssessmentCard(
              title: 'Cardio Risk Assessment',
              description: 'Evaluate your cardiovascular health risk factors and lifestyle habits.',
              icon: Icons.monitor_heart,
              color: Color(0xFFFFEBEE),
              assessmentType: AssessmentType.cardio,
            ),
            SizedBox(height: 12),
            _AssessmentCard(
              title: 'Diabetes Risk Assessment',
              description: 'Assess your risk factors for developing type 2 diabetes.',
              icon: Icons.bloodtype,
              color: Color(0xFFFFF3E0),
              assessmentType: AssessmentType.diabetes,
            ),
            SizedBox(height: 12),
            _AssessmentCard(
              title: 'Mental Health Assessment',
              description: 'Evaluate your mental wellbeing and stress management.',
              icon: Icons.psychology,
              color: Color(0xFFE3F2FD),
              assessmentType: AssessmentType.mentalHealth,
            ),
            SizedBox(height: 12),
            _AssessmentCard(
              title: 'Nutrition Assessment',
              description: 'Analyze your dietary habits and nutritional balance.',
              icon: Icons.restaurant,
              color: Color(0xFFF3E5F5),
              assessmentType: AssessmentType.nutrition,
            ),
          ],
        ),
      ),
    );
  }
}

enum AssessmentType {
  lifestyle,
  cardio,
  diabetes,
  mentalHealth,
  nutrition,
}

class _AssessmentCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final AssessmentType assessmentType;

  const _AssessmentCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.assessmentType,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuestionnairePage(
                assessmentType: assessmentType,
                title: title,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.black54, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Start Assessment',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionnairePage extends StatefulWidget {
  final AssessmentType assessmentType;
  final String title;

  const QuestionnairePage({
    super.key,
    required this.assessmentType,
    required this.title,
  });

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  int _currentQuestionIndex = 0;
  final Map<int, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    final questionnaire = _getQuestionnaireData(widget.assessmentType);

    if (_currentQuestionIndex >= questionnaire.questions.length) {
      return _buildResultsPage(questionnaire);
    }

    final question = questionnaire.questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / questionnaire.questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              'Question ${_currentQuestionIndex + 1} of ${questionnaire.questions.length}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Question
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Options
            ...question.options.map((option) => _buildOptionButton(option)),
            const SizedBox(height: 24),

            // Navigation buttons
            Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: _previousQuestion,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _currentQuestionIndex == questionnaire.questions.length - 1
                          ? 'View Results'
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _selectAnswer(option),
        style: ElevatedButton.styleFrom(
          backgroundColor: _answers[_currentQuestionIndex] == option
              ? Colors.blue
              : Colors.grey[100],
          foregroundColor: _answers[_currentQuestionIndex] == option
              ? Colors.white
              : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          option,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  void _selectAnswer(String answer) {
    setState(() {
      _answers[_currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_answers[_currentQuestionIndex] != null) {
      if (_currentQuestionIndex < _getQuestionnaireData(widget.assessmentType).questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
      } else {
        // Show results
        setState(() {
          _currentQuestionIndex++;
        });
      }
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Widget _buildResultsPage(QuestionnaireData questionnaire) {
    final score = _calculateScore(questionnaire);
    final riskLevel = _getRiskLevel(score, questionnaire.maxScore);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} Results'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getRiskColor(riskLevel),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _getRiskIcon(riskLevel),
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getRiskTitle(riskLevel),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score: $score/${questionnaire.maxScore}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recommendations
            Text(
              'Recommendations',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._getRecommendations(riskLevel, widget.assessmentType),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex = 0;
                        _answers.clear();
                      });
                    },
                    child: const Text('Retake Assessment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _calculateScore(QuestionnaireData questionnaire) {
    int score = 0;
    _answers.forEach((questionIndex, answer) {
      final question = questionnaire.questions[questionIndex];
      score += question.getScore(answer);
    });
    return score;
  }

  String _getRiskLevel(int score, int maxScore) {
    final percentage = (score / maxScore) * 100;

    // Adjusted thresholds for better distribution
    if (percentage >= 75) return 'low';      // 75%+ = Low Risk
    if (percentage >= 50) return 'moderate'; // 50-74% = Moderate Risk
    return 'high';                          // <50% = High Risk
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Icons.check_circle;
      case 'moderate':
        return Icons.warning;
      case 'high':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String _getRiskTitle(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return 'Excellent! Low Risk';
      case 'moderate':
        return 'Moderate Risk';
      case 'high':
        return 'High Risk - Action Needed';
      default:
        return 'Assessment Complete';
    }
  }

  List<Widget> _getRecommendations(String riskLevel, AssessmentType assessmentType) {
    switch (assessmentType) {
      case AssessmentType.lifestyle:
        return _getLifestyleRecommendations(riskLevel);
      case AssessmentType.cardio:
        return _getCardioRecommendations(riskLevel);
      case AssessmentType.diabetes:
        return _getDiabetesRecommendations(riskLevel);
      case AssessmentType.mentalHealth:
        return _getMentalHealthRecommendations(riskLevel);
      case AssessmentType.nutrition:
        return _getNutritionRecommendations(riskLevel);
    }
  }

  List<Widget> _getLifestyleRecommendations(String riskLevel) {
    if (riskLevel == 'low') {
      return [
        _buildRecommendationItem(
          Icons.check_circle,
          Colors.green,
          'Excellent lifestyle habits!',
          'Continue your current routine for optimal health.',
        ),
        _buildRecommendationItem(
          Icons.fitness_center,
          Colors.blue,
          'Maintain regular exercise',
          'Keep up with your 150 minutes of moderate activity per week.',
        ),
      ];
    } else if (riskLevel == 'moderate') {
      return [
        _buildRecommendationItem(
          Icons.schedule,
          Colors.orange,
          'Improve sleep schedule',
          'Aim for 7-9 hours of quality sleep each night.',
        ),
        _buildRecommendationItem(
          Icons.restaurant,
          Colors.orange,
          'Balanced diet needed',
          'Focus on whole foods, reduce processed foods.',
        ),
      ];
    } else {
      return [
        _buildRecommendationItem(
          Icons.warning,
          Colors.red,
          'Lifestyle changes needed',
          'Consult healthcare provider for personalized advice.',
        ),
        _buildRecommendationItem(
          Icons.local_hospital,
          Colors.red,
          'Medical checkup recommended',
          'Schedule comprehensive health screening.',
        ),
      ];
    }
  }

  List<Widget> _getCardioRecommendations(String riskLevel) {
    if (riskLevel == 'low') {
      return [
        _buildRecommendationItem(
          Icons.favorite,
          Colors.green,
          'Excellent heart health!',
          'Continue your heart-healthy lifestyle.',
        ),
      ];
    } else if (riskLevel == 'moderate') {
      return [
        _buildRecommendationItem(
          Icons.directions_run,
          Colors.orange,
          'Increase physical activity',
          'Aim for 30 minutes of cardio exercise daily.',
        ),
      ];
    } else {
      return [
        _buildRecommendationItem(
          Icons.local_hospital,
          Colors.red,
          'See cardiologist',
          'Schedule cardiac evaluation immediately.',
        ),
      ];
    }
  }

  List<Widget> _getDiabetesRecommendations(String riskLevel) {
    if (riskLevel == 'low') {
      return [
        _buildRecommendationItem(
          Icons.check_circle,
          Colors.green,
          'Low diabetes risk!',
          'Maintain healthy lifestyle to keep risk low.',
        ),
      ];
    } else if (riskLevel == 'moderate') {
      return [
        _buildRecommendationItem(
          Icons.monitor_weight,
          Colors.orange,
          'Weight management',
          'Maintain healthy BMI through diet and exercise.',
        ),
      ];
    } else {
      return [
        _buildRecommendationItem(
          Icons.local_hospital,
          Colors.red,
          'Diabetes screening needed',
          'Consult doctor for glucose testing.',
        ),
      ];
    }
  }

  List<Widget> _getMentalHealthRecommendations(String riskLevel) {
    if (riskLevel == 'low') {
      return [
        _buildRecommendationItem(
          Icons.sentiment_very_satisfied,
          Colors.green,
          'Excellent mental health!',
          'Continue stress management practices.',
        ),
      ];
    } else if (riskLevel == 'moderate') {
      return [
        _buildRecommendationItem(
          Icons.self_improvement,
          Colors.orange,
          'Stress management',
          'Practice mindfulness or meditation daily.',
        ),
      ];
    } else {
      return [
        _buildRecommendationItem(
          Icons.support,
          Colors.red,
          'Professional help recommended',
          'Consider consulting mental health professional.',
        ),
      ];
    }
  }

  List<Widget> _getNutritionRecommendations(String riskLevel) {
    if (riskLevel == 'low') {
      return [
        _buildRecommendationItem(
          Icons.restaurant,
          Colors.green,
          'Excellent nutrition!',
          'Continue your balanced dietary habits.',
        ),
      ];
    } else if (riskLevel == 'moderate') {
      return [
        _buildRecommendationItem(
          Icons.eco,
          Colors.orange,
          'Increase fruits/vegetables',
          'Aim for 5+ servings of produce daily.',
        ),
      ];
    } else {
      return [
        _buildRecommendationItem(
          Icons.assignment,
          Colors.red,
          'Nutrition consultation',
          'Consider working with registered dietitian.',
        ),
      ];
    }
  }

  Widget _buildRecommendationItem(IconData icon, Color color, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  QuestionnaireData _getQuestionnaireData(AssessmentType type) {
    switch (type) {
      case AssessmentType.lifestyle:
        return QuestionnaireData(
          maxScore: 24, // Fixed: was 20, actual max is 4+5+5+5+5=24
          questions: [
            QuestionData(
              question: 'How many hours of sleep do you typically get per night?',
              options: ['Less than 6 hours', '6-7 hours', '7-9 hours', 'More than 9 hours'],
              scores: [1, 2, 4, 3],
            ),
            QuestionData(
              question: 'How often do you engage in moderate physical activity?',
              options: ['Rarely/Never', '1-2 times per week', '3-4 times per week', 'Daily'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How would you rate your stress levels?',
              options: ['Very high', 'High', 'Moderate', 'Low'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How often do you eat fruits and vegetables?',
              options: ['Rarely', '1-2 times per week', '3-4 times per week', 'Daily'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'Do you smoke or use tobacco products?',
              options: ['Yes, regularly', 'Yes, occasionally', 'Quit recently', 'Never'],
              scores: [1, 2, 3, 5],
            ),
          ],
        );
      case AssessmentType.cardio:
        return QuestionnaireData(
          maxScore: 25,
          questions: [
            QuestionData(
              question: 'What is your age group?',
              options: ['Under 30', '30-45', '46-60', 'Over 60'],
              scores: [5, 4, 2, 1],
            ),
            QuestionData(
              question: 'Do you have a family history of heart disease?',
              options: ['Yes, both parents', 'Yes, one parent', 'Yes, extended family', 'No family history'],
              scores: [1, 2, 3, 5],
            ),
            QuestionData(
              question: 'What is your blood pressure status?',
              options: ['High (140/90+)', 'Borderline high', 'Normal', 'Don\'t know'],
              scores: [1, 3, 5, 3],
            ),
            QuestionData(
              question: 'How often do you exercise aerobically?',
              options: ['Never', '1-2 times per week', '3-4 times per week', '5+ times per week'],
              scores: [1, 3, 4, 5],
            ),
            QuestionData(
              question: 'Do you currently smoke or have you smoked in the past?',
              options: ['Current smoker', 'Former smoker (quit <1 year ago)', 'Former smoker (quit 1+ years ago)', 'Never smoked'],
              scores: [1, 2, 4, 5],
            ),
          ],
        );
      case AssessmentType.diabetes:
        return QuestionnaireData(
          maxScore: 25,
          questions: [
            QuestionData(
              question: 'What is your current weight status?',
              options: ['Underweight', 'Normal weight', 'Overweight', 'Obese'],
              scores: [4, 5, 2, 1],
            ),
            QuestionData(
              question: 'How often do you eat sugary foods and drinks?',
              options: ['Multiple times daily', 'Daily', 'Few times per week', 'Rarely/Never'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'Do you have a family history of diabetes?',
              options: ['Yes, both parents', 'Yes, one parent', 'Yes, siblings', 'No family history'],
              scores: [1, 2, 3, 5],
            ),
            QuestionData(
              question: 'How often do you eat whole grains and fiber-rich foods?',
              options: ['Rarely', '1-2 times per week', '3-4 times per week', 'Daily'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How many hours per day do you spend sitting or being sedentary?',
              options: ['More than 8 hours', '6-8 hours', '4-6 hours', 'Less than 4 hours'],
              scores: [1, 2, 4, 5],
            ),
          ],
        );
      case AssessmentType.mentalHealth:
        return QuestionnaireData(
          maxScore: 25,
          questions: [
            QuestionData(
              question: 'How often do you feel overwhelmed by stress?',
              options: ['Daily', 'Several times per week', 'Occasionally', 'Rarely/Never'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How would you rate your overall mood?',
              options: ['Very poor', 'Poor', 'Good', 'Excellent'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How often do you practice relaxation techniques?',
              options: ['Never', 'Rarely', 'Sometimes', 'Regularly'],
              scores: [1, 2, 3, 5],
            ),
            QuestionData(
              question: 'How would you rate your sleep quality?',
              options: ['Very poor', 'Poor', 'Good', 'Excellent'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How often do you feel socially connected and supported?',
              options: ['Rarely/Never', 'Sometimes', 'Often', 'Always'],
              scores: [1, 2, 4, 5],
            ),
          ],
        );
      case AssessmentType.nutrition:
        return QuestionnaireData(
          maxScore: 25,
          questions: [
            QuestionData(
              question: 'How many servings of fruits do you eat daily?',
              options: ['0', '1', '2', '3 or more'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How many servings of vegetables do you eat daily?',
              options: ['0-1', '2-3', '4-5', '6 or more'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'How often do you eat processed/fast food?',
              options: ['Daily', 'Several times per week', 'Once per week', 'Rarely/Never'],
              scores: [1, 2, 4, 5],
            ),
            QuestionData(
              question: 'Do you read nutrition labels when shopping?',
              options: ['Never', 'Rarely', 'Sometimes', 'Always'],
              scores: [1, 2, 3, 5],
            ),
            QuestionData(
              question: 'How many glasses of water do you drink daily?',
              options: ['Less than 4', '4-6', '7-8', 'More than 8'],
              scores: [1, 3, 4, 5],
            ),
          ],
        );
    }
  }
}

class QuestionnaireData {
  final int maxScore;
  final List<QuestionData> questions;

  const QuestionnaireData({
    required this.maxScore,
    required this.questions,
  });
}

class QuestionData {
  final String question;
  final List<String> options;
  final List<int> scores;

  const QuestionData({
    required this.question,
    required this.options,
    required this.scores,
  });

  int getScore(String answer) {
    final index = options.indexOf(answer);
    return index >= 0 ? scores[index] : 0;
  }
}


