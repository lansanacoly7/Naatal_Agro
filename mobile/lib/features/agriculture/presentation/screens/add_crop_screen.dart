import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/agriculture_provider.dart';
import '../../../../shared/utils/data_refresh.dart';

class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key});

  @override
  ConsumerState<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends ConsumerState<AddCropScreen> {
  static const _suggestedCrops = ['Mil', 'Maïs', 'Arachide', 'Riz', 'Tomate', 'Oignon', 'Manioc', 'Niébé'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cropTypeController = TextEditingController();
  final _areaSizeController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _plantingDate;
  DateTime? _harvestDate;
  bool _isLoading = false;

  final _dateFormatter = DateFormat('yyyy-MM-dd');

  Future<void> _selectDate(BuildContext context, bool isPlanting) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPlanting) {
          _plantingDate = picked;
        } else {
          _harvestDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_plantingDate == null || _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner les deux dates.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cropData = {
        'name': _nameController.text.trim(),
        'crop_type': _cropTypeController.text.trim(),
        'area_size': double.parse(_areaSizeController.text.trim()),
        'location': _locationController.text.trim(),
        'planting_date': _dateFormatter.format(_plantingDate!),
        'expected_harvest_date': _dateFormatter.format(_harvestDate!),
        'status': 'active',
      };

      await ref.read(agricultureRepositoryProvider).addCrop(cropData);

      // Invalidate providers so Dashboard and Crops List refresh
      refreshAfterDataChange(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Culture ajoutée avec succès !'), backgroundColor: Colors.green),
        );
        context.pop(); // Go back to crops list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cropTypeController.dispose();
    _areaSizeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool _isSelectedCrop(String crop) => _cropTypeController.text.trim().toLowerCase() == crop.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouvelle culture', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Parcelle',
              icon: Icons.landscape_rounded,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Nom de la parcelle',
                  hint: 'ex : Champ Nord',
                  icon: Icons.label_outline_rounded,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _areaSizeController,
                  label: 'Surface',
                  hint: 'ex : 1.5',
                  icon: Icons.straighten_rounded,
                  isNumber: true,
                  suffix: 'ha',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _locationController,
                  label: 'Localisation',
                  hint: 'Région, ville',
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Culture',
              icon: Icons.eco_rounded,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final crop in _suggestedCrops)
                      ChoiceChip(
                        label: Text(crop),
                        selected: _isSelectedCrop(crop),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _isSelectedCrop(crop) ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _cropTypeController.text = crop),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _cropTypeController,
                  label: 'Type de culture',
                  hint: 'Choisissez ci-dessus ou saisissez',
                  icon: Icons.grass_rounded,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Calendrier',
              icon: Icons.event_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDateSelector(
                        label: 'Semis',
                        date: _plantingDate,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateSelector(
                        label: 'Récolte estimée',
                        date: _harvestDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _submitForm,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isLoading ? 'Ajout en cours…' : 'Ajouter la culture'),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajoutez votre parcelle',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Suivez-la de la semence à la récolte.',
                  style: TextStyle(color: Colors.white70, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        fillColor: AppColors.background,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ce champ est requis';
        }
        if (isNumber && double.tryParse(value) == null) {
          return 'Veuillez entrer un nombre valide';
        }
        return null;
      },
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasDate ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasDate ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasDate ? _dateFormatter.format(date) : 'Choisir',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: hasDate ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
