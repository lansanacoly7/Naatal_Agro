import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../ui/ui.dart';
class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  bool _pushEnabled = true;
  bool _smsEnabled = false;
  bool _emailEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('notif_push') ?? true;
      _smsEnabled = prefs.getBool('notif_sms') ?? false;
      _emailEnabled = prefs.getBool('notif_email') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        backgroundColor: context.c.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.c.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: context.c.ink, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Gérez vos préférences de notifications.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),
          _buildSwitchTile('Notifications Push', 'Alertes météo, prix, et nouveautés directement sur votre téléphone', _pushEnabled, (val) {
            setState(() => _pushEnabled = val);
            _savePreference('notif_push', val);
          }),
          const SizedBox(height: 16),
          _buildSwitchTile('Alertes SMS', 'Recevez les alertes de prix critiques par SMS', _smsEnabled, (val) {
            setState(() => _smsEnabled = val);
            _savePreference('notif_sms', val);
          }),
          const SizedBox(height: 16),
          _buildSwitchTile('Emails récapitulatifs', 'Résumé hebdomadaire du marché et conseils', _emailEnabled, (val) {
            setState(() => _emailEnabled = val);
            _savePreference('notif_email', val);
          }),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: context.c.accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
