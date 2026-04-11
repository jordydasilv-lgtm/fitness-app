import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/app_data_sync_service.dart';
import 'services/step_counter_service.dart';

Widget buildObjetivosProScreen() => const ObjetivosPro();

class ObjetivosPro extends StatefulWidget {
  const ObjetivosPro({super.key});

  @override
  State<ObjetivosPro> createState() => _ObjetivosProState();
}

class _ObjetivosProState extends State<ObjetivosPro> {
  int pasos = 0;
  double caloriasConsumidas = 0;
  double caloriasEjercicio = 0;
  double proteina = 0;
  double agua = 0;
  int tiempo = 0;
  bool entreno = false;
  String objetivoUsuario = 'Mantener';
  double peso = 0;
  double altura = 0;
  int edad = 0;

  int xp = 0;
  int nivel = 1;
  int racha = 0;
  String ultimaFecha = '';

  late final VoidCallback _stepsListener;
  late final VoidCallback _dataListener;

  int get metaPasos {
    switch (objetivoUsuario) {
      case 'Bajar peso':
        return 12000;
      case 'Subir masa':
        return 9000;
      default:
        return 10000;
    }
  }

  int get metaTiempo {
    switch (objetivoUsuario) {
      case 'Bajar peso':
        return 45;
      case 'Subir masa':
        return 60;
      default:
        return 40;
    }
  }

  double get metaCalorias {
    if (peso == 0 || altura == 0 || edad == 0) return 0;

    final caloriasBase =
        (10 * (peso * 0.453592) + 6.25 * altura - 5 * edad + 5) * 1.2;

    switch (objetivoUsuario) {
      case 'Bajar peso':
        return (caloriasBase - 350).clamp(1200, double.infinity).toDouble();
      case 'Subir masa':
        return caloriasBase + 300;
      default:
        return caloriasBase;
    }
  }

  double get metaProteina {
    if (peso == 0) return 120;

    switch (objetivoUsuario) {
      case 'Bajar peso':
        return peso * 1.0;
      case 'Subir masa':
        return peso * 1.1;
      default:
        return peso * 0.8;
    }
  }

  double get metaAgua {
    if (peso == 0) return 2.0;
    final pesoKg = peso * 0.453592;
    return (pesoKg * 0.035).clamp(1.5, 5.0).toDouble();
  }

  double get caloriasNetas => (caloriasConsumidas - caloriasEjercicio)
      .clamp(0, double.infinity)
      .toDouble();

  int get metricasCumplidas {
    var total = 0;
    if (_cumpleRangoCalorias()) total++;
    if (pasos >= metaPasos) total++;
    if (proteina >= metaProteina) total++;
    if (agua >= metaAgua) total++;
    if (entreno && tiempo >= metaTiempo) total++;
    return total;
  }

  double get progresoDia => metricasCumplidas / 5;

  String get mensajePrincipal {
    if (metricasCumplidas >= 5) {
      return 'Dia redondo. Cumpliste todo lo importante.';
    }
    if (metricasCumplidas >= 3) {
      return 'Vas bien. Te faltan pocos ajustes para cerrar el dia fuerte.';
    }
    return 'Todavia puedes empujar tu progreso con comida, agua o entrenamiento.';
  }

  @override
  void initState() {
    super.initState();
    _stepsListener = () {
      if (!mounted) return;
      setState(() {
        pasos = StepCounterService.instance.currentSteps;
      });
    };
    _dataListener = () {
      cargarDatos();
    };
    StepCounterService.instance.dailySteps.addListener(_stepsListener);
    AppDataSyncService.instance.refreshTick.addListener(_dataListener);
    cargarDatos();
  }

  @override
  void dispose() {
    StepCounterService.instance.dailySteps.removeListener(_stepsListener);
    AppDataSyncService.instance.refreshTick.removeListener(_dataListener);
    super.dispose();
  }

  Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      caloriasConsumidas = prefs.getDouble('calorias') ?? 0;
      caloriasEjercicio = prefs.getDouble('caloriasEjercicio') ?? 0;
      proteina = prefs.getDouble('proteina') ?? 0;
      agua = prefs.getDouble('aguaConsumida') ?? 0;
      pasos = StepCounterService.instance.currentSteps;
      entreno = prefs.getBool('entreno') ?? false;
      tiempo = prefs.getInt('tiempo') ?? 0;
      objetivoUsuario = prefs.getString('goal') ?? 'Mantener';
      peso = prefs.getDouble('weight') ?? 0;
      altura = prefs.getDouble('height') ?? 0;
      edad = prefs.getInt('age') ?? 0;
      xp = prefs.getInt('xp') ?? 0;
      nivel = prefs.getInt('nivel') ?? 1;
      racha = prefs.getInt('racha') ?? 0;
      ultimaFecha = prefs.getString('progresoUltimaFecha') ?? '';
    });
  }

  Future<void> guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('xp', xp);
    await prefs.setInt('nivel', nivel);
    await prefs.setInt('racha', racha);
    await prefs.setString('progresoUltimaFecha', ultimaFecha);
  }

  bool _cumpleRangoCalorias() {
    if (metaCalorias <= 0) return false;
    final minimo = metaCalorias * 0.9;
    final maximo = metaCalorias * 1.1;
    return caloriasNetas >= minimo && caloriasNetas <= maximo;
  }

  void completarMision() {
    final hoy =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';

    if (ultimaFecha == hoy || metricasCumplidas < 4) {
      return;
    }

    xp += 50;
    racha += 1;

    if (xp >= 200) {
      nivel++;
      xp = 0;
    }

    ultimaFecha = hoy;
    guardarDatos();
  }

  double progreso(double actual, double meta) {
    if (meta <= 0) return 0;
    return (actual / meta).clamp(0, 1).toDouble();
  }

  String _formatearNumero(num valor) {
    if (valor == valor.roundToDouble()) {
      return valor.toStringAsFixed(0);
    }
    return valor.toStringAsFixed(1);
  }

  Widget _heroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi progreso',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Objetivo actual: $objetivoUsuario',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progresoDia,
              minHeight: 12,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$metricasCumplidas de 5 metas cumplidas',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensajePrincipal,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _progressCard({
    required String title,
    required String subtitle,
    required double actual,
    required double meta,
    required Color color,
    required IconData icon,
    required String status,
  }) {
    final progress = progreso(actual, meta);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                status,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatearNumero(actual)} / ${_formatearNumero(meta)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _achievementSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Impulso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryPill('Nivel', '$nivel'),
              const SizedBox(width: 10),
              _summaryPill('XP', '$xp / 200'),
              const SizedBox(width: 10),
              _summaryPill('Racha', '$racha dias'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            metricasCumplidas >= 4
                ? 'Hoy estas cerca de sumar XP real. Mantén ese ritmo.'
                : 'Si completas 4 de 5 metas del día, tu progreso suma XP y racha.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    completarMision();

    final caloriasStatus = _cumpleRangoCalorias() ? 'En rango' : 'Ajustar';
    final proteinaStatus = proteina >= metaProteina ? 'Cumplida' : 'Subir';
    final pasosStatus = pasos >= metaPasos ? 'Cumplidos' : 'Faltan';
    final aguaStatus = agua >= metaAgua ? 'Completa' : 'Tomar';
    final entrenoStatus = entreno && tiempo >= metaTiempo
        ? 'Hecho'
        : 'Pendiente';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Mi progreso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroSection(),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryPill(
                'Cal netas',
                '${_formatearNumero(caloriasNetas)} kcal',
              ),
              const SizedBox(width: 10),
              _summaryPill(
                'Meta diaria',
                '${_formatearNumero(metaCalorias)} kcal',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _progressCard(
            title: 'Calorías del día',
            subtitle: 'Balance neto según tu objetivo $objetivoUsuario',
            actual: caloriasNetas,
            meta: metaCalorias == 0 ? 1 : metaCalorias,
            color: Colors.deepOrange,
            icon: Icons.local_fire_department,
            status: caloriasStatus,
          ),
          _progressCard(
            title: 'Proteína',
            subtitle: 'Meta personalizada para apoyar tu objetivo físico',
            actual: proteina,
            meta: metaProteina,
            color: Colors.blue,
            icon: Icons.fitness_center,
            status: proteinaStatus,
          ),
          _progressCard(
            title: 'Pasos',
            subtitle: 'Movimiento diario para sostener tu progreso',
            actual: pasos.toDouble(),
            meta: metaPasos.toDouble(),
            color: Colors.green,
            icon: Icons.directions_walk,
            status: pasosStatus,
          ),
          _progressCard(
            title: 'Agua',
            subtitle: 'Hidratación recomendada según tu peso',
            actual: agua,
            meta: metaAgua,
            color: Colors.cyan,
            icon: Icons.water_drop,
            status: aguaStatus,
          ),
          _progressCard(
            title: 'Entrenamiento',
            subtitle: entreno
                ? 'Llevas $tiempo min registrados hoy'
                : 'Aún no hay sesión registrada hoy',
            actual: entreno ? tiempo.toDouble() : 0,
            meta: metaTiempo.toDouble(),
            color: Colors.purple,
            icon: Icons.timer,
            status: entrenoStatus,
          ),
          const SizedBox(height: 6),
          _achievementSection(),
        ],
      ),
    );
  }
}
