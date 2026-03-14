import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';

class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.label,
    required this.symbol,
  });

  final String code;
  final String label;
  final String symbol;
}

const currencyOptions = [
  CurrencyOption(code: 'EUR', label: 'Euro', symbol: 'EUR'),
  CurrencyOption(code: 'USD', label: 'US Dollar', symbol: 'USD'),
  CurrencyOption(code: 'GBP', label: 'Pound Sterling', symbol: 'GBP'),
  CurrencyOption(code: 'CHF', label: 'Swiss Franc', symbol: 'CHF'),
  CurrencyOption(code: 'BRL', label: 'Brazilian Real', symbol: 'BRL'),
  CurrencyOption(code: 'MXN', label: 'Mexican Peso', symbol: 'MXN'),
];

const Map<String, IconData> categoryIcons = {
  'utensils': Icons.restaurant_rounded,
  'cart': Icons.shopping_bag_rounded,
  'car': Icons.directions_car_rounded,
  'home': Icons.home_rounded,
  'plane': Icons.flight_takeoff_rounded,
  'party': Icons.celebration_rounded,
  'health': Icons.favorite_rounded,
  'work': Icons.work_rounded,
  'coffee': Icons.local_cafe_rounded,
  'bolt': Icons.bolt_rounded,
  'paw': Icons.pets_rounded,
  'receipt': Icons.receipt_long_rounded,
};

const Map<String, IconData> groupIcons = {
  'groups': Icons.groups_rounded,
  'home': Icons.home_rounded,
  'trip': Icons.flight_takeoff_rounded,
  'beach': Icons.beach_access_rounded,
  'camp': Icons.cabin_rounded,
  'boat': Icons.sailing_rounded,
  'train': Icons.train_rounded,
  'hotel': Icons.hotel_rounded,
  'shop': Icons.shopping_basket_rounded,
  'food': Icons.restaurant_rounded,
  'coffee': Icons.local_cafe_rounded,
  'beer': Icons.local_bar_rounded,
  'bbq': Icons.outdoor_grill_rounded,
  'party': Icons.celebration_rounded,
  'music': Icons.music_note_rounded,
  'movie': Icons.movie_rounded,
  'game': Icons.sports_esports_rounded,
  'park': Icons.park_rounded,
  'hiking': Icons.terrain_rounded,
  'work': Icons.work_rounded,
  'study': Icons.school_rounded,
  'pets': Icons.pets_rounded,
  'car': Icons.directions_car_rounded,
  'bike': Icons.pedal_bike_rounded,
  'taxi': Icons.local_taxi_rounded,
  'sports': Icons.sports_soccer_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'savings': Icons.savings_rounded,
  'gift': Icons.redeem_rounded,
  'camera': Icons.photo_camera_rounded,
  'fitness': Icons.fitness_center_rounded,
  'health': Icons.local_hospital_rounded,
  'baby': Icons.child_care_rounded,
  'tools': Icons.handyman_rounded,
  'globe': Icons.public_rounded,
  'stars': Icons.auto_awesome_rounded,
};

const Map<String, String> groupIconLabels = {
  'groups': 'Grupo',
  'home': 'Casa',
  'trip': 'Viaje',
  'beach': 'Playa',
  'camp': 'Escapada',
  'boat': 'Barco',
  'train': 'Tren',
  'hotel': 'Hotel',
  'shop': 'Compras',
  'food': 'Comida',
  'coffee': 'Cafe',
  'beer': 'Bar',
  'bbq': 'Barbacoa',
  'party': 'Fiesta',
  'music': 'Musica',
  'movie': 'Cine',
  'game': 'Gaming',
  'park': 'Parque',
  'hiking': 'Ruta',
  'work': 'Trabajo',
  'study': 'Estudio',
  'pets': 'Mascotas',
  'car': 'Coche',
  'bike': 'Bici',
  'taxi': 'Taxi',
  'sports': 'Deporte',
  'wallet': 'Cartera',
  'savings': 'Ahorro',
  'gift': 'Regalo',
  'camera': 'Fotos',
  'fitness': 'Gym',
  'health': 'Salud',
  'baby': 'Bebe',
  'tools': 'Herramientas',
  'globe': 'Mundo',
  'stars': 'Planazo',
};

IconData groupIconForKey(String key) => groupIcons[key] ?? Icons.groups_rounded;

IconData categoryIconForKey(String key) => categoryIcons[key] ?? Icons.receipt_long_rounded;

String groupIconLabelForKey(String key) => groupIconLabels[key] ?? 'Grupo';

List<ExpenseCategory> buildDefaultCategories() {
  return const [
    ExpenseCategory(id: 'food', name: 'Comida', iconKey: 'utensils', colorHex: '0xFFE4572E', isDefault: true),
    ExpenseCategory(id: 'groceries', name: 'Super', iconKey: 'cart', colorHex: '0xFFF3C677', isDefault: true),
    ExpenseCategory(id: 'transport', name: 'Transporte', iconKey: 'car', colorHex: '0xFF3A86FF', isDefault: true),
    ExpenseCategory(id: 'house', name: 'Casa', iconKey: 'home', colorHex: '0xFF6A4C93', isDefault: true),
    ExpenseCategory(id: 'trip', name: 'Viaje', iconKey: 'plane', colorHex: '0xFF1B998B', isDefault: true),
    ExpenseCategory(id: 'fun', name: 'Ocio', iconKey: 'party', colorHex: '0xFFFF006E', isDefault: true),
    ExpenseCategory(id: 'health', name: 'Salud', iconKey: 'health', colorHex: '0xFFD90429', isDefault: true),
    ExpenseCategory(id: 'work', name: 'Trabajo', iconKey: 'work', colorHex: '0xFF2D3142', isDefault: true),
  ];
}

Color colorFromHex(String value) {
  return Color(int.parse(value));
}

String money(double amount, String currency) {
  return NumberFormat.simpleCurrency(name: currency, decimalDigits: 2).format(amount);
}

List<GroupMember> sortedMembersByName(Iterable<GroupMember> members) {
  final sorted = members.toList();
  sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return sorted;
}