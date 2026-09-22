import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../logger/app_logger.dart';
import 'lava_lamp_palette.dart';
import 'render_lava_lamp.dart';

/// The app background: a lava lamp of soft blobs that merge and part,
/// under a still grain.
///
/// The blobs stand still while the window is hidden, the background is off
/// screen, the system asks for less motion or [animate] is off. Until the
/// shader is loaded the plain background shows
class AppLavaBackground extends StatefulWidget {
  static const shaderAsset = 'shaders/lava_lamp.frag';

  /// `false` keeps the picture still, e.g. while a full-screen video covers it
  final bool animate;

  const AppLavaBackground({super.key, this.animate = true});

  @override
  State<AppLavaBackground> createState() => _AppLavaBackgroundState();
}

class _AppLavaBackgroundState extends State<AppLavaBackground> {
  static const _appLogger = AppLogger(where: 'AppLavaBackground');

  /// Loaded once for the app: a background made again shows at once
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _loading;

  ui.FragmentProgram? _loadedProgram = _program;
  ui.Image? _grain;
  Color? _grainColor;
  late final AppLifecycleListener _lifecycleListener;
  var _windowVisible = _visible(WidgetsBinding.instance.lifecycleState);

  @override
  void initState() {
    super.initState();

    _lifecycleListener = AppLifecycleListener(onStateChange: _onLifecycle);

    if (_loadedProgram != null) return;

    (_loading ??= ui.FragmentProgram.fromAsset(
      AppLavaBackground.shaderAsset,
    ).then((program) => _program = program)).then(
      (program) {
        if (mounted) setState(() => _loadedProgram = program);
      },
      onError: (Object error, StackTrace stackTrace) => _appLogger.logError(
        'The lava lamp shader did not load: $error',
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final grainColor = context.color.lavaGrain;

    if (grainColor == _grainColor) return;

    _grainColor = grainColor;
    _grain = LavaLampGrain.made(grainColor);

    if (_grain != null) return;

    LavaLampGrain.tile(grainColor).then((grain) {
      if (mounted && grainColor == _grainColor) {
        setState(() => _grain = grain);
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// A minimized window or one hidden in the tray shows nothing. Before
  /// the first report the window is taken as shown
  static bool _visible(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    AppLifecycleState.resumed || AppLifecycleState.inactive || null => true,
  };

  void _onLifecycle(AppLifecycleState state) {
    final visible = _visible(state);

    if (visible != _windowVisible) {
      setState(() => _windowVisible = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final palette = LavaLampPalette(
      base: colors.background,
      haze: colors.lavaHaze,
      body: colors.lavaBody,
      core: colors.lavaCore,
      deep: colors.lavaDeep,
      veil: colors.lavaVeil,
      grain: colors.lavaGrain,
    );
    final program = _loadedProgram;

    if (program == null) {
      return ColoredBox(color: palette.base, child: const SizedBox.expand());
    }

    return _LavaLampSurface(
      program: program,
      palette: palette,
      grain: _grain,
      animating:
          widget.animate &&
          _windowVisible &&
          TickerMode.valuesOf(context).enabled &&
          !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
    );
  }
}

class _LavaLampSurface extends LeafRenderObjectWidget {
  final ui.FragmentProgram program;
  final LavaLampPalette palette;
  final ui.Image? grain;
  final bool animating;

  const _LavaLampSurface({
    required this.program,
    required this.palette,
    required this.grain,
    required this.animating,
  });

  @override
  RenderLavaLamp createRenderObject(BuildContext context) => RenderLavaLamp(
    shader: program.fragmentShader(),
    palette: palette,
    grain: grain,
    animating: animating,
  );

  @override
  void updateRenderObject(BuildContext context, RenderLavaLamp renderObject) {
    renderObject
      ..palette = palette
      ..grain = grain
      ..animating = animating;
  }
}
