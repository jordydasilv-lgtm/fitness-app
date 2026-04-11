import 'package:flutter/material.dart';

import 'services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationSettingsData _settings = NotificationSettingsData.defaults();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await NotificationService.instance.loadSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _pickTime({
    required int initialHour,
    required int initialMinute,
    required void Function(TimeOfDay time) onSelected,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (selected != null) {
      setState(() {
        onSelected(selected);
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_settings.waterEndHour < _settings.waterStartHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La hora final de agua debe ser mayor o igual a la inicial.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await NotificationService.instance.saveSettings(_settings);
    await NotificationService.instance.scheduleSavedNotifications();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificaciones actualizadas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('Entrenamiento'),
                SwitchListTile(
                  value: _settings.trainingEnabled,
                  title: const Text('Activar recordatorio'),
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(trainingEnabled: value);
                    });
                  },
                ),
                _buildTimeTile(
                  label: 'Hora',
                  value: NotificationService.formatTime(
                    _settings.trainingHour,
                    _settings.trainingMinute,
                  ),
                  enabled: _settings.trainingEnabled,
                  onTap: () => _pickTime(
                    initialHour: _settings.trainingHour,
                    initialMinute: _settings.trainingMinute,
                    onSelected: (time) {
                      _settings = _settings.copyWith(
                        trainingHour: time.hour,
                        trainingMinute: time.minute,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionTitle('Comidas'),
                _buildMealCard(
                  title: 'Desayuno',
                  enabled: _settings.breakfastEnabled,
                  time: NotificationService.formatTime(
                    _settings.breakfastHour,
                    _settings.breakfastMinute,
                  ),
                  onToggle: (value) {
                    setState(() {
                      _settings = _settings.copyWith(breakfastEnabled: value);
                    });
                  },
                  onTap: () => _pickTime(
                    initialHour: _settings.breakfastHour,
                    initialMinute: _settings.breakfastMinute,
                    onSelected: (time) {
                      _settings = _settings.copyWith(
                        breakfastHour: time.hour,
                        breakfastMinute: time.minute,
                      );
                    },
                  ),
                ),
                _buildMealCard(
                  title: 'Almuerzo',
                  enabled: _settings.lunchEnabled,
                  time: NotificationService.formatTime(
                    _settings.lunchHour,
                    _settings.lunchMinute,
                  ),
                  onToggle: (value) {
                    setState(() {
                      _settings = _settings.copyWith(lunchEnabled: value);
                    });
                  },
                  onTap: () => _pickTime(
                    initialHour: _settings.lunchHour,
                    initialMinute: _settings.lunchMinute,
                    onSelected: (time) {
                      _settings = _settings.copyWith(
                        lunchHour: time.hour,
                        lunchMinute: time.minute,
                      );
                    },
                  ),
                ),
                _buildMealCard(
                  title: 'Cena',
                  enabled: _settings.dinnerEnabled,
                  time: NotificationService.formatTime(
                    _settings.dinnerHour,
                    _settings.dinnerMinute,
                  ),
                  onToggle: (value) {
                    setState(() {
                      _settings = _settings.copyWith(dinnerEnabled: value);
                    });
                  },
                  onTap: () => _pickTime(
                    initialHour: _settings.dinnerHour,
                    initialMinute: _settings.dinnerMinute,
                    onSelected: (time) {
                      _settings = _settings.copyWith(
                        dinnerHour: time.hour,
                        dinnerMinute: time.minute,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionTitle('Agua'),
                SwitchListTile(
                  value: _settings.waterEnabled,
                  title: const Text('Activar recordatorios de agua'),
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(waterEnabled: value);
                    });
                  },
                ),
                _buildTimeTile(
                  label: 'Inicio',
                  value: NotificationService.formatTime(
                    _settings.waterStartHour,
                    0,
                  ),
                  enabled: _settings.waterEnabled,
                  onTap: () => _pickTime(
                    initialHour: _settings.waterStartHour,
                    initialMinute: 0,
                    onSelected: (time) {
                      _settings = _settings.copyWith(waterStartHour: time.hour);
                    },
                  ),
                ),
                _buildTimeTile(
                  label: 'Fin',
                  value: NotificationService.formatTime(
                    _settings.waterEndHour,
                    0,
                  ),
                  enabled: _settings.waterEnabled,
                  onTap: () => _pickTime(
                    initialHour: _settings.waterEndHour,
                    initialMinute: 0,
                    onSelected: (time) {
                      _settings = _settings.copyWith(waterEndHour: time.hour);
                    },
                  ),
                ),
                ListTile(
                  enabled: _settings.waterEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Intervalo'),
                  trailing: DropdownButton<int>(
                    value: _settings.waterIntervalHours,
                    onChanged: _settings.waterEnabled
                        ? (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _settings = _settings.copyWith(
                                waterIntervalHours: value,
                              );
                            });
                          }
                        : null,
                    items: const [1, 2, 3, 4]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value hora${value == 1 ? '' : 's'}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionTitle('Resumen diario'),
                SwitchListTile(
                  value: _settings.summaryEnabled,
                  title: const Text('Activar resumen diario'),
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(summaryEnabled: value);
                    });
                  },
                ),
                _buildTimeTile(
                  label: 'Hora',
                  value: NotificationService.formatTime(
                    _settings.summaryHour,
                    _settings.summaryMinute,
                  ),
                  enabled: _settings.summaryEnabled,
                  onTap: () => _pickTime(
                    initialHour: _settings.summaryHour,
                    initialMinute: _settings.summaryMinute,
                    onSelected: (time) {
                      _settings = _settings.copyWith(
                        summaryHour: time.hour,
                        summaryMinute: time.minute,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.schedule),
      onTap: enabled ? onTap : null,
    );
  }

  Widget _buildMealCard({
    required String title,
    required bool enabled,
    required String time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SwitchListTile(
            value: enabled,
            title: Text(title),
            onChanged: onToggle,
          ),
          ListTile(
            enabled: enabled,
            title: const Text('Hora'),
            subtitle: Text(time),
            trailing: const Icon(Icons.schedule),
            onTap: enabled ? onTap : null,
          ),
        ],
      ),
    );
  }
}
