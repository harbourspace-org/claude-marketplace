---
name: branding
description: >
  Load Harbour.Space brand tokens into the conversation — colors, typography,
  spacing, copy rules, breakpoints, and source file locations.
user-invocable: true
allowed-tools: Read
---

# Harbour.Space Brand Reference

**Design system source:** `website` repo — Next.js 16, Styled Components, Ant Design 4.
**Figma tokens:** `website/figma_tokens.json`

---

## Colors

### Modern design system tokens
**Source of truth:** `website/figma_tokens.json` (exported from Figma — these are the canonical values).
`website/src/designSystem/colors.ts` exists but has slightly different values; always prefer Figma for visual work.

#### Purple — primary brand

| Token | Hex (Figma) | Usage |
|---|---|---|
| `purple-50` | `#efeeff` | Page backgrounds, tinted sections, `brand` semantic alias |
| `purple-100` | `#dedcff` | Hover states, subtle highlights |
| `purple-200` | `#cac5ff` | Borders on brand surfaces |
| `purple-300` | `#b3aaff` | Decorative accents |
| `purple-400` | `#9d8cff` | Default `purple` alias; links on dark bg |
| `purple-500` | `#8869fd` | **Primary CTAs, active states — the main HS purple** |
| `purple-600` | `#7346ef` | Hover on primary CTA |
| `purple-700` | `#5d35c4` | Secondary actions, active nav |
| `purple-800` | `#462b94` | Dark brand surfaces |
| `purple-900` | `#312067` | Header, footer, very dark brand areas |
| `purple-950` | `#1e1440` | Deepest brand dark |

#### Neutral / Gray

| Token | Hex | Usage |
|---|---|---|
| `neutral-50` | `#FAFAFA` | Page bg (light) |
| `neutral-100` | `#F5F5F5` | Card bg, input bg |
| `neutral-200` | `#E5E5E5` | Dividers, borders |
| `neutral-300` | `#D4D4D4` | Disabled borders |
| `neutral-400` | `#A3A3A3` | Placeholder text, disabled |
| `neutral-500` | `#737373` | Secondary text |
| `neutral-600` | `#525252` | Subdued body text |
| `neutral-700` | `#404040` | Body text (light mode) |
| `neutral-800` | `#262626` | Strong body text |
| `neutral-900` | `#171717` | Near-black text |
| `neutral-950` | `#0A0A0A` | Deepest text |
| `black-default` | `#030712` | True black |
| `black-400` | `#1C1C1C` | Alternative black |

#### Green — success / positive

| Token | Hex | Usage |
|---|---|---|
| `green-400` | `#34D399` | Default `green` alias |
| `green-500` | `#10B981` | `success` semantic alias |
| `green-600` | `#059669` | Hover on success |

#### Semantic aliases

| Alias | Resolves to | Hex |
|---|---|---|
| `brand` | `purple-50` | `#f4f2ff` |
| `success` | `green-500` | `#10B981` |
| `white` | — | `#ffffff` |

---

### Legacy palette
**Source:** `website/src/utils/styles.ts` — used in older Styled Components.

| Name | Hex | Usage |
|---|---|---|
| `brand` | `#4b2696` | Primary purple in legacy components |
| `brandLight` | `#685dc5` | Hover, links (legacy) |
| `brandDark` | `#3c237f` | Active state (legacy) |
| `brandHover` | `#6336cb` | Hover on brand elements |
| `brandOrange` | `#ff6b00` | Orange accent (rare) |
| `brandPink` | `#ec038d` | Pink accent (rare) |
| `brandGreen` | `#4FA16C` | Legacy success green |
| `text` / `black` | `#242424` | Default body text |
| `grayDark` | `#535353` | Secondary text |
| `grayText` | `#808080` | Tertiary text |
| `grayBorder` | `#e6e6e6` | Borders, dividers |
| `grayFon` | `#f8f8f8` | Light background |
| `error` | `#EC5857` | Error state |
| `link` | `#523996` | Inline links |
| `yellow` | `#F2C94C` | Highlight / badge |
| `orange` | `#F2994A` | Warning, accents |

> Prefer modern design system tokens for new work. Use legacy names only when editing existing Styled Components.

---

## Typography

### Font family
**Primary:** `Apercu Pro` — custom font, **not** available via Google Fonts.
**Source files:** `website/src/styles/apercu-pro.css` (WOFF/WOFF2, loaded locally)
**Actual font files:** `website/public/fonts/` (apercupro-light, apercupro-medium, apercupro-bold)
**Fallback:** `Arial, Helvetica, sans-serif`
**Monospace (code):** `Fira Code` — Google Fonts (`website/src/account/index.css`)

| Weight | File | CSS weight |
|---|---|---|
| Light | `apercupro-light.woff2` | `300` |
| Medium | `apercupro-medium.woff2` | `400`, `500` |
| Bold | `apercupro-bold.woff` | `700` |

To use Apercu Pro in a new project, copy the font files from `website/public/fonts/` and import `apercu-pro.css`.

### Font size scale (fluid — `clamp()`)
**Source:** `website/src/designSystem/typography.ts`

| Token | Clamp value | Approx range |
|---|---|---|
| `font-size-2xs` | `clamp(0.625rem, 0.555rem + 0.267vw, 0.875rem)` | 10–14px |
| `font-size-xs` | `clamp(0.75rem, 0.68rem + 0.267vw, 1rem)` | 12–16px |
| `font-size-sm` | `clamp(0.875rem, 0.805rem + 0.267vw, 1.125rem)` | 14–18px |
| `font-size-md` | `clamp(1rem, 0.895rem + 0.4vw, 1.375rem)` | 16–22px |
| `font-size-lg` | `clamp(1.125rem, 0.88rem + 0.933vw, 2rem)` | 18–32px |
| `font-size-xl` | `clamp(1.25rem, 0.9rem + 1.333vw, 2.5rem)` | 20–40px |
| `font-size-2xl` | `clamp(1.5rem, 0.94rem + 2.133vw, 3.5rem)` | 24–56px |
| `font-size-3xl` | `clamp(1.75rem, 0.84rem + 3.467vw, 5rem)` | 28–80px |
| `font-size-4xl` | `clamp(2.25rem, 0.92rem + 5.067vw, 7rem)` | 36–112px |
| `font-size-5xl` | `clamp(2.625rem, 0.21rem + 9.2vw, 11.25rem)` | 42–180px |

### Line height tokens

| Token | Value |
|---|---|
| `leading-none` | `1` |
| `leading-tight` | `1.15` |
| `leading-snug` | `1.25` |
| `leading-normal` | `1.5` |
| `leading-relaxed` | `1.625` |
| `leading-loose` | `2` |

### Letter spacing tokens

| Token | Value |
|---|---|
| `tracking-tighter` | `-0.05em` |
| `tracking-tight` | `-0.025em` |
| `tracking-normal` | `0em` |
| `tracking-wide` | `0.025em` |
| `tracking-wider` | `0.05em` |
| `tracking-widest` | `0.1em` |

### Pre-composed typography variants
**Source:** `headlineVariants`, `bodyVariants`, `detailVariants` in `typography.ts`

**Headline** — tight line-height at large sizes, looser at small:
- `5xl` / `4xl`: `leading-none`, `tracking-tight` — hero displays
- `3xl` / `2xl` / `xl`: `leading-normal` — section headings
- `lg` / `md`: `leading-relaxed` — subheadings
- `sm` / `xs` / `2xs`: `leading-normal`, `tracking-wide` — labels

**Detail** — always `tracking-wider` (`0.05em`) — used for eyebrow labels, captions, tags.

**Body** — `leading-normal` to `leading-relaxed` depending on size.

---

## Spacing

### Fluid spacing scale
**Source:** `website/src/designSystem/spacing.ts`

All use `clamp()` — scales between mobile and 1440px viewport.

| Token | Value | ~1440px |
|---|---|---|
| `space-3xs` | `clamp(0.25rem, 0.18rem + 0.267vw, 0.5rem)` | 4px |
| `space-2xs` | `clamp(0.5rem, 0.36rem + 0.533vw, 1rem)` | 8px |
| `space-xs` | `clamp(0.75rem, 0.54rem + 0.8vw, 1.5rem)` | 12px |
| `space-s` | `clamp(1rem, 0.72rem + 1.067vw, 2rem)` | 16px |
| `space-m` | `clamp(1.5rem, 1.08rem + 1.6vw, 3rem)` | 24px |
| `space-l` | `clamp(2rem, 1.44rem + 2.133vw, 4rem)` | 32px |
| `space-xl` | `clamp(2.5rem, 1.8rem + 2.667vw, 5rem)` | 40px |
| `space-2xl` | `clamp(3rem, 2.16rem + 3.2vw, 6rem)` | 48px |
| `space-3xl` | `clamp(4rem, 2.88rem + 4.267vw, 8rem)` | 64px |
| `space-4xl` | `clamp(5rem, 3.6rem + 5.333vw, 10rem)` | 80px |
| `space-5xl` | `clamp(8rem, 5.76rem + 8.533vw, 16rem)` | 128px |

Composite one-up tokens also exist: `space-xs-s`, `space-s-m`, `space-m-l`, etc. — use for elements that need to breathe slightly more than a fixed step.

---

## Breakpoints

**Source:** `website/src/utils/styles.ts`

| Name | Value | Type |
|---|---|---|
| `phone` | `767px` | max-width |
| `phoneVertical` | `480px` | max-width |
| `tabletSmall` | `1023px` | max-width |
| `tabletMiddle` | `1123px` | max-width |
| `tabletNew` | `1080px` | max-width |
| `tablet` | `1300px` | max-width |
| `tabletLaptop` | `1200px` | max-width |
| `laptop` | `1400px` | max-width |
| `desktop` | `1700px` | min-height |

Key page layout constants:
- `headerHeight`: `74px` (desktop), `66px` (mobile/tablet)
- Page top padding: `128px` desktop (80px header + 48px banner), `96px` mobile

---

## Copy & Tone

No formal style guide exists — conventions derived from live content.

**Voice:** Aspirational, warm, institutional. Not dry or corporate.
**Audience:** Prospective students, professionals, alumni — globally minded, ambitious.

| Rule | Example |
|---|---|
| Lead with benefit, not feature | "Learn from world-class practitioners" not "We have experienced teachers" |
| Use "you" directly | "Start your journey" not "Students can begin" |
| City/campus copy is sensory | "Barcelona's vibrant energy", "the dynamic heart of Asia" |
| CTAs are active and inviting | "Book a Campus Tour", "Apply Now", "Explore Programs" |
| Avoid jargon | Plain language first; technical terms only in technical contexts |
| Numbers add credibility | "3 weeks · 40 hours · 1 mentor" — specific beats vague |
| Sentence case for UI labels | "Apply now" not "Apply Now" (except proper nouns & CTAs) |

---

## Effects

**Box shadow (default):** `0 3px 4px rgba(0,0,0,.14)`

**Primary easing:** `cubic-bezier(0.33, 1, 0.68, 1)` (`ease-power2-out`) — used for most transitions and enter animations.

**Source:** `website/src/utils/styles.ts` — full easing library (Sine, Quad, Cubic, Quart, Expo, Back variants).

---

## Source file map

| What | File |
|---|---|
| Color tokens | `website/src/designSystem/colors.ts` |
| Typography tokens | `website/src/designSystem/typography.ts` |
| Spacing tokens | `website/src/designSystem/spacing.ts` |
| Figma export | `website/figma_tokens.json` |
| Legacy colors + breakpoints | `website/src/utils/styles.ts` |
| Font face definitions | `website/src/styles/apercu-pro.css` |
| Font files | `website/public/fonts/` |
| Blog SCSS vars | `website/src/blog/styles/const.scss` |
| Global app styles | `website/pages/_app.tsx` |
