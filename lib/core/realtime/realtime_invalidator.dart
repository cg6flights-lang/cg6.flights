import 'dart:async';

import 'package:cg6_flights/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Subscribes a single Realtime channel to one or more Postgres tables and
/// runs [onChange] whenever any of them emits an INSERT/UPDATE/DELETE.
///
/// Used for the "realtime -> invalidate" pattern: queries that rely on embedded
/// joins (e.g. `crew_members` with `flight_squadrons(name)`) cannot be turned
/// into Supabase `.stream()` calls, so instead we listen for table changes and
/// invalidate the corresponding Riverpod provider, which re-runs the original
/// query with its joins.
///
/// Changes are debounced to coalesce bursts (e.g. a multi-row update or several
/// related tables changing at once) into a single [onChange] call.
///
/// In safe local mode (no Supabase credentials) it becomes a no-op: the page
/// still works, just without live refresh.
class RealtimeInvalidator {
  RealtimeInvalidator({
    required String channelName,
    required List<String> tables,
    required void Function() onChange,
    Duration debounce = const Duration(milliseconds: 300),
  })  : _onChange = onChange,
        _debounce = debounce {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = Supabase.instance.client;
      final channel = client.channel(channelName);
      for (final table in tables) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _scheduleChange(),
        );
      }
      channel.subscribe();
      _client = client;
      _channel = channel;
    } catch (_) {
      // Realtime unavailable — degrade gracefully to no live refresh.
      _client = null;
      _channel = null;
    }
  }

  final void Function() _onChange;
  final Duration _debounce;
  SupabaseClient? _client;
  RealtimeChannel? _channel;
  Timer? _debounceTimer;

  void _scheduleChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _onChange);
  }

  /// Cancels the pending debounce and removes the Realtime channel.
  /// Call from the owning widget's `dispose()`.
  void dispose() {
    _debounceTimer?.cancel();
    final channel = _channel;
    final client = _client;
    if (channel != null && client != null) {
      client.removeChannel(channel);
    }
  }
}
