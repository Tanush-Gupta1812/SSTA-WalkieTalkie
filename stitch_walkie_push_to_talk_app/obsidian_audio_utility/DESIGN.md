---
name: Obsidian Audio Utility
colors:
  surface: '#121315'
  surface-dim: '#121315'
  surface-bright: '#38393b'
  surface-container-lowest: '#0d0e10'
  surface-container-low: '#1b1c1e'
  surface-container: '#1f2022'
  surface-container-high: '#292a2c'
  surface-container-highest: '#343537'
  on-surface: '#e3e2e4'
  on-surface-variant: '#d8c3ad'
  inverse-surface: '#e3e2e4'
  inverse-on-surface: '#303033'
  outline: '#a08e7a'
  outline-variant: '#534434'
  surface-tint: '#ffb95f'
  primary: '#ffc174'
  on-primary: '#472a00'
  primary-container: '#f59e0b'
  on-primary-container: '#613b00'
  inverse-primary: '#855300'
  secondary: '#4edea3'
  on-secondary: '#003824'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#8fd5ff'
  on-tertiary: '#00344a'
  tertiary-container: '#1abdff'
  on-tertiary-container: '#004966'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffddb8'
  primary-fixed-dim: '#ffb95f'
  on-primary-fixed: '#2a1700'
  on-primary-fixed-variant: '#653e00'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#c5e7ff'
  tertiary-fixed-dim: '#7fd0ff'
  on-tertiary-fixed: '#001e2d'
  on-tertiary-fixed-variant: '#004c6a'
  background: '#121315'
  on-background: '#e3e2e4'
  surface-variant: '#343537'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '600'
    lineHeight: 48px
    letterSpacing: -0.03em
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.025em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
    letterSpacing: -0.015em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.005em
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.08em
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-2xs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
  space-3xl: 4rem
  gutter-mobile: 1rem
  gutter-desktop: 1.5rem
  max-width-interface: 480px
---

## Brand & Style

This design system establishes a high-fidelity, distraction-free voice transmission environment. Engineered for discreet, immediate communication, the visual language departs from toy-like radio tropes and excessive gamified neon accents. Instead, it embodies the precision, weight, and timeless sophistication of high-end acoustic hardware and professional broadcast monitors.

The core aesthetic unites dark-mode minimalism with disciplined glassmorphism. Surfaces are deep, layered obsidian planes illuminated by soft, natural illumination rather than harsh synthetic highlights. Micro-interactions and state changes prioritize acoustic clarity: warmth indicates live transmission, cool emerald signals passive readiness, and muted charcoal provides spatial quietude. Every component emphasizes high-touch utility, low cognitive overhead, and frictionless real-time operation.

## Colors

The palette operates on strict luminescence tiers to maximize contrast without inducing visual fatigue in low-light environments.

- **Background Canvas:** Deep charcoal and obsidian (`#0F1012` transitioning to `#141518`) absorb visual noise and anchor the viewport.
- **Surfaces & Cards:** Tiered charcoal tones (`#1A1C20` base, `#22252A` active/hovered) paired with subtle, low-opacity glass borders (`rgba(255, 255, 255, 0.08)` and fine highlights `rgba(255, 255, 255, 0.05)`).
- **Typography Hierarchy:** Off-white (`#F3F4F6`) commands primary reading priority; silver-gray (`#9CA3AF`) provides secondary descriptive context; deep ash (`#6B7280`) is reserved for inactive states, structural dividers, and timestamps.
- **Accents & Telemetry:**
  - *Warm Amber / Champagne Gold (`#F59E0B`, `#E5A93C`):* Applied exclusively to live audio pipelines, active PTT broadcast states, selected channels, and primary focal toggles.
  - *Subtle Emerald (`#10B981`):* Denotes passive peer connectivity, low-latency status, and standby readiness.
  - *Signal Attenuation:* Critical warnings use an understated crimson (`#EF4444`), strictly bounded to hardware errors or connection failure.

## Typography

The type system balances human clarity with hardware instrumentation. Plus Jakarta Sans handles primary interface layers, providing warm, legible geometric contours without eccentricities. JetBrains Mono serves as an auxiliary telemetry font for frequency channels, latency readouts, timestamps, and input/output metering.

- Maintain negative letter-spacing on headline scales (`-0.015em` to `-0.03em`) to present a consolidated, modern aesthetic.
- Restrict `label-caps` to telemetry labels, channel identifiers, and mute indicators; apply uppercase transform with extended letter tracking.
- Do not use weights below `400` on dark obsidian backgrounds to preserve legibility against light diffusion.

## Layout & Spacing

This design system uses an adaptive single-axis layout engine. On handheld devices, interfaces run edge-to-edge with a standard `1rem` lateral padding and adhere to lower thumb-zone ergonomics for voice controls. On desktop and tablet displays, communication decks constrain to a centered maximum width (`480px` for mobile-style compact docks, expandable up to `1024px` for split-channel consoles).

- **Vertical Rhythm:** Rooted in an 8px scale (`0.5rem`, `1rem`, `1.5rem`, `2rem`). Micro paddings inside telemetry bars and pill indicators employ half-steps (`0.25rem` / `4px`).
- **Touch Targets:** Any interactive voice toggle or push-to-talk trigger maintains a minimum boundary of `48px × 48px`, expanding up to `120px` or full container widths for primary broadcast activators.
- **SafeArea Integration:** Floating transmission islands reserve a minimum bottom offset of `2rem` plus device-safe-area insets to prevent gesture collisions.

## Elevation & Depth

Visual hierarchy uses tonal surface elevation reinforced by translucent glass barriers and concentrated atmospheric illumination:

1. **Floor (Level 0 - `#0F1012`):** Base canvas layer. Flat, absorbing, non-interactive.
2. **Sub-Surface (Level 1 - `#141518`):** Recessed containers, channel lists, and inactive panel segments.
3. **Elevated Surfaces (Level 2 - `#1A1C20`):** Floating channel cards and utility trays. Features a 1px perimeter border rendered in `rgba(255, 255, 255, 0.07)` and an ultra-diffused shadow (`box-shadow: 0 12px 32px -4px rgba(0, 0, 0, 0.5)`).
4. **Interactive Floating Elements (Level 3 - `#22252A` with `backdrop-filter: blur(20px)`):** Control bars, audio adjustment sheets, and system menus. Borders increase to `rgba(255, 255, 255, 0.12)`.
5. **Aura / Active State Glows:** Rather than harsh, drop-cast shadows, active transmitting states emit a restrained radial aura: `0 0 40px -10px rgba(245, 158, 11, 0.25)`. Standby connections project a tight emerald luminescence: `0 0 16px -4px rgba(16, 185, 129, 0.2)`.

## Shapes

The interface balances soft structural framing with circular utility points:

- **Containers & Audio Cards:** Follow `rounded-2xl` (`1rem` / `16px`) to `rounded-3xl` (`1.5rem` / `24px`), softening the technical perimeter while retaining structural geometry.
- **Controls & Telemetry Badges:** Use full pills (`9999px`) for channel switchers, online indicators, and micro-buttons.
- **Primary PTT Core:** Pure circle or rounded-rect morphing geometry with continuous curvature (`squircle`), eliminating harsh 90-degree corners to evoke physical, precision-milled audio gear.

## Components

### Push-To-Talk (PTT) Trigger
- **Resting State:** Circular or broad pill button filled with `#1A1C20`, surrounded by an inner highlight ring (`rgba(255, 255, 255, 0.08)`) and fine 1px border (`#22252A`). Icon/Label rendered in `#9CA3AF`.
- **Active / Depressed State:** Seamless background shift to `#22252A` with a calibrated amber radial aura (`rgba(245, 158, 11, 0.2)`). The perimeter border brightens to `#F59E0B`. Micro-haptic scale transformation: transforms to `scale(0.98)` with a `150ms cubic-bezier(0.2, 0.8, 0.2, 1)` response.

### Audio Channel Cards
- Constructed with `#1A1C20` base, 1px border of `rgba(255, 255, 255, 0.06)`, and `1.25rem` internal padding.
- Contains an inline live waveform meter using low-opacity vertical bars (`#6B7280`), brightening dynamically to `#F59E0B` when audio is flowing.
- Inactive members display low opacity (`#6B7280`); actively transmitting speakers receive an illuminated amber ring badge.

### Floating Action Bar (Dock)
- Suspended over the base floor with `backdrop-filter: blur(24px)` and background color `rgba(26, 28, 32, 0.85)`.
- Enclosed with a `1px` high-pass glass stroke (`rgba(255, 255, 255, 0.1)`).
- Houses quick-mute toggles, input level monitoring, and channel switching affordances.

### Input Fields & Controls
- Form surfaces leverage `#141518` inset backgrounds with zero outer drop shadows.
- Active focus state trades default platform outlines for a sharp, refined border in `rgba(245, 158, 11, 0.6)`.
- Monospace auxiliary labels (`JetBrains Mono`, `11px`) pinned directly above the container frame.

### Status Indicators & Badges
- Pinned status pills: 6px solid dots (`#10B981` for connected, `#F59E0B` for transmitting, `#6B7280` for deafened/idle).
- Accompanied by uppercase monospace status descriptions with `0.08em` tracking.