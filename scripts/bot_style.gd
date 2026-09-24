extends RefCounted
## Local bot appearance choices. Gameplay and online identity colors stay separate.

enum Palette { STANDARD, MUTED, NEON, CUSTOM }
enum PatternMix { ALL, SUBTLE, BOLD, CUSTOM }

const PALETTE_NAMES := ["Standard", "Muted", "Neon", "Custom"]
const MIX_NAMES := ["All patterns", "Subtle", "Bold", "Custom"]
const ALL_PATTERNS_MASK := (1 << 9) - 1
const SUBTLE_MASK := (1 << 0) | (1 << 1) | (1 << 2) | (1 << 7)
const BOLD_MASK := ALL_PATTERNS_MASK ^ SUBTLE_MASK

static func color_for(base: Color, palette: int, custom_saturation: float = 0.65,
		custom_brightness: float = 0.8) -> Color:
	match palette:
		Palette.MUTED:
			return Color.from_hsv(base.h, base.s * 0.48, minf(base.v, 0.72))
		Palette.NEON:
			return Color.from_hsv(base.h, maxf(base.s, 0.82), 1.0)
		Palette.CUSTOM:
			return Color.from_hsv(base.h, clampf(custom_saturation, 0.0, 1.0),
				clampf(custom_brightness, 0.35, 1.0))
	return base

static func pattern_mask(mix: int, custom_mask: int) -> int:
	match mix:
		PatternMix.SUBTLE:
			return SUBTLE_MASK
		PatternMix.BOLD:
			return BOLD_MASK
		PatternMix.CUSTOM:
			return custom_mask & ALL_PATTERNS_MASK if custom_mask & ALL_PATTERNS_MASK else ALL_PATTERNS_MASK
	return ALL_PATTERNS_MASK

static func choose_pattern(rng: RandomNumberGenerator, mix: int, custom_mask: int,
		exclude: int = -1) -> int:
	var mask := pattern_mask(mix, custom_mask)
	var choices: Array[int] = []
	for pattern in range(9):
		if mask & (1 << pattern) and pattern != exclude:
			choices.append(pattern)
	if choices.is_empty():
		return exclude if exclude >= 0 and mask & (1 << exclude) else 0
	return choices[rng.randi_range(0, choices.size() - 1)]
