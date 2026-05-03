import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:street_food/models/truck.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final trucksProvider = FutureProvider<List<Truck>>((ref) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from('trucks')
      .select()
      .eq('is_active', true)
      .order('created_at');

  return (rows as List<dynamic>)
      .map((e) => Truck.fromMap(e as Map<String, dynamic>))
      .toList();
});
