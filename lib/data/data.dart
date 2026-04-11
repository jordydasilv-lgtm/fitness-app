class Food {
  final String name;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;
  final String icon;

  Food({
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.icon,
  });
}

class Routine {
  final String name;
  final int duration;

  Routine({
    required this.name,
    required this.duration,
  });
}

class DailyData {
  int consumed = 0;
  int burned = 0;

  int carbs = 0;
  int protein = 0;
  int fat = 0;

  List<Food> breakfast = [];
  List<Food> lunch = [];
  List<Food> dinner = [];
}

DailyData dailyData = DailyData();

List<Food> foods = [
  Food(name: "Pollo a la plancha", calories: 165, carbs: 0, protein: 31, fat: 3, icon: "🍗"),
  Food(name: "Arroz integral", calories: 216, carbs: 45, protein: 5, fat: 2, icon: "🍚"),
  Food(name: "Huevo entero", calories: 70, carbs: 1, protein: 6, fat: 5, icon: "🥚"),
  Food(name: "Avena", calories: 150, carbs: 27, protein: 5, fat: 3, icon: "🥣"),
  Food(name: "Banano", calories: 105, carbs: 27, protein: 1, fat: 0, icon: "🍌"),
  Food(name: "Manzana", calories: 95, carbs: 25, protein: 0, fat: 0, icon: "🍎"),
  Food(name: "Salmón", calories: 208, carbs: 0, protein: 20, fat: 13, icon: "🐟"),
  Food(name: "Atún", calories: 132, carbs: 0, protein: 28, fat: 1, icon: "🐠"),
  Food(name: "Pan integral", calories: 80, carbs: 15, protein: 4, fat: 1, icon: "🍞"),
  Food(name: "Yogurt griego", calories: 120, carbs: 4, protein: 10, fat: 5, icon: "🥛"),
  Food(name: "Brócoli", calories: 55, carbs: 11, protein: 4, fat: 0, icon: "🥦"),
  Food(name: "Zanahoria", calories: 50, carbs: 12, protein: 1, fat: 0, icon: "🥕"),
  Food(name: "Papa", calories: 160, carbs: 37, protein: 4, fat: 0, icon: "🥔"),
  Food(name: "Queso mozzarella", calories: 85, carbs: 1, protein: 6, fat: 6, icon: "🧀"),
  Food(name: "Carne magra", calories: 250, carbs: 0, protein: 26, fat: 15, icon: "🥩"),
  Food(name: "Pechuga de pavo", calories: 120, carbs: 1, protein: 24, fat: 1, icon: "🍗"),
  Food(name: "Leche descremada", calories: 90, carbs: 12, protein: 8, fat: 0, icon: "🥛"),
  Food(name: "Aguacate", calories: 240, carbs: 12, protein: 3, fat: 22, icon: "🥑"),
  Food(name: "Almendras", calories: 170, carbs: 6, protein: 6, fat: 15, icon: "🌰"),
  Food(name: "Nueces", calories: 180, carbs: 4, protein: 4, fat: 18, icon: "🌰"),
];

void addFood(Food food, String meal) {
  if (meal == "desayuno") {
    dailyData.breakfast.add(food);
  } else if (meal == "almuerzo") {
    dailyData.lunch.add(food);
  } else {
    dailyData.dinner.add(food);
  }

  dailyData.consumed += food.calories;
  dailyData.carbs += food.carbs;
  dailyData.protein += food.protein;
  dailyData.fat += food.fat;
}