class StoryCardFilmPreset {
  const StoryCardFilmPreset({
    required this.exposure,
    required this.contrast,
    required this.saturation,
    required this.temperature,
    required this.tint,
    required this.fade,
    required this.grain,
    required this.softness,
    required this.bloom,
    required this.vignette,
    required this.shadowTeal,
    required this.highlightWarmth,
  });

  const StoryCardFilmPreset.neutral()
    : exposure = 0,
      contrast = 1,
      saturation = 1,
      temperature = 0,
      tint = 0,
      fade = 0,
      grain = 0,
      softness = 0,
      bloom = 0,
      vignette = 0,
      shadowTeal = 0,
      highlightWarmth = 0;

  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double fade;
  final double grain;
  final double softness;
  final double bloom;
  final double vignette;
  final double shadowTeal;
  final double highlightWarmth;

  bool get isNeutral =>
      exposure == 0 &&
      contrast == 1 &&
      saturation == 1 &&
      temperature == 0 &&
      tint == 0 &&
      fade == 0 &&
      grain == 0 &&
      softness == 0 &&
      bloom == 0 &&
      vignette == 0 &&
      shadowTeal == 0 &&
      highlightWarmth == 0;
}

enum StoryCardFilmLook {
  original(id: 'original', label: '원본', preset: StoryCardFilmPreset.neutral()),
  warmth(
    id: 'warmth',
    label: '온기',
    preset: StoryCardFilmPreset(
      exposure: 0.03,
      contrast: 0.97,
      saturation: 0.94,
      temperature: 0.42,
      tint: 0.02,
      fade: 0.06,
      grain: 0.12,
      softness: 0.08,
      bloom: 0.09,
      vignette: 0.08,
      shadowTeal: 0.05,
      highlightWarmth: 0.32,
    ),
  ),
  quiet(
    id: 'quiet',
    label: '고요',
    preset: StoryCardFilmPreset(
      exposure: -0.12,
      contrast: 1.08,
      saturation: 0.88,
      temperature: 0.28,
      tint: -0.10,
      fade: 0.02,
      grain: 0.10,
      softness: 0.06,
      bloom: 0.08,
      vignette: 0.16,
      shadowTeal: 0.28,
      highlightWarmth: 0.22,
    ),
  ),
  color(
    id: 'color',
    label: '컬러',
    preset: StoryCardFilmPreset(
      exposure: 0.04,
      contrast: 1.10,
      saturation: 1.16,
      temperature: 0.10,
      tint: -0.02,
      fade: 0,
      grain: 0.08,
      softness: 0.03,
      bloom: 0.04,
      vignette: 0.08,
      shadowTeal: 0.08,
      highlightWarmth: 0.10,
    ),
  ),
  moment(
    id: 'moment',
    label: '순간',
    preset: StoryCardFilmPreset(
      exposure: -0.05,
      contrast: 1.04,
      saturation: 0.90,
      temperature: 0.22,
      tint: -0.10,
      fade: 0.11,
      grain: 0.30,
      softness: 0.20,
      bloom: 0.32,
      vignette: 0.20,
      shadowTeal: 0.32,
      highlightWarmth: 0.35,
    ),
  );

  const StoryCardFilmLook({
    required this.id,
    required this.label,
    required this.preset,
  });

  factory StoryCardFilmLook.fromJson(String? value) {
    for (final look in values) {
      if (look.id == value) {
        return look;
      }
    }
    return StoryCardFilmLook.original;
  }

  final String id;
  final String label;
  final StoryCardFilmPreset preset;
}

class StoryCardFilmState {
  const StoryCardFilmState({required this.look, required this.seed});

  const StoryCardFilmState.original()
    : look = StoryCardFilmLook.original,
      seed = 0;

  factory StoryCardFilmState.fromJson(Object? value) {
    if (value is! Map) {
      return const StoryCardFilmState.original();
    }
    final json = Map<String, dynamic>.from(value);
    final rawLook = json['look'];
    final rawSeed = json['seed'];
    return StoryCardFilmState(
      look: StoryCardFilmLook.fromJson(rawLook is String ? rawLook : null),
      seed: rawSeed is num ? rawSeed.toInt().clamp(0, 0x7fffffff).toInt() : 0,
    );
  }

  final StoryCardFilmLook look;
  final int seed;

  StoryCardFilmState copyWith({StoryCardFilmLook? look, int? seed}) {
    return StoryCardFilmState(look: look ?? this.look, seed: seed ?? this.seed);
  }

  Map<String, dynamic> toJson() => {'look': look.id, 'seed': seed};

  @override
  bool operator ==(Object other) {
    return other is StoryCardFilmState &&
        other.look == look &&
        other.seed == seed;
  }

  @override
  int get hashCode => Object.hash(look, seed);
}

abstract final class StoryCardFilmSeed {
  static int now() => fromDateTime(DateTime.now());

  static int fromDateTime(DateTime instant) {
    final seed = instant.microsecondsSinceEpoch.abs() % 0x7fffffff;
    return seed == 0 ? 1 : seed;
  }
}
