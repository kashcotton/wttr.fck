import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../models/weather.dart';
import '../roasts/censor.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = [];
  bool _loading = false;
  String? _error;
  int _req = 0;

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
    setState(() {});
  }

  Future<void> _search(String q) async {
    final id = ++_req;
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await AppScope.of(context).api.search(q);
      if (!mounted || id != _req) return;
      setState(() {
        _results = r;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _req) return;
      setState(() {
        _error = "Search broke. Check your connection.";
        _loading = false;
      });
    }
  }

  void _pick(Place? p) {
    AppScope.of(context).select(p);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final query = _ctrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _search,
          style: t.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Search for a place',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
              },
            ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            children: [
              if (query.length < 2) ...[
                ListTile(
                  leading: Icon(Icons.near_me_rounded, color: cs.primary),
                  title: const Text('Use my location'),
                  subtitle: Text(censor('Wherever the hell you are', s.profanity)),
                  trailing: s.followingDevice
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  onTap: () => _pick(null),
                ),
                if (s.saved.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Saved places',
                        style: t.titleSmall?.copyWith(color: cs.primary)),
                  ),
                  for (final p in s.saved)
                    Dismissible(
                      key: ValueKey(p.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: cs.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Icon(Icons.delete_outline,
                            color: cs.onErrorContainer),
                      ),
                      onDismissed: (_) => s.removeSaved(p),
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(p.name),
                        subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.star_rounded),
                          color: cs.primary,
                          onPressed: () => s.removeSaved(p),
                        ),
                        onTap: () => _pick(p),
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      censor(
                          'Tap the star next to a city to save it here. '
                          'For when you need to know how shitty it is at your mom\'s place.',
                          s.profanity),
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ] else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                )
              else if (!_loading && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No place called "$query". Did you make that up?',
                    style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              else
                for (final p in _results)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(p.name),
                    subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
                    trailing: IconButton(
                      tooltip: s.isSaved(p) ? 'Unsave' : 'Save',
                      icon: Icon(s.isSaved(p)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded),
                      color: s.isSaved(p) ? cs.primary : null,
                      onPressed: () => setState(() => s.toggleSaved(p)),
                    ),
                    onTap: () => _pick(p),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
