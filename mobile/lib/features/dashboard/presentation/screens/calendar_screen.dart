import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbol_data_local.dart';

enum TaskStatus { pending, completed }

class CropTask {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final TaskStatus status;
  final String phase; // ex: 'Irrigation', 'Semis'

  CropTask({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.status = TaskStatus.pending,
    required this.phase,
  });
}

class SmartAdjustment {
  final String taskId;
  final String message;
  final DateTime proposedDate;
  final String reason;

  SmartAdjustment({
    required this.taskId,
    required this.message,
    required this.proposedDate,
    required this.reason,
  });
}
// --- Modèles Locaux pour la Démo ---
class CropLifecycle {
  final String name;
  final String variety;
  final String imagePath;
  final String plot;
  final String currentPhase;
  final double progress;
  final List<int> sowingMonths;
  final List<int> harvestMonths;
  final List<int> favorableSowingDays; // ex: 1, 2, 15, 16
  final List<int> favorableHarvestDays;
  final List<CropTask> tasks;
  final SmartAdjustment? pendingAdjustment;

  CropLifecycle({
    required this.name,
    required this.variety,
    required this.imagePath,
    required this.plot,
    required this.currentPhase,
    required this.progress,
    required this.sowingMonths,
    required this.harvestMonths,
    this.favorableSowingDays = const [],
    this.favorableHarvestDays = const [],
    this.tasks = const [],
    this.pendingAdjustment,
  });
}

final List<CropLifecycle> _mockCrops = [
  CropLifecycle(
    name: 'Tomates',
    variety: 'Mongal F1',
    imagePath: 'assets/images/tomates_recolte.jpg',
    plot: 'Parcelle Nord',
    currentPhase: 'Croissance',
    progress: 0.45,
    sowingMonths: [5, 6], // Mai, Juin
    harvestMonths: [8, 9], // Août, Septembre
    favorableSowingDays: [12, 14, 15, 20],
    favorableHarvestDays: [5, 10, 25, 28],
    tasks: [
      CropTask(id: 't1', title: 'Irrigation', description: 'Irrigation goutte à goutte recommandée (4h)', date: DateTime(DateTime.now().year, DateTime.now().month, 18), phase: 'Irrigation'),
      CropTask(id: 't2', title: 'Sarclage', description: 'Retirer les mauvaises herbes', date: DateTime(DateTime.now().year, DateTime.now().month, 22), phase: 'Entretien'),
      CropTask(id: 't3', title: 'Application NPK', description: 'Fertilisation de surface', date: DateTime(DateTime.now().year, DateTime.now().month, 10), phase: 'Nutrition', status: TaskStatus.completed),
    ],
    pendingAdjustment: SmartAdjustment(
      taskId: 't1',
      message: 'Modification recommandée',
      proposedDate: DateTime(DateTime.now().year, DateTime.now().month, 19),
      reason: 'Une pluie importante est prévue le 18 juin.',
    ),
  ),
  CropLifecycle(
    name: 'Mil',
    variety: 'Souna 3',
    imagePath: 'assets/images/mil_recolte.jpg',
    plot: 'Champ Principal',
    currentPhase: 'Préparation',
    progress: 0.10,
    sowingMonths: [6, 7], // Juin, Juillet
    harvestMonths: [10, 11], // Octobre, Novembre
    favorableSowingDays: [2, 5, 8],
    favorableHarvestDays: [12, 15, 20],
  ),
  CropLifecycle(
    name: 'Arachide',
    variety: 'Fleur 11',
    imagePath: 'assets/images/arachide_recolte.jpg',
    plot: 'Parcelle Est',
    currentPhase: 'Floraison',
    progress: 0.60,
    sowingMonths: [6, 7], // Juin, Juillet
    harvestMonths: [9, 10], // Septembre, Octobre
    favorableSowingDays: [1, 3, 10],
    favorableHarvestDays: [5, 12, 18],
  ),
];

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                physics: const BouncingScrollPhysics(),
                itemCount: _mockCrops.length,
                itemBuilder: (context, index) {
                  final crop = _mockCrops[index];
                  return _buildCropCard(context, crop);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Mes Cultures',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.eco, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildCropCard(BuildContext context, CropLifecycle crop) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => CropCalendarDetailScreen(crop: crop)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Petite photo à gauche
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                crop.imagePath,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            // Détails à droite
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          crop.name,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(crop.progress * 100).toInt()}%',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${crop.variety} • ${crop.plot}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Phase : ${crop.currentPhase}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: crop.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// VUE DETAIL : CALENDRIER INTERACTIF DE LA CULTURE
// ---------------------------------------------------------
class CropCalendarDetailScreen extends StatefulWidget {
  final CropLifecycle crop;

  const CropCalendarDetailScreen({super.key, required this.crop});

  @override
  State<CropCalendarDetailScreen> createState() => _CropCalendarDetailScreenState();
}

class _CropCalendarDetailScreenState extends State<CropCalendarDetailScreen> {
  late DateTime _focusedMonth;
  late CropLifecycle _currentCrop;

  @override
  void initState() {
    super.initState();
    _currentCrop = widget.crop;
    initializeDateFormatting('fr_FR', null);
    // On se place sur le premier mois de semis par défaut s'il existe
    int initialMonth = DateTime.now().month;
    if (_currentCrop.sowingMonths.isNotEmpty) {
      initialMonth = _currentCrop.sowingMonths.first;
    }
    _focusedMonth = DateTime(DateTime.now().year, initialMonth, 1);
  }

  void _acceptAdjustment() {
    if (_currentCrop.pendingAdjustment == null) return;
    
    final adjustment = _currentCrop.pendingAdjustment!;
    final updatedTasks = _currentCrop.tasks.map((task) {
      if (task.id == adjustment.taskId) {
        return CropTask(
          id: task.id,
          title: task.title,
          description: task.description,
          date: adjustment.proposedDate,
          phase: task.phase,
          status: task.status,
        );
      }
      return task;
    }).toList();

    // Sort tasks by date
    updatedTasks.sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _currentCrop = CropLifecycle(
        name: _currentCrop.name,
        variety: _currentCrop.variety,
        imagePath: _currentCrop.imagePath,
        plot: _currentCrop.plot,
        currentPhase: _currentCrop.currentPhase,
        progress: _currentCrop.progress,
        sowingMonths: _currentCrop.sowingMonths,
        harvestMonths: _currentCrop.harvestMonths,
        favorableSowingDays: _currentCrop.favorableSowingDays,
        favorableHarvestDays: _currentCrop.favorableHarvestDays,
        tasks: updatedTasks,
        pendingAdjustment: null, // clear adjustment
      );
    });
  }

  void _dismissAdjustment() {
    setState(() {
      _currentCrop = CropLifecycle(
        name: _currentCrop.name,
        variety: _currentCrop.variety,
        imagePath: _currentCrop.imagePath,
        plot: _currentCrop.plot,
        currentPhase: _currentCrop.currentPhase,
        progress: _currentCrop.progress,
        sowingMonths: _currentCrop.sowingMonths,
        harvestMonths: _currentCrop.harvestMonths,
        favorableSowingDays: _currentCrop.favorableSowingDays,
        favorableHarvestDays: _currentCrop.favorableHarvestDays,
        tasks: _currentCrop.tasks,
        pendingAdjustment: null, // clear adjustment
      );
    });
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildLegend(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildMonthNavigator(),
                      const SizedBox(height: 20),
                      _buildCalendarGrid(),
                      const SizedBox(height: 40),
                      if (_currentCrop.pendingAdjustment != null) ...[
                        _buildSmartAdjustmentCard(_currentCrop.pendingAdjustment!),
                        const SizedBox(height: 32),
                      ],
                      _buildTaskTimeline(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Calendrier : ${widget.crop.name}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.green.shade500, 'Semis Propice'),
          const SizedBox(width: 24),
          _buildLegendItem(Colors.orange.shade500, 'Récolte Propice'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    final monthName = DateFormat.yMMMM('fr_FR').format(_focusedMonth).toUpperCase();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _previousMonth,
          icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 30),
        ),
        Text(
          monthName,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary, letterSpacing: 1.2),
        ),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right, color: AppColors.primary, size: 30),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOffset = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday - 1; // 0 for Monday
    
    final isSowingMonth = widget.crop.sowingMonths.contains(_focusedMonth.month);
    final isHarvestMonth = widget.crop.harvestMonths.contains(_focusedMonth.month);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          // Jours de la semaine
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'].map((day) => 
              SizedBox(
                width: 35,
                child: Text(day, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              )
            ).toList(),
          ),
          const SizedBox(height: 16),
          // Grille des jours
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + firstDayOffset,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox();
              
              final day = index - firstDayOffset + 1;
              final isFavorableSowing = isSowingMonth && widget.crop.favorableSowingDays.contains(day);
              final isFavorableHarvest = isHarvestMonth && widget.crop.favorableHarvestDays.contains(day);
              
              BoxDecoration decoration;
              Color textColor = AppColors.textPrimary;
              FontWeight fontWeight = FontWeight.w600;

              if (isFavorableSowing) {
                decoration = BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                );
                textColor = Colors.white;
                fontWeight = FontWeight.bold;
              } else if (isFavorableHarvest) {
                decoration = BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                );
                textColor = Colors.white;
                fontWeight = FontWeight.bold;
              } else if (isSowingMonth || isHarvestMonth) {
                // Mois propice, mais pas un "jour idéal" = couleur très légère
                decoration = BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSowingMonth ? Colors.green.shade50 : Colors.orange.shade50,
                );
              } else {
                decoration = const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent);
              }

              // Météo (Mock)
              IconData? weatherIcon;
              Color weatherColor = Colors.transparent;
              if (day == 18 && _focusedMonth.month == DateTime.now().month) {
                weatherIcon = Icons.water_drop; // Pluie importante
                weatherColor = Colors.blue.shade300;
              } else if (day == 19 && _focusedMonth.month == DateTime.now().month) {
                weatherIcon = Icons.wb_sunny; // Soleil
                weatherColor = Colors.orange.shade300;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: decoration,
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(color: textColor, fontWeight: fontWeight, fontSize: 14),
                    ),
                  ),
                  if (weatherIcon != null)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
                        child: Icon(weatherIcon, size: 10, color: weatherColor),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmartAdjustmentCard(SmartAdjustment adjustment) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(adjustment.message, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(adjustment.reason, style: TextStyle(color: Colors.orange.shade900, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'Action proposée : Déplacer au ${DateFormat('dd MMMM', 'fr_FR').format(adjustment.proposedDate)} ?', 
            style: TextStyle(color: Colors.orange.shade900, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _acceptAdjustment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _dismissAdjustment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Garder la date', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Itinéraire Technique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        const SizedBox(height: 20),
        ..._currentCrop.tasks.map((task) {
          final isCompleted = task.status == TaskStatus.completed;
          final isToday = task.date.day == DateTime.now().day && task.date.month == DateTime.now().month;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : (isToday ? AppColors.primary : Colors.grey.shade300),
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 4) : null,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 80,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.grey.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCompleted ? Colors.transparent : Colors.grey.withValues(alpha: 0.1)),
                      boxShadow: isCompleted ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy', 'fr_FR').format(task.date),
                              style: TextStyle(
                                color: isCompleted ? Colors.grey : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.phase,
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey.shade600 : AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCompleted ? Colors.grey : AppColors.textPrimary,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: TextStyle(
                            color: isCompleted ? Colors.grey : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
