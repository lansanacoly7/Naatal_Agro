import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = prefs.getString('price_alerts');
    if (alertsJson != null) {
      final List<dynamic> decoded = json.decode(alertsJson);
      setState(() {
        _alerts = List<Map<String, dynamic>>.from(decoded);
      });
    }
  }

  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_alerts', json.encode(_alerts));
  }

  void _toggleAlert(int index, bool value) {
    setState(() {
      _alerts[index]['isActive'] = value;
    });
    _saveAlerts();
  }

  void _showAddAlertDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddAlertBottomSheet(),
    ).then((newAlert) {
      if (newAlert != null) {
        setState(() {
          _alerts.add(newAlert);
        });
        _saveAlerts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mes Alertes Prix',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _alerts.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
              itemCount: _alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertCard(alert, index);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAlertDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        label: const Text('Nouvelle Alerte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            'Aucune alerte configurée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            'Soyez prévenu dès qu\'un prix\natteint votre objectif.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, int index) {
    final bool isActive = alert['isActive'];
    final bool isUp = alert['isUp'];
    final Color color = isUp ? Colors.green : Colors.red;
    final IconData icon = isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert['product'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isActive ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert['condition'],
                    style: TextStyle(
                      color: isActive ? Colors.grey.shade700 : Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (val) => _toggleAlert(index, val),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
            ),
          ],
        ),
      ),
    );
  }
}

class AddAlertBottomSheet extends StatefulWidget {
  const AddAlertBottomSheet({super.key});

  @override
  State<AddAlertBottomSheet> createState() => _AddAlertBottomSheetState();
}

class _AddAlertBottomSheetState extends State<AddAlertBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedProduct = 'Oignon Local';
  bool _isUpCondition = true;
  final TextEditingController _priceController = TextEditingController();

  final List<String> _products = ['Oignon Local', 'Arachide', 'Mil', 'Tomate', 'Riz', 'Maïs'];

  void _saveAlert() {
    if (_formKey.currentState!.validate()) {
      final price = _priceController.text;
      final condition = 'Prix ${_isUpCondition ? '>' : '<'} $price FCFA/kg';
      
      Navigator.of(context).pop({
        'product': _selectedProduct,
        'condition': condition,
        'isActive': true,
        'isUp': _isUpCondition,
      });
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Créer une alerte prix',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            
            // Produit
            const Text('Produit', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProduct,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: _products.map((String product) {
                    return DropdownMenuItem<String>(
                      value: product,
                      child: Text(product, style: const TextStyle(fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProduct = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Condition
            const Text('Condition', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isUpCondition = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isUpCondition ? Colors.green.withValues(alpha: 0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isUpCondition ? Colors.green : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up_rounded, color: _isUpCondition ? Colors.green : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text('Supérieur à', style: TextStyle(
                            color: _isUpCondition ? Colors.green : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isUpCondition = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isUpCondition ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !_isUpCondition ? Colors.red : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_down_rounded, color: !_isUpCondition ? Colors.red : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text('Inférieur à', style: TextStyle(
                            color: !_isUpCondition ? Colors.red : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Prix cible
            const Text('Prix Cible (FCFA/kg)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ex: 500',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir un prix';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Bouton de validation
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Enregistrer l\'alerte',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
