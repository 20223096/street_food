import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:street_food/models/truck.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TruckService {
  TruckService(this._client);

  final SupabaseClient _client;

  static const _bucket = 'truck-photos';

  Future<void> ensureAuthSession() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  Future<Truck> createUserReport({
    required String name,
    required double latitude,
    required double longitude,
    required List<String> categoryTags,
    File? photoFile,
  }) async {
    await ensureAuthSession();

    final insert = await _client
        .from('trucks')
        .insert({
          'name': name.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'source': 'user_report',
          'category_tags': categoryTags,
          'is_active': true,
        })
        .select()
        .single();

    var truck = Truck.fromMap(Map<String, dynamic>.from(insert));

    if (photoFile != null) {
      final ext = p.extension(photoFile.path).toLowerCase();
      final safeExt = ext.isEmpty ? '.jpg' : ext;
      final objectPath = '${truck.id}/${const Uuid().v4()}$safeExt';

      await _client.storage.from(_bucket).upload(
            objectPath,
            photoFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(objectPath);

      final updated = await _client
          .from('trucks')
          .update({'cover_image_url': publicUrl})
          .eq('id', truck.id)
          .select()
          .single();

      truck = Truck.fromMap(Map<String, dynamic>.from(updated));
    }

    return truck;
  }
}
