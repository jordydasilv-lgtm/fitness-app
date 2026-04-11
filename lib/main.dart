import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'home_principal.dart';
import 'notification_settings_screen.dart';
import 'services/app_data_sync_service.dart';
import 'services/external_progress_widget_service.dart';
import 'services/notification_service.dart';
import 'services/step_counter_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await StepCounterService.instance.initialize();
  await NotificationService.instance.scheduleSavedNotifications();
  runApp(const NutrifynGoApp());
}

const Color fitTrackPageBackgroundColor = Color(0xFFD8F1FF);
const Color fitAppPageBackgroundColor = fitTrackPageBackgroundColor;

int _currentIndex = 0;

class NutrifynGoApp extends StatelessWidget {
  const NutrifynGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutrifynGo',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: fitTrackPageBackgroundColor,
        canvasColor: fitTrackPageBackgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB8E8),
          brightness: Brightness.light,
          surface: fitTrackPageBackgroundColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: fitTrackPageBackgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: fitTrackPageBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: fitTrackPageBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const AppBootstrapScreen(),
    );
  }
}

class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await cargarTodo();

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: fitTrackPageBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!user.hasCompletedProfile) {
      return const UserForm(isFirstSetup: true);
    }

    return const HomePrincipal();
  }
}

class UserData {
  String name = "";
  String sex = "Hombre";
  int age = 0;
  double weight = 0;
  double height = 0;
  String goal = "Mantener";
  String photoBase64 = "";
  String photoUrl = "";
  String authEmail = "";
  String authProvider = "";
  String authUid = "";

  double caloriasEjercicio = 0;

  bool get hasCompletedProfile {
    return name.trim().isNotEmpty && age > 0 && weight > 0 && height > 0;
  }

  double get baseCalories {
    if (weight == 0 || height == 0 || age == 0) return 0;
    final pesoKg = weight * 0.453592;
    final ajusteSexo = sex == "Mujer" ? -161 : 5;
    return (10 * pesoKg + 6.25 * height - 5 * age + ajusteSexo) * 1.2;
  }

  double get calories {
    final caloriasBase = baseCalories;
    if (caloriasBase == 0) return 0;

    switch (goal) {
      case "Bajar peso":
        return (caloriasBase - 350).clamp(1200, double.infinity).toDouble();
      case "Subir masa":
        return caloriasBase + 300;
      default:
        return caloriasBase;
    }
  }

  void loadFromJson(Map<String, dynamic> data) {
    name = data['name']?.toString() ?? name;
    sex = data['sex']?.toString() ?? sex;
    age = (data['age'] as num?)?.toInt() ?? age;
    weight = (data['weight'] as num?)?.toDouble() ?? weight;
    height = (data['height'] as num?)?.toDouble() ?? height;
    goal = data['goal']?.toString() ?? goal;
    photoBase64 = data['photoBase64']?.toString() ?? photoBase64;
    photoUrl = data['photoUrl']?.toString() ?? photoUrl;
  }
}

UserData user = UserData();

Future<String?> seleccionarFotoPerfilBase64() async {
  try {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 720,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  } catch (_) {
    return null;
  }
}

Uint8List? bytesFotoUsuario() {
  if (user.photoBase64.trim().isEmpty) return null;
  try {
    return base64Decode(user.photoBase64);
  } catch (_) {
    return null;
  }
}

Widget avatarUsuario({
  double radius = 28,
  double fontSize = 24,
  Color backgroundColor = const Color(0xFF2563EB),
}) {
  final bytes = bytesFotoUsuario();
  final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

  if (bytes != null) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: MemoryImage(bytes),
      backgroundColor: Colors.white,
    );
  }

  if (user.photoUrl.trim().isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(user.photoUrl),
      backgroundColor: Colors.white,
    );
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Map<String, List<Map<String, dynamic>>> rutinaGlobal = {
  "Lunes": [],
  "Martes": [],
  "Miércoles": [],
  "Jueves": [],
  "Viernes": [],
  "Sábado": [],
};

List<Map<String, dynamic>> favoritosGlobal = [];
List<Map<String, dynamic>> canastaGlobal = [];
Map<String, List<Map<String, dynamic>>> comidasHistorialGlobal = {};
Map<String, List<Map<String, dynamic>>> ejerciciosHistorialGlobal = {};
Map<String, Map<String, String>> bienestarHistorialGlobal = {};
double caloriasConsumidas = 0;
double proteinaConsumida = 0;
double carbsConsumidos = 0;
double caloriasEjercicio = 0;
double aguaConsumida = 0;
Map<String, double> aguaHistorialGlobal = {};
List<Map<String, dynamic>> desayunoGlobal = [];
List<Map<String, dynamic>> almuerzoGlobal = [];
List<Map<String, dynamic>> cenaGlobal = [];
List<Map<String, dynamic>> snacksGlobal = [];
List<Map<String, dynamic>> alimentosPersonalizadosGlobal = [];

const List<String> tiposComidaPrincipales = [
  "Desayuno",
  "Almuerzo",
  "Cena",
  "Snack",
];

const String premiumPrefsKey = 'premiumActivado';
const String progressWidgetPrefsKey = 'mostrarWidgetProgreso';

bool premiumActivadoGlobal = false;
bool mostrarWidgetProgresoGlobal = true;

Future<void> guardarEstadoPremium(bool activo) async {
  premiumActivadoGlobal = activo;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(premiumPrefsKey, activo);
}

Future<bool> cargarEstadoPremium() async {
  final prefs = await SharedPreferences.getInstance();
  premiumActivadoGlobal = prefs.getBool(premiumPrefsKey) ?? false;
  return premiumActivadoGlobal;
}

const List<Map<String, dynamic>> rutinasPremiumDemo = [
  {
    'titulo': 'Definicion total 360',
    'objetivo': 'Bajar grasa',
    'nivel': 'Intermedio',
    'frecuencia': '5 dias por semana',
    'enfoque':
        'Combina fuerza metabolica, core y cardio inteligente para acelerar el gasto calorico sin perder masa muscular.',
    'categorias': ['Cardio HIIT', 'Pierna', 'Core', 'Espalda', 'Full body'],
    'ejercicios': [
      'Sentadilla con salto',
      'Remo con mancuerna',
      'Mountain climbers',
      'Plancha con toque de hombros',
      'Zancadas alternas',
    ],
  },
  {
    'titulo': 'Gluteo y pierna power',
    'objetivo': 'Gluteo y pierna',
    'nivel': 'Avanzado',
    'frecuencia': '4 dias por semana',
    'enfoque':
        'Sube volumen y tension mecanica con bloques enfocados en gluteo mayor, femoral, cuadriceps y estabilidad.',
    'categorias': ['Gluteo', 'Pierna', 'Movilidad', 'Fuerza'],
    'ejercicios': [
      'Hip thrust',
      'Peso muerto rumano',
      'Sentadilla bulgara',
      'Abduccion en banda',
      'Step up controlado',
    ],
  },
  {
    'titulo': 'Masa limpia upper-lower',
    'objetivo': 'Subir masa',
    'nivel': 'Principiante',
    'frecuencia': '4 dias por semana',
    'enfoque':
        'Rutina guiada por niveles con progresion simple para construir fuerza y masa en torso y tren inferior.',
    'categorias': ['Pecho', 'Espalda', 'Pierna', 'Hombro', 'Brazo'],
    'ejercicios': [
      'Press de pecho',
      'Jalon al pecho',
      'Prensa',
      'Curl de biceps',
      'Press militar sentado',
    ],
  },
];

const List<Map<String, dynamic>> recetasPremiumDemo = [
  {
    'tipo': 'Desayuno',
    'nombre': 'Bowl de avena proteico tropical',
    'descripcion':
        'Desayuno alto en proteina con carbohidratos limpios para arrancar el dia con energia estable.',
    'ingredientes': [
      '60 g de avena',
      '200 ml de leche descremada',
      '170 g de yogurt griego',
      '1 banano en rodajas',
      '10 g de chia',
    ],
    'preparacion': [
      'Cocina la avena con la leche hasta que quede cremosa.',
      'Sirve en un bowl y agrega el yogurt encima.',
      'Termina con banano y chia para sumar textura.',
    ],
    'calorias': 430,
    'proteina': 28,
    'carbs': 58,
  },
  {
    'tipo': 'Almuerzo',
    'nombre': 'Pollo citrico con arroz y brocoli',
    'descripcion':
        'Almuerzo balanceado para recomposicion corporal con buena saciedad y recuperacion.',
    'ingredientes': [
      '160 g de pechuga de pollo',
      '120 g de arroz integral cocido',
      '100 g de brocoli',
      '1 cdita de aceite de oliva',
      'Limon, ajo y paprika',
    ],
    'preparacion': [
      'Sazona el pollo con limon, ajo y paprika.',
      'Cocina el pollo a la plancha hasta dorar ambos lados.',
      'Sirve con arroz integral y brocoli al vapor.',
    ],
    'calorias': 540,
    'proteina': 44,
    'carbs': 46,
  },
  {
    'tipo': 'Cena',
    'nombre': 'Salmon con pure rustico y ensalada fresca',
    'descripcion':
        'Cena premium para recuperar musculo sin pesadez y mantener grasas de calidad.',
    'ingredientes': [
      '150 g de salmon',
      '180 g de papa cocida',
      'Mix de hojas verdes',
      '1 cdita de aceite de oliva',
      'Sal marina y pimienta',
    ],
    'preparacion': [
      'Hornea el salmon con sal y pimienta durante 12 a 15 minutos.',
      'Haz un pure rustico con la papa cocida y un toque de aceite.',
      'Acompana con hojas verdes frescas.',
    ],
    'calorias': 510,
    'proteina': 34,
    'carbs': 31,
  },
  {
    'tipo': 'Snack',
    'nombre': 'Yogurt crunchy con fruta y nueces',
    'descripcion':
        'Snack rapido para sostener hambre controlada y meter proteina entre comidas.',
    'ingredientes': [
      '170 g de yogurt griego',
      '80 g de frutos rojos',
      '15 g de nueces picadas',
      '1 cdita de miel',
    ],
    'preparacion': [
      'Sirve el yogurt en un vaso o bowl.',
      'Agrega frutos rojos y nueces por encima.',
      'Termina con una cucharadita de miel.',
    ],
    'calorias': 250,
    'proteina': 18,
    'carbs': 19,
  },
];

const List<Map<String, dynamic>> catalogoBaseAlimentos = [
  {
    "nombre": "Avena cocida",
    "calorias": 150,
    "proteina": 5,
    "carbs": 27,
    "tipos": ["Desayuno", "Snack"],
  },
  {
    "nombre": "Huevo",
    "calorias": 78,
    "proteina": 6,
    "carbs": 1,
    "tipos": ["Desayuno", "Cena"],
  },
  {
    "nombre": "Yogurt griego",
    "calorias": 130,
    "proteina": 12,
    "carbs": 9,
    "tipos": ["Desayuno", "Snack"],
  },
  {
    "nombre": "Pan integral",
    "calorias": 90,
    "proteina": 4,
    "carbs": 18,
    "tipos": ["Desayuno", "Snack"],
  },
  {
    "nombre": "Banano",
    "calorias": 105,
    "proteina": 1,
    "carbs": 27,
    "tipos": ["Desayuno", "Snack"],
  },
  {
    "nombre": "Arepa",
    "calorias": 180,
    "proteina": 4,
    "carbs": 36,
    "tipos": ["Desayuno"],
  },
  {
    "nombre": "Queso fresco",
    "calorias": 95,
    "proteina": 7,
    "carbs": 2,
    "tipos": ["Desayuno", "Cena"],
  },
  {
    "nombre": "Manzana",
    "calorias": 95,
    "proteina": 0,
    "carbs": 25,
    "tipos": ["Desayuno", "Snack"],
  },
  {
    "nombre": "Pechuga de pollo",
    "calorias": 165,
    "proteina": 31,
    "carbs": 0,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Arroz blanco",
    "calorias": 205,
    "proteina": 4,
    "carbs": 45,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Carne magra",
    "calorias": 215,
    "proteina": 26,
    "carbs": 0,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Pescado al horno",
    "calorias": 190,
    "proteina": 28,
    "carbs": 0,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Pasta cocida",
    "calorias": 220,
    "proteina": 8,
    "carbs": 43,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Papa cocida",
    "calorias": 160,
    "proteina": 4,
    "carbs": 37,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Frijoles",
    "calorias": 175,
    "proteina": 11,
    "carbs": 30,
    "tipos": ["Almuerzo"],
  },
  {
    "nombre": "Ensalada mixta",
    "calorias": 60,
    "proteina": 2,
    "carbs": 10,
    "tipos": ["Almuerzo", "Cena"],
  },
  {
    "nombre": "Atún en agua",
    "calorias": 120,
    "proteina": 26,
    "carbs": 0,
    "tipos": ["Cena", "Snack"],
  },
  {
    "nombre": "Sopa de verduras",
    "calorias": 140,
    "proteina": 5,
    "carbs": 20,
    "tipos": ["Cena"],
  },
  {
    "nombre": "Tortilla de maíz",
    "calorias": 110,
    "proteina": 3,
    "carbs": 22,
    "tipos": ["Cena", "Almuerzo"],
  },
  {
    "nombre": "Aguacate",
    "calorias": 120,
    "proteina": 2,
    "carbs": 6,
    "tipos": ["Desayuno", "Cena", "Snack"],
  },
  {
    "nombre": "Almendras",
    "calorias": 170,
    "proteina": 6,
    "carbs": 6,
    "tipos": ["Snack"],
  },
  {
    "nombre": "Batido proteico",
    "calorias": 190,
    "proteina": 24,
    "carbs": 8,
    "tipos": ["Snack"],
  },
  {
    "nombre": "Galletas de arroz",
    "calorias": 70,
    "proteina": 1,
    "carbs": 14,
    "tipos": ["Snack"],
  },
  {
    "nombre": "Mantequilla de maní",
    "calorias": 95,
    "proteina": 4,
    "carbs": 4,
    "tipos": ["Snack", "Desayuno"],
  },
  {
    "nombre": "Fresas",
    "calorias": 50,
    "proteina": 1,
    "carbs": 12,
    "tipos": ["Desayuno", "Snack"],
  },
];

const List<String> diasSemanaEspanol = [
  "Lunes",
  "Martes",
  "Miércoles",
  "Jueves",
  "Viernes",
  "Sábado",
  "Domingo",
];

const List<Map<String, dynamic>> bienestarPreguntas = [
  {
    "id": "energia",
    "pregunta": "¿Cómo está tu energía hoy?",
    "opciones": ["Muy baja", "Baja", "Normal", "Alta"],
  },
  {
    "id": "animo",
    "pregunta": "¿Cómo está tu ánimo hoy?",
    "opciones": ["Triste", "Neutral", "Bien", "Excelente"],
  },
  {
    "id": "hambre",
    "pregunta": "¿Cómo sentiste tu hambre hoy?",
    "opciones": ["Muy baja", "Controlada", "Alta", "Ansiedad"],
  },
  {
    "id": "sueno",
    "pregunta": "¿Cómo dormiste?",
    "opciones": ["Muy mal", "Regular", "Bien", "Excelente"],
  },
  {
    "id": "estres",
    "pregunta": "¿Qué nivel de estrés tuviste hoy?",
    "opciones": ["Muy alto", "Alto", "Normal", "Bajo"],
  },
  {
    "id": "motivacion",
    "pregunta": "¿Qué tanta motivación tuviste hoy?",
    "opciones": ["Muy baja", "Baja", "Buena", "Muy alta"],
  },
];

String fechaActualKey([DateTime? fecha]) {
  final actual = fecha ?? DateTime.now();
  return '${actual.year}-${actual.month}-${actual.day}';
}

String nombreDiaCompleto(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return "Lunes";
    case DateTime.tuesday:
      return "Martes";
    case DateTime.wednesday:
      return "Miércoles";
    case DateTime.thursday:
      return "Jueves";
    case DateTime.friday:
      return "Viernes";
    case DateTime.saturday:
      return "Sábado";
    default:
      return "Domingo";
  }
}

DateTime inicioSemanaActual([DateTime? fecha]) {
  final actual = fecha ?? DateTime.now();
  final soloFecha = DateTime(actual.year, actual.month, actual.day);
  return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
}

List<DateTime> obtenerDiasSemanaActual([DateTime? fecha]) {
  final inicio = inicioSemanaActual(fecha);
  return List<DateTime>.generate(
    7,
    (index) => inicio.add(Duration(days: index)),
  );
}

List<Map<String, dynamic>> copiarListaMapas(List<Map<String, dynamic>> items) {
  return items.map((item) => Map<String, dynamic>.from(item)).toList();
}

String fechaKeyPadded(DateTime fecha) {
  return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
}

double valorNumerico(dynamic valor) {
  if (valor is num) {
    return valor.toDouble();
  }

  return double.tryParse(valor?.toString() ?? "") ?? 0;
}

const double gramosPorOnza = 28.3495;

double pesoReferenciaSugerido(String nombre) {
  final texto = nombre.toLowerCase();

  if (texto.contains('huevo')) return 50;
  if (texto.contains('pan integral')) return 30;
  if (texto.contains('banano')) return 118;
  if (texto.contains('manzana')) return 182;
  if (texto.contains('arepa')) return 90;
  if (texto.contains('queso fresco')) return 30;
  if (texto.contains('yogurt')) return 170;
  if (texto.contains('avena')) return 234;
  if (texto.contains('pechuga de pollo')) return 120;
  if (texto.contains('arroz blanco')) return 158;
  if (texto.contains('carne magra')) return 120;
  if (texto.contains('pescado')) return 120;
  if (texto.contains('pasta')) return 140;
  if (texto.contains('papa')) return 173;
  if (texto.contains('frijoles')) return 172;
  if (texto.contains('ensalada')) return 100;
  if (texto.contains('atun')) return 100;
  if (texto.contains('sopa')) return 240;
  if (texto.contains('tortilla')) return 30;
  if (texto.contains('aguacate')) return 50;
  if (texto.contains('almendras')) return 28;
  if (texto.contains('batido')) return 330;
  if (texto.contains('galletas de arroz')) return 9;
  if (texto.contains('mantequilla de man')) return 16;
  if (texto.contains('fresas')) return 144;

  return 100;
}

double gramosPorUnidadSugeridos(String nombre, double gramosReferencia) {
  final texto = nombre.toLowerCase();

  if (texto.contains('almendras')) return 1.2;
  if (texto.contains('fresas')) return 12;
  if (texto.contains('huevo') ||
      texto.contains('banano') ||
      texto.contains('manzana') ||
      texto.contains('arepa') ||
      texto.contains('yogurt') ||
      texto.contains('aguacate') ||
      texto.contains('batido') ||
      texto.contains('tortilla') ||
      texto.contains('galletas de arroz') ||
      texto.contains('pan integral') ||
      texto.contains('queso fresco') ||
      texto.contains('mantequilla de man')) {
    return gramosReferencia;
  }

  return gramosReferencia;
}

double gramosReferenciaAlimento(Map<String, dynamic> alimento) {
  final gramos = valorNumerico(alimento['gramosReferencia']);
  if (gramos > 0) {
    return gramos;
  }

  return pesoReferenciaSugerido(alimento['nombre']?.toString() ?? '');
}

double gramosUnidadAlimento(Map<String, dynamic> alimento) {
  final gramos = valorNumerico(alimento['gramosPorUnidad']);
  if (gramos > 0) {
    return gramos;
  }

  return gramosPorUnidadSugeridos(
    alimento['nombre']?.toString() ?? '',
    gramosReferenciaAlimento(alimento),
  );
}

double gramosTotalesDesdePorcion({
  double? gramos,
  double? onzas,
  double? unidades,
  required double gramosReferencia,
  required double gramosPorUnidad,
}) {
  if ((gramos ?? 0) > 0) {
    return gramos!.toDouble();
  }

  if ((onzas ?? 0) > 0) {
    return onzas!.toDouble() * gramosPorOnza;
  }

  if ((unidades ?? 0) > 0) {
    return unidades!.toDouble() * gramosPorUnidad;
  }

  return gramosReferencia > 0 ? gramosReferencia : 100;
}

Map<String, dynamic> construirRegistroComidaConPorcion(
  Map<String, dynamic> alimento, {
  required String tipo,
  double? gramos,
  double? onzas,
  double? unidades,
  String? basketId,
}) {
  final nombre = alimento['nombre']?.toString() ?? '';
  final baseCalorias = valorNumerico(
    alimento['baseCalorias'] ?? alimento['calorias'] ?? alimento['cal'],
  );
  final baseProteina = valorNumerico(
    alimento['baseProteina'] ?? alimento['proteina'] ?? alimento['pro'],
  );
  final baseCarbs = valorNumerico(
    alimento['baseCarbs'] ?? alimento['carbs'] ?? alimento['car'],
  );
  final gramosReferencia = gramosReferenciaAlimento(alimento);
  final gramosPorUnidad = gramosUnidadAlimento(alimento);
  final gramosFinal = gramosTotalesDesdePorcion(
    gramos: gramos,
    onzas: onzas,
    unidades: unidades,
    gramosReferencia: gramosReferencia,
    gramosPorUnidad: gramosPorUnidad,
  ).clamp(1.0, 5000.0).toDouble();
  final factor = gramosReferencia <= 0 ? 1.0 : gramosFinal / gramosReferencia;

  return {
    'basketId': basketId ?? generarIdCanasta(),
    'nombre': nombre,
    'comidaTipo': normalizarTipoComida(tipo),
    'baseCalorias': baseCalorias,
    'baseProteina': baseProteina,
    'baseCarbs': baseCarbs,
    'gramosReferencia': gramosReferencia,
    'gramosPorUnidad': gramosPorUnidad,
    'gramos': gramosFinal,
    'onzas': gramosFinal / gramosPorOnza,
    'unidades': gramosPorUnidad <= 0 ? 1.0 : gramosFinal / gramosPorUnidad,
    'calorias': baseCalorias * factor,
    'proteina': baseProteina * factor,
    'carbs': baseCarbs * factor,
    'personalizado': alimento['personalizado'] == true,
  };
}

String resumenPorcionAlimento(Map item) {
  final gramos = valorNumerico(item['gramos']);
  final onzas = valorNumerico(item['onzas']);
  final unidades = valorNumerico(item['unidades']);

  return '${formatearMacro(gramos)} g • ${formatearMacro(onzas)} oz • ${formatearMacro(unidades)} un';
}

String normalizarTipoComida(String? tipo) {
  final valor = (tipo ?? "").trim().toLowerCase();
  switch (valor) {
    case "desayuno":
      return "Desayuno";
    case "almuerzo":
      return "Almuerzo";
    case "cena":
      return "Cena";
    case "snack":
    case "snacks":
      return "Snack";
    default:
      return "Snack";
  }
}

String claveAlimento(String nombre) {
  return nombre.trim().toLowerCase();
}

Map<String, dynamic> normalizarAlimentoCatalogo(Map<String, dynamic> item) {
  final tiposRaw = item['tipos'] as List?;
  final tipoIndividual = item['tipo']?.toString();
  final tipos = tiposRaw != null && tiposRaw.isNotEmpty
      ? tiposRaw
            .map((tipo) => normalizarTipoComida(tipo.toString()))
            .toSet()
            .toList()
      : [normalizarTipoComida(tipoIndividual)];

  final nombre = item['nombre']?.toString() ?? '';
  final calorias = valorNumerico(
    item['baseCalorias'] ?? item['calorias'] ?? item['cal'],
  );
  final proteina = valorNumerico(
    item['baseProteina'] ?? item['proteina'] ?? item['pro'],
  );
  final carbs = valorNumerico(
    item['baseCarbs'] ?? item['carbs'] ?? item['car'],
  );
  final gramosReferencia = valorNumerico(item['gramosReferencia']) > 0
      ? valorNumerico(item['gramosReferencia'])
      : pesoReferenciaSugerido(nombre);
  final gramosPorUnidad = valorNumerico(item['gramosPorUnidad']) > 0
      ? valorNumerico(item['gramosPorUnidad'])
      : gramosPorUnidadSugeridos(nombre, gramosReferencia);

  return {
    'nombre': nombre,
    'calorias': calorias,
    'proteina': proteina,
    'carbs': carbs,
    'baseCalorias': calorias,
    'baseProteina': proteina,
    'baseCarbs': carbs,
    'gramosReferencia': gramosReferencia,
    'gramosPorUnidad': gramosPorUnidad,
    'tipos': tipos,
    'personalizado': item['personalizado'] == true,
  };
}

List<Map<String, dynamic>> obtenerCatalogoAlimentos([String? tipo]) {
  final catalogoUnico = <String, Map<String, dynamic>>{};

  for (final fuente in [
    ...catalogoBaseAlimentos,
    ...alimentosPersonalizadosGlobal,
  ]) {
    final alimento = normalizarAlimentoCatalogo(fuente);
    final clave = claveAlimento(alimento['nombre'] as String);
    catalogoUnico[clave] = alimento;
  }

  final alimentos = catalogoUnico.values.toList();
  if (tipo == null) {
    alimentos.sort(
      (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String),
    );
    return alimentos;
  }

  final tipoNormalizado = normalizarTipoComida(tipo);
  final filtrados = alimentos.where((item) {
    final tipos = List<String>.from(item['tipos'] as List);
    return tipos.contains(tipoNormalizado);
  }).toList();

  filtrados.sort(
    (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String),
  );
  return filtrados;
}

Map<String, dynamic>? buscarAlimentoPorNombre(String nombre) {
  final clave = claveAlimento(nombre);
  for (final item in obtenerCatalogoAlimentos()) {
    if (claveAlimento(item['nombre'] as String) == clave) {
      return item;
    }
  }

  return null;
}

String generarIdCanasta() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

Map<String, dynamic> crearRegistroCanasta(
  Map<String, dynamic> alimento,
  String tipo,
) {
  return construirRegistroComidaConPorcion(alimento, tipo: tipo);
}

bool eliminarAlimentoDeCanasta(Map alimento) {
  final basketId = alimento['basketId']?.toString();
  final antes = canastaGlobal.length;

  if (basketId != null && basketId.isNotEmpty) {
    canastaGlobal.removeWhere(
      (item) => item['basketId']?.toString() == basketId,
    );
  } else {
    final nombre = alimento['nombre']?.toString() ?? '';
    final tipo = normalizarTipoComida(alimento['comidaTipo']?.toString());
    final calorias = valorNumerico(alimento['calorias']);
    canastaGlobal.removeWhere((item) {
      return item['nombre']?.toString() == nombre &&
          normalizarTipoComida(item['comidaTipo']?.toString()) == tipo &&
          valorNumerico(item['calorias']) == calorias;
    });
  }

  final cambio = canastaGlobal.length != antes;
  if (cambio) {
    recalcularTotalesAlimentos();
  }
  return cambio;
}

Future<String?> seleccionarTipoComida(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona una comida',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...tiposComidaPrincipales.map((tipo) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorParaTipoComida(tipo),
                    child: Icon(
                      iconoParaTipoComida(tipo),
                      color: Colors.black87,
                    ),
                  ),
                  title: Text(tipo),
                  onTap: () => Navigator.pop(context, tipo),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

Future<Map<String, dynamic>?> mostrarDialogoCrearAlimento(
  BuildContext context,
  String tipoActual,
) {
  final nombreController = TextEditingController();
  final caloriasController = TextEditingController();
  final proteinaController = TextEditingController();
  final carbsController = TextEditingController();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Agregar alimento a ${normalizarTipoComida(tipoActual)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: caloriasController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorías'),
              ),
              TextField(
                controller: proteinaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Proteína (g)'),
              ),
              TextField(
                controller: carbsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Carbohidratos (g)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) {
                return;
              }

              Navigator.pop(context, {
                'nombre': nombre,
                'calorias': valorNumerico(caloriasController.text),
                'proteina': valorNumerico(proteinaController.text),
                'carbs': valorNumerico(carbsController.text),
                'tipos': [normalizarTipoComida(tipoActual)],
                'personalizado': true,
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  ).whenComplete(() {
    nombreController.dispose();
    caloriasController.dispose();
    proteinaController.dispose();
    carbsController.dispose();
  });
}

List<Map<String, dynamic>> obtenerAlimentosRegistradosPorTipo(String tipo) {
  final tipoNormalizado = normalizarTipoComida(tipo);
  return canastaGlobal
      .where((item) {
        return normalizarTipoComida(item['comidaTipo']?.toString()) ==
            tipoNormalizado;
      })
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

void recalcularTotalesAlimentos() {
  caloriasConsumidas = canastaGlobal.fold<double>(
    0,
    (total, item) => total + valorNumerico(item['calorias']),
  );
  proteinaConsumida = canastaGlobal.fold<double>(
    0,
    (total, item) => total + valorNumerico(item['proteina']),
  );
  carbsConsumidos = canastaGlobal.fold<double>(
    0,
    (total, item) => total + valorNumerico(item['carbs']),
  );
}

void normalizarCanastaGlobal() {
  canastaGlobal = canastaGlobal.map((item) {
    final normalizado = Map<String, dynamic>.from(item);
    normalizado['comidaTipo'] = normalizarTipoComida(
      normalizado['comidaTipo']?.toString() ?? normalizado['tipo']?.toString(),
    );

    final alimentoReferencia = buscarAlimentoPorNombre(
      normalizado['nombre']?.toString() ?? '',
    );

    final baseCalorias = valorNumerico(
      normalizado['baseCalorias'] ??
          alimentoReferencia?['baseCalorias'] ??
          alimentoReferencia?['calorias'] ??
          normalizado['calorias'] ??
          normalizado['cal'],
    );
    final baseProteina = valorNumerico(
      normalizado['baseProteina'] ??
          alimentoReferencia?['baseProteina'] ??
          alimentoReferencia?['proteina'] ??
          normalizado['proteina'] ??
          normalizado['pro'],
    );
    final baseCarbs = valorNumerico(
      normalizado['baseCarbs'] ??
          alimentoReferencia?['baseCarbs'] ??
          alimentoReferencia?['carbs'] ??
          normalizado['carbs'] ??
          normalizado['car'],
    );
    final gramosReferencia = valorNumerico(
      normalizado['gramosReferencia'] ??
          alimentoReferencia?['gramosReferencia'],
    );
    final gramosBase = gramosReferencia > 0
        ? gramosReferencia
        : pesoReferenciaSugerido(normalizado['nombre']?.toString() ?? '');
    final gramosUnidad = valorNumerico(
      normalizado['gramosPorUnidad'] ?? alimentoReferencia?['gramosPorUnidad'],
    );
    final gramosPorUnidad = gramosUnidad > 0
        ? gramosUnidad
        : gramosPorUnidadSugeridos(
            normalizado['nombre']?.toString() ?? '',
            gramosBase,
          );
    final gramos = gramosTotalesDesdePorcion(
      gramos: valorNumerico(normalizado['gramos']) > 0
          ? valorNumerico(normalizado['gramos'])
          : null,
      onzas: valorNumerico(normalizado['onzas']) > 0
          ? valorNumerico(normalizado['onzas'])
          : null,
      unidades: valorNumerico(normalizado['unidades']) > 0
          ? valorNumerico(normalizado['unidades'])
          : null,
      gramosReferencia: gramosBase,
      gramosPorUnidad: gramosPorUnidad,
    ).clamp(1.0, 5000.0).toDouble();
    final factor = gramosBase <= 0 ? 1.0 : gramos / gramosBase;

    normalizado['baseCalorias'] = baseCalorias;
    normalizado['baseProteina'] = baseProteina;
    normalizado['baseCarbs'] = baseCarbs;
    normalizado['gramosReferencia'] = gramosBase;
    normalizado['gramosPorUnidad'] = gramosPorUnidad;
    normalizado['gramos'] = gramos;
    normalizado['onzas'] = gramos / gramosPorOnza;
    normalizado['unidades'] = gramosPorUnidad <= 0
        ? 1.0
        : gramos / gramosPorUnidad;
    normalizado['calorias'] = baseCalorias * factor;
    normalizado['proteina'] = baseProteina * factor;
    normalizado['carbs'] = baseCarbs * factor;

    normalizado['basketId'] =
        normalizado['basketId']?.toString() ?? generarIdCanasta();

    return normalizado;
  }).toList();

  recalcularTotalesAlimentos();
}

double calcularCalorias(String tipo) {
  return obtenerAlimentosRegistradosPorTipo(
    tipo,
  ).fold(0, (total, item) => total + valorNumerico(item["calorias"]));
}

double calcularProteina(String tipo) {
  return obtenerAlimentosRegistradosPorTipo(
    tipo,
  ).fold(0, (total, item) => total + valorNumerico(item["proteina"]));
}

double calcularCarbs(String tipo) {
  return obtenerAlimentosRegistradosPorTipo(
    tipo,
  ).fold(0, (total, item) => total + valorNumerico(item["carbs"]));
}

String formatearMacro(dynamic valor) {
  final numero = (valor as num?)?.toDouble() ?? valorNumerico(valor);
  if (numero == numero.roundToDouble()) {
    return numero.toStringAsFixed(0);
  }

  return numero.toStringAsFixed(1);
}

String resumenAlimento(Map item) {
  return "${formatearMacro(item["calorias"])} kcal • P: ${formatearMacro(item["proteina"])}g • C: ${formatearMacro(item["carbs"])}g";
}

Future<Map<String, dynamic>?> mostrarDialogoPorcionAlimento(
  BuildContext context, {
  required Map<String, dynamic> alimento,
  required String tipo,
  bool editando = false,
}) {
  final alimentoBase = normalizarAlimentoCatalogo(alimento);
  final caloriasBase = valorNumerico(alimentoBase['baseCalorias']);
  final proteinaBase = valorNumerico(alimentoBase['baseProteina']);
  final carbsBase = valorNumerico(alimentoBase['baseCarbs']);
  final gramosReferencia = gramosReferenciaAlimento(alimentoBase);
  final gramosPorUnidad = gramosUnidadAlimento(alimentoBase);
  final gramosInicial = valorNumerico(alimento['gramos']) > 0
      ? valorNumerico(alimento['gramos'])
      : gramosReferencia;
  final gramosController = TextEditingController(
    text: formatearMacro(gramosInicial),
  );
  final onzasController = TextEditingController(
    text: formatearMacro(gramosInicial / gramosPorOnza),
  );
  final unidadesController = TextEditingController(
    text: formatearMacro(
      gramosPorUnidad <= 0 ? 1 : gramosInicial / gramosPorUnidad,
    ),
  );
  var sincronizando = false;

  double leerControl(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
  }

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          var gramosActual = gramosInicial;

          void sincronizarDesdeGramos(double gramos) {
            final gramosNormalizados = gramos.clamp(1.0, 5000.0).toDouble();
            sincronizando = true;
            gramosController.text = formatearMacro(gramosNormalizados);
            onzasController.text = formatearMacro(
              gramosNormalizados / gramosPorOnza,
            );
            unidadesController.text = formatearMacro(
              gramosPorUnidad <= 0 ? 1 : gramosNormalizados / gramosPorUnidad,
            );
            sincronizando = false;
            setModalState(() {
              gramosActual = gramosNormalizados;
            });
          }

          final gramosCalculados = leerControl(gramosController) > 0
              ? leerControl(gramosController)
              : gramosActual;
          gramosActual = gramosCalculados.clamp(1.0, 5000.0).toDouble();
          final factor = gramosReferencia <= 0
              ? 1.0
              : gramosActual / gramosReferencia;
          final calorias = caloriasBase * factor;
          final proteina = proteinaBase * factor;
          final carbs = carbsBase * factor;

          Widget controlCantidad({
            required String titulo,
            required String unidad,
            required TextEditingController controller,
            required VoidCallback onLess,
            required VoidCallback onMore,
            required ValueChanged<String> onChanged,
          }) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _dialogStepperButton(icon: Icons.remove, onTap: onLess),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: onChanged,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            suffixText: unidad,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _dialogStepperButton(icon: Icons.add, onTap: onMore),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget macroPreview(String label, String value, Color color) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF9FDFF), Color(0xFFE7F4FF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 54,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F6CBD), Color(0xFF69B7FF)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  iconoParaAlimento(
                                    alimentoBase['nombre'].toString(),
                                  ),
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alimentoBase['nombre'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ajusta la porción antes de agregarla a ${normalizarTipoComida(tipo)}.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Referencia: ${formatearMacro(gramosReferencia)} g por porción base',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sugerencia in [
                          gramosReferencia,
                          gramosReferencia * 1.5,
                          gramosReferencia * 2,
                        ])
                          ActionChip(
                            label: Text('${formatearMacro(sugerencia)} g'),
                            onPressed: () => sincronizarDesdeGramos(sugerencia),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    controlCantidad(
                      titulo: 'Gramos',
                      unidad: 'g',
                      controller: gramosController,
                      onLess: () => sincronizarDesdeGramos(gramosActual - 10),
                      onMore: () => sincronizarDesdeGramos(gramosActual + 10),
                      onChanged: (_) {
                        if (sincronizando) return;
                        sincronizarDesdeGramos(leerControl(gramosController));
                      },
                    ),
                    const SizedBox(height: 12),
                    controlCantidad(
                      titulo: 'Onzas',
                      unidad: 'oz',
                      controller: onzasController,
                      onLess: () =>
                          sincronizarDesdeGramos(gramosActual - gramosPorOnza),
                      onMore: () =>
                          sincronizarDesdeGramos(gramosActual + gramosPorOnza),
                      onChanged: (_) {
                        if (sincronizando) return;
                        sincronizarDesdeGramos(
                          leerControl(onzasController) * gramosPorOnza,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    controlCantidad(
                      titulo: 'Unidades',
                      unidad: 'un',
                      controller: unidadesController,
                      onLess: () => sincronizarDesdeGramos(
                        gramosActual - gramosPorUnidad,
                      ),
                      onMore: () => sincronizarDesdeGramos(
                        gramosActual + gramosPorUnidad,
                      ),
                      onChanged: (_) {
                        if (sincronizando) return;
                        sincronizarDesdeGramos(
                          leerControl(unidadesController) * gramosPorUnidad,
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        macroPreview(
                          'Calorías',
                          '${formatearMacro(calorias)} kcal',
                          const Color(0xFFFFF2DC),
                        ),
                        const SizedBox(width: 10),
                        macroPreview(
                          'Proteína',
                          '${formatearMacro(proteina)} g',
                          const Color(0xFFDFF4E7),
                        ),
                        const SizedBox(width: 10),
                        macroPreview(
                          'Carbos',
                          '${formatearMacro(carbs)} g',
                          const Color(0xFFFFE6E0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                construirRegistroComidaConPorcion(
                                  alimentoBase,
                                  tipo: tipo,
                                  gramos: gramosActual,
                                  basketId: alimento['basketId']?.toString(),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F6CBD),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: Icon(editando ? Icons.save : Icons.add),
                            label: Text(
                              editando ? 'Guardar porción' : 'Agregar comida',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    gramosController.dispose();
    onzasController.dispose();
    unidadesController.dispose();
  });
}

Widget _dialogStepperButton({
  required IconData icon,
  required VoidCallback onTap,
}) {
  return Material(
    color: const Color(0xFF0F6CBD),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

IconData iconoParaTipoComida(String tipo) {
  switch (normalizarTipoComida(tipo)) {
    case 'Desayuno':
      return Icons.breakfast_dining;
    case 'Almuerzo':
      return Icons.lunch_dining;
    case 'Cena':
      return Icons.dinner_dining;
    default:
      return Icons.icecream;
  }
}

Color colorParaTipoComida(String tipo) {
  switch (normalizarTipoComida(tipo)) {
    case 'Desayuno':
      return const Color(0xFFFFF1C9);
    case 'Almuerzo':
      return const Color(0xFFFFE1D6);
    case 'Cena':
      return const Color(0xFFDDE8FF);
    default:
      return const Color(0xFFD7F6E8);
  }
}

IconData iconoParaAlimento(String nombre) {
  final texto = nombre.toLowerCase();
  if (texto.contains('huevo')) return Icons.egg_alt;
  if (texto.contains('pan') ||
      texto.contains('arepa') ||
      texto.contains('tortilla')) {
    return Icons.bakery_dining;
  }
  if (texto.contains('avena') ||
      texto.contains('cereal') ||
      texto.contains('granola')) {
    return Icons.breakfast_dining;
  }
  if (texto.contains('yogurt') ||
      texto.contains('queso') ||
      texto.contains('leche')) {
    return Icons.local_cafe;
  }
  if (texto.contains('manzana') ||
      texto.contains('banano') ||
      texto.contains('fresa') ||
      texto.contains('fruta')) {
    return Icons.apple;
  }
  if (texto.contains('pollo') ||
      texto.contains('carne') ||
      texto.contains('atún') ||
      texto.contains('pescado')) {
    return Icons.set_meal;
  }
  if (texto.contains('arroz') ||
      texto.contains('pasta') ||
      texto.contains('frijoles') ||
      texto.contains('papa')) {
    return Icons.rice_bowl;
  }
  if (texto.contains('ensalada') ||
      texto.contains('verdura') ||
      texto.contains('aguacate')) {
    return Icons.eco;
  }
  if (texto.contains('almendra') || texto.contains('mantequilla')) {
    return Icons.spa;
  }
  if (texto.contains('batido')) return Icons.local_drink;
  return Icons.restaurant_menu;
}

IconData iconoParaCategoriaEjercicio(String tipo) {
  switch (tipo) {
    case 'Brazo':
      return Icons.fitness_center;
    case 'Pierna':
      return Icons.directions_run;
    case 'Abdomen':
      return Icons.self_improvement;
    case 'Glúteo':
      return Icons.accessibility_new;
    case 'Bajar peso':
      return Icons.local_fire_department;
    case 'Tonificar':
      return Icons.sports_gymnastics;
    default:
      return Icons.sports;
  }
}

IconData iconoParaEjercicio(Map<String, dynamic> ejercicio) {
  final nombre = (ejercicio['nombre']?.toString() ?? '').toLowerCase();
  final tipo = ejercicio['tipo']?.toString() ?? '';

  if (nombre.contains('correr') || nombre.contains('caminata')) {
    return Icons.directions_run;
  }
  if (nombre.contains('bicicleta')) return Icons.pedal_bike;
  if (nombre.contains('natación')) return Icons.pool;
  if (nombre.contains('boxeo')) return Icons.sports_mma;
  if (nombre.contains('yoga') || nombre.contains('pilates')) {
    return Icons.self_improvement;
  }
  if (nombre.contains('plancha')) return Icons.horizontal_rule;
  if (nombre.contains('sentadilla') || nombre.contains('zancada')) {
    return Icons.accessibility_new;
  }
  if (nombre.contains('peso muerto')) return Icons.fitness_center;
  if (nombre.contains('burpees') || nombre.contains('jumping')) {
    return Icons.bolt;
  }

  return iconoParaCategoriaEjercicio(tipo);
}

List<Color> coloresCategoriaEjercicio(String tipo) {
  switch (tipo) {
    case 'Brazo':
      return const [Color(0xFF2563EB), Color(0xFF7DD3FC)];
    case 'Pierna':
      return const [Color(0xFFF97316), Color(0xFFFDBA74)];
    case 'Abdomen':
      return const [Color(0xFFEAB308), Color(0xFFFEF08A)];
    case 'Glúteo':
      return const [Color(0xFF16A34A), Color(0xFF86EFAC)];
    case 'Bajar peso':
      return const [Color(0xFFDC2626), Color(0xFFFCA5A5)];
    case 'Tonificar':
      return const [Color(0xFF7C3AED), Color(0xFFC4B5FD)];
    default:
      return const [Color(0xFF334155), Color(0xFFCBD5E1)];
  }
}

List<String> musculosEjercicio(Map<String, dynamic> ejercicio) {
  final tipo = ejercicio['tipo']?.toString() ?? '';
  final nombre = (ejercicio['nombre']?.toString() ?? '').toLowerCase();

  if (nombre.contains('sentadilla')) {
    return ['Cuádriceps', 'Glúteos', 'Core'];
  }
  if (nombre.contains('plancha')) {
    return ['Core', 'Hombros', 'Abdomen'];
  }
  if (nombre.contains('peso muerto')) {
    return ['Glúteos', 'Femoral', 'Espalda baja'];
  }
  if (nombre.contains('flexiones')) {
    return ['Pecho', 'Tríceps', 'Hombros'];
  }
  if (nombre.contains('hip thrust') || nombre.contains('glúteo')) {
    return ['Glúteos', 'Femoral', 'Core'];
  }

  switch (tipo) {
    case 'Brazo':
      return ['Bíceps', 'Tríceps', 'Hombros'];
    case 'Pierna':
      return ['Cuádriceps', 'Femoral', 'Glúteos'];
    case 'Abdomen':
      return ['Abdomen', 'Core', 'Oblicuos'];
    case 'Glúteo':
      return ['Glúteos', 'Femoral', 'Cadera'];
    case 'Bajar peso':
      return ['Cardio', 'Core', 'Piernas'];
    case 'Tonificar':
      return ['Cuerpo completo', 'Core', 'Estabilidad'];
    default:
      return ['Cuerpo completo'];
  }
}

String descripcionEjercicioVisual(Map<String, dynamic> ejercicio) {
  final tipo = ejercicio['tipo']?.toString() ?? '';
  final nombre = (ejercicio['nombre']?.toString() ?? '').toLowerCase();

  if (nombre.contains('curl')) {
    return 'Movimiento de fuerza para flexionar el codo y activar sobre todo bíceps y antebrazo.';
  }
  if (nombre.contains('flexiones')) {
    return 'Ejercicio clásico de empuje que fortalece pecho, tríceps y hombros usando tu propio peso corporal.';
  }
  if (nombre.contains('sentadilla')) {
    return 'Movimiento base de pierna y glúteo donde bajas la cadera manteniendo el pecho firme y el core activo.';
  }
  if (nombre.contains('plancha')) {
    return 'Trabajo isométrico para estabilizar abdomen, hombros y zona media sin perder alineación corporal.';
  }
  if (nombre.contains('hip thrust') || nombre.contains('puente')) {
    return 'Empuje de cadera enfocado en activar glúteos con control y buena extensión al subir.';
  }
  if (nombre.contains('burpees') || nombre.contains('jumping')) {
    return 'Ejercicio explosivo y cardiovascular para elevar pulsaciones y quemar calorías rápido.';
  }

  switch (tipo) {
    case 'Brazo':
      return 'Ejercicio de tren superior para ganar fuerza y control en brazos y hombros.';
    case 'Pierna':
      return 'Ejercicio de tren inferior pensado para fuerza, potencia o resistencia de piernas.';
    case 'Abdomen':
      return 'Movimiento para fortalecer el core, mejorar estabilidad y controlar mejor la postura.';
    case 'Glúteo':
      return 'Ejercicio orientado a activar glúteos y mejorar fuerza de cadera y pierna.';
    case 'Bajar peso':
      return 'Movimiento dinámico de cardio para subir el gasto calórico y mejorar la resistencia.';
    case 'Tonificar':
      return 'Trabajo funcional para marcar musculatura, controlar el movimiento y mejorar estabilidad.';
    default:
      return 'Ejercicio guiado para trabajar tu cuerpo de forma segura y progresiva.';
  }
}

List<String> pasosEjercicioVisual(Map<String, dynamic> ejercicio) {
  final nombre = (ejercicio['nombre']?.toString() ?? '').toLowerCase();
  final tipo = ejercicio['tipo']?.toString() ?? '';

  if (nombre.contains('flexiones')) {
    return [
      'Coloca manos a la altura del pecho y el cuerpo en línea recta.',
      'Baja el pecho con control sin hundir la cadera.',
      'Empuja el suelo hasta volver arriba y repite.',
    ];
  }
  if (nombre.contains('sentadilla')) {
    return [
      'Abre los pies al ancho de hombros y mantén el pecho alto.',
      'Baja la cadera como si fueras a sentarte.',
      'Sube empujando con talones y aprieta glúteos arriba.',
    ];
  }
  if (nombre.contains('plancha')) {
    return [
      'Apoya antebrazos o manos y alinea hombros con codos.',
      'Activa abdomen y glúteos sin levantar ni hundir la cadera.',
      'Mantén la posición respirando controlado.',
    ];
  }
  if (nombre.contains('hip thrust') || nombre.contains('puente')) {
    return [
      'Apoya espalda alta y deja pies firmes en el suelo.',
      'Empuja la cadera hacia arriba con fuerza en glúteos.',
      'Baja lento sin perder tensión y repite.',
    ];
  }
  if (nombre.contains('curl')) {
    return [
      'Sujeta el peso con codos pegados al cuerpo.',
      'Flexiona el codo hasta subir la carga con control.',
      'Baja lento sin balancear el torso.',
    ];
  }

  switch (tipo) {
    case 'Brazo':
      return [
        'Ajusta postura y activa abdomen antes de empezar.',
        'Haz el movimiento controlando hombros y codos.',
        'Regresa lento para mantener tensión muscular.',
      ];
    case 'Pierna':
      return [
        'Coloca los pies firmes y reparte el peso estable.',
        'Baja con control manteniendo rodillas alineadas.',
        'Sube empujando fuerte sin perder postura.',
      ];
    case 'Abdomen':
      return [
        'Activa el core antes de iniciar el ejercicio.',
        'Controla el movimiento sin jalar el cuello.',
        'Respira y mantén la tensión en la zona media.',
      ];
    case 'Glúteo':
      return [
        'Busca estabilidad en cadera y pies.',
        'Haz el empuje concentrando el trabajo en glúteos.',
        'Baja lento para no perder activación.',
      ];
    case 'Bajar peso':
      return [
        'Empieza con ritmo cómodo y postura firme.',
        'Aumenta intensidad sin perder técnica.',
        'Respira constante y mantén continuidad.',
      ];
    default:
      return [
        'Prepara la postura inicial correctamente.',
        'Ejecuta el movimiento de forma controlada.',
        'Vuelve a la posición inicial y repite.',
      ];
  }
}

String tipEjercicioVisual(Map<String, dynamic> ejercicio) {
  final tipo = ejercicio['tipo']?.toString() ?? '';
  final nombre = (ejercicio['nombre']?.toString() ?? '').toLowerCase();

  if (nombre.contains('plancha')) {
    return 'Si sientes la espalda baja, aprieta abdomen y glúteos antes de seguir.';
  }
  if (nombre.contains('sentadilla')) {
    return 'Las rodillas deben seguir la dirección de los pies, no colapsar hacia adentro.';
  }
  if (nombre.contains('flexiones')) {
    return 'Mantén cuello neutro y evita que la cadera se hunda al bajar.';
  }

  switch (tipo) {
    case 'Bajar peso':
      return 'Empieza con menos intensidad si no conoces el movimiento y luego acelera progresivamente.';
    case 'Tonificar':
      return 'Prioriza técnica y control antes que velocidad o carga.';
    default:
      return 'Haz primero una serie suave para aprender el recorrido antes de exigir más al cuerpo.';
  }
}

String etiquetaVisualEjercicio(Map<String, dynamic> ejercicio) {
  final tipo = ejercicio['tipo']?.toString() ?? '';
  switch (tipo) {
    case 'Brazo':
      return 'Empuje y control';
    case 'Pierna':
      return 'Potencia inferior';
    case 'Abdomen':
      return 'Core activo';
    case 'Glúteo':
      return 'Cadera fuerte';
    case 'Bajar peso':
      return 'Cardio intenso';
    case 'Tonificar':
      return 'Resistencia funcional';
    default:
      return 'Movimiento guiado';
  }
}

String poseVisualEjercicio(Map<String, dynamic> ejercicio) {
  final tipo = ejercicio['tipo']?.toString() ?? '';
  final nombre = (ejercicio['nombre']?.toString() ?? '').toLowerCase();

  if (nombre.contains('flexiones')) return 'pushup';
  if (nombre.contains('plancha')) return 'plank';
  if (nombre.contains('sentadilla')) return 'squat';
  if (nombre.contains('hip thrust') || nombre.contains('puente')) {
    return 'bridge';
  }
  if (nombre.contains('curl')) return 'curl';
  if (nombre.contains('correr') ||
      nombre.contains('caminata') ||
      nombre.contains('jumping') ||
      nombre.contains('burpees')) {
    return 'run';
  }

  switch (tipo) {
    case 'Pierna':
      return 'squat';
    case 'Abdomen':
      return 'plank';
    case 'Brazo':
      return 'curl';
    case 'Bajar peso':
      return 'run';
    default:
      return 'athlete';
  }
}

Widget ilustracionEjercicioVisual(
  Map<String, dynamic> ejercicio,
  List<Color> colores,
) {
  return Container(
    width: 116,
    height: 150,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ExercisePosePainter(
              pose: poseVisualEjercicio(ejercicio),
              primaryColor: Colors.white,
              accentColor: colores.last,
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Vista del movimiento',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> mostrarDetalleEjercicio(
  BuildContext context,
  Map<String, dynamic> ejercicio, {
  String? textoAccion,
  VoidCallback? onAccion,
}) {
  final tipo = ejercicio['tipo']?.toString() ?? '';
  final colores = coloresCategoriaEjercicio(tipo);
  final musculos = musculosEjercicio(ejercicio);
  final pasos = pasosEjercicioVisual(ejercicio);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FBFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colores),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colores.first.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    etiquetaVisualEjercicio(ejercicio),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  ejercicio['nombre'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${ejercicio['cal']} kcal • ${detalleEjercicio(ejercicio)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ilustracionEjercicioVisual(ejercicio, colores),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cómo se hace',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  descripcionEjercicioVisual(ejercicio),
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: musculos.map((musculo) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        musculo,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                ...pasos.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final paso = entry.value;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colores.first,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            paso,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tipEjercicioVisual(ejercicio),
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAccion != null && textoAccion != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onAccion();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colores.first,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(textoAccion),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

String? obtenerDiaRutinaActual([DateTime? fecha]) {
  switch ((fecha ?? DateTime.now()).weekday) {
    case DateTime.monday:
      return "Lunes";
    case DateTime.tuesday:
      return "Martes";
    case DateTime.wednesday:
      return "Miércoles";
    case DateTime.thursday:
      return "Jueves";
    case DateTime.friday:
      return "Viernes";
    case DateTime.saturday:
      return "Sábado";
    default:
      return null;
  }
}

List<Map<String, dynamic>> obtenerRutinaDelDiaActual([DateTime? fecha]) {
  final diaActual = obtenerDiaRutinaActual(fecha);
  if (diaActual == null) {
    return <Map<String, dynamic>>[];
  }

  return rutinaGlobal[diaActual] ?? <Map<String, dynamic>>[];
}

int obtenerMinutosRutina(Map<String, dynamic> ejercicio) {
  final tiempo = ejercicio["tiempo"]?.toString() ?? "0";
  final match = RegExp(r'\d+').firstMatch(tiempo);
  return int.tryParse(match?.group(0) ?? "0") ?? 0;
}

bool ejercicioUsaRepeticiones(Map<String, dynamic> ejercicio) {
  const tiposPorRepeticiones = {"Brazo", "Pierna", "Abdomen", "Glúteo"};
  return tiposPorRepeticiones.contains(ejercicio["tipo"]?.toString() ?? "");
}

String inferirSeriesEjercicio(Map<String, dynamic> ejercicio) {
  final tipo = ejercicio["tipo"]?.toString() ?? "";
  if (tipo == "Pierna" || tipo == "Glúteo") {
    return "4 series";
  }

  return "3 series";
}

String inferirRepeticionesEjercicio(Map<String, dynamic> ejercicio) {
  final minutos = obtenerMinutosRutina(ejercicio);
  if (minutos >= 12) {
    return "12 repeticiones";
  }
  if (minutos <= 8) {
    return "10 repeticiones";
  }

  return "15 repeticiones";
}

String detalleEjercicio(Map<String, dynamic> ejercicio) {
  final tiempo = ejercicio["tiempo"]?.toString();
  if (ejercicioUsaRepeticiones(ejercicio)) {
    final series =
        ejercicio["series"]?.toString() ?? inferirSeriesEjercicio(ejercicio);
    final repeticiones =
        ejercicio["repeticiones"]?.toString() ??
        inferirRepeticionesEjercicio(ejercicio);

    if (tiempo != null && tiempo.isNotEmpty) {
      return "$series x $repeticiones • $tiempo";
    }

    return "$series x $repeticiones";
  }

  return tiempo == null || tiempo.isEmpty ? "Sin duración" : tiempo;
}

double calcularCaloriasRutinaActual([DateTime? fecha]) {
  return obtenerRutinaDelDiaActual(fecha).fold<double>(
    0,
    (total, ejercicio) => total + ((ejercicio["cal"] ?? 0) as num).toDouble(),
  );
}

enum ChatIntent { none, rutina, comida }

enum ChatQuestionStep {
  none,
  rutinaEdad,
  rutinaPeso,
  rutinaAltura,
  rutinaSexo,
  rutinaObjetivo,
  comidaObjetivo,
  comidaTipo,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> quickReplies;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.quickReplies = const [],
  });

  Map<String, dynamic> toJson() {
    return {'text': text, 'isUser': isUser, 'quickReplies': quickReplies};
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      quickReplies: List<String>.from(
        json['quickReplies'] as List? ?? const [],
      ),
    );
  }
}

class ChatRoutineProfile {
  int? edad;
  double? pesoLb;
  double? alturaCm;
  String? sexo;
  String? objetivo;

  Map<String, dynamic> toJson() {
    return {
      'edad': edad,
      'pesoLb': pesoLb,
      'alturaCm': alturaCm,
      'sexo': sexo,
      'objetivo': objetivo,
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    edad = json['edad'] as int?;
    pesoLb = valorNumerico(json['pesoLb']);
    alturaCm = valorNumerico(json['alturaCm']);
    sexo = json['sexo']?.toString();
    objetivo = json['objetivo']?.toString();

    if (pesoLb == 0) pesoLb = null;
    if (alturaCm == 0) alturaCm = null;
    if (sexo?.isEmpty ?? true) sexo = null;
    if (objetivo?.isEmpty ?? true) objetivo = null;
  }

  void reset() {
    edad = null;
    pesoLb = null;
    alturaCm = null;
    sexo = null;
    objetivo = null;
  }
}

const String aiApiKey = String.fromEnvironment('AI_API_KEY');
const String aiApiUrl = String.fromEnvironment(
  'AI_API_URL',
  defaultValue: 'https://api.openai.com/v1/chat/completions',
);
const String aiModel = String.fromEnvironment(
  'AI_MODEL',
  defaultValue: 'gpt-4o-mini',
);

bool iaExternaDisponible() {
  return aiApiKey.trim().isNotEmpty;
}

Future<String?> consultarIAExterna({
  required String systemPrompt,
  required List<Map<String, String>> messages,
}) async {
  if (!iaExternaDisponible()) {
    return null;
  }

  try {
    final response = await http
        .post(
          Uri.parse(aiApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $aiApiKey',
          },
          body: jsonEncode({
            'model': aiModel,
            'temperature': 0.7,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              ...messages.map(
                (message) => {
                  'role': message['role'] ?? 'user',
                  'content': message['content'] ?? '',
                },
              ),
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return null;
    }

    final message = choices.first['message'];
    if (message is! Map) {
      return null;
    }

    final content = message['content'];
    if (content is String) {
      return content.trim();
    }

    if (content is List) {
      final texto = content
          .whereType<Map>()
          .map((item) => item['text']?.toString() ?? '')
          .join();
      return texto.trim().isEmpty ? null : texto.trim();
    }

    return null;
  } catch (_) {
    return null;
  }
}

List<Map<String, String>> construirMensajesApiDesdeChat(
  List<ChatMessage> messages,
) {
  final recientes = messages.length > 8
      ? messages.sublist(messages.length - 8)
      : messages;

  return recientes
      .map(
        (message) => {
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.text,
        },
      )
      .toList();
}

Future<String?> generarRespuestaLibreIA({required List<ChatMessage> messages}) {
  return consultarIAExterna(
    systemPrompt:
        'Eres un coach virtual en espanol para una app fitness. Responde de forma clara, breve y practica sobre rutinas, nutricion, comidas y objetivos corporales. Si faltan datos importantes para dar una rutina exacta, pide esos datos de forma concisa. No des consejos medicos ni diagnosticos.',
    messages: construirMensajesApiDesdeChat(messages),
  );
}

Future<String?> generarRespuestaRutinaIAExterna(ChatRoutineProfile profile) {
  final prompt =
      '''
    Eres un entrenador virtual para una app fitness. Responde en espanol.
    Usa este perfil para recomendar una rutina breve, concreta y accionable:
    - Edad: ${profile.edad} anos
    - Peso: ${formatearMacro(profile.pesoLb)} lb
    - Altura: ${formatearMacro(profile.alturaCm)} cm
    - Sexo: ${profile.sexo}
    - Objetivo: ${profile.objetivo}

    Reglas:
    - Recomienda una rutina segura y concreta.
    - Da 4 ejercicios maximo.
    - Para cada ejercicio, indica series/repeticiones o tiempo.
    - Cierra con una recomendacion corta de descanso.
    - No hagas diagnosticos medicos.
    ''';

  return consultarIAExterna(
    systemPrompt:
        'Eres un coach fitness experto en rutinas personalizadas y explicas con claridad.',
    messages: [
      {'role': 'user', 'content': prompt},
    ],
  );
}

Future<String?> generarRespuestaComidaIAExterna({
  required String objetivo,
  required String tipoComida,
}) {
  final alimentos = recomendarComidasIA(
    objetivo: objetivo,
    tipoComida: tipoComida,
  );
  final lista = alimentos
      .map((item) {
        return '- ${item['nombre']}: ${formatearMacro(item['calorias'])} kcal, ${formatearMacro(item['proteina'])} g proteina, ${formatearMacro(item['carbs'])} g carbs';
      })
      .join('\n');

  final prompt =
      '''
    Recomiendame comida en espanol para este caso:
    - Objetivo: $objetivo
    - Tipo de comida: $tipoComida

    Puedes usar estas opciones reales de la app:
    $lista

    Reglas:
    - Elige hasta 4 opciones.
    - Explica por que sirven para ese objetivo.
    - Mantente breve y practica.
    ''';

  return consultarIAExterna(
    systemPrompt:
        'Eres un nutricionista virtual para una app fitness y recomiendas opciones de comida practicas.',
    messages: [
      {'role': 'user', 'content': prompt},
    ],
  );
}

const Map<String, List<Map<String, dynamic>>> sugerenciasRutinaIA = {
  'Bajar peso': [
    {'nombre': 'HIIT', 'cal': 250, 'tiempo': '20 min'},
    {'nombre': 'Caminata rápida', 'cal': 120, 'tiempo': '20 min'},
    {'nombre': 'Jumping jacks', 'cal': 150, 'tiempo': '10 min'},
    {'nombre': 'Burpees', 'cal': 180, 'tiempo': '10 min'},
  ],
  'Tonificar': [
    {'nombre': 'Circuito full body', 'cal': 180, 'tiempo': '20 min'},
    {'nombre': 'Pesas ligeras', 'cal': 120, 'tiempo': '15 min'},
    {'nombre': 'Pilates', 'cal': 140, 'tiempo': '20 min'},
    {'nombre': 'Resistencia con bandas', 'cal': 130, 'tiempo': '15 min'},
  ],
  'Pierna': [
    {'nombre': 'Sentadillas', 'cal': 120, 'tiempo': '12 min'},
    {'nombre': 'Zancadas', 'cal': 110, 'tiempo': '12 min'},
    {'nombre': 'Peso muerto', 'cal': 140, 'tiempo': '12 min'},
    {'nombre': 'Step ups', 'cal': 110, 'tiempo': '12 min'},
  ],
  'Abdomen': [
    {'nombre': 'Plancha', 'cal': 70, 'tiempo': '8 min'},
    {'nombre': 'Crunch', 'cal': 80, 'tiempo': '10 min'},
    {'nombre': 'Russian twist', 'cal': 85, 'tiempo': '10 min'},
    {'nombre': 'Mountain climbers', 'cal': 120, 'tiempo': '10 min'},
  ],
  'Glúteo': [
    {'nombre': 'Hip thrust', 'cal': 130, 'tiempo': '12 min'},
    {'nombre': 'Puente de glúteo', 'cal': 100, 'tiempo': '10 min'},
    {'nombre': 'Sentadilla búlgara', 'cal': 140, 'tiempo': '12 min'},
    {'nombre': 'Patada de glúteo', 'cal': 95, 'tiempo': '10 min'},
  ],
  'Subir masa': [
    {'nombre': 'Sentadillas', 'cal': 120, 'tiempo': '12 min'},
    {'nombre': 'Curl de bíceps', 'cal': 80, 'tiempo': '10 min'},
    {'nombre': 'Hip thrust', 'cal': 130, 'tiempo': '12 min'},
    {'nombre': 'Remo con mancuerna', 'cal': 95, 'tiempo': '12 min'},
  ],
};

String? normalizarSexoChat(String valor) {
  final texto = valor.trim().toLowerCase();
  if (texto.contains('muj')) return 'Mujer';
  if (texto.contains('hom') || texto == 'h') return 'Hombre';
  return null;
}

String? normalizarObjetivoChat(String valor) {
  final texto = valor.trim().toLowerCase();
  if (texto.contains('bajar')) return 'Bajar peso';
  if (texto.contains('tonif')) return 'Tonificar';
  if (texto.contains('pierna')) return 'Pierna';
  if (texto.contains('abd')) return 'Abdomen';
  if (texto.contains('glut') || texto.contains('glú')) return 'Glúteo';
  if (texto.contains('sub') ||
      texto.contains('masa') ||
      texto.contains('ganar')) {
    return 'Subir masa';
  }
  return null;
}

String? normalizarTipoComidaChat(String valor) {
  final texto = valor.trim().toLowerCase();
  if (texto.contains('des')) return 'Desayuno';
  if (texto.contains('alm')) return 'Almuerzo';
  if (texto.contains('cen')) return 'Cena';
  if (texto.contains('snack') || texto.contains('meri')) return 'Snack';
  return null;
}

double calcularIndiceMasaCorporal({
  required double pesoLb,
  required double alturaCm,
}) {
  final pesoKg = pesoLb * 0.453592;
  final alturaMetros = alturaCm / 100;
  if (pesoKg <= 0 || alturaMetros <= 0) return 0;
  return pesoKg / (alturaMetros * alturaMetros);
}

List<Map<String, dynamic>> recomendarComidasIA({
  required String objetivo,
  required String tipoComida,
}) {
  final base = obtenerCatalogoAlimentos(tipoComida);
  final objetivoNormalizado = normalizarObjetivoChat(objetivo) ?? 'Tonificar';

  int prioridad(Map<String, dynamic> item) {
    final proteina = valorNumerico(item['proteina']);
    final carbs = valorNumerico(item['carbs']);
    final calorias = valorNumerico(item['calorias']);

    switch (objetivoNormalizado) {
      case 'Bajar peso':
        return ((proteina * 5) - (carbs * 1.5) - (calorias * 0.2)).round();
      case 'Subir masa':
        return ((proteina * 4) + (carbs * 2.5) + (calorias * 0.3)).round();
      default:
        return ((proteina * 4) + (carbs * 1.2) - (calorias * 0.05)).round();
    }
  }

  final ordenados = [...base]
    ..sort((a, b) => prioridad(b).compareTo(prioridad(a)));
  return ordenados.take(4).toList();
}

String construirRespuestaComidaIA({
  required String objetivo,
  required String tipoComida,
}) {
  final sugerencias = recomendarComidasIA(
    objetivo: objetivo,
    tipoComida: tipoComida,
  );
  if (sugerencias.isEmpty) {
    return 'No encontré alimentos para $tipoComida ahora mismo. Puedes crear uno manual desde la sección de comidas.';
  }

  final resumen = sugerencias
      .map((item) {
        return '• ${item['nombre']}: ${formatearMacro(item['calorias'])} kcal, ${formatearMacro(item['proteina'])} g proteína, ${formatearMacro(item['carbs'])} g carbs';
      })
      .join('\n');

  return 'Para $tipoComida y objetivo ${normalizarObjetivoChat(objetivo) ?? objetivo}, te sugiero estas opciones:\n$resumen\n\nSi quieres, después puedes ir a comidas y ajustar gramos, onzas o unidades antes de agregar cada alimento.';
}

String construirRespuestaRutinaIA(ChatRoutineProfile profile) {
  final objetivo = profile.objetivo ?? 'Tonificar';
  final ejercicios =
      sugerenciasRutinaIA[objetivo] ?? sugerenciasRutinaIA['Tonificar']!;
  final imc = calcularIndiceMasaCorporal(
    pesoLb: profile.pesoLb ?? 0,
    alturaCm: profile.alturaCm ?? 0,
  );
  final edad = profile.edad ?? 0;

  final intensidad = edad >= 50
      ? 'moderada y técnica'
      : imc >= 30
      ? 'progresiva con pausas cortas'
      : 'media-alta';
  final frecuencia = objetivo == 'Bajar peso'
      ? '4 a 5 días por semana'
      : objetivo == 'Subir masa'
      ? '4 días por semana con descanso entre grupos'
      : '3 a 4 días por semana';
  final ejerciciosTexto = ejercicios
      .map((item) {
        return '• ${item['nombre']} - ${item['tiempo']} - ${item['cal']} kcal aprox';
      })
      .join('\n');

  return 'Con tus datos, te recomiendo una rutina enfocada en $objetivo con intensidad $intensidad y frecuencia de $frecuencia.\n\nPerfil:\n• Edad: ${profile.edad} años\n• Peso: ${formatearMacro(profile.pesoLb)} lb\n• Altura: ${formatearMacro(profile.alturaCm)} cm\n• Sexo: ${profile.sexo}\n\nRutina sugerida:\n$ejerciciosTexto\n\nEmpieza con 5 minutos de calentamiento y deja 60 a 90 segundos de descanso entre ejercicios. Si quieres, puedo darte también comida recomendada para ese objetivo.';
}

void abrirChatAsistenteIA(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AIAssistantChatScreen()),
  );
}

class AIAssistantChatScreen extends StatefulWidget {
  const AIAssistantChatScreen({super.key});

  @override
  State<AIAssistantChatScreen> createState() => _AIAssistantChatScreenState();
}

class _AIAssistantChatScreenState extends State<AIAssistantChatScreen> {
  static const String _chatHistoryPrefsKey = 'aiChatHistory';
  static const String _chatFlowPrefsKey = 'aiChatFlowState';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatRoutineProfile _routineProfile = ChatRoutineProfile();

  ChatIntent _intent = ChatIntent.none;
  ChatQuestionStep _step = ChatQuestionStep.none;
  String? _foodGoal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _restaurarChatPersistido();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  ChatMessage _mensajeBienvenidaChat() {
    return const ChatMessage(
      text:
          'Soy tu asistente de rutinas y comida. Puedes preguntarme cosas como: "qué rutina necesito para glúteo" o "qué comida me recomiendas para bajar peso".',
      isUser: false,
      quickReplies: [
        'Quiero una rutina',
        'Quiero comida recomendada',
        'Ayúdame a bajar peso',
      ],
    );
  }

  Future<void> _guardarHistorialChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chatHistoryPrefsKey,
      jsonEncode(_messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> _guardarEstadoChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chatFlowPrefsKey,
      jsonEncode({
        'intent': _intent.name,
        'step': _step.name,
        'foodGoal': _foodGoal,
        'routineProfile': _routineProfile.toJson(),
      }),
    );
  }

  Future<void> _guardarPersistenciaChat() async {
    await _guardarHistorialChat();
    await _guardarEstadoChat();
  }

  ChatIntent _chatIntentDesdeString(String? value) {
    return ChatIntent.values
        .where((item) => item.name == value)
        .firstWhere((_) => true, orElse: () => ChatIntent.none);
  }

  ChatQuestionStep _chatStepDesdeString(String? value) {
    return ChatQuestionStep.values
        .where((item) => item.name == value)
        .firstWhere((_) => true, orElse: () => ChatQuestionStep.none);
  }

  Future<void> _restaurarChatPersistido() async {
    final prefs = await SharedPreferences.getInstance();
    final chatGuardado = prefs.getString(_chatHistoryPrefsKey);
    final flowGuardado = prefs.getString(_chatFlowPrefsKey);

    final mensajes = chatGuardado == null
        ? <ChatMessage>[_mensajeBienvenidaChat()]
        : List<ChatMessage>.from(
            (jsonDecode(chatGuardado) as List).map(
              (item) =>
                  ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
            ),
          );

    if (flowGuardado != null) {
      final flow = Map<String, dynamic>.from(
        jsonDecode(flowGuardado) as Map<String, dynamic>,
      );
      _intent = _chatIntentDesdeString(flow['intent']?.toString());
      _step = _chatStepDesdeString(flow['step']?.toString());
      _foodGoal = flow['foodGoal']?.toString();
      final profileJson = Map<String, dynamic>.from(
        flow['routineProfile'] as Map? ?? <String, dynamic>{},
      );
      _routineProfile.loadFromJson(profileJson);
    }

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(
          mensajes.isEmpty ? <ChatMessage>[_mensajeBienvenidaChat()] : mensajes,
        );
    });
    _scrollToBottom();
  }

  void _addBotMessage(String text, {List<String> quickReplies = const []}) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: false, quickReplies: quickReplies),
      );
    });
    _guardarPersistenciaChat();
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _guardarPersistenciaChat();
    _scrollToBottom();
  }

  void _resetFlow({bool keepMessages = true}) {
    _intent = ChatIntent.none;
    _step = ChatQuestionStep.none;
    _foodGoal = null;
    _routineProfile.reset();

    if (!keepMessages) {
      setState(() {
        _messages.clear();
      });
    }

    _guardarPersistenciaChat();
  }

  void _startRoutineFlow() {
    _resetFlow();
    _intent = ChatIntent.rutina;
    _step = ChatQuestionStep.rutinaEdad;
    _guardarEstadoChat();
    _addBotMessage(
      'Para recomendarte una rutina, primero dime tu edad.',
      quickReplies: const ['18', '25', '30', '40'],
    );
  }

  void _startFoodFlow() {
    _resetFlow();
    _intent = ChatIntent.comida;
    _step = ChatQuestionStep.comidaObjetivo;
    _guardarEstadoChat();
    _addBotMessage(
      'Para darte comida recomendada, dime tu objetivo principal.',
      quickReplies: const ['Bajar peso', 'Tonificar', 'Subir masa'],
    );
  }

  Future<void> _handleIncomingMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    _addUserMessage(text);

    if (text.toLowerCase() == 'reiniciar' ||
        text.toLowerCase() == 'empezar de nuevo') {
      _resetFlow();
      _addBotMessage(
        'Listo. Empezamos de nuevo. Puedo ayudarte con rutina o comida.',
        quickReplies: const ['Quiero una rutina', 'Quiero comida recomendada'],
      );
      return;
    }

    if (_intent == ChatIntent.rutina && _step != ChatQuestionStep.none) {
      await _handleRoutineFlow(text);
      return;
    }

    if (_intent == ChatIntent.comida && _step != ChatQuestionStep.none) {
      await _handleFoodFlow(text);
      return;
    }

    final lower = text.toLowerCase();
    final preguntaRutina = RegExp(
      r'rutina|ejercicio|entren|pierna|abdomen|glute|glúte|tonif|bajar peso|subir masa',
    ).hasMatch(lower);
    final preguntaComida = RegExp(
      r'comida|aliment|desayuno|almuerzo|cena|snack|proteina|proteína|carbo|caloria|caloría',
    ).hasMatch(lower);

    if (preguntaRutina && !preguntaComida) {
      _startRoutineFlow();
      return;
    }

    if (preguntaComida && !preguntaRutina) {
      final objetivo = normalizarObjetivoChat(text);
      final tipo = normalizarTipoComidaChat(text);
      if (objetivo != null && tipo != null) {
        _addBotMessage(
          construirRespuestaComidaIA(objetivo: objetivo, tipoComida: tipo),
        );
      } else {
        _startFoodFlow();
      }
      return;
    }

    if (preguntaRutina && preguntaComida) {
      _addBotMessage(
        'Puedo ayudarte con las dos cosas. Elige primero qué quieres resolver.',
        quickReplies: const ['Quiero una rutina', 'Quiero comida recomendada'],
      );
      return;
    }

    await _responderPreguntaLibre(text);
  }

  Future<void> _responderPreguntaLibre(String text) async {
    if (iaExternaDisponible()) {
      setState(() {
        _isLoading = true;
      });
      final respuesta = await generarRespuestaLibreIA(messages: _messages);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (respuesta != null && respuesta.isNotEmpty) {
        _addBotMessage(respuesta);
        return;
      }
    }

    _addBotMessage(
      'Puedo responderte sobre rutinas y comida. Dime qué necesitas y te guío paso a paso.',
      quickReplies: const [
        'Quiero una rutina',
        'Quiero comida recomendada',
        'Ayúdame a bajar peso',
      ],
    );
  }

  Future<void> _responderRutinaFinal() async {
    String respuesta = construirRespuestaRutinaIA(_routineProfile);

    if (iaExternaDisponible()) {
      setState(() {
        _isLoading = true;
      });
      final externa = await generarRespuestaRutinaIAExterna(_routineProfile);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (externa != null && externa.isNotEmpty) {
        respuesta = externa;
      }
    }

    _addBotMessage(respuesta);
  }

  Future<void> _responderComidaFinal({
    required String objetivo,
    required String tipo,
  }) async {
    String respuesta = construirRespuestaComidaIA(
      objetivo: objetivo,
      tipoComida: tipo,
    );

    if (iaExternaDisponible()) {
      setState(() {
        _isLoading = true;
      });
      final externa = await generarRespuestaComidaIAExterna(
        objetivo: objetivo,
        tipoComida: tipo,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (externa != null && externa.isNotEmpty) {
        respuesta = externa;
      }
    }

    _addBotMessage(respuesta);
  }

  Future<void> _handleRoutineFlow(String text) async {
    switch (_step) {
      case ChatQuestionStep.rutinaEdad:
        final edad = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
        if (edad == null || edad < 12 || edad > 90) {
          _addBotMessage(
            'Escríbeme una edad válida en años.',
            quickReplies: const ['18', '25', '30', '40'],
          );
          return;
        }
        _routineProfile.edad = edad;
        _step = ChatQuestionStep.rutinaPeso;
        _guardarEstadoChat();
        _addBotMessage(
          'Ahora dime tu peso en libras.',
          quickReplies: const ['120', '150', '180', '200'],
        );
        break;
      case ChatQuestionStep.rutinaPeso:
        final peso = double.tryParse(
          text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9\.]'), ''),
        );
        if (peso == null || peso < 60 || peso > 500) {
          _addBotMessage(
            'Escríbeme tu peso en libras. Ejemplo: 150',
            quickReplies: const ['120', '150', '180', '200'],
          );
          return;
        }
        _routineProfile.pesoLb = peso;
        _step = ChatQuestionStep.rutinaAltura;
        _guardarEstadoChat();
        _addBotMessage(
          'Ahora dime tu altura en centímetros.',
          quickReplies: const ['160', '170', '175', '180'],
        );
        break;
      case ChatQuestionStep.rutinaAltura:
        final altura = double.tryParse(
          text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9\.]'), ''),
        );
        if (altura == null || altura < 120 || altura > 230) {
          _addBotMessage(
            'Escríbeme tu altura en centímetros. Ejemplo: 170',
            quickReplies: const ['160', '170', '175', '180'],
          );
          return;
        }
        _routineProfile.alturaCm = altura;
        _step = ChatQuestionStep.rutinaSexo;
        _guardarEstadoChat();
        _addBotMessage(
          '¿Cuál es tu sexo?',
          quickReplies: const ['Hombre', 'Mujer'],
        );
        break;
      case ChatQuestionStep.rutinaSexo:
        final sexo = normalizarSexoChat(text);
        if (sexo == null) {
          _addBotMessage(
            'Respóndeme con Hombre o Mujer.',
            quickReplies: const ['Hombre', 'Mujer'],
          );
          return;
        }
        _routineProfile.sexo = sexo;
        _step = ChatQuestionStep.rutinaObjetivo;
        _guardarEstadoChat();
        _addBotMessage(
          '¿Qué deseas trabajar o lograr?',
          quickReplies: const [
            'Bajar peso',
            'Tonificar',
            'Pierna',
            'Abdomen',
            'Glúteo',
            'Subir masa',
          ],
        );
        break;
      case ChatQuestionStep.rutinaObjetivo:
        final objetivo = normalizarObjetivoChat(text);
        if (objetivo == null) {
          _addBotMessage(
            'Elige uno de estos objetivos para recomendarte mejor la rutina.',
            quickReplies: const [
              'Bajar peso',
              'Tonificar',
              'Pierna',
              'Abdomen',
              'Glúteo',
              'Subir masa',
            ],
          );
          return;
        }
        _routineProfile.objetivo = objetivo;
        _step = ChatQuestionStep.none;
        _intent = ChatIntent.none;
        _guardarEstadoChat();
        await _responderRutinaFinal();
        break;
      default:
        break;
    }
  }

  Future<void> _handleFoodFlow(String text) async {
    switch (_step) {
      case ChatQuestionStep.comidaObjetivo:
        final objetivo = normalizarObjetivoChat(text);
        if (objetivo == null) {
          _addBotMessage(
            'Dime si buscas bajar peso, tonificar o subir masa.',
            quickReplies: const ['Bajar peso', 'Tonificar', 'Subir masa'],
          );
          return;
        }
        _foodGoal = objetivo;
        _step = ChatQuestionStep.comidaTipo;
        _guardarEstadoChat();
        _addBotMessage(
          '¿Para qué comida quieres la recomendación?',
          quickReplies: const ['Desayuno', 'Almuerzo', 'Cena', 'Snack'],
        );
        break;
      case ChatQuestionStep.comidaTipo:
        final tipo = normalizarTipoComidaChat(text);
        if (tipo == null || _foodGoal == null) {
          _addBotMessage(
            'Elige desayuno, almuerzo, cena o snack.',
            quickReplies: const ['Desayuno', 'Almuerzo', 'Cena', 'Snack'],
          );
          return;
        }
        final objetivo = _foodGoal!;
        _step = ChatQuestionStep.none;
        _intent = ChatIntent.none;
        _guardarEstadoChat();
        await _responderComidaFinal(objetivo: objetivo, tipo: tipo);
        break;
      default:
        break;
    }
  }

  Widget _messageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF0F6CBD), Color(0xFF3A93F3)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF1F7FF)],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
            if (!isUser && message.quickReplies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.quickReplies.map((reply) {
                  return ActionChip(
                    label: Text(reply),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _handleIncomingMessage(reply);
                          },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fitAppPageBackgroundColor,
      appBar: AppBar(
        backgroundColor: fitAppPageBackgroundColor,
        title: const Text('Coach IA'),
        actions: [
          TextButton(
            onPressed: () {
              _resetFlow(keepMessages: false);
              setState(() {
                _messages.add(
                  const ChatMessage(
                    text:
                        'Chat reiniciado. Puedes preguntarme por rutina o comida y te guío paso a paso.',
                    isUser: false,
                    quickReplies: [
                      'Quiero una rutina',
                      'Quiero comida recomendada',
                    ],
                  ),
                );
              });
              _guardarHistorialChat();
            },
            child: const Text('Reiniciar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF093E7A), Color(0xFF3EA2FF)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente inteligente de entrenamiento y comida',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Te hace preguntas cuando hacen falta datos y luego responde según lo que pidas.',
                  style: TextStyle(color: Colors.white, height: 1.3),
                ),
                SizedBox(height: 8),
                Text(
                  aiApiKey == ''
                      ? 'Modo local activo. Configura AI_API_KEY para usar IA real.'
                      : 'IA real conectada.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                ..._messages.map(_messageBubble),
                if (_isLoading)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F6CBD),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Pensando respuesta...'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu pregunta...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) async {
                        final text = _messageController.text;
                        _messageController.clear();
                        await _handleIncomingMessage(text);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final text = _messageController.text;
                            _messageController.clear();
                            await _handleIncomingMessage(text);
                          },
                    backgroundColor: const Color(0xFF0F6CBD),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int calcularTiempoRutinaActual([DateTime? fecha]) {
  return obtenerRutinaDelDiaActual(
    fecha,
  ).fold<int>(0, (total, ejercicio) => total + obtenerMinutosRutina(ejercicio));
}

double calcularMetaAguaLitros() {
  if (user.weight <= 0) {
    return 2.0;
  }

  final pesoKg = user.weight * 0.453592;
  final metaBase = pesoKg * 0.035;
  return metaBase.clamp(1.5, 5.0).toDouble();
}

double calcularMetaProteinaDiariaGramos() {
  final pesoKg = user.weight * 0.453592;
  if (pesoKg <= 0) {
    return 110;
  }

  double multiplicador;
  switch (user.goal) {
    case "Bajar peso":
      multiplicador = 2.0;
      break;
    case "Subir masa":
      multiplicador = 1.9;
      break;
    default:
      multiplicador = 1.6;
      break;
  }

  if (user.age >= 50) {
    multiplicador += 0.1;
  }

  multiplicador += user.sex == "Mujer" ? -0.05 : 0.05;
  return (pesoKg * multiplicador).clamp(75, 220).toDouble();
}

double calcularMetaGrasasDiariasGramos() {
  final pesoKg = user.weight * 0.453592;
  if (pesoKg <= 0) {
    return 60;
  }

  double multiplicador = user.sex == "Mujer" ? 0.95 : 0.85;
  switch (user.goal) {
    case "Bajar peso":
      multiplicador -= 0.05;
      break;
    case "Subir masa":
      multiplicador += 0.15;
      break;
  }

  if (user.age >= 50) {
    multiplicador += 0.05;
  }

  return (pesoKg * multiplicador).clamp(40, 110).toDouble();
}

double calcularMetaCarbsDiariosGramos() {
  final caloriasMeta = user.calories > 0 ? user.calories : 2000;
  final caloriasProteina = calcularMetaProteinaDiariaGramos() * 4;
  final caloriasGrasa = calcularMetaGrasasDiariasGramos() * 9;
  final caloriasDisponibles = (caloriasMeta - caloriasProteina - caloriasGrasa)
      .clamp(320.0, caloriasMeta * 0.6)
      .toDouble();

  return (caloriasDisponibles / 4).clamp(80, 360).toDouble();
}

Future<void> guardarTodo() async {
  final prefs = await SharedPreferences.getInstance();
  normalizarCanastaGlobal();
  caloriasEjercicio = calcularCaloriasRutinaActual();
  final tiempoRutina = calcularTiempoRutinaActual();
  final tieneRutina = obtenerRutinaDelDiaActual().isNotEmpty;
  aguaHistorialGlobal[fechaActualKey()] = aguaConsumida;
  comidasHistorialGlobal[fechaActualKey()] = copiarListaMapas(canastaGlobal);
  // 🔥 GUARDAR FECHA ACTUAL
  prefs.setString(
    "fecha",
    "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}",
  );
  prefs.setDouble("caloriasEjercicio", caloriasEjercicio);
  prefs.setInt("tiempo", tiempoRutina);
  prefs.setBool("entreno", tieneRutina);
  prefs.setString("rutina", jsonEncode(rutinaGlobal));

  // usuario
  prefs.setString("name", user.name);
  prefs.setString("sex", user.sex);
  prefs.setInt("age", user.age);
  prefs.setDouble("weight", user.weight);
  prefs.setDouble("height", user.height);
  prefs.setString("goal", user.goal);
  prefs.setString("photoBase64", user.photoBase64);
  prefs.setString("photoUrl", user.photoUrl);
  prefs.setString("authEmail", '');
  prefs.setString("authProvider", '');
  prefs.setString("authUid", '');

  // macros
  prefs.setDouble("calorias", caloriasConsumidas);
  prefs.setDouble("proteina", proteinaConsumida);
  prefs.setDouble("carbs", carbsConsumidos);
  prefs.setDouble("aguaConsumida", aguaConsumida);
  prefs.setBool(premiumPrefsKey, premiumActivadoGlobal);
  prefs.setString("aguaHistorial", jsonEncode(aguaHistorialGlobal));
  prefs.setString("comidasHistorial", jsonEncode(comidasHistorialGlobal));
  prefs.setString("ejerciciosHistorial", jsonEncode(ejerciciosHistorialGlobal));
  prefs.setString("bienestarHistorial", jsonEncode(bienestarHistorialGlobal));

  // 🔥 GUARDAR CANASTA
  prefs.setString("canasta", jsonEncode(canastaGlobal));
  prefs.setString(
    "alimentosPersonalizados",
    jsonEncode(alimentosPersonalizadosGlobal),
  );

  // 🔥 GUARDAR FAVORITOS
  prefs.setString("favoritos", jsonEncode(favoritosGlobal));

  AppDataSyncService.instance.notifyDataChanged();
  await ExternalProgressWidgetService.syncFromPrefs();
  await NotificationService.instance.refreshDailySummaryNotification();
}

Future<void> cargarTodo() async {
  final prefs = await SharedPreferences.getInstance();
  String hoy =
      "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
  String? fechaGuardada = prefs.getString("fecha");
  premiumActivadoGlobal = prefs.getBool(premiumPrefsKey) ?? false;
  caloriasEjercicio = prefs.getDouble("caloriasEjercicio") ?? 0;
  final canastaString = prefs.getString("canasta");
  final canastaGuardada = canastaString == null
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          (jsonDecode(canastaString) as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );

  final alimentosPersonalizadosString = prefs.getString(
    "alimentosPersonalizados",
  );
  if (alimentosPersonalizadosString != null) {
    alimentosPersonalizadosGlobal = List<Map<String, dynamic>>.from(
      (jsonDecode(alimentosPersonalizadosString) as List).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
  }

  final aguaHistorialString = prefs.getString("aguaHistorial");
  if (aguaHistorialString != null) {
    aguaHistorialGlobal = Map<String, double>.from(
      (jsonDecode(aguaHistorialString) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }

  final comidasHistorialString = prefs.getString("comidasHistorial");
  if (comidasHistorialString != null) {
    comidasHistorialGlobal = Map<String, List<Map<String, dynamic>>>.from(
      (jsonDecode(comidasHistorialString) as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          List<Map<String, dynamic>>.from(
            (value as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          ),
        ),
      ),
    );
  }

  final ejerciciosHistorialString = prefs.getString("ejerciciosHistorial");
  if (ejerciciosHistorialString != null) {
    ejerciciosHistorialGlobal = Map<String, List<Map<String, dynamic>>>.from(
      (jsonDecode(ejerciciosHistorialString) as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          List<Map<String, dynamic>>.from(
            (value as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          ),
        ),
      ),
    );
  }

  final bienestarHistorialString = prefs.getString("bienestarHistorial");
  if (bienestarHistorialString != null) {
    bienestarHistorialGlobal = Map<String, Map<String, String>>.from(
      (jsonDecode(bienestarHistorialString) as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          Map<String, String>.from(
            (value as Map<String, dynamic>).map(
              (innerKey, innerValue) =>
                  MapEntry(innerKey, innerValue.toString()),
            ),
          ),
        ),
      ),
    );
  }

  String? rutinaString = prefs.getString("rutina");
  if (rutinaString != null) {
    rutinaGlobal = Map<String, List<Map<String, dynamic>>>.from(
      jsonDecode(rutinaString).map(
        (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
      ),
    );
  }

  caloriasEjercicio = calcularCaloriasRutinaActual();
  await prefs.setDouble("caloriasEjercicio", caloriasEjercicio);
  await prefs.setInt("tiempo", calcularTiempoRutinaActual());
  await prefs.setBool("entreno", obtenerRutinaDelDiaActual().isNotEmpty);

  // 🔥 SI CAMBIÓ EL DÍA → REINICIAR TODO
  if (fechaGuardada != hoy) {
    if (fechaGuardada != null && canastaGuardada.isNotEmpty) {
      comidasHistorialGlobal[fechaGuardada] = copiarListaMapas(canastaGuardada);
      await prefs.setString(
        "comidasHistorial",
        jsonEncode(comidasHistorialGlobal),
      );
    }

    caloriasConsumidas = 0;
    proteinaConsumida = 0;
    carbsConsumidos = 0;
    aguaConsumida = 0;
    canastaGlobal.clear();
    desayunoGlobal.clear();
    almuerzoGlobal.clear();
    cenaGlobal.clear();
    snacksGlobal.clear();
    // guardar nuevo día
    prefs.setString("fecha", hoy);

    await prefs.setDouble("calorias", 0);
    await prefs.setDouble("proteina", 0);
    await prefs.setDouble("carbs", 0);
    await prefs.setDouble("aguaConsumida", 0);
    await prefs.setString("canasta", jsonEncode([]));
  }

  user.name = prefs.getString("name") ?? "";
  user.sex = prefs.getString("sex") ?? "Hombre";
  user.age = prefs.getInt("age") ?? 0;
  user.weight = prefs.getDouble("weight") ?? 0;
  user.height = prefs.getDouble("height") ?? 0;
  user.goal = prefs.getString("goal") ?? "Mantener";
  user.photoBase64 = prefs.getString("photoBase64") ?? "";
  user.photoUrl = prefs.getString("photoUrl") ?? "";
  user.authEmail = '';
  user.authProvider = '';
  user.authUid = '';

  caloriasConsumidas = prefs.getDouble("calorias") ?? 0;
  proteinaConsumida = prefs.getDouble("proteina") ?? 0;
  carbsConsumidos = prefs.getDouble("carbs") ?? 0;
  aguaConsumida = prefs.getDouble("aguaConsumida") ?? 0;

  canastaGlobal = fechaGuardada == hoy ? copiarListaMapas(canastaGuardada) : [];
  normalizarCanastaGlobal();
  aguaHistorialGlobal[fechaActualKey()] = aguaConsumida;

  comidasHistorialGlobal[fechaActualKey()] = copiarListaMapas(canastaGlobal);

  // 🔥 CARGAR FAVORITOS
  String? favString = prefs.getString("favoritos");
  if (favString != null) {
    favoritosGlobal = List<Map<String, dynamic>>.from(jsonDecode(favString));
  }

  await ExternalProgressWidgetService.syncFromPrefs();
}

// PERFIL Y FORMULARIO
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editarPerfil() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserForm()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _cambiarFoto() async {
    final foto = await seleccionarFotoPerfilBase64();
    if (foto == null) return;

    setState(() {
      user.photoBase64 = foto;
      user.photoUrl = '';
    });
    await guardarTodo();
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _dataTile(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const subtitle = 'Tus datos y tu progreso se guardan en este dispositivo.';

    return Scaffold(
      backgroundColor: fitTrackPageBackgroundColor,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _editarPerfil,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1D4ED8),
                    Color(0xFF14B8A6),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Perfil local',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      avatarUsuario(radius: 52, fontSize: 34),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: InkWell(
                          onTap: _cambiarFoto,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name.isEmpty ? 'Tu perfil' : user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _metricCard(
                  'Edad',
                  '${user.age} años',
                  Icons.cake_rounded,
                  const Color(0xFF2563EB),
                ),
                _metricCard(
                  'Peso',
                  '${user.weight.toStringAsFixed(0)} lb',
                  Icons.monitor_weight_rounded,
                  const Color(0xFFEA580C),
                ),
                _metricCard(
                  'Altura',
                  '${user.height.toStringAsFixed(0)} cm',
                  Icons.height_rounded,
                  const Color(0xFF7C3AED),
                ),
                _metricCard(
                  'Meta kcal',
                  user.calories.toStringAsFixed(0),
                  Icons.local_fire_department_rounded,
                  const Color(0xFF16A34A),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _dataTile('Sexo', user.sex, Icons.wc_rounded),
            _dataTile('Objetivo', user.goal, Icons.flag_rounded),
            _dataTile(
              'Guardado',
              'Tus datos se guardan localmente en este dispositivo.',
              Icons.save_rounded,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inicio de sesión social desactivado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Esta app ahora usa solo guardado local, sin acceso con Google ni Facebook.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _editarPerfil,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6CBD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar perfil'),
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

class UserForm extends StatefulWidget {
  final bool isFirstSetup;

  const UserForm({super.key, this.isFirstSetup = false});

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final age = TextEditingController();
  final weight = TextEditingController();
  final height = TextEditingController();
  final List<String> sexos = ['Hombre', 'Mujer'];
  final List<String> objetivos = ['Bajar peso', 'Mantener', 'Subir masa'];
  late String sexoSeleccionado;
  late String objetivoSeleccionado;
  bool _saving = false;
  String _photoBase64 = '';

  @override
  void initState() {
    super.initState();
    _llenarDesdeUsuario();
  }

  void _llenarDesdeUsuario() {
    name.text = user.name;
    age.text = user.age == 0 ? '' : user.age.toString();
    weight.text = user.weight == 0 ? '' : user.weight.toString();
    height.text = user.height == 0 ? '' : user.height.toString();
    sexoSeleccionado = sexos.contains(user.sex) ? user.sex : 'Hombre';
    objetivoSeleccionado = objetivos.contains(user.goal)
        ? user.goal
        : 'Mantener';
    _photoBase64 = user.photoBase64;
  }

  Future<void> _seleccionarFoto() async {
    final foto = await seleccionarFotoPerfilBase64();
    if (foto == null) return;
    setState(() {
      _photoBase64 = foto;
    });
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    user.name = name.text.trim();
    user.sex = sexoSeleccionado;
    user.age = int.tryParse(age.text) ?? 0;
    user.weight = double.tryParse(weight.text) ?? 0;
    user.height = double.tryParse(height.text) ?? 0;
    user.goal = objetivoSeleccionado;
    user.photoBase64 = _photoBase64;
    if (_photoBase64.isNotEmpty) {
      user.photoUrl = '';
    }

    await guardarTodo();

    if (!mounted) return;
    setState(() => _saving = false);

    if (widget.isFirstSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePrincipal()),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if ((value ?? '').trim().isEmpty) {
            return 'Completa $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.isFirstSetup
        ? 'Crea tu perfil una sola vez'
        : 'Edita tu perfil';
    final subtitulo = widget.isFirstSetup
        ? 'Completa tus datos al entrar por primera vez. Después los verás siempre listos en tu perfil.'
        : 'Actualiza tu información y tu foto cuando lo necesites.';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isFirstSetup,
        title: Text(widget.isFirstSetup ? 'Bienvenido' : 'Datos del perfil'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2FBFF), Color(0xFFFFF7EF)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1D4ED8),
                          Color(0xFF22C55E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Builder(
                              builder: (context) {
                                final previousPhoto = user.photoBase64;
                                user.photoBase64 = _photoBase64;
                                final avatar = avatarUsuario(
                                  radius: 52,
                                  fontSize: 34,
                                );
                                user.photoBase64 = previousPhoto;
                                return avatar;
                              },
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: InkWell(
                                onTap: _seleccionarFoto,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo_rounded,
                                    color: Color(0xFF0F172A),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitulo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Guardado local en este dispositivo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sin inicio de sesión social',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'El perfil se mantiene en este dispositivo. Google y Facebook ya no están disponibles para entrar.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        _input(name, 'Nombre completo'),
                        _input(age, 'Edad', keyboardType: TextInputType.number),
                        _input(
                          weight,
                          'Peso (lb)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        _input(
                          height,
                          'Altura (cm)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DropdownButtonFormField<String>(
                            initialValue: sexoSeleccionado,
                            decoration: InputDecoration(
                              labelText: 'Sexo',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: sexos
                                .map(
                                  (sexo) => DropdownMenuItem<String>(
                                    value: sexo,
                                    child: Text(sexo),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                sexoSeleccionado = value ?? 'Hombre';
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: DropdownButtonFormField<String>(
                            initialValue: objetivoSeleccionado,
                            decoration: InputDecoration(
                              labelText: 'Objetivo',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: objetivos
                                .map(
                                  (objetivo) => DropdownMenuItem<String>(
                                    value: objetivo,
                                    child: Text(objetivo),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                objetivoSeleccionado = value ?? 'Mantener';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _guardarPerfil,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F6CBD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving
                            ? 'Guardando perfil...'
                            : widget.isFirstSetup
                            ? 'Entrar a la app'
                            : 'Guardar cambios',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int caloriasEjercicio = 0;
  int tiempoEjercicio = 0;
  int pasosActuales = 0;
  int page = 0;
  int currentIndex = 0;
  bool _premiumActivado = false;
  bool _mostrarWidgetProgreso = true;
  late PageController _pageController;
  late DateTime fechaActual;
  late DateTime _hoySistema;
  int calorias = 0;
  int tiempo = 0;
  late final VoidCallback _stepsListener;
  late final VoidCallback _dataListener;
  late final TextEditingController _aguaController;
  Set<String> _diasDescansoInforme = <String>{};
  _HomeScreenState();

  late List<Widget> _pages;

  void _initPages() {
    _pages = [
      const ProfileScreen(), //index 0
      const ComidasScreen(), //index 1
      const RutinasScreen(), //index 2
      const ObjetivosPage(), //index 3
    ];
  }

  void eliminarComida(Map comida) {
    if (!_viendoHoy) return;
    setState(() {
      eliminarAlimentoDeCanasta(comida);
    });
    guardarTodo();
  }

  Future<void> _editarPorcionComida(Map<String, dynamic> item) async {
    if (!_viendoHoy) return;
    final actualizado = await mostrarDialogoPorcionAlimento(
      context,
      alimento: item,
      tipo: normalizarTipoComida(item['comidaTipo']?.toString()),
      editando: true,
    );
    if (!mounted || actualizado == null) return;

    setState(() {
      final indice = canastaGlobal.indexWhere(
        (actual) =>
            actual['basketId']?.toString() ==
            actualizado['basketId']?.toString(),
      );
      if (indice >= 0) {
        canastaGlobal[indice] = actualizado;
      }
      normalizarCanastaGlobal();
    });
    await guardarTodo();
  }

  List<Color> _coloresTarjetaComida(String tipo) {
    switch (normalizarTipoComida(tipo)) {
      case 'Desayuno':
        return const [Color(0xFFFFE4B8), Color(0xFFFFF7DD)];
      case 'Almuerzo':
        return const [Color(0xFFFFD5C8), Color(0xFFFFF0EA)];
      case 'Cena':
        return const [Color(0xFFCFDFFF), Color(0xFFF1F5FF)];
      default:
        return const [Color(0xFFCFF3E5), Color(0xFFF0FFF9)];
    }
  }

  Future<void> _abrirCategoriaYRefrescar(String tipo) async {
    if (!_viendoHoy) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoriaScreen(titulo: tipo)),
    );
    if (!mounted) return;
    setState(() {});
  }

  Widget _macroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _itemComidaDestacado(String tipo, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              iconoParaAlimento(item['nombre'].toString()),
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _viendoHoy ? () => _editarPorcionComida(item) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nombre'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      resumenPorcionAlimento(item),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resumenAlimento(item),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_viendoHoy)
            IconButton(
              onPressed: () => eliminarComida(item),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.history_toggle_off_rounded, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaComidaPrincipal(String tipo) {
    final items = _comidasDelDiaPorTipoFecha(tipo, fechaActual);
    final colores = _coloresTarjetaComida(tipo);
    final calorias = _caloriasTipoFecha(tipo, fechaActual).toStringAsFixed(0);
    final proteina = _proteinaTipoFecha(tipo, fechaActual).toStringAsFixed(0);
    final carbs = _carbsTipoFecha(tipo, fechaActual).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colores,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(iconoParaTipoComida(tipo), color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipo,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items.isEmpty
                          ? 'Sin alimentos todavía. Toca agregar comida para empezar.'
                          : '${items.length} alimentos registrados en esta fecha',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _viendoHoy
                    ? () => _abrirCategoriaYRefrescar(tipo)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_viendoHoy ? 'Agregar comida' : 'Solo lectura'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _macroPill('Calorías', '$calorias kcal')),
              const SizedBox(width: 10),
              Expanded(child: _macroPill('Proteína', '$proteina g')),
              const SizedBox(width: 10),
              Expanded(child: _macroPill('Carbos', '$carbs g')),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'Aquí verás cada comida con gramos, onzas, unidades y sus macros calculados en tiempo real.',
                style: TextStyle(color: Colors.grey.shade800, height: 1.3),
              ),
            )
          else
            ...items.take(3).map((item) => _itemComidaDestacado(tipo, item)),
          if (items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+ ${items.length - 3} alimentos más en $tipo',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget comidaAgregadaItem(Map item) {
    return Padding(
      padding: const EdgeInsets.only(left: 60, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ${item["nombre"]}"),
                Text(
                  resumenAlimento(item),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              eliminarComida(item);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _abrirRutinasDesdeCard() async {
    if (!_viendoHoy) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RutinasScreen()),
    );
    await _recargarDashboard();
  }

  bool get _viendoHoy => _esMismaFecha(fechaActual, _hoySistema);

  String get _fechaSeleccionadaKey => fechaActualKey(fechaActual);

  List<Map<String, dynamic>> _comidasDeFecha(DateTime fecha) {
    if (_esMismaFecha(fecha, _hoySistema)) {
      return copiarListaMapas(canastaGlobal);
    }
    return copiarListaMapas(
      comidasHistorialGlobal[fechaActualKey(fecha)] ?? <Map<String, dynamic>>[],
    );
  }

  List<Map<String, dynamic>> _ejerciciosDeFecha(DateTime fecha) {
    return copiarListaMapas(
      ejerciciosHistorialGlobal[fechaActualKey(fecha)] ??
          ejerciciosHistorialGlobal[fechaKeyPadded(fecha)] ??
          <Map<String, dynamic>>[],
    );
  }

  double _aguaDeFecha(DateTime fecha) {
    if (_esMismaFecha(fecha, _hoySistema)) {
      return aguaConsumida;
    }
    return (aguaHistorialGlobal[fechaActualKey(fecha)] ??
            aguaHistorialGlobal[fechaKeyPadded(fecha)] ??
            0)
        .toDouble();
  }

  int _pasosDeFecha(DateTime fecha) {
    if (_esMismaFecha(fecha, _hoySistema)) {
      return pasosActuales;
    }
    final history = StepCounterService.instance.stepHistory.value;
    return history[fechaKeyPadded(fecha)] ??
        history[fechaActualKey(fecha)] ??
        0;
  }

  double _sumarCampoFecha(List<Map<String, dynamic>> items, String key) {
    return items.fold<double>(
      0,
      (total, item) => total + valorNumerico(item[key]),
    );
  }

  List<Map<String, dynamic>> _comidasDelDiaPorTipoFecha(
    String tipo,
    DateTime fecha,
  ) {
    final tipoNormalizado = normalizarTipoComida(tipo);
    return _comidasDeFecha(fecha)
        .where(
          (item) =>
              normalizarTipoComida(item['comidaTipo']?.toString()) ==
              tipoNormalizado,
        )
        .toList();
  }

  double _caloriasTipoFecha(String tipo, DateTime fecha) {
    return _sumarCampoFecha(
      _comidasDelDiaPorTipoFecha(tipo, fecha),
      'calorias',
    );
  }

  double _proteinaTipoFecha(String tipo, DateTime fecha) {
    return _sumarCampoFecha(
      _comidasDelDiaPorTipoFecha(tipo, fecha),
      'proteina',
    );
  }

  double _carbsTipoFecha(String tipo, DateTime fecha) {
    return _sumarCampoFecha(_comidasDelDiaPorTipoFecha(tipo, fecha), 'carbs');
  }

  int _caloriasEjercicioFecha(DateTime fecha) {
    return _ejerciciosDeFecha(fecha).fold<int>(
      0,
      (total, ejercicio) => total + valorNumerico(ejercicio['cal']).round(),
    );
  }

  int _tiempoEjercicioFecha(DateTime fecha) {
    return _ejerciciosDeFecha(fecha).fold<int>(
      0,
      (total, ejercicio) => total + obtenerMinutosRutina(ejercicio),
    );
  }

  String _textoFechaSeleccionada() {
    final hoy = _esMismaFecha(fechaActual, _hoySistema);
    final ayer = _esMismaFecha(
      fechaActual,
      DateTime(
        _hoySistema.year,
        _hoySistema.month,
        _hoySistema.day,
      ).subtract(const Duration(days: 1)),
    );
    final manana = _esMismaFecha(
      fechaActual,
      DateTime(
        _hoySistema.year,
        _hoySistema.month,
        _hoySistema.day,
      ).add(const Duration(days: 1)),
    );

    final fechaTexto =
        '${fechaActual.day}/${fechaActual.month}/${fechaActual.year}';
    if (hoy) return 'Hoy • $fechaTexto';
    if (ayer) return 'Ayer • $fechaTexto';
    if (manana) return 'Mañana • $fechaTexto';
    return '${nombreDiaCompleto(fechaActual.weekday)} • $fechaTexto';
  }

  Future<void> _moverFecha(int delta) async {
    await guardarTodo();
    if (!mounted) return;
    final nuevaFecha = DateTime(
      fechaActual.year,
      fechaActual.month,
      fechaActual.day,
    ).add(Duration(days: delta));
    setState(() {
      fechaActual = nuevaFecha;
      _aguaController.text = _aguaDeFecha(nuevaFecha).toStringAsFixed(2);
    });
  }

  Widget _dateNavigator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _moverFecha(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _textoFechaSeleccionada(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _viendoHoy
                      ? 'Estás viendo el progreso del día actual.'
                      : 'Estás viendo un día guardado. Si no tuvo actividad, verás todo en cero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _moverFecha(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Map<String, String> get _bienestarHoy {
    return Map<String, String>.from(
      bienestarHistorialGlobal[_fechaSeleccionadaKey] ?? <String, String>{},
    );
  }

  Future<void> _editarBienestarHoy() async {
    final respuestasIniciales = _bienestarHoy;
    final respuestas = Map<String, String>.from(respuestasIniciales);

    final resultado = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final completado = bienestarPreguntas.every(
              (pregunta) => respuestas.containsKey(pregunta["id"]),
            );

            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.mood,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '¿Cómo te sientes hoy?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Responde una vez al día. Puedes editar tus respuestas cuando quieras.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 18),
                      ...bienestarPreguntas.map((pregunta) {
                        final preguntaId = pregunta["id"] as String;
                        final opciones = List<String>.from(
                          pregunta["opciones"] as List,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pregunta["pregunta"] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: opciones.map((opcion) {
                                  final selected =
                                      respuestas[preguntaId] == opcion;
                                  return ChoiceChip(
                                    label: Text(opcion),
                                    selected: selected,
                                    selectedColor: Colors.blue.shade100,
                                    onSelected: (_) {
                                      setModalState(() {
                                        respuestas[preguntaId] = opcion;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: completado
                              ? () => Navigator.pop(context, respuestas)
                              : null,
                          child: const Text('Guardar respuestas'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (resultado == null) return;

    setState(() {
      bienestarHistorialGlobal[_fechaSeleccionadaKey] = resultado;
    });
    await guardarTodo();
  }

  Future<void> _abrirInformeSemanal() async {
    final diasDescanso = await _seleccionarDiasDescanso();
    if (!mounted || diasDescanso == null) {
      return;
    }

    setState(() {
      _diasDescansoInforme = diasDescanso;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyReportScreen(restDays: diasDescanso),
      ),
    );
  }

  Future<void> _abrirPremiumHub() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumHubScreen()),
    );

    final premium = await cargarEstadoPremium();
    if (!mounted) return;
    setState(() {
      _premiumActivado = premium;
    });
  }

  int get _metaPasosWidget {
    switch (user.goal) {
      case 'Bajar peso':
        return 12000;
      case 'Subir masa':
        return 9000;
      default:
        return 10000;
    }
  }

  Future<void> _guardarPreferenciaWidgetProgreso(bool value) async {
    mostrarWidgetProgresoGlobal = value;
    await ExternalProgressWidgetService.setActive(value);
    if (!mounted) return;
    setState(() {
      _mostrarWidgetProgreso = value;
    });
  }

  Future<void> _instalarWidgetExterno() async {
    await _guardarPreferenciaWidgetProgreso(true);

    final soportaAnclar =
        await ExternalProgressWidgetService.canRequestPinWidget();
    if (soportaAnclar) {
      await ExternalProgressWidgetService.requestPin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El selector del widget se abrio en tu telefono.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El widget ya esta listo. Agregalo manualmente desde la pantalla principal de Android.',
        ),
      ),
    );
  }

  Future<Set<String>?> _seleccionarDiasDescanso() async {
    final seleccion = Set<String>.from(_diasDescansoInforme);

    return showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Informe semanal IA'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Marca los dias que quieres tomar como descanso para ajustar el informe de ejercicios.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: diasSemanaEspanol.map((dia) {
                      final activo = seleccion.contains(dia);
                      return FilterChip(
                        label: Text(dia),
                        selected: activo,
                        onSelected: (value) {
                          setModalState(() {
                            if (value) {
                              seleccion.add(dia);
                            } else {
                              seleccion.remove(dia);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, Set<String>.from(seleccion)),
                  child: const Text('Ver informe'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> cargarEjercicio() async {
    setState(() {
      caloriasEjercicio = calcularCaloriasRutinaActual().toInt();
      tiempoEjercicio = calcularTiempoRutinaActual();
    });
  }

  Future<void> _recargarDashboard() async {
    await cargarTodo();
    await cargarEjercicio();
    final premium = await cargarEstadoPremium();
    final prefs = await SharedPreferences.getInstance();
    final mostrarWidget =
        prefs.getBool(progressWidgetPrefsKey) ?? mostrarWidgetProgresoGlobal;

    if (!mounted) {
      return;
    }

    setState(() {
      _premiumActivado = premium;
      _mostrarWidgetProgreso = mostrarWidget;
      _aguaController.text = _aguaDeFecha(fechaActual).toStringAsFixed(2);
    });
  }

  Widget _externalWidgetSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: Color(0xFF0F766E),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Widget fuera de la app',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mostrarWidgetProgreso
                          ? 'Ya esta sincronizado para mostrarse fuera de la app con calorias, agua y pasos.'
                          : 'Activalo para tener un widget real en Android, fuera de la app y listo para agregar a la pantalla.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _mostrarWidgetProgreso,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF14B8A6),
                onChanged: _guardarPreferenciaWidgetProgreso,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Que hace',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Muestra calorias, agua y pasos fuera de la app. En dispositivos compatibles tambien puede verse con la pantalla bloqueada.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _instalarWidgetExterno,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.add_to_home_screen_rounded),
                  label: const Text('Agregar al telefono'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ExternalProgressWidgetService.syncFromPrefs,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: BorderSide(color: Colors.blueGrey.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Actualizar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _mostrarWidgetProgreso
                ? 'Si lo desactivas, el widget deja de sincronizarse y mostrara un estado pausado hasta que lo actives otra vez.'
                : 'Activalo y luego usa "Agregar al telefono" para fijarlo en tu pantalla principal.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _premiumHeroButton() {
    final titulo = _premiumActivado ? 'Premium activo' : 'Activa Premium';
    final subtitulo = _premiumActivado
        ? 'Informe inteligente, rutinas premium y recetas completas listas para usar.'
        : 'Desbloquea informe semanal IA, rutinas por objetivo y recetas completas.';

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: _abrirPremiumHub,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101828), Color(0xFF1D4ED8), Color(0xFF22C55E)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amberAccent,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _PremiumBadge(label: 'Informe semanal IA'),
                _PremiumBadge(label: 'Rutinas por objetivo'),
                _PremiumBadge(label: 'Recetas con macros'),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _abrirPremiumHub,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF101828),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _premiumActivado ? 'Ver Premium' : 'Descubrir Premium',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _initPages();
    _pageController = PageController(); // 👈 ESTA LÍNEA
    _aguaController = TextEditingController(
      text: aguaConsumida.toStringAsFixed(2),
    );
    pasosActuales = StepCounterService.instance.currentSteps;
    _stepsListener = () {
      if (!mounted) return;
      setState(() {
        pasosActuales = StepCounterService.instance.currentSteps;
      });
      ExternalProgressWidgetService.syncFromPrefs();
    };
    _dataListener = () {
      _recargarDashboard();
    };
    StepCounterService.instance.dailySteps.addListener(_stepsListener);
    AppDataSyncService.instance.refreshTick.addListener(_dataListener);
    _hoySistema = DateTime.now();
    fechaActual = DateTime(
      _hoySistema.year,
      _hoySistema.month,
      _hoySistema.day,
    );
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));

      await StepCounterService.instance.syncCurrentDay();
      await cargarTodo(); // 🔥 recarga datos
      await cargarEjercicio();

      if (!mounted) return false;
      setState(() {
        _hoySistema = DateTime.now();
        if (_viendoHoy) {
          fechaActual = DateTime(
            _hoySistema.year,
            _hoySistema.month,
            _hoySistema.day,
          );
        }
      });

      return true;
    });

    _recargarDashboard();
  }

  @override
  void dispose() {
    StepCounterService.instance.dailySteps.removeListener(_stepsListener);
    AppDataSyncService.instance.refreshTick.removeListener(_dataListener);
    _aguaController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> guardarAgua(double litros) async {
    final meta = calcularMetaAguaLitros();
    final double normalizado = litros.clamp(0, meta * 1.5).toDouble();

    setState(() {
      aguaConsumida = normalizado;
      aguaHistorialGlobal[fechaActualKey()] = aguaConsumida;
      _aguaController.text = aguaConsumida.toStringAsFixed(2);
    });

    await guardarTodo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fitAppPageBackgroundColor,
      body: _currentIndex == 0
          ? SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFDDF4FF), Color(0xFFF4FBFF)],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (user.name.isEmpty) {
                                  // 👉 Primera vez → formulario
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const UserForm(isFirstSetup: true),
                                    ),
                                  );
                                } else {
                                  // 👉 Ya tiene datos → perfil
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileScreen(),
                                    ),
                                  );
                                }

                                setState(() {});
                              },
                              child: avatarUsuario(radius: 21, fontSize: 16),
                            ),
                            const Spacer(),
                            const Text(
                              "NutrifynGo",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.smart_toy_outlined),
                              onPressed: () => abrirChatAsistenteIA(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none),
                              onPressed: _abrirInformeSemanal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _textoFechaSeleccionada(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _dateNavigator(),

                        // CALORIAS CARD
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: box(),
                          child: Column(
                            children: [
                              const Text(
                                "",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // SLIDER
                              SizedBox(
                                height: 220,
                                child: PageView(
                                  controller: _pageController,
                                  physics: const BouncingScrollPhysics(),
                                  onPageChanged: (index) {
                                    setState(() {
                                      page = index; // 🔥 ESTA ES LA CLAVE
                                    });
                                  },
                                  children: [
                                    buildCalories(),
                                    buildDailyDetailCard(),
                                    buildWaterTracker(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  3,
                                  (i) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: page == i
                                          ? Colors.blue
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // PASOS Y EJERCICIO
                        Row(
                          children: [
                            expandedCard(
                              color: Colors.pink,
                              icon: Icons.directions_walk,
                              title: "Pasos",
                              value: _pasosDeFecha(fechaActual).toString(),
                              subtitle: 'Objetivo: $_metaPasosWidget',
                            ),
                            expandedCard(
                              color: Colors.orange,
                              icon: Icons.local_fire_department,
                              title: "Ejercicio",
                              value:
                                  "${_caloriasEjercicioFecha(fechaActual)} cal",
                              subtitle:
                                  "${(_tiempoEjercicioFecha(fechaActual) ~/ 60).toString().padLeft(2, '0')}:${(_tiempoEjercicioFecha(fechaActual) % 60).toString().padLeft(2, '0')} h",
                              onTap: _viendoHoy ? _abrirRutinasDesdeCard : null,
                            ),
                          ],
                        ),

                        foodSection(),

                        // PESO
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: box(),
                          child: buildWeeklyStepsChart(),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: buildWellbeingSection(),
                        ),

                        _externalWidgetSection(),

                        _premiumHeroButton(),

                        const SizedBox(height: 200),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : _pages[_currentIndex],
    );
  }

  Widget buildCalories() {
    double meta = user.calories == 0 ? 2000 : user.calories;
    final comidasDia = _comidasDeFecha(fechaActual);
    final caloriasComida = _sumarCampoFecha(comidasDia, 'calorias');
    final proteinaDia = _sumarCampoFecha(comidasDia, 'proteina');
    final carbsDia = _sumarCampoFecha(comidasDia, 'carbs');
    final caloriasEjercicioActual = _caloriasEjercicioFecha(
      fechaActual,
    ).toDouble();
    double neto = caloriasComida - caloriasEjercicioActual;
    if (neto < 0) neto = 0;

    double progreso = neto / meta;
    if (progreso > 1) progreso = 1;

    final metaProteina = calcularMetaProteinaDiariaGramos();
    final metaCarbs = calcularMetaCarbsDiariosGramos();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Calorías",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 10),

        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: progreso,
                strokeWidth: 10,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.blueAccent,
                ),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (user.calories - neto).toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text("Restantes"),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _macroProgressBubble(
              title: 'Prot. restante',
              actual: proteinaDia,
              meta: metaProteina,
              color: Colors.blue,
            ),
            const SizedBox(width: 14),
            _macroProgressBubble(
              title: 'Carbos restantes',
              actual: carbsDia,
              meta: metaCarbs,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget buildDailyDetailCard() {
    final desayuno = _comidasDelDiaPorTipoFecha('Desayuno', fechaActual);
    final almuerzo = _comidasDelDiaPorTipoFecha('Almuerzo', fechaActual);
    final cena = _comidasDelDiaPorTipoFecha('Cena', fechaActual);
    final snack = _comidasDelDiaPorTipoFecha('Snack', fechaActual);
    final ejercicios = _ejerciciosDeFecha(fechaActual);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Tu día en detalle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          _dailySummaryMealBlock('Desayuno', desayuno, Colors.amber.shade100),
          const SizedBox(height: 10),
          _dailySummaryMealBlock('Almuerzo', almuerzo, Colors.orange.shade100),
          const SizedBox(height: 10),
          _dailySummaryMealBlock('Cena', cena, Colors.indigo.shade100),
          const SizedBox(height: 10),
          _dailySummaryMealBlock('Snack', snack, Colors.teal.shade100),
          const SizedBox(height: 10),
          _dailySummaryMetricTile(
            icon: Icons.fitness_center,
            title: 'Ejercicios de esta fecha',
            content: ejercicios.isEmpty
                ? 'Aún no hay ejercicios registrados en esta fecha.'
                : ejercicios.map((item) => item['nombre']).join(', '),
            footer:
                '${_caloriasEjercicioFecha(fechaActual)} kcal • ${_tiempoEjercicioFecha(fechaActual)} min',
            color: Colors.pink.shade50,
          ),
          const SizedBox(height: 10),
          _dailySummaryMetricTile(
            icon: Icons.local_drink,
            title: 'Agua tomada',
            content:
                '${_aguaDeFecha(fechaActual).toStringAsFixed(2)} L de ${calcularMetaAguaLitros().toStringAsFixed(2)} L',
            footer: _aguaDeFecha(fechaActual) >= calcularMetaAguaLitros()
                ? 'Meta de agua cumplida'
                : 'Sigue hidratándote',
            color: Colors.cyan.shade50,
          ),
          const SizedBox(height: 10),
          _dailySummaryMetricTile(
            icon: Icons.directions_walk,
            title: 'Pasos del día',
            content: '${_pasosDeFecha(fechaActual)} pasos registrados',
            footer: _pasosDeFecha(fechaActual) >= _metaPasosWidget
                ? 'Objetivo diario cumplido'
                : 'Objetivo sugerido: ${_metaPasosWidget.toStringAsFixed(0)} pasos',
            color: Colors.green.shade50,
          ),
        ],
      ),
    );
  }

  Widget buildWaterTracker() {
    final metaAgua = calcularMetaAguaLitros();
    final aguaDelDia = _aguaDeFecha(fechaActual);
    final double progresoAgua = metaAgua == 0
        ? 0.0
        : (aguaDelDia / metaAgua).clamp(0.0, 1.0).toDouble();
    final double faltante = (metaAgua - aguaDelDia)
        .clamp(0.0, metaAgua)
        .toDouble();
    final metaCumplida = aguaDelDia >= metaAgua;
    final colorAgua = metaCumplida ? Colors.green : Colors.lightBlueAccent;
    final colorTexto = metaCumplida ? Colors.green.shade700 : Colors.blueAccent;
    final historial = aguaHistorialGlobal.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final historialReciente = historial.take(5).toList();

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Agua",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 92,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: metaCumplida ? Colors.green : Colors.blueGrey,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: metaCumplida
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        color: metaCumplida
                            ? Colors.green.shade50
                            : Colors.blueGrey.shade50,
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 92 * progresoAgua,
                        decoration: BoxDecoration(
                          color: colorAgua,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_drink, color: colorTexto, size: 18),
                          Text(
                            '${(progresoAgua * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorTexto,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta: ${metaAgua.toStringAsFixed(2)} L',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Llevas: ${aguaDelDia.toStringAsFixed(2)} L',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Faltan: ${faltante.toStringAsFixed(2)} L',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (metaCumplida) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Meta cumplida',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextField(
                      controller: _aguaController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: _viendoHoy,
                      decoration: InputDecoration(
                        labelText: _viendoHoy
                            ? 'Litros consumidos'
                            : 'Historial del día',
                        hintText: '1.25',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (value) async {
                        final litros = double.tryParse(
                          value.replaceAll(',', '.'),
                        );
                        if (litros == null) return;
                        await guardarAgua(litros);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: _viendoHoy
                    ? () => guardarAgua(aguaConsumida + 0.25)
                    : null,
                child: const Text('+0.25 L', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                onPressed: _viendoHoy
                    ? () => guardarAgua(aguaConsumida + 0.50)
                    : null,
                child: const Text('+0.50 L', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _viendoHoy ? () => guardarAgua(0) : null,
                child: const Text('Reiniciar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Historial reciente',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (historialReciente.isEmpty)
            const Text(
              'Aun no hay historial de agua.',
              style: TextStyle(fontSize: 12),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: historialReciente.map((entry) {
                  final esHoy = entry.key == fechaActualKey();
                  final esFechaSeleccionada =
                      entry.key == _fechaSeleccionadaKey ||
                      entry.key == fechaKeyPadded(fechaActual);
                  final metaCumplidaDia = entry.value >= metaAgua;
                  return Container(
                    width: 78,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: metaCumplidaDia
                          ? Colors.green.shade50
                          : esHoy
                          ? Colors.blue.shade50
                          : esFechaSeleccionada
                          ? Colors.indigo.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: metaCumplidaDia
                            ? Colors.green.shade300
                            : esHoy
                            ? Colors.blue.shade200
                            : esFechaSeleccionada
                            ? Colors.indigo.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatearFechaHistorial(entry.key),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.water_drop,
                          color: metaCumplidaDia
                              ? Colors.green
                              : Colors.lightBlue,
                          size: 18,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.value.toStringAsFixed(2)} L',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          metaCumplidaDia ? Icons.check_circle : Icons.cancel,
                          color: metaCumplidaDia
                              ? Colors.green
                              : Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          metaCumplidaDia ? 'Cumplida' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: metaCumplidaDia
                                ? Colors.green.shade800
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildWeeklyStepsChart() {
    final weeklyHistory = StepCounterService.instance.getLast7DaysHistory();
    final maxSteps = weeklyHistory
        .map((entry) => entry.value)
        .fold<int>(
          10000,
          (maxValue, value) => value > maxValue ? value : maxValue,
        );
    final double topValue = ((maxSteps / 2000).ceil() * 2000)
        .clamp(2000, 30000)
        .toDouble();
    final totalSteps = weeklyHistory.fold<int>(
      0,
      (total, entry) => total + entry.value,
    );
    final averageSteps = totalSteps / weeklyHistory.length;
    final bestDay = weeklyHistory.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial de pasos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text('Ultimos 7 dias', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topValue,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: topValue / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
                },
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: topValue / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= weeklyHistory.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _nombreCortoDia(weeklyHistory[index].key.weekday),
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: weeklyHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final steps = entry.value.value.toDouble();
                final isToday = _esMismaFecha(entry.value.key, DateTime.now());
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: steps,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                      color: isToday ? Colors.pinkAccent : Colors.blueAccent,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: topValue,
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _weeklyStatCard(
                'Promedio',
                averageSteps.toStringAsFixed(0),
                Colors.pink.shade50,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _weeklyStatCard(
                'Mejor dia',
                '${_nombreCortoDia(bestDay.key.weekday)} ${bestDay.value}',
                Colors.blue.shade50,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildWellbeingSection() {
    final respuestas = _bienestarHoy;
    final respondido = respuestas.length == bienestarPreguntas.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F8FF)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.favorite, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¿Cómo te sientes hoy?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: _editarBienestarHoy,
                child: Text(respondido ? 'Editar' : 'Responder'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            respondido
                ? 'Tus respuestas de hoy quedaron guardadas. Puedes editarlas cuando quieras.'
                : 'Responde estas 6 preguntas una vez al día y guarda tu estado emocional y físico.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (!respondido)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: bienestarPreguntas.map((pregunta) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '• ${pregunta["pregunta"]}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Column(
              children: bienestarPreguntas.map((pregunta) {
                final preguntaId = pregunta['id'] as String;
                final respuesta = respuestas[preguntaId] ?? 'Sin respuesta';
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pregunta['pregunta'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          respuesta,
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _weeklyStatCard(String title, String value, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _nombreCortoDia(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'M';
      case DateTime.wednesday:
        return 'X';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      default:
        return 'D';
    }
  }

  bool _esMismaFecha(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatearFechaHistorial(String fecha) {
    final partes = fecha.split('-');
    if (partes.length != 3) {
      return fecha;
    }

    final year = int.tryParse(partes[0]);
    final month = int.tryParse(partes[1]);
    final day = int.tryParse(partes[2]);
    if (year == null || month == null || day == null) {
      return fecha;
    }

    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}';
  }

  Widget macroData(String title, double value, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            value.toStringAsFixed(0),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        Text(title),
      ],
    );
  }

  Widget _macroProgressBubble({
    required String title,
    required double actual,
    required double meta,
    required Color color,
  }) {
    final progress = meta <= 0
        ? 0.0
        : (actual / meta).clamp(0.0, 1.0).toDouble();
    final restante = (meta - actual).clamp(0.0, double.infinity).toDouble();

    return Column(
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                restante.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12)),
        Text(
          '${actual.toStringAsFixed(0)}/${meta.toStringAsFixed(0)} g',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _dailySummaryMealBlock(
    String title,
    List<Map<String, dynamic>> items,
    Color color,
  ) {
    final nombres = items.isEmpty
        ? 'Sin alimentos registrados'
        : items.map((item) => item['nombre']).join(', ');
    final calorias = items.fold<double>(
      0,
      (total, item) => total + ((item['calorias'] ?? 0) as num).toDouble(),
    );

    return _dailySummaryMetricTile(
      icon: Icons.restaurant_menu,
      title: title,
      content: nombres,
      footer: '${calorias.toStringAsFixed(0)} kcal • ${items.length} alimentos',
      color: color,
    );
  }

  Widget _dailySummaryMetricTile({
    required IconData icon,
    required String title,
    required String content,
    required String footer,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(content, style: TextStyle(color: Colors.grey.shade800)),
                const SizedBox(height: 6),
                Text(
                  footer,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget macroCircle(String text, Color color) {
    return Column(
      children: [
        CircleAvatar(radius: 30, backgroundColor: color),
        const SizedBox(height: 6),
        Text(text),
      ],
    );
  }

  Widget expandedCard({
    required Color color,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: box(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(title),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget foodSection() {
    final comidasDia = _comidasDeFecha(fechaActual);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B5CAD), Color(0xFF7EC5FF)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alimentación diaria',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Toca un alimento para ajustar gramos, onzas o unidades y ver sus macros exactos antes de agregarlo.',
                            style: TextStyle(color: Colors.white, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComidasScreen(),
                          ),
                        );
                        if (!mounted) return;
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Ver todo'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _macroPill(
                        'Total calorías',
                        '${_sumarCampoFecha(comidasDia, 'calorias').toStringAsFixed(0)} kcal',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _macroPill(
                        'Proteína',
                        '${_sumarCampoFecha(comidasDia, 'proteina').toStringAsFixed(0)} g',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _macroPill(
                        'Carbos',
                        '${_sumarCampoFecha(comidasDia, 'carbs').toStringAsFixed(0)} g',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _tarjetaComidaPrincipal('Desayuno'),
          _tarjetaComidaPrincipal('Almuerzo'),
          _tarjetaComidaPrincipal('Cena'),
          _tarjetaComidaPrincipal('Snack'),
        ],
      ),
    );
  }

  Widget foodItem(
    BuildContext context, {
    required String title,
    required String kcal,
    required String subtitle,
    required IconData icon,
    required bool active,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔥 FILA PRINCIPAL
          Row(
            children: [
              // ICONO
              CircleAvatar(
                radius: 25,
                backgroundColor: colorParaTipoComida(title),
                child: Icon(icon, color: Colors.black87, size: 28),
              ),

              const SizedBox(width: 12),

              // TEXTO
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
                    if (kcal.isNotEmpty)
                      Text(kcal, style: const TextStyle(color: Colors.grey)),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              /// 🔥 BOTÓN +
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),

                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoriaScreen(titulo: title),
                      ),
                    );

                    if (!mounted) return;
                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          /// 🔥 COMIDAS AGREGADAS (DEBAJO)
          if (title == "Desayuno")
            ...obtenerAlimentosRegistradosPorTipo(
              "Desayuno",
            ).map((item) => comidaAgregadaItem(item)),

          if (title == "Almuerzo")
            ...obtenerAlimentosRegistradosPorTipo(
              "Almuerzo",
            ).map((item) => comidaAgregadaItem(item)),

          if (title == "Cena")
            ...obtenerAlimentosRegistradosPorTipo(
              "Cena",
            ).map((item) => comidaAgregadaItem(item)),

          if (title == "Snack")
            ...obtenerAlimentosRegistradosPorTipo(
              "Snack",
            ).map((item) => comidaAgregadaItem(item)),
        ],
      ),
    );
  }

  Widget divider() {
    return Divider(color: Colors.grey.shade200, thickness: 1, height: 0);
  }

  BoxDecoration box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)],
    );
  }

  Widget bottomBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: "Comidas"),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: "Rutinas",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Objetivos"),
      ],
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,

      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,

      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        // 👉 CUANDO TOCA "COMIDAS"
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComidasScreen()),
          );
        }

        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RutinasScreen()),
          );
          cargarEjercicio();
        }
      },
    );
  }
}

class CategoriaScreenListView extends StatelessWidget {
  final String titulo;

  const CategoriaScreenListView({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(child: Text("Comidas de $titulo")),
    );
  }
}

class ComidasScreen extends StatefulWidget {
  const ComidasScreen({super.key});

  @override
  State<ComidasScreen> createState() => _ComidasScreenState();
}

class _ComidasScreenState extends State<ComidasScreen> {
  final List<Map<String, dynamic>> comidas = const [
    {
      'titulo': 'Desayuno',
      'icono': Icons.breakfast_dining,
      'color': Color(0xFFFFF1C9),
    },
    {
      'titulo': 'Almuerzo',
      'icono': Icons.lunch_dining,
      'color': Color(0xFFFFE1D6),
    },
    {
      'titulo': 'Cena',
      'icono': Icons.dinner_dining,
      'color': Color(0xFFDDE8FF),
    },
    {'titulo': 'Snack', 'icono': Icons.icecream, 'color': Color(0xFFD7F6E8)},
  ];

  Future<void> _abrirCategoria(String tipo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoriaScreen(titulo: tipo)),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editarPorcion(Map<String, dynamic> item) async {
    final actualizado = await mostrarDialogoPorcionAlimento(
      context,
      alimento: item,
      tipo: normalizarTipoComida(item['comidaTipo']?.toString()),
      editando: true,
    );
    if (!mounted || actualizado == null) return;

    setState(() {
      final indice = canastaGlobal.indexWhere(
        (actual) =>
            actual['basketId']?.toString() ==
            actualizado['basketId']?.toString(),
      );
      if (indice >= 0) {
        canastaGlobal[indice] = actualizado;
      }
      normalizarCanastaGlobal();
    });
    await guardarTodo();
  }

  Widget _resumenGeneral() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F6CBD), Color(0xFF4CA9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan diario de comidas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Busca alimentos reales o crea uno manual con calorías, proteína y carbohidratos.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final tipo = await seleccionarTipoComida(context);
                    if (!mounted || tipo == null) return;
                    await _abrirCategoria(tipo);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final tipo = await seleccionarTipoComida(context);
                    if (!mounted || tipo == null) return;
                    final nuevo = await mostrarDialogoCrearAlimento(
                      context,
                      tipo,
                    );
                    if (!mounted || nuevo == null) return;

                    final alimento = normalizarAlimentoCatalogo(nuevo);
                    final indiceExistente = alimentosPersonalizadosGlobal
                        .indexWhere(
                          (item) =>
                              claveAlimento(item['nombre'] as String) ==
                              claveAlimento(alimento['nombre'] as String),
                        );
                    setState(() {
                      if (indiceExistente >= 0) {
                        alimentosPersonalizadosGlobal[indiceExistente] =
                            alimento;
                      } else {
                        alimentosPersonalizadosGlobal.add(alimento);
                      }
                      canastaGlobal.add(crearRegistroCanasta(alimento, tipo));
                      normalizarCanastaGlobal();
                    });
                    await guardarTodo();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F6CBD),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _macroMiniCard(
                  'Calorías',
                  '${caloriasConsumidas.toStringAsFixed(0)} kcal',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _macroMiniCard(
                  'Proteína',
                  '${proteinaConsumida.toStringAsFixed(0)} g',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _macroMiniCard(
                  'Carbos',
                  '${carbsConsumidos.toStringAsFixed(0)} g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroMiniCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comidaCard(Map<String, dynamic> data) {
    final titulo = data['titulo'] as String;
    final color = data['color'] as Color;
    final icono = data['icono'] as IconData;
    final items = obtenerAlimentosRegistradosPorTipo(titulo);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icono, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${calcularCalorias(titulo).toStringAsFixed(0)} kcal • P ${calcularProteina(titulo).toStringAsFixed(0)} g • C ${calcularCarbs(titulo).toStringAsFixed(0)} g',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _abrirCategoria(titulo),
                icon: const Icon(Icons.add_circle, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No has agregado alimentos en $titulo todavía.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            ...items.take(4).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.33),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorParaTipoComida(
                          titulo,
                        ).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconoParaAlimento(item['nombre'].toString()),
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _editarPorcion(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['nombre'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resumenPorcionAlimento(item),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resumenAlimento(item),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          eliminarAlimentoDeCanasta(item);
                        });
                        guardarTodo();
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              );
            }),
          if (items.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${items.length - 4} alimentos más',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _abrirCategoria(titulo),
              icon: const Icon(Icons.search),
              label: const Text('Buscar o crear alimento'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fitAppPageBackgroundColor,
      appBar: AppBar(
        backgroundColor: fitAppPageBackgroundColor,
        elevation: 0,
        title: const Text("Comidas", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined, color: Colors.black),
            onPressed: () => abrirChatAsistenteIA(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            onPressed: () => _abrirCategoria('Snack'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _resumenGeneral(),
            const SizedBox(height: 16),
            ...comidas.map(_comidaCard),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class CategoriaScreen extends StatefulWidget {
  final String titulo;

  const CategoriaScreen({super.key, required this.titulo});

  @override
  State<CategoriaScreen> createState() => _CategoriaScreenState();
}

class _CategoriaScreenState extends State<CategoriaScreen> {
  late final TextEditingController _busquedaController;
  List<Map<String, dynamic>> comidas = [];
  bool _guardando = false;

  String get tipoActual => normalizarTipoComida(widget.titulo);

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController();
    _refrescarListado();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _refrescarListado() {
    final termino = _busquedaController.text.trim().toLowerCase();
    final base = obtenerCatalogoAlimentos(tipoActual);

    comidas = base.where((item) {
      if (termino.isEmpty) return true;
      return (item['nombre'] as String).toLowerCase().contains(termino);
    }).toList();

    if (mounted) {
      setState(() {});
    }
  }

  int _cantidadAgregada(String nombre) {
    return obtenerAlimentosRegistradosPorTipo(tipoActual)
        .where(
          (item) =>
              claveAlimento(item['nombre'] as String) == claveAlimento(nombre),
        )
        .length;
  }

  Future<void> _agregarAlimento(Map<String, dynamic> registro) async {
    setState(() {
      _guardando = true;
    });

    canastaGlobal.add(registro);
    normalizarCanastaGlobal();
    await guardarTodo();

    if (!mounted) return;
    setState(() {
      _guardando = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${registro['nombre']} agregado a $tipoActual')),
    );
  }

  Future<void> _seleccionarPorcionYAgregar(
    Map<String, dynamic> alimento,
  ) async {
    final registro = await mostrarDialogoPorcionAlimento(
      context,
      alimento: alimento,
      tipo: tipoActual,
    );
    if (!mounted || registro == null) return;
    await _agregarAlimento(registro);
  }

  Future<void> _crearAlimentoManual() async {
    final nuevo = await mostrarDialogoCrearAlimento(context, tipoActual);
    if (nuevo == null) return;

    final alimento = normalizarAlimentoCatalogo(nuevo);
    final indiceExistente = alimentosPersonalizadosGlobal.indexWhere(
      (item) =>
          claveAlimento(item['nombre'] as String) ==
          claveAlimento(alimento['nombre'] as String),
    );

    if (indiceExistente >= 0) {
      alimentosPersonalizadosGlobal[indiceExistente] = alimento;
    } else {
      alimentosPersonalizadosGlobal.add(alimento);
    }

    _refrescarListado();
    await _seleccionarPorcionYAgregar(alimento);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fitAppPageBackgroundColor,
      appBar: AppBar(
        backgroundColor: fitAppPageBackgroundColor,
        title: Text('Buscar en $tipoActual'),
        actions: [
          TextButton.icon(
            onPressed: _crearAlimentoManual,
            icon: const Icon(Icons.edit_note),
            label: const Text('Crear'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _busquedaController,
              onChanged: (_) => _refrescarListado(),
              decoration: InputDecoration(
                hintText: 'Buscar alimento',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: comidas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 56),
                          const SizedBox(height: 12),
                          const Text(
                            'No encontré ese alimento.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Puedes crearlo manualmente con sus calorías, proteína y carbohidratos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _crearAlimentoManual,
                            icon: const Icon(Icons.add),
                            label: const Text('Crear alimento'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: comidas.length,
                    separatorBuilder: (_, separatorIndex) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = comidas[index];
                      final cantidad = _cantidadAgregada(
                        item['nombre'] as String,
                      );

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colorParaTipoComida(tipoActual),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    iconoParaAlimento(
                                      item['nombre'].toString(),
                                    ),
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _guardando
                                        ? null
                                        : () =>
                                              _seleccionarPorcionYAgregar(item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        item['nombre'],
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (cantidad > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$cantidad agregados',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${formatearMacro(item['calorias'])} kcal • P ${formatearMacro(item['proteina'])} g • C ${formatearMacro(item['carbs'])} g • Ref ${formatearMacro(gramosReferenciaAlimento(item))} g',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _guardando
                                    ? null
                                    : () => _seleccionarPorcionYAgregar(item),
                                icon: const Icon(Icons.tune),
                                label: const Text('Elegir porción y agregar'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearAlimentoManual,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Nuevo alimento'),
      ),
    );
  }
}

class RutinasScreen extends StatefulWidget {
  const RutinasScreen({super.key});

  @override
  State<RutinasScreen> createState() => _RutinasScreenState();
}

class _RutinasScreenState extends State<RutinasScreen> {
  final Map<String, bool> _diasExpandidos = {};

  bool _esDiaActual(String dia) {
    return dia == nombreDiaCompleto(DateTime.now().weekday);
  }

  void _sincronizarHistorialEjerciciosHoy(String dia) {
    if (!_esDiaActual(dia)) return;
    ejerciciosHistorialGlobal[fechaActualKey()] = copiarListaMapas(
      rutinaGlobal[dia] ?? <Map<String, dynamic>>[],
    );
  }

  int caloriasDia(String dia) {
    return rutinaGlobal[dia]!.fold(
      0,
      (total, e) => total + ((e["cal"] ?? 0) as num).toInt(),
    );
  }

  int minutosDia(String dia) {
    return rutinaGlobal[dia]!.fold(
      0,
      (total, e) => total + obtenerMinutosRutina(e),
    );
  }

  List<Color> _gradienteDia(String dia) {
    switch (dia) {
      case 'Lunes':
        return const [Color(0xFF0F4C81), Color(0xFF5BA8FF)];
      case 'Martes':
        return const [Color(0xFF7A3419), Color(0xFFFF9D63)];
      case 'Miércoles':
        return const [Color(0xFF14532D), Color(0xFF4ADE80)];
      case 'Jueves':
        return const [Color(0xFF5B21B6), Color(0xFFC084FC)];
      case 'Viernes':
        return const [Color(0xFF9A3412), Color(0xFFF97316)];
      case 'Sábado':
        return const [Color(0xFF164E63), Color(0xFF22D3EE)];
      default:
        return const [Color(0xFF334155), Color(0xFF94A3B8)];
    }
  }

  IconData _iconoDiaSemana(String dia) {
    switch (dia) {
      case 'Lunes':
        return Icons.rocket_launch;
      case 'Martes':
        return Icons.local_fire_department;
      case 'Miércoles':
        return Icons.sports_gymnastics;
      case 'Jueves':
        return Icons.bolt;
      case 'Viernes':
        return Icons.fitness_center;
      case 'Sábado':
        return Icons.workspace_premium;
      default:
        return Icons.calendar_today;
    }
  }

  Widget _metricaRutina(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewEjercicio(Map<String, dynamic> ejercicio) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => mostrarDetalleEjercicio(context, ejercicio),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconoParaEjercicio(ejercicio), size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              ejercicio['nombre'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ejercicioExpandido(String dia, Map<String, dynamic> item) {
    final ejerciciosDia = rutinaGlobal[dia]!;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => mostrarDetalleEjercicio(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                iconoParaEjercicio(item),
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['nombre'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item["cal"]} kcal • ${detalleEjercicio(item)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toca para ver cómo se hace',
                    style: TextStyle(
                      color: Colors.blueGrey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                setState(() {
                  ejerciciosDia.remove(item);
                  _sincronizarHistorialEjerciciosHoy(dia);
                });
                await guardarTodo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardDiaSemana(String dia) {
    final ejerciciosDia = rutinaGlobal[dia]!;
    final calorias = caloriasDia(dia);
    final minutos = minutosDia(dia);
    final expandido = _diasExpandidos[dia] ?? false;
    final gradiente = _gradienteDia(dia);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradiente,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: gradiente.first.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(_iconoDiaSemana(dia), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dia,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ejerciciosDia.isEmpty
                            ? 'No hay ejercicios cargados para este día.'
                            : 'Semana activa con ${ejerciciosDia.length} ejercicios listos.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    FilledButton(
                      onPressed: () => agregarEjercicio(dia),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Agregar'),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _diasExpandidos[dia] = !expandido;
                        });
                      },
                      icon: Icon(
                        expandido
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _metricaRutina('Calorías', '$calorias kcal'),
                const SizedBox(width: 10),
                _metricaRutina('Minutos', '$minutos min'),
                const SizedBox(width: 10),
                _metricaRutina('Ejercicios', '${ejerciciosDia.length}'),
              ],
            ),
            const SizedBox(height: 14),
            if (ejerciciosDia.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Crea una sesión espectacular agregando ejercicios para este día.',
                  style: TextStyle(color: Colors.white, height: 1.3),
                ),
              )
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ejerciciosDia
                      .take(3)
                      .map(_previewEjercicio)
                      .toList(),
                ),
              ),
              if (ejerciciosDia.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${ejerciciosDia.length - 3} ejercicios más',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              crossFadeState: expandido
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: ejerciciosDia.isEmpty
                      ? [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Text('No hay ejercicios agregados.'),
                          ),
                        ]
                      : ejerciciosDia
                            .map((item) => _ejercicioExpandido(dia, item))
                            .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> agregarEjercicio(String dia) async {
    final item = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => EjerciciosScreen(dia: dia)),
    );

    if (item != null) {
      final ejercicio = Map<String, dynamic>.from(item);

      setState(() {
        rutinaGlobal[dia]!.add(ejercicio);
        _sincronizarHistorialEjerciciosHoy(dia);
      });

      await guardarTodo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = rutinaGlobal.keys.toList();
    final totalCalorias = dias.fold<int>(
      0,
      (total, dia) => total + caloriasDia(dia),
    );
    final totalMinutos = dias.fold<int>(
      0,
      (total, dia) => total + minutosDia(dia),
    );
    final totalEjercicios = dias.fold<int>(
      0,
      (total, dia) => total + rutinaGlobal[dia]!.length,
    );

    return Scaffold(
      backgroundColor: fitAppPageBackgroundColor,
      appBar: AppBar(
        title: const Text("Rutinas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => abrirChatAsistenteIA(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B3B8C), Color(0xFF4EA8FF)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu semana de entrenamiento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cada día ahora vive en una card más potente, visual y fácil de revisar.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _metricaRutina('Semana kcal', '$totalCalorias'),
                    const SizedBox(width: 10),
                    _metricaRutina('Semana min', '$totalMinutos'),
                    const SizedBox(width: 10),
                    _metricaRutina('Total ejercicios', '$totalEjercicios'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...dias.map(_cardDiaSemana),
        ],
      ),
    );
  }
}

class EjerciciosScreen extends StatefulWidget {
  final String dia;

  const EjerciciosScreen({super.key, required this.dia});

  @override
  State<EjerciciosScreen> createState() => _EjerciciosScreenState();
}

class _EjerciciosScreenState extends State<EjerciciosScreen> {
  String categoriaSeleccionada = "Brazo";
  final TextEditingController _busquedaController = TextEditingController();
  String _busqueda = '';

  final List<String> categorias = [
    "Brazo",
    "Pierna",
    "Abdomen",
    "Glúteo",
    "Bajar peso",
    "Tonificar",
  ];

  List<Map<String, dynamic>> ejercicios(String tipo) {
    List<Map<String, dynamic>> base = [
      // 🟦 BRAZO
      {
        "nombre": "Curl de bíceps",
        "tipo": "Brazo",
        "cal": 80,
        "tiempo": "10 min",
      },
      {"nombre": "Flexiones", "tipo": "Brazo", "cal": 100, "tiempo": "10 min"},
      {
        "nombre": "Fondos en silla",
        "tipo": "Brazo",
        "cal": 90,
        "tiempo": "10 min",
      },
      {
        "nombre": "Tríceps con mancuerna",
        "tipo": "Brazo",
        "cal": 85,
        "tiempo": "10 min",
      },
      {
        "nombre": "Plancha con brazos",
        "tipo": "Brazo",
        "cal": 70,
        "tiempo": "8 min",
      },
      {
        "nombre": "Curl martillo",
        "tipo": "Brazo",
        "cal": 80,
        "tiempo": "10 min",
      },
      {
        "nombre": "Flexiones diamante",
        "tipo": "Brazo",
        "cal": 110,
        "tiempo": "10 min",
      },
      {
        "nombre": "Extensión de tríceps",
        "tipo": "Brazo",
        "cal": 90,
        "tiempo": "10 min",
      },
      {
        "nombre": "Remo con mancuerna",
        "tipo": "Brazo",
        "cal": 95,
        "tiempo": "12 min",
      },
      {
        "nombre": "Flexiones inclinadas",
        "tipo": "Brazo",
        "cal": 85,
        "tiempo": "10 min",
      },

      // 🟥 PIERNA
      {
        "nombre": "Sentadillas",
        "tipo": "Pierna",
        "cal": 120,
        "tiempo": "12 min",
      },
      {"nombre": "Zancadas", "tipo": "Pierna", "cal": 110, "tiempo": "12 min"},
      {
        "nombre": "Prensa de piernas",
        "tipo": "Pierna",
        "cal": 130,
        "tiempo": "12 min",
      },
      {
        "nombre": "Elevación de talones",
        "tipo": "Pierna",
        "cal": 90,
        "tiempo": "10 min",
      },
      {
        "nombre": "Sentadilla sumo",
        "tipo": "Pierna",
        "cal": 120,
        "tiempo": "12 min",
      },
      {
        "nombre": "Peso muerto",
        "tipo": "Pierna",
        "cal": 140,
        "tiempo": "12 min",
      },
      {"nombre": "Step ups", "tipo": "Pierna", "cal": 110, "tiempo": "12 min"},
      {
        "nombre": "Saltos de sentadilla",
        "tipo": "Pierna",
        "cal": 150,
        "tiempo": "10 min",
      },
      {
        "nombre": "Extensión de piernas",
        "tipo": "Pierna",
        "cal": 100,
        "tiempo": "10 min",
      },
      {
        "nombre": "Curl femoral",
        "tipo": "Pierna",
        "cal": 100,
        "tiempo": "10 min",
      },

      // 🟨 ABDOMEN
      {"nombre": "Crunch", "tipo": "Abdomen", "cal": 80, "tiempo": "10 min"},
      {"nombre": "Plancha", "tipo": "Abdomen", "cal": 70, "tiempo": "8 min"},
      {
        "nombre": "Elevaciones de piernas",
        "tipo": "Abdomen",
        "cal": 90,
        "tiempo": "10 min",
      },
      {
        "nombre": "Bicicleta abdominal",
        "tipo": "Abdomen",
        "cal": 100,
        "tiempo": "10 min",
      },
      {
        "nombre": "Russian twist",
        "tipo": "Abdomen",
        "cal": 85,
        "tiempo": "10 min",
      },
      {
        "nombre": "Mountain climbers",
        "tipo": "Abdomen",
        "cal": 120,
        "tiempo": "10 min",
      },
      {
        "nombre": "Plancha lateral",
        "tipo": "Abdomen",
        "cal": 70,
        "tiempo": "8 min",
      },
      {"nombre": "V-ups", "tipo": "Abdomen", "cal": 95, "tiempo": "10 min"},
      {
        "nombre": "Toe touches",
        "tipo": "Abdomen",
        "cal": 85,
        "tiempo": "10 min",
      },
      {
        "nombre": "Crunch inverso",
        "tipo": "Abdomen",
        "cal": 90,
        "tiempo": "10 min",
      },

      // 🟩 GLÚTEO
      {
        "nombre": "Hip thrust",
        "tipo": "Glúteo",
        "cal": 130,
        "tiempo": "12 min",
      },
      {
        "nombre": "Puente de glúteo",
        "tipo": "Glúteo",
        "cal": 100,
        "tiempo": "10 min",
      },
      {
        "nombre": "Patada de glúteo",
        "tipo": "Glúteo",
        "cal": 95,
        "tiempo": "10 min",
      },
      {
        "nombre": "Sentadilla búlgara",
        "tipo": "Glúteo",
        "cal": 140,
        "tiempo": "12 min",
      },
      {
        "nombre": "Abducciones",
        "tipo": "Glúteo",
        "cal": 90,
        "tiempo": "10 min",
      },
      {
        "nombre": "Fire hydrant",
        "tipo": "Glúteo",
        "cal": 85,
        "tiempo": "10 min",
      },
      {
        "nombre": "Peso muerto rumano",
        "tipo": "Glúteo",
        "cal": 140,
        "tiempo": "12 min",
      },
      {
        "nombre": "Step ups glúteo",
        "tipo": "Glúteo",
        "cal": 120,
        "tiempo": "12 min",
      },
      {
        "nombre": "Donkey kicks",
        "tipo": "Glúteo",
        "cal": 90,
        "tiempo": "10 min",
      },
      {
        "nombre": "Sentadilla profunda",
        "tipo": "Glúteo",
        "cal": 130,
        "tiempo": "12 min",
      },

      // 🔥 BAJAR PESO
      {
        "nombre": "Correr",
        "tipo": "Bajar peso",
        "cal": 200,
        "tiempo": "20 min",
      },
      {
        "nombre": "Saltar cuerda",
        "tipo": "Bajar peso",
        "cal": 220,
        "tiempo": "15 min",
      },
      {
        "nombre": "Burpees",
        "tipo": "Bajar peso",
        "cal": 180,
        "tiempo": "10 min",
      },
      {
        "nombre": "Jumping jacks",
        "tipo": "Bajar peso",
        "cal": 150,
        "tiempo": "10 min",
      },
      {"nombre": "HIIT", "tipo": "Bajar peso", "cal": 250, "tiempo": "20 min"},
      {
        "nombre": "Escaladora",
        "tipo": "Bajar peso",
        "cal": 200,
        "tiempo": "15 min",
      },
      {
        "nombre": "Bicicleta",
        "tipo": "Bajar peso",
        "cal": 180,
        "tiempo": "20 min",
      },
      {
        "nombre": "Natación",
        "tipo": "Bajar peso",
        "cal": 220,
        "tiempo": "20 min",
      },
      {
        "nombre": "Caminata rápida",
        "tipo": "Bajar peso",
        "cal": 120,
        "tiempo": "20 min",
      },
      {"nombre": "Boxeo", "tipo": "Bajar peso", "cal": 230, "tiempo": "15 min"},

      // 🎯 TONIFICAR
      {
        "nombre": "Circuito full body",
        "tipo": "Tonificar",
        "cal": 180,
        "tiempo": "20 min",
      },
      {
        "nombre": "Pesas ligeras",
        "tipo": "Tonificar",
        "cal": 120,
        "tiempo": "15 min",
      },
      {
        "nombre": "Pilates",
        "tipo": "Tonificar",
        "cal": 140,
        "tiempo": "20 min",
      },
      {"nombre": "Yoga", "tipo": "Tonificar", "cal": 120, "tiempo": "20 min"},
      {
        "nombre": "Resistencia con bandas",
        "tipo": "Tonificar",
        "cal": 130,
        "tiempo": "15 min",
      },
      {
        "nombre": "Entrenamiento funcional",
        "tipo": "Tonificar",
        "cal": 170,
        "tiempo": "20 min",
      },
      {"nombre": "TRX", "tipo": "Tonificar", "cal": 180, "tiempo": "20 min"},
      {
        "nombre": "Core completo",
        "tipo": "Tonificar",
        "cal": 150,
        "tiempo": "15 min",
      },
      {
        "nombre": "Balance training",
        "tipo": "Tonificar",
        "cal": 130,
        "tiempo": "15 min",
      },
      {
        "nombre": "Movilidad",
        "tipo": "Tonificar",
        "cal": 100,
        "tiempo": "15 min",
      },
    ];

    return base.where((e) => e["tipo"] == tipo).toList();
  }

  Future<void> guardarRutina() async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString("rutina", jsonEncode(rutinaGlobal));
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _ejerciciosFiltrados() {
    final base = ejercicios(categoriaSeleccionada);
    if (_busqueda.trim().isEmpty) return base;

    final texto = _busqueda.toLowerCase();
    return base.where((item) {
      final nombre = item['nombre']?.toString().toLowerCase() ?? '';
      return nombre.contains(texto);
    }).toList();
  }

  Widget _heroSelector() {
    final colores = coloresCategoriaEjercicio(categoriaSeleccionada);
    final total = ejercicios(categoriaSeleccionada).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colores,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colores.first.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Agregar a ${widget.dia}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  categoriaSeleccionada,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explora una selección más visual de ejercicios, toca cualquiera para ver la guía y agrégalo en un paso.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 98,
            height: 128,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconoParaCategoriaEjercicio(categoriaSeleccionada),
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'opciones',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriaChip(String categoria) {
    final selected = categoria == categoriaSeleccionada;
    final colores = coloresCategoriaEjercicio(categoria);

    return GestureDetector(
      onTap: () {
        setState(() {
          categoriaSeleccionada = categoria;
          _busqueda = '';
          _busquedaController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: colores) : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.blueGrey.shade100,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colores.first.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconoParaCategoriaEjercicio(categoria),
              size: 18,
              color: selected ? Colors.white : colores.first,
            ),
            const SizedBox(width: 8),
            Text(
              categoria,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(Map<String, dynamic> item) {
    final colores = coloresCategoriaEjercicio(item['tipo']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, colores.last.withValues(alpha: 0.18)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            mostrarDetalleEjercicio(
              context,
              item,
              textoAccion: 'Agregar a ${widget.dia}',
              onAccion: () {
                Navigator.pop(context, item);
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colores),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        iconoParaEjercicio(item),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nombre'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            descripcionEjercicioVisual(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, item),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _selectorMetricChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${item['cal']} kcal',
                      color: const Color(0xFFEA580C),
                    ),
                    _selectorMetricChip(
                      icon: Icons.timer_outlined,
                      label: detalleEjercicio(item),
                      color: const Color(0xFF2563EB),
                    ),
                    _selectorMetricChip(
                      icon: Icons.touch_app_rounded,
                      label: 'Toca para ver guía',
                      color: colores.first,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _ejerciciosFiltrados();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F9FF),
        title: Text(widget.dia),
      ),
      body: Column(
        children: [
          _heroSelector(),
          SizedBox(
            height: 52,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              itemBuilder: (context, index) =>
                  _categoriaChip(categorias[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: TextField(
              controller: _busquedaController,
              onChanged: (value) {
                setState(() {
                  _busqueda = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio en $categoriaSeleccionada',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _busqueda.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() {
                            _busqueda = '';
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            iconoParaCategoriaEjercicio(categoriaSeleccionada),
                            size: 56,
                            color: Colors.blueGrey.shade300,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No encontré ejercicios con esa búsqueda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Prueba otro nombre o cambia de categoría para ver más opciones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: lista.length,
                    itemBuilder: (context, index) =>
                        _exerciseCard(lista[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class ObjetivosPage extends StatefulWidget {
  const ObjetivosPage({super.key});

  @override
  State<ObjetivosPage> createState() => _ObjetivosPageState();
}

class _ObjetivosPageState extends State<ObjetivosPage> {
  bool cargando = true;
  bool completo = false;

  @override
  void initState() {
    super.initState();
    verificar();
  }

  Future<void> verificar() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      completo = prefs.getBool('formulario_completo') ?? false;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        backgroundColor: fitAppPageBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: fitAppPageBackgroundColor,
      body: completo
          ? const Center(child: Text("Objetivos completados"))
          : const Center(child: Text("Complete su perfil primero")),
    );
  }
}

class WeeklyReportScreen extends StatelessWidget {
  final Set<String> restDays;

  const WeeklyReportScreen({super.key, required this.restDays});

  List<Map<String, dynamic>> _comidasDia(DateTime fecha) {
    return copiarListaMapas(
      comidasHistorialGlobal[fechaActualKey(fecha)] ?? <Map<String, dynamic>>[],
    );
  }

  List<Map<String, dynamic>> _comidasPorTipo(DateTime fecha, String tipo) {
    return _comidasDia(
      fecha,
    ).where((item) => item["comidaTipo"] == tipo).toList();
  }

  List<Map<String, dynamic>> _ejerciciosDia(DateTime fecha) {
    final nombreDia = nombreDiaCompleto(fecha.weekday);
    if (restDays.contains(nombreDia)) {
      return <Map<String, dynamic>>[];
    }

    return copiarListaMapas(
      ejerciciosHistorialGlobal[fechaActualKey(fecha)] ??
          ejerciciosHistorialGlobal[fechaKeyPadded(fecha)] ??
          <Map<String, dynamic>>[],
    );
  }

  double _sumarCampo(List<Map<String, dynamic>> items, String key) {
    return items.fold<double>(
      0,
      (total, item) => total + ((item[key] ?? 0) as num).toDouble(),
    );
  }

  String _formatearNumero(num valor) {
    if (valor == valor.roundToDouble()) {
      return valor.toStringAsFixed(0);
    }

    return valor.toStringAsFixed(1);
  }

  String _resumenNombres(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return 'Sin registro';
    }

    final nombres = items
        .take(2)
        .map((item) => item["nombre"].toString())
        .join(', ');
    if (items.length > 2) {
      return '$nombres +${items.length - 2}';
    }

    return nombres;
  }

  Map<String, dynamic> _crearResumenSemanal() {
    final semana = obtenerDiasSemanaActual();
    final caloriasObjetivoDiarias = user.calories;
    final caloriasObjetivoSemanales = caloriasObjetivoDiarias * 7;
    double totalCalorias = 0;
    double totalProteina = 0;
    double totalCarbs = 0;
    double caloriasEntrenadas = 0;
    double caloriasNetas = 0;
    int minutosEntrenados = 0;
    int diasCompletos = 0;
    int diasActivos = 0;
    int diasEnRangoCalorico = 0;
    DateTime? mejorDiaProteina;
    double mejorProteina = 0;

    for (final fecha in semana) {
      final desayuno = _comidasPorTipo(fecha, 'Desayuno');
      final almuerzo = _comidasPorTipo(fecha, 'Almuerzo');
      final cena = _comidasPorTipo(fecha, 'Cena');
      final comidasDia = [...desayuno, ...almuerzo, ...cena];
      final ejercicios = _ejerciciosDia(fecha);
      final caloriasComidasDia = _sumarCampo(comidasDia, 'calorias');
      final caloriasEjercicioDia = _sumarCampo(ejercicios, 'cal');
      final caloriasNetasDia = (caloriasComidasDia - caloriasEjercicioDia)
          .clamp(0, double.infinity)
          .toDouble();
      final proteinaDia = _sumarCampo(comidasDia, 'proteina');

      totalCalorias += caloriasComidasDia;
      totalProteina += proteinaDia;
      totalCarbs += _sumarCampo(comidasDia, 'carbs');
      caloriasEntrenadas += caloriasEjercicioDia;
      caloriasNetas += caloriasNetasDia;
      minutosEntrenados += ejercicios.fold<int>(
        0,
        (total, item) => total + obtenerMinutosRutina(item),
      );

      if (caloriasObjetivoDiarias > 0) {
        final minimo = caloriasObjetivoDiarias * 0.9;
        final maximo = caloriasObjetivoDiarias * 1.1;
        if (caloriasNetasDia >= minimo && caloriasNetasDia <= maximo) {
          diasEnRangoCalorico++;
        }
      }

      if (desayuno.isNotEmpty && almuerzo.isNotEmpty && cena.isNotEmpty) {
        diasCompletos++;
      }

      if (ejercicios.isNotEmpty) {
        diasActivos++;
      }

      if (proteinaDia > mejorProteina) {
        mejorProteina = proteinaDia;
        mejorDiaProteina = fecha;
      }
    }

    return {
      'totalCalorias': totalCalorias,
      'totalProteina': totalProteina,
      'totalCarbs': totalCarbs,
      'caloriasEntrenadas': caloriasEntrenadas,
      'caloriasNetas': caloriasNetas,
      'caloriasObjetivoDiarias': caloriasObjetivoDiarias,
      'caloriasObjetivoSemanales': caloriasObjetivoSemanales,
      'minutosEntrenados': minutosEntrenados,
      'diasCompletos': diasCompletos,
      'diasActivos': diasActivos,
      'diasEnRangoCalorico': diasEnRangoCalorico,
      'mejorDiaProteina': mejorDiaProteina,
      'mejorProteina': mejorProteina,
    };
  }

  String _generarNarrativa(Map<String, dynamic> resumen) {
    final diasCompletos = resumen['diasCompletos'] as int;
    final diasActivos = resumen['diasActivos'] as int;
    final caloriasObjetivoDiarias =
        resumen['caloriasObjetivoDiarias'] as double;
    final caloriasObjetivoSemanales =
        resumen['caloriasObjetivoSemanales'] as double;
    final caloriasNetas = resumen['caloriasNetas'] as double;
    final diasEnRangoCalorico = resumen['diasEnRangoCalorico'] as int;
    final mejorDiaProteina = resumen['mejorDiaProteina'] as DateTime?;
    final mejorProteina = resumen['mejorProteina'] as double;
    final descansos = restDays.isEmpty
        ? 'sin descansos marcados'
        : 'con descanso en ${restDays.join(', ')}';

    final alimentacionBase = diasCompletos >= 5
        ? 'Tu alimentación semanal estuvo bastante sólida, con varios días completos de desayuno, almuerzo y cena.'
        : 'Tu alimentación todavía tiene huecos esta semana; conviene registrar mejor desayuno, almuerzo y cena para que el análisis sea más preciso.';

    final alimentacion = caloriasObjetivoDiarias <= 0
        ? '$alimentacionBase Completa bien tu perfil para comparar el informe contra una meta calórica personalizada.'
        : diasEnRangoCalorico >= 4
        ? '$alimentacionBase Además, tu balance neto quedó cerca de tu meta calórica de ${_formatearNumero(caloriasObjetivoDiarias)} kcal en $diasEnRangoCalorico días.'
        : caloriasNetas < caloriasObjetivoSemanales * 0.9
        ? '$alimentacionBase Esta semana te quedaste por debajo de tu objetivo calórico del perfil con bastante frecuencia.'
        : '$alimentacionBase Esta semana te pasaste de tu objetivo calórico del perfil en varios días.';

    final entrenamiento = diasActivos >= 4
        ? 'El bloque de ejercicios se ve consistente y con buena frecuencia.'
        : 'El bloque de ejercicios estuvo ligero; puedes subir la frecuencia o ajustar mejor la planificación.';

    final proteina = mejorDiaProteina == null
        ? 'Aún no hay suficiente información de proteína para destacar un día fuerte.'
        : 'Tu mejor día de proteína fue ${nombreDiaCompleto(mejorDiaProteina.weekday)}, con ${_formatearNumero(mejorProteina)} g.';

    return '$alimentacion $entrenamiento $proteina El informe fue generado $descansos para interpretar mejor la carga de entrenamiento.';
  }

  String _estadoCaloricoDia(double caloriasNetas, double metaCalorica) {
    if (metaCalorica <= 0) {
      return 'Sin meta del perfil';
    }

    final minimo = metaCalorica * 0.9;
    final maximo = metaCalorica * 1.1;
    if (caloriasNetas < minimo) {
      return 'Por debajo de meta';
    }
    if (caloriasNetas > maximo) {
      return 'Por arriba de meta';
    }

    return 'En rango recomendado';
  }

  Color _colorEstadoCalorico(String estado) {
    switch (estado) {
      case 'En rango recomendado':
        return Colors.green;
      case 'Por debajo de meta':
        return Colors.orange;
      case 'Por arriba de meta':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _resumenCard(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _bloqueComida(String titulo, List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            _resumenNombres(items),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatearNumero(_sumarCampo(items, 'calorias'))} kcal • P: ${_formatearNumero(_sumarCampo(items, 'proteina'))}g • C: ${_formatearNumero(_sumarCampo(items, 'carbs'))}g',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _bloqueEjercicio(
    DateTime fecha,
    List<Map<String, dynamic>> ejercicios,
  ) {
    final descanso = restDays.contains(nombreDiaCompleto(fecha.weekday));
    final totalMin = ejercicios.fold<int>(
      0,
      (total, item) => total + obtenerMinutosRutina(item),
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ejercicios',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (descanso)
            const Text('Descanso programado para este día.')
          else if (ejercicios.isEmpty)
            const Text('Sin ejercicios registrados.')
          else ...[
            Text(
              ejercicios.map((item) => item['nombre'].toString()).join(', '),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatearNumero(_sumarCampo(ejercicios, 'cal'))} kcal • $totalMin min',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _diaCard(DateTime fecha) {
    final desayuno = _comidasPorTipo(fecha, 'Desayuno');
    final almuerzo = _comidasPorTipo(fecha, 'Almuerzo');
    final cena = _comidasPorTipo(fecha, 'Cena');
    final ejercicios = _ejerciciosDia(fecha);
    final descanso = restDays.contains(nombreDiaCompleto(fecha.weekday));
    final caloriasComidasDia = _sumarCampo([
      ...desayuno,
      ...almuerzo,
      ...cena,
    ], 'calorias');
    final caloriasEjercicioDia = _sumarCampo(ejercicios, 'cal');
    final caloriasNetasDia = (caloriasComidasDia - caloriasEjercicioDia)
        .clamp(0, double.infinity)
        .toDouble();
    final metaCalorica = user.calories;
    final estadoCalorico = _estadoCaloricoDia(caloriasNetasDia, metaCalorica);
    final colorEstado = _colorEstadoCalorico(estadoCalorico);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreDiaCompleto(fecha.weekday),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (descanso)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Descanso',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estadoCalorico,
                  style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metaCalorica <= 0
                      ? 'Completa tu perfil para calcular tu meta diaria.'
                      : 'Meta: ${_formatearNumero(metaCalorica)} kcal • Neto del día: ${_formatearNumero(caloriasNetasDia)} kcal',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          _bloqueComida('Desayuno', desayuno),
          _bloqueComida('Almuerzo', almuerzo),
          _bloqueComida('Cena', cena),
          _bloqueEjercicio(fecha, ejercicios),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semana = obtenerDiasSemanaActual();
    final resumen = _crearResumenSemanal();
    final rango =
        '${semana.first.day.toString().padLeft(2, '0')}/${semana.first.month.toString().padLeft(2, '0')} - ${semana.last.day.toString().padLeft(2, '0')}/${semana.last.month.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Informe IA semanal')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), Color(0xFFFDF7F1)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analisis inteligente de tu semana',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(rango, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),
                  Text(
                    _generarNarrativa(resumen),
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (restDays.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: restDays.map((dia) {
                  return Chip(
                    label: Text(dia),
                    backgroundColor: Colors.orange.shade100,
                  );
                }).toList(),
              ),
            if (restDays.isNotEmpty) const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.55,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _resumenCard(
                  'Meta semanal',
                  resumen['caloriasObjetivoSemanales'] as double <= 0
                      ? 'Completa perfil'
                      : '${_formatearNumero(resumen['caloriasObjetivoSemanales'] as double)} kcal',
                  Colors.white,
                ),
                _resumenCard(
                  'Proteina semanal',
                  '${_formatearNumero(resumen['totalProteina'] as double)} g',
                  Colors.white,
                ),
                _resumenCard(
                  'Dias en rango',
                  '${resumen['diasEnRangoCalorico']}/7',
                  Colors.white,
                ),
                _resumenCard(
                  'Balance semanal',
                  '${_formatearNumero(resumen['caloriasNetas'] as double)} kcal netas',
                  Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...semana.map(_diaCard),
          ],
        ),
      ),
    );
  }
}

class PremiumHubScreen extends StatefulWidget {
  const PremiumHubScreen({super.key});

  @override
  State<PremiumHubScreen> createState() => _PremiumHubScreenState();
}

class _PremiumHubScreenState extends State<PremiumHubScreen> {
  bool _premiumActivado = premiumActivadoGlobal;

  @override
  void initState() {
    super.initState();
    _cargarPremium();
  }

  Future<void> _cargarPremium() async {
    final premium = await cargarEstadoPremium();
    if (!mounted) return;
    setState(() {
      _premiumActivado = premium;
    });
  }

  Future<void> _activarPremium() async {
    await guardarEstadoPremium(true);
    if (!mounted) return;
    setState(() {
      _premiumActivado = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium activado para esta cuenta.')),
    );
  }

  void _mostrarBloqueoPremium() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activa Premium para abrir esta funcion.')),
    );
  }

  Future<void> _abrirInformePremium() async {
    if (!_premiumActivado) {
      _mostrarBloqueoPremium();
      return;
    }

    final seleccion = <String>{};
    final dias = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Informe semanal inteligente'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona tus dias de descanso para personalizar el analisis.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: diasSemanaEspanol.map((dia) {
                      final activo = seleccion.contains(dia);
                      return FilterChip(
                        label: Text(dia),
                        selected: activo,
                        onSelected: (value) {
                          setModalState(() {
                            if (value) {
                              seleccion.add(dia);
                            } else {
                              seleccion.remove(dia);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, Set<String>.from(seleccion)),
                  child: const Text('Abrir informe'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || dias == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WeeklyReportScreen(restDays: dias)),
    );
  }

  Future<void> _abrirRutinasPremium() async {
    if (!_premiumActivado) {
      _mostrarBloqueoPremium();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumRoutinesScreen()),
    );
  }

  Future<void> _abrirRecetasPremium() async {
    if (!_premiumActivado) {
      _mostrarBloqueoPremium();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumRecipesScreen()),
    );
  }

  Widget _heroPremium() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.amberAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Premium Fit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _premiumActivado
                ? 'Tu cuenta ya tiene acceso al analisis inteligente, rutinas premium y recetas completas.'
                : 'Activa tu cuenta premium para desbloquear analisis mas profundos y contenido guiado de alto valor.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PremiumBadge(label: 'Calorias y proteina'),
              _PremiumBadge(label: 'Agua y pasos'),
              _PremiumBadge(label: 'Entrenos y recetas'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _premiumActivado ? null : _activarPremium,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(
                _premiumActivado
                    ? Icons.verified_rounded
                    : Icons.lock_open_rounded,
              ),
              label: Text(
                _premiumActivado ? 'Premium activo' : 'Activar Premium',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4FBFF), Color(0xFFFFF7ED)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroPremium(),
            const SizedBox(height: 18),
            PremiumFeatureCard(
              icon: Icons.insights_rounded,
              title: 'Informe semanal inteligente',
              description:
                  'Analiza calorias, proteina, agua, pasos y entrenos de la semana para darte recomendaciones concretas.',
              bullets: const [
                'Balance neto semanal y dias en rango calorico.',
                'Lectura clara de proteina, agua, pasos y ejercicio.',
                'Recomendaciones practicas para corregir la proxima semana.',
              ],
              actionLabel: 'Abrir informe',
              locked: !_premiumActivado,
              colors: const [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
              onTap: _abrirInformePremium,
            ),
            const SizedBox(height: 14),
            PremiumFeatureCard(
              icon: Icons.fitness_center_rounded,
              title: 'Rutinas premium',
              description:
                  'Mas ejercicios, mas categorias, niveles principiante, intermedio y avanzado, y rutinas por objetivo.',
              bullets: const [
                'Planes por bajar grasa, gluteo y pierna, abdomen o masa muscular.',
                'Bloques por nivel para progresar sin improvisar.',
                'Categorias completas para combinar fuerza, cardio y core.',
              ],
              actionLabel: 'Ver rutinas',
              locked: !_premiumActivado,
              colors: const [Color(0xFF7C3AED), Color(0xFFE879F9)],
              onTap: _abrirRutinasPremium,
            ),
            const SizedBox(height: 14),
            PremiumFeatureCard(
              icon: Icons.restaurant_menu_rounded,
              title: 'Recetas completas',
              description:
                  'Recetas listas para desayuno, almuerzo, cena y snacks con ingredientes, preparacion y macros.',
              bullets: const [
                'Ideas rapidas para seguir tu objetivo sin pensar demasiado.',
                'Ingredientes claros y pasos simples para cocinar.',
                'Macros ya calculados para registrar mas rapido.',
              ],
              actionLabel: 'Ver recetas',
              locked: !_premiumActivado,
              colors: const [Color(0xFFEA580C), Color(0xFFFBBF24)],
              onTap: _abrirRecetasPremium,
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> bullets;
  final String actionLabel;
  final bool locked;
  final List<Color> colors;
  final VoidCallback onTap;

  const PremiumFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.bullets,
    required this.actionLabel,
    required this.locked,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(27),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                Icon(
                  locked ? Icons.lock_rounded : Icons.verified_rounded,
                  color: locked ? Colors.grey.shade600 : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
            const SizedBox(height: 14),
            ...bullets.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: colors.first, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.first,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  locked ? Icons.lock_open_rounded : Icons.arrow_forward,
                ),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  final String label;

  const _PremiumBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PremiumRoutinesScreen extends StatelessWidget {
  const PremiumRoutinesScreen({super.key});

  Color _nivelColor(String nivel) {
    switch (nivel) {
      case 'Principiante':
        return Colors.green;
      case 'Intermedio':
        return Colors.orange;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas premium')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFF), Color(0xFFFFF8FD)],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rutinasPremiumDemo.length,
          itemBuilder: (context, index) {
            final rutina = rutinasPremiumDemo[index];
            final categorias = List<String>.from(rutina['categorias'] as List);
            final ejercicios = List<String>.from(rutina['ejercicios'] as List);
            final colorNivel = _nivelColor(rutina['nivel'].toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rutina['titulo'].toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rutina['enfoque'].toString(),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: colorNivel.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          rutina['nivel'].toString(),
                          style: TextStyle(
                            color: colorNivel,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip('Objetivo: ${rutina['objetivo']}'),
                      _metaChip(rutina['frecuencia'].toString()),
                      ...categorias.map((item) => _metaChip(item)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ejercicios destacados',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...ejercicios.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RutinasScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir mis rutinas'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class PremiumRecipesScreen extends StatelessWidget {
  const PremiumRecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recetas premium')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF5), Color(0xFFF7FBFF)],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: recetasPremiumDemo.length,
          itemBuilder: (context, index) {
            final receta = recetasPremiumDemo[index];
            final ingredientes = List<String>.from(
              receta['ingredientes'] as List,
            );
            final preparacion = List<String>.from(
              receta['preparacion'] as List,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0D9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          receta['tipo'].toString(),
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _recipeMacro(receta['calorias'].toString(), 'kcal'),
                      const SizedBox(width: 8),
                      _recipeMacro(receta['proteina'].toString(), 'P'),
                      const SizedBox(width: 8),
                      _recipeMacro(receta['carbs'].toString(), 'C'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    receta['nombre'].toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    receta['descripcion'].toString(),
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ingredientes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...ingredientes.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Preparacion',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...preparacion.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _metaChip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _recipeMacro(String value, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class _ExercisePosePainter extends CustomPainter {
  final String pose;
  final Color primaryColor;
  final Color accentColor;

  _ExercisePosePainter({
    required this.pose,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accentColor.withValues(alpha: 0.28),
              accentColor.withValues(alpha: 0.02),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.42),
              radius: size.width * 0.62,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.4),
      size.width * 0.4,
      backgroundGlow,
    );

    final floorPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.8),
        width: size.width * 0.72,
        height: 12,
      ),
      floorPaint,
    );

    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = primaryColor;
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.95)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (pose) {
      case 'pushup':
        _paintPushup(canvas, size, linePaint, fillPaint, accentPaint);
        break;
      case 'plank':
        _paintPlank(canvas, size, linePaint, fillPaint, accentPaint);
        break;
      case 'squat':
        _paintSquat(canvas, size, linePaint, fillPaint, accentPaint);
        break;
      case 'bridge':
        _paintBridge(canvas, size, linePaint, fillPaint, accentPaint);
        break;
      case 'curl':
        _paintCurl(canvas, size, linePaint, fillPaint, accentPaint);
        break;
      case 'run':
        _paintRun(canvas, size, linePaint, fillPaint, accentPaint);
        break;
      default:
        _paintAthlete(canvas, size, linePaint, fillPaint, accentPaint);
    }
  }

  void _drawHead(Canvas canvas, Offset center, Paint fillPaint) {
    canvas.drawCircle(center, 8, fillPaint);
  }

  void _drawSegment(Canvas canvas, Offset a, Offset b, Paint paint) {
    canvas.drawLine(a, b, paint);
  }

  void _drawWeight(Canvas canvas, Offset center, Paint accentPaint) {
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      accentPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 10, center.dy - 6),
      Offset(center.dx - 10, center.dy + 6),
      accentPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 10, center.dy - 6),
      Offset(center.dx + 10, center.dy + 6),
      accentPaint,
    );
  }

  void _paintPushup(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final head = Offset(size.width * 0.76, size.height * 0.34);
    final shoulder = Offset(size.width * 0.64, size.height * 0.42);
    final hip = Offset(size.width * 0.44, size.height * 0.48);
    final knee = Offset(size.width * 0.28, size.height * 0.55);
    final foot = Offset(size.width * 0.14, size.height * 0.61);
    final handFront = Offset(size.width * 0.77, size.height * 0.62);
    final handBack = Offset(size.width * 0.62, size.height * 0.6);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, hip, knee, linePaint);
    _drawSegment(canvas, knee, foot, linePaint);
    _drawSegment(canvas, shoulder, handBack, linePaint);
    _drawSegment(canvas, shoulder, handFront, linePaint);
    _drawSegment(
      canvas,
      hip,
      Offset(size.width * 0.58, size.height * 0.45),
      accentPaint,
    );
  }

  void _paintPlank(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final head = Offset(size.width * 0.78, size.height * 0.32);
    final shoulder = Offset(size.width * 0.66, size.height * 0.38);
    final hip = Offset(size.width * 0.44, size.height * 0.42);
    final ankle = Offset(size.width * 0.16, size.height * 0.49);
    final elbow = Offset(size.width * 0.72, size.height * 0.59);
    final hand = Offset(size.width * 0.58, size.height * 0.6);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, hip, ankle, linePaint);
    _drawSegment(canvas, shoulder, elbow, linePaint);
    _drawSegment(canvas, elbow, hand, linePaint);
    _drawSegment(
      canvas,
      hip,
      Offset(size.width * 0.54, size.height * 0.4),
      accentPaint,
    );
  }

  void _paintSquat(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final head = Offset(size.width * 0.5, size.height * 0.2);
    final shoulder = Offset(size.width * 0.5, size.height * 0.33);
    final hip = Offset(size.width * 0.5, size.height * 0.5);
    final kneeLeft = Offset(size.width * 0.36, size.height * 0.65);
    final kneeRight = Offset(size.width * 0.64, size.height * 0.65);
    final footLeft = Offset(size.width * 0.28, size.height * 0.78);
    final footRight = Offset(size.width * 0.72, size.height * 0.78);
    final handLeft = Offset(size.width * 0.34, size.height * 0.44);
    final handRight = Offset(size.width * 0.66, size.height * 0.44);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, hip, kneeLeft, linePaint);
    _drawSegment(canvas, hip, kneeRight, linePaint);
    _drawSegment(canvas, kneeLeft, footLeft, linePaint);
    _drawSegment(canvas, kneeRight, footRight, linePaint);
    _drawSegment(canvas, shoulder, handLeft, linePaint);
    _drawSegment(canvas, shoulder, handRight, linePaint);
    _drawSegment(canvas, kneeLeft, kneeRight, accentPaint);
  }

  void _paintBridge(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final benchPaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.1,
          size.height * 0.56,
          size.width * 0.25,
          10,
        ),
        const Radius.circular(10),
      ),
      benchPaint,
    );

    final head = Offset(size.width * 0.32, size.height * 0.46);
    final shoulder = Offset(size.width * 0.4, size.height * 0.54);
    final hip = Offset(size.width * 0.58, size.height * 0.42);
    final knee = Offset(size.width * 0.76, size.height * 0.54);
    final foot = Offset(size.width * 0.84, size.height * 0.7);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, hip, knee, linePaint);
    _drawSegment(canvas, knee, foot, linePaint);
    _drawSegment(
      canvas,
      shoulder,
      Offset(size.width * 0.26, size.height * 0.58),
      linePaint,
    );
    _drawSegment(canvas, shoulder, hip, accentPaint);
  }

  void _paintCurl(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final head = Offset(size.width * 0.5, size.height * 0.2);
    final shoulder = Offset(size.width * 0.5, size.height * 0.34);
    final hip = Offset(size.width * 0.5, size.height * 0.56);
    final footLeft = Offset(size.width * 0.4, size.height * 0.8);
    final footRight = Offset(size.width * 0.6, size.height * 0.8);
    final elbowLeft = Offset(size.width * 0.36, size.height * 0.46);
    final handLeft = Offset(size.width * 0.42, size.height * 0.34);
    final handRight = Offset(size.width * 0.68, size.height * 0.56);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, hip, footLeft, linePaint);
    _drawSegment(canvas, hip, footRight, linePaint);
    _drawSegment(canvas, shoulder, elbowLeft, linePaint);
    _drawSegment(canvas, elbowLeft, handLeft, linePaint);
    _drawSegment(canvas, shoulder, handRight, linePaint);
    _drawWeight(canvas, handLeft, accentPaint);
    _drawWeight(canvas, handRight, accentPaint);
  }

  void _paintRun(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final head = Offset(size.width * 0.56, size.height * 0.18);
    final shoulder = Offset(size.width * 0.5, size.height * 0.32);
    final hip = Offset(size.width * 0.42, size.height * 0.52);
    final handFront = Offset(size.width * 0.68, size.height * 0.38);
    final handBack = Offset(size.width * 0.34, size.height * 0.44);
    final kneeFront = Offset(size.width * 0.58, size.height * 0.62);
    final footFront = Offset(size.width * 0.72, size.height * 0.76);
    final kneeBack = Offset(size.width * 0.3, size.height * 0.66);
    final footBack = Offset(size.width * 0.18, size.height * 0.72);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, shoulder, handFront, linePaint);
    _drawSegment(canvas, shoulder, handBack, linePaint);
    _drawSegment(canvas, hip, kneeFront, linePaint);
    _drawSegment(canvas, kneeFront, footFront, linePaint);
    _drawSegment(canvas, hip, kneeBack, linePaint);
    _drawSegment(canvas, kneeBack, footBack, linePaint);

    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.28),
      Offset(size.width * 0.92, size.height * 0.28),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.36),
      Offset(size.width * 0.88, size.height * 0.36),
      accentPaint,
    );
  }

  void _paintAthlete(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint fillPaint,
    Paint accentPaint,
  ) {
    final head = Offset(size.width * 0.5, size.height * 0.2);
    final shoulder = Offset(size.width * 0.5, size.height * 0.34);
    final hip = Offset(size.width * 0.5, size.height * 0.55);
    final handLeft = Offset(size.width * 0.34, size.height * 0.48);
    final handRight = Offset(size.width * 0.66, size.height * 0.48);
    final footLeft = Offset(size.width * 0.4, size.height * 0.8);
    final footRight = Offset(size.width * 0.6, size.height * 0.8);

    _drawHead(canvas, head, fillPaint);
    _drawSegment(canvas, shoulder, hip, linePaint);
    _drawSegment(canvas, shoulder, handLeft, linePaint);
    _drawSegment(canvas, shoulder, handRight, linePaint);
    _drawSegment(canvas, hip, footLeft, linePaint);
    _drawSegment(canvas, hip, footRight, linePaint);
    _drawSegment(canvas, handLeft, handRight, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _ExercisePosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
