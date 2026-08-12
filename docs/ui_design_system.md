# Puitei Chhakchhuak UI design system

Puitei Chhakchhuak uses a crisp, operational visual language informed by Linear's density, Stripe's data hierarchy, and Apple Human Interface Design principles. The interface prioritizes legibility, direct manipulation, touch ergonomics, accessible contrast, and restrained detail.

## Tokens

Semantic tokens live in `app/assets/tailwind/application.css`. Templates should use `page`, `surface`, `surface-muted`, `ink`, `ink-muted`, `line`, `brand`, `gold`, and `emerald-refined` rather than arbitrary colours. Dark-theme values are prepared under `[data-theme="dark"]`; no theme switch is exposed yet.

The application uses a local-first Inter/SF-compatible sans-serif stack so rendering never waits on a remote font. The canvas is a cool neutral, panels are white with one-pixel borders, and shadows are reserved for elevation rather than decoration. Gold is limited to financial or premium detail, emerald communicates operational progress, and deep navy is the primary action colour.

## Components

- Buttons: `.button-primary`, `.button-secondary`, `.button-outline`, `.button-ghost`, `.button-danger`, and `.button-icon`; use `.button-sm` or `.button-lg` only when hierarchy requires it.
- Inputs: `.form-input` provides a compact 40px desktop control that expands to a touch-friendly minimum on coarse-pointer devices.
- Cards: `.card` for a shell and `.section-card` for a padded section.
- Toolbars and metrics: `.toolbar`, `.metric-card`, and `.metric-value` provide compact Stripe-style data and filtering regions.
- Icons: call `ui_icon("name")`; icons are decorative by default and accept `label:` when the SVG itself conveys meaning.
- Status: call `status_badge(status, label:, variant:)`; status always includes readable text and never depends on colour alone.
- Shared partials: `page_header`, `stat_card`, `empty_state`, and `avatar` provide consistent composition without moving business logic into views.

## Layout and accessibility

Authenticated desktop pages use a 232px sticky sidebar and 56px topbar. Future modules are kept out of the primary navigation until they become actionable. Mobile pages use a safe-area-aware topbar and fixed five-item bottom navigation. Main content includes enough bottom padding to remain clear of the navigation.

Interactive controls target at least 44px on coarse-pointer devices. Focus indicators are visible, reduced-motion preferences are respected, mobile overflow menus are dialogs with focus management, and icon-only actions require accessible labels. Status never depends on colour alone.
