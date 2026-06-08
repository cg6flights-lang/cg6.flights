import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/trash/domain/trash_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final trashRepositoryProvider = Provider<TrashRepository>((ref) {
  return SupabaseTrashRepository(Supabase.instance.client);
});

abstract class TrashRepository {
  Future<AppResult<List<TrashItem>>> listTrashItems({String? section});
  Future<AppResult<void>> restoreItem({
    required String section,
    required String id,
  });
  Future<AppResult<void>> permanentlyDeleteItem({
    required String section,
    required String id,
  });
}

class SupabaseTrashRepository implements TrashRepository {
  SupabaseTrashRepository(this._client);

  final SupabaseClient _client;

  static const _sections = {
    'aircraft': _SectionMeta(
      table: 'aircraft',
      sectionKey: 'trash.section.aircraft',
      identifierCols: ['tail_number', 'model'],
      secondaryCols: ['unit_id'],
      deletedAtCol: 'deleted_at',
      useActive: true,
    ),
    'crew': _SectionMeta(
      table: 'crew_members',
      sectionKey: 'trash.section.crew',
      identifierCols: ['full_name', 'document_id'],
      secondaryCols: ['unit_id'],
      deletedAtCol: 'deleted_at',
      useActive: true,
    ),
    'routes': _SectionMeta(
      table: 'routes',
      sectionKey: 'trash.section.routes',
      identifierCols: ['name'],
      secondaryCols: ['unit_id'],
      deletedAtCol: 'deleted_at',
      useActive: true,
    ),
    'units': _SectionMeta(
      table: 'units',
      sectionKey: 'trash.section.units',
      identifierCols: ['name', 'code'],
      secondaryCols: [],
      deletedAtCol: 'deleted_at',
      useActive: true,
    ),
    'users': _SectionMeta(
      table: 'profiles',
      sectionKey: 'trash.section.users',
      identifierCols: ['display_name', 'email'],
      secondaryCols: ['unit_id'],
      deletedAtCol: null, // uses status = 'inactive'
      useActive: false,
      customFilter: "status.eq.inactive",
    ),
    'flight_orders': _SectionMeta(
      table: 'flight_orders',
      sectionKey: 'trash.section.flight_orders',
      identifierCols: ['order_number'],
      secondaryCols: ['unit_id', 'operation_date'],
      deletedAtCol: 'deleted_at',
      useActive: false,
    ),
    'flights': _SectionMeta(
      table: 'flights',
      sectionKey: 'trash.section.flights',
      identifierCols: ['aircraft_id'],
      secondaryCols: ['unit_id', 'flight_order_id'],
      deletedAtCol: 'deleted_at',
      useActive: false,
    ),
    'calendar_events': _SectionMeta(
      table: 'calendar_events',
      sectionKey: 'trash.section.calendar_events',
      identifierCols: ['title'],
      secondaryCols: ['event_date'],
      deletedAtCol: 'deleted_at',
      useActive: false,
    ),
    'messages': _SectionMeta(
      table: 'messages',
      sectionKey: 'trash.section.messages',
      identifierCols: ['subject'],
      secondaryCols: ['sender_id'],
      deletedAtCol: 'deleted_at',
      useActive: false,
    ),
    'flight_order_profiles': _SectionMeta(
      table: 'flight_order_profiles',
      sectionKey: 'trash.section.flight_order_profiles',
      identifierCols: ['description'],
      secondaryCols: ['flight_order_id'],
      deletedAtCol: 'deleted_at',
      useActive: false,
    ),
  };

  @override
  Future<AppResult<List<TrashItem>>> listTrashItems({String? section}) async {
    try {
      final sectionsToQuery = section != null && _sections.containsKey(section)
          ? {section: _sections[section]!}
          : _sections;

      final allItems = <TrashItem>[];

      for (final entry in sectionsToQuery.entries) {
        final key = entry.key;
        final meta = entry.value;

        try {
          // Query all rows and filter deleted in Dart to avoid SDK compatibility issues
          final response = await _client
              .from(meta.table)
              .select('*')
              .order(meta.deletedAtCol ?? 'updated_at', ascending: false)
              .limit(200);

          final rows = response as List<dynamic>;

          for (final row in rows) {
            final map = Map<String, dynamic>.from(row as Map);

            // Filter: only include deleted items
            final isDeleted = meta.customFilter != null
                ? map['status'] == 'inactive'
                : map[meta.deletedAtCol!] != null;
            if (!isDeleted) continue;

            // Build identifier
            final idParts = <String>[];
            for (final col in meta.identifierCols) {
              final val = map[col];
              if (val != null && val.toString().isNotEmpty) {
                idParts.add(val.toString());
              }
            }
            final identifier = idParts.join(' — ');

            // Build secondary info
            final secondaryParts = <String>[];
            for (final col in meta.secondaryCols) {
              final val = map[col];
              if (val != null && val.toString().isNotEmpty) {
                secondaryParts.add(val.toString());
              }
            }
            final secondaryInfo = secondaryParts.join(' | ');

            // Deleted at
            final deletedAtRaw = meta.deletedAtCol != null
                ? map[meta.deletedAtCol]
                : map['updated_at'];
            final deletedAt = deletedAtRaw != null
                ? DateTime.tryParse(deletedAtRaw.toString()) ?? DateTime.now()
                : DateTime.now();

            allItems.add(TrashItem(
              id: map['id'].toString(),
              section: key,
              sectionKey: meta.sectionKey,
              identifier: identifier.isNotEmpty ? identifier : key,
              secondaryInfo: secondaryInfo,
              deletedBy: 'Sistema',
              deletedAt: deletedAt,
              metadata: map,
            ));
          }
        } catch (_) {
          // Skip tables where the column doesn't exist yet (migration pending)
          continue;
        }
      }

      // Sort all items by deletedAt descending
      allItems.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

      return AppSuccess(allItems);
    } catch (e) {
      return AppFailure(
        AppError(
          code: 'TRASH_LOAD_FAILED',
          message: 'No se pudo cargar la papelera: $e',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> restoreItem({
    required String section,
    required String id,
  }) async {
    try {
      final meta = _sections[section];
      if (meta == null) {
        return const AppFailure(
          AppError(
            code: 'TRASH_INVALID_SECTION',
            message: 'Sección no válida.',
            category: AppErrorCategory.validation,
            severity: AppErrorSeverity.medium,
          ),
        );
      }

      if (section == 'users') {
        // Restore user: set status back to 'active'
        await _client
            .from('profiles')
            .update({'status': 'active', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', id);
      } else if (meta.useActive) {
        // Restore with active flag
        await _client
            .from(meta.table)
            .update({
              'active': true,
              meta.deletedAtCol!: null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
      } else {
        // Just clear deleted_at
        await _client
            .from(meta.table)
            .update({
              meta.deletedAtCol!: null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
      }

      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'TRASH_RESTORE_FAILED',
          message: 'No se pudo restaurar el elemento.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> permanentlyDeleteItem({
    required String section,
    required String id,
  }) async {
    try {
      final meta = _sections[section];
      if (meta == null) {
        return const AppFailure(
          AppError(
            code: 'TRASH_INVALID_SECTION',
            message: 'Sección no válida.',
            category: AppErrorCategory.validation,
            severity: AppErrorSeverity.medium,
          ),
        );
      }

      await _client.from(meta.table).delete().eq('id', id);

      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'TRASH_PERMANENT_DELETE_FAILED',
          message: 'No se pudo eliminar definitivamente.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }
}

class _SectionMeta {
  const _SectionMeta({
    required this.table,
    required this.sectionKey,
    required this.identifierCols,
    required this.secondaryCols,
    required this.deletedAtCol,
    required this.useActive,
    this.customFilter,
  });

  final String table;
  final String sectionKey;
  final List<String> identifierCols;
  final List<String> secondaryCols;
  final String? deletedAtCol;
  final bool useActive;
  final String? customFilter;
}
