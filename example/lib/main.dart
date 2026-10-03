import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animated_intro/flutter_animated_intro.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preferences_history_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load local history before autoplay can evaluate first-run eligibility.
  final preferences = await SharedPreferences.getInstance();
  runApp(IntroDemoApp(historyStore: PreferencesHistoryStore(preferences)));
}

const ink = Color(0xFF182C25);
const forest = Color(0xFF296348);
const canvas = Color(0xFFF5F6F0);
const muted = Color(0xFF6F7E75);

/// Interactive playground for target integration, playback rules, and theming.
/// Inject a memory history store in tests or persistent storage in the real app.
class IntroDemoApp extends StatefulWidget {
  const IntroDemoApp({
    super.key,
    required this.historyStore,
    this.autoPlay = true,
  });

  /// App-owned history adapter, keeping storage plugins outside the package.
  final IntroHistoryStore historyStore;

  /// Initial screen autoplay setting; the playground can change it at runtime.
  final bool autoPlay;
  @override
  State<IntroDemoApp> createState() => _IntroDemoAppState();
}

class _IntroDemoAppState extends State<IntroDemoApp> {
  final _navigator = GlobalKey<NavigatorState>();
  // Existing-key integration: the same key is attached to the actual bag button.
  final _cartKey = GlobalKey();
  late IntroController _intro;
  late IntroStep _suppliedStep;
  late bool _autoPlay;
  IntroFrequency _frequency = IntroFrequency.once;
  bool _dark = false, _customCard = false, _showArrow = true;
  int _accent = 0, _cartCount = 0, _visit = 0;
  String _status = 'Your workspace is ready.';
  ModalRoute<dynamic>? _detailsRoute;
  bool _detailsOpening = false;
  final List<String> _events = [];
  Color get _color =>
      [forest, const Color(0xFF7654B5), const Color(0xFF216B9C)][_accent];

  @override
  void initState() {
    super.initState();
    _autoPlay = widget.autoPlay;
    _createController();
  }

  void _log(String event) {
    if (!mounted) return;
    setState(() {
      _status = event;
      _events.insert(0, event);
      if (_events.length > 5) _events.removeLast();
    });
  }

  void _createController() {
    // Supplied-widget integration: retain the step and insert targetWidget once.
    _suppliedStep = IntroStep.widget(
      id: 'collection',
      widget: const _CollectionBanner(),
      title: 'A little inspiration',
      description:
          'This banner was passed directly to IntroStep.widget. Insert step.targetWidget in your layout and the anchor is registered for you.',
      placement: IntroPlacement.above,
    );
    _intro = IntroController(
      // Keep this ID stable across visits; version it when the tour content changes.
      tourId: 'bloom-store-v1',
      historyStore: widget.historyStore,
      policy: IntroPlaybackPolicy(
        frequency: _frequency,
        cooldown: const Duration(minutes: 1),
        maxPlays: _frequency == IntroFrequency.cooldown ? 5 : null,
      ),
      steps: [
        const IntroStep(
          target: IntroAnchor.id('welcome'),
          title: 'Welcome to Bloom',
          description:
              'A calmer space to find your next favorite plant. This tour follows real widgets, even when the layout changes. Tap the highlight or choose Next.',
        ),
        IntroStep(
          target: const IntroAnchor.id('first-plant'),
          title: 'Bring a little green home',
          description:
              'This Add button uses an IntroTarget wrapper. Next runs the same action and updates the real cart. Your selection stays after the tour.',
          onNext: () async {
            if (!mounted) return IntroActionResult.stay;
            setState(() => _cartCount++);
            _log('Monstera added to your bag.');
            return IntroActionResult.advance;
          },
        ),
        IntroStep(
          target: IntroAnchor.key(_cartKey),
          title: 'Your bag, one tap away',
          description:
              'Already have a GlobalKey? Pass it as an IntroAnchor.key. Next opens the real bag sheet, and the tour follows us inside.',
          onNext: () async {
            // Do not await sheet dismissal: the next target lives inside the sheet.
            _openDetails();
            return IntroActionResult.advance;
          },
        ),
        IntroStep(
          target: const IntroAnchor.id('bag-details'),
          title: 'Works inside a bottom sheet',
          description:
              'The flow sits above the Navigator, so modal targets remain visible. This step closes only the sheet owned by this demo before continuing.',
          // Also prepare the sheet when reaching this step through Back or goTo.
          onEnter: () async {
            _openDetails();
          },
          onNext: () async {
            await _closeDetails();
            return IntroActionResult.advance;
          },
          placement: IntroPlacement.above,
        ),
        _suppliedStep,
      ],
      onStarted: () async =>
          _log('Tour started · ${_frequencyLabel(_frequency)}'),
      onStepChanged: (index, _) => _log('Exploring step ${index + 1} of 5'),
      onCompleted: () async {
        await _closeDetails();
        _log('Tour complete. Make yourself at home.');
      },
      onSkipped: () async {
        await _closeDetails();
        _log('Tour skipped. Replay whenever you like.');
      },
      onError: (error, _) => _log('Step unavailable. Retry or skip the tour.'),
    );
  }

  void _openDetails() {
    // Guard the interval before the route builder runs as well as mounted sheets.
    if (_detailsRoute != null || _detailsOpening) return;
    final context = _navigator.currentContext;
    if (context == null) return;
    _detailsOpening = true;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        isDismissible: !_intro.isActive,
        enableDrag: !_intro.isActive,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (sheetContext) {
          _detailsRoute = ModalRoute.of(sheetContext);
          _detailsOpening = false;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              child: IntroTarget(
                id: 'bag-details',
                // Explicit ownership also supports modal targets outside a local scope.
                controller: _intro,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your little green corner',
                      style: Theme.of(sheetContext).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const _PlantArt(
                          icon: Icons.eco_rounded,
                          color: Color(0xFFE2EBDC),
                          size: 72,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monstera deliciosa',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '$_cartCount in your bag · Easy-care favorite',
                                style: const TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${(_cartCount * 28).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'This is a local demo. No checkout, network request, or payment is performed.',
                      style: TextStyle(color: muted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _intro.isActive ? null : _closeDetails,
                        child: const Text('Keep exploring'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).whenComplete(() {
        _detailsRoute = null;
        _detailsOpening = false;
      }),
    );
  }

  Future<void> _closeDetails() async {
    final route = _detailsRoute;
    if (route?.isCurrent ?? false) {
      _navigator.currentState?.pop();
      // Wait for the exit transition so the next target is no longer covered.
      await route!.completed;
    }
    _detailsRoute = null;
  }

  void _replacePolicy(IntroFrequency frequency) {
    // Policies are immutable; replace the controller but retain its history ID.
    _closeDetails();
    final previous = _intro;
    previous.stop();
    setState(() {
      _frequency = frequency;
      _createController();
    });
    // Give IntroFlow a frame to detach the old controller before disposing it.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _reopen() {
    _closeDetails();
    _intro.stop();
    // A new key remounts the screen trigger, simulating another screen visit.
    setState(() => _visit++);
    _log('Screen reopened. Automatic playback follows your policy.');
  }

  Future<void> _reset() async {
    _closeDetails();
    _intro.stop();
    await _intro.resetHistory();
    _log('Playback history cleared. Reopen the screen to try first run.');
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _color,
      brightness: _dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'Bloom · Intro Flow Playground',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _dark ? const Color(0xFF131E19) : canvas,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
      // A global overlay above the Navigator can highlight bottom-sheet targets.
      // The screen trigger below owns autoplay, avoiding two competing starters.
      builder: (context, child) => IntroFlow(
        controller: _intro,
        autoPlay: false,
        theme: IntroTheme(accentColor: _color, showArrow: _showArrow),
        cardBuilder: _customCard
            ? (_, details) => _CustomCard(details: details)
            : null,
        child: child!,
      ),
      // Automatic starts honor frequency; Replay intro deliberately bypasses it.
      home: IntroAutoPlay(
        key: ValueKey(_visit),
        controller: _intro,
        enabled: _autoPlay,
        child: ListenableBuilder(
          listenable: _intro,
          builder: (_, child) =>
              PopScope(canPop: !_intro.isActive, child: child!),
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1080;
                return Row(
                  children: [
                    if (wide)
                      _Sidebar(color: _color, replay: () => _intro.replay()),
                    Expanded(
                      child: SafeArea(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(wide ? 36 : 20),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _topBar(),
                                  const SizedBox(height: 36),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: _store(context),
                                        ),
                                        const SizedBox(width: 32),
                                        Expanded(
                                          flex: 4,
                                          child: _settings(context),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _store(context),
                                    const SizedBox(height: 28),
                                    _settings(context),
                                  ],
                                  const SizedBox(height: 28),
                                  Text(
                                    'FLUTTER ANIMATED INTRO FLOW  /  EXAMPLE APP',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Icon(Icons.spa_rounded, color: _color, size: 30),
            const SizedBox(width: 10),
            const Text(
              'bloom',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 16),
            const _Pill(
              label: 'THE INTRO PLAYGROUND',
              color: Color(0xFFE3EBDD),
              textColor: forest,
            ),
          ],
        ),
        OutlinedButton.icon(
          key: _cartKey,
          onPressed: _openDetails,
          icon: const Icon(Icons.shopping_bag_outlined, size: 19),
          label: Text('Your bag ($_cartCount)'),
        ),
      ],
    ),
  );
  Widget _store(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IntroTarget(
        id: 'welcome',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A little green.\nA lot of good.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thoughtfully chosen plants for the places you call home.',
              style: TextStyle(color: muted, height: 1.6, fontSize: 16),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Pill(label: 'All plants', color: _color, textColor: Colors.white),
          const _Pill(
            label: 'Easy care',
            color: Color(0xFFE9ECE4),
            textColor: muted,
          ),
          const _Pill(
            label: 'Pet friendly',
            color: Color(0xFFE9ECE4),
            textColor: muted,
          ),
          const _Pill(
            label: 'New arrivals',
            color: Color(0xFFE9ECE4),
            textColor: muted,
          ),
        ],
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Text(
              'Meet your new favorites',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.grid_view_rounded, size: 19, color: muted),
        ],
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620
              ? 3
              : constraints.maxWidth >= 360
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: width,
                child: _ProductCard(
                  introTargetId: 'first-plant',
                  name: 'Monstera',
                  note: 'The statement maker',
                  price: 28,
                  icon: Icons.eco_rounded,
                  tint: const Color(0xFFE2EBDC),
                  badge: 'BESTSELLER',
                  onAdd: () {
                    setState(() => _cartCount++);
                    _log('Monstera added to your bag.');
                  },
                ),
              ),
              SizedBox(
                width: width,
                child: _ProductCard(
                  name: 'Olive tree',
                  note: 'Mediterranean soul',
                  price: 42,
                  icon: Icons.park_rounded,
                  tint: const Color(0xFFEDE8D9),
                  badge: 'SUN LOVER',
                  onAdd: () => _log('Try the Monstera in this demo.'),
                ),
              ),
              SizedBox(
                width: width,
                child: _ProductCard(
                  name: 'Bird of paradise',
                  note: 'A tropical escape',
                  price: 36,
                  icon: Icons.grass_rounded,
                  tint: const Color(0xFFE1E9E8),
                  badge: 'NEW',
                  onAdd: () => _log('Try the Monstera in this demo.'),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      // Insert the supplied target into the real responsive layout exactly once.
      _suppliedStep.targetWidget,
      const SizedBox(height: 22),
      Wrap(
        spacing: 20,
        runSpacing: 10,
        children: const [
          _TrustNote(
            icon: Icons.local_shipping_outlined,
            label: 'Grown with care',
          ),
          _TrustNote(icon: Icons.favorite_border, label: 'A happier home'),
          _TrustNote(icon: Icons.wifi_off_rounded, label: 'Fully offline demo'),
        ],
      ),
    ],
  );
  Widget _settings(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, color: _color),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Make it yours',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'A real tour. Your rules. Try the package controls below.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text(
          'PLAYBACK FREQUENCY',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<IntroFrequency>(
          key: ValueKey(_frequency),
          initialValue: _frequency,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          isExpanded: true,
          items: IntroFrequency.values
              .map(
                (f) =>
                    DropdownMenuItem(value: f, child: Text(_frequencyLabel(f))),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) _replacePolicy(value);
          },
        ),
        const SizedBox(height: 10),
        const Text(
          'Once uses persisted local history. Cooldown is one minute with a five-play limit.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 14),
        _switch(
          'Autoplay on screen open',
          _autoPlay,
          (v) => setState(() => _autoPlay = v),
        ),
        _switch(
          'Custom coach card',
          _customCard,
          (v) => setState(() => _customCard = v),
        ),
        _switch(
          'Show target arrow',
          _showArrow,
          (v) => setState(() => _showArrow = v),
        ),
        _switch('Dark appearance', _dark, (v) => setState(() => _dark = v)),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Accent color',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Semantics(
                  label: 'Accent ${i + 1}',
                  button: true,
                  selected: i == _accent,
                  child: InkWell(
                    onTap: () => setState(() => _accent = i),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: [
                          forest,
                          const Color(0xFF7654B5),
                          const Color(0xFF216B9C),
                        ][i],
                        shape: BoxShape.circle,
                      ),
                      child: i == _accent
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 17,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _intro.replay(),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Replay intro'),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _reopen,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reopen screen'),
            ),
            TextButton(onPressed: _reset, child: const Text('Reset history')),
          ],
        ),
        const Divider(height: 36),
        ListenableBuilder(
          listenable: _intro,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE CONTROLLER',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: _color,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    label: _intro.isActive
                        ? (_intro.isPaused ? 'Paused' : 'Playing')
                        : 'Idle',
                    color: const Color(0xFFE3EBDD),
                    textColor: forest,
                  ),
                  _Pill(
                    label: '${_intro.history.playCount} plays',
                    color: const Color(0xFFE9ECE4),
                    textColor: muted,
                  ),
                  _Pill(
                    label: _intro.history.completed
                        ? 'Completed'
                        : 'Not completed',
                    color: const Color(0xFFE9ECE4),
                    textColor: muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _intro.isActive
                        ? () =>
                              _intro.isPaused ? _intro.resume() : _intro.pause()
                        : null,
                    child: Text(_intro.isPaused ? 'Resume' : 'Pause'),
                  ),
                  TextButton(
                    onPressed: _intro.isActive ? _intro.stop : null,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _status,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_events.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final event in _events.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $event',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ),
        ],
      ],
    ),
  );
  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

String _frequencyLabel(IntroFrequency frequency) => switch (frequency) {
  IntroFrequency.once => 'Once per installation',
  IntroFrequency.oncePerSession => 'Once per session',
  IntroFrequency.everyVisit => 'Every screen visit',
  IntroFrequency.cooldown => 'After a cooldown',
  IntroFrequency.manual => 'Manual only',
};

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.color, required this.replay});
  final Color color;
  final VoidCallback replay;
  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    color: ink,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.spa_rounded, color: Color(0xFFC5DFA7), size: 38),
        const SizedBox(height: 12),
        const Text(
          'bloom\nplant studio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 56),
        const _NavItem(
          icon: Icons.storefront_outlined,
          label: 'Discover',
          selected: true,
        ),
        const _NavItem(icon: Icons.eco_outlined, label: 'Our plants'),
        const _NavItem(icon: Icons.favorite_border, label: 'Favorites'),
        const _NavItem(icon: Icons.menu_book_outlined, label: 'Plant care'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFC5DFA7),
                size: 20,
              ),
              const SizedBox(height: 12),
              const Text(
                'New here?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Let us show you around.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: replay,
                child: const Text(
                  'Take the tour',
                  style: TextStyle(color: Color(0xFFC5DFA7)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: selected ? const Color(0xFFC5DFA7) : Colors.white54,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });
  final String label;
  final Color color, textColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// Local Flutter artwork keeps this example runnable without network assets.
class _PlantArt extends StatelessWidget {
  const _PlantArt({required this.icon, required this.color, this.size = 150});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: size * .12,
          child: Container(
            width: size * .42,
            height: size * .10,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        Positioned(
          top: size * .13,
          child: Icon(icon, size: size * .65, color: forest),
        ),
        Positioned(
          bottom: size * .17,
          child: Container(
            width: size * .24,
            height: size * .24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC58962), Color(0xFFA36A4A)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );
}

// Only the first product wraps its real Add control with an IntroTarget.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.note,
    required this.price,
    required this.icon,
    required this.tint,
    required this.badge,
    required this.onAdd,
    this.introTargetId,
  });
  final String name, note, badge;
  final int price;
  final IconData icon;
  final Color tint;
  final VoidCallback onAdd;
  final String? introTargetId;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              _PlantArt(icon: icon, color: tint, size: constraints.maxWidth),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: forest,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(note, style: const TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '\$$price',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (introTargetId != null)
              IntroTarget(
                id: introTargetId!,
                child: IconButton.filledTonal(
                  onPressed: onAdd,
                  tooltip: 'Add $name to bag',
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              )
            else
              IconButton.filledTonal(
                onPressed: onAdd,
                tooltip: 'Add $name to bag',
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
          ],
        ),
      ],
    ),
  );
}

class _CollectionBanner extends StatelessWidget {
  const _CollectionBanner();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE SLOW LIVING COLLECTION',
                style: TextStyle(
                  color: Color(0xFFC5DFA7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Room to grow.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Small changes. A softer everyday.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.spa_rounded, color: Color(0xFFC5DFA7), size: 56),
      ],
    ),
  );
}

class _TrustNote extends StatelessWidget {
  const _TrustNote({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: muted, size: 16),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
}

// Custom cards receive the same controller state and commands as the default UI.
// Disable actions while busy and honor allowBack/allowSkip when presenting controls.
class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.details});
  final IntroCardDetails details;
  @override
  Widget build(BuildContext context) => Material(
    color: ink,
    borderRadius: BorderRadius.circular(24),
    elevation: 12,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A GUIDED MOMENT  /  ${details.stepNumber} OF ${details.stepCount}',
            style: const TextStyle(
              color: Color(0xFFC5DFA7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            details.step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            details.step.description,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.6,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: details.isBusy ? null : details.next,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC5DFA7),
                  foregroundColor: ink,
                ),
                child: Text(details.isLastStep ? 'Let’s explore' : 'Show me'),
              ),
              if (details.allowBack && details.stepNumber > 1)
                TextButton(
                  onPressed: details.isBusy ? null : details.back,
                  child: const Text(
                    'Back',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              if (details.allowSkip)
                TextButton(
                  onPressed: details.skip,
                  child: const Text(
                    'Maybe later',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              TextButton(
                onPressed: details.controller.pause,
                child: const Text(
                  'Pause',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
