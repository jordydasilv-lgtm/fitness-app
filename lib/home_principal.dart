import 'package:flutter/material.dart';

// 👇 IMPORTA TUS PANTALLAS
import 'main.dart' show HomeScreen, ComidasScreen, RutinasScreen;
import 'objetivos_pro.dart';

class HomePrincipal extends StatefulWidget {
  const HomePrincipal({super.key});

  @override
  State<HomePrincipal> createState() => _HomePrincipalState();
}

class _HomePrincipalState extends State<HomePrincipal> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ComidasScreen(),
    const RutinasScreen(),
    const ObjetivosPro(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _cambiarPagina(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _cambiarPagina,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: "Comidas"),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: "Rutinas",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: "Mi progreso"),
        ],
      ),
    );
  }
}
