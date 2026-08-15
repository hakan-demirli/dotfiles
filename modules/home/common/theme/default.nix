# Bridges the Dracula colour specification onto the Material 3 role model.
#
# Dracula is authoritative for every colour it publishes. Material 3 supplies
# structure and fills only the gaps Dracula leaves: the intermediate surface
# steps, the on-accent colours and the accent containers.
#
# Dracula's neutrals lie on a single tonal line (hue 276.77, chroma 11.36), so
# the derived surface steps extend Dracula's own ramp rather than introducing a
# new hue. Dracula Background measures tone 17.3, which is the Material 3
# surfaceContainerHigh position, so panels and bars keep their current colour
# while gaining depth steps above and below.
let
  dracula = import ./dracula.nix;
  m3 = import ./m3.nix;
  tones = import ./tones.nix;

  neutral = role: tones.neutral.${toString m3.darkTone.${role}};

  # Nix renders floats with six decimal places; trim to the shortest exact form.
  number =
    n:
    let
      s = builtins.toString n;
      whole = builtins.match "(-?[0-9]+)\\.?0*" s;
      fraction = builtins.match "(-?[0-9]+\\.[0-9]*[1-9])0*" s;
    in
    if whole != null then
      builtins.head whole
    else if fraction != null then
      builtins.head fraction
    else
      s;

  bezier = points: "cubic-bezier(${builtins.concatStringsSep ", " (map number points)})";

  # Roboto is the Material 3 reference typeface, so the vendored type scale's
  # sizes, line heights and tracking were measured against its metrics.
  family = {
    plain = "Roboto";
    brand = "Roboto";
    mono = "JetBrainsMono Nerd Font Mono";
    icon = "Symbols Nerd Font Mono";
  };
in
{
  inherit (dracula) ansi syntax;
  inherit (m3) state elevation;

  dracula = dracula.standard;

  palette = {
    surface = neutral "surface";
    surfaceDim = neutral "surfaceDim";
    surfaceBright = neutral "surfaceBright";
    surfaceContainerLowest = neutral "surfaceContainerLowest";
    surfaceContainerLow = neutral "surfaceContainerLow";
    surfaceContainer = neutral "surfaceContainer";
    surfaceContainerHigh = dracula.standard.background;
    surfaceContainerHighest = neutral "surfaceContainerHighest";

    onSurface = dracula.standard.foreground;
    onSurfaceVariant = neutral "onSurfaceVariant";
    outline = dracula.standard.comment;
    outlineVariant = dracula.standard.selection;

    inverseSurface = neutral "onSurface";
    inverseOnSurface = tones.neutral."20";

    shadow = "#000000";
    scrim = "#000000";

    primary = dracula.standard.purple;
    onPrimary = tones.onAccent.purple;
    primaryContainer = tones.accentContainer.purple;
    onPrimaryContainer = tones.onAccentContainer.purple;
    primaryFixed = tones.accentFixed.purple;
    primaryFixedDim = tones.accentFixedDim.purple;

    secondary = dracula.standard.pink;
    onSecondary = tones.onAccent.pink;
    secondaryContainer = tones.accentContainer.pink;
    onSecondaryContainer = tones.onAccentContainer.pink;
    secondaryFixed = tones.accentFixed.pink;
    secondaryFixedDim = tones.accentFixedDim.pink;

    tertiary = dracula.standard.cyan;
    onTertiary = tones.onAccent.cyan;
    tertiaryContainer = tones.accentContainer.cyan;
    onTertiaryContainer = tones.onAccentContainer.cyan;
    tertiaryFixed = tones.accentFixed.cyan;
    tertiaryFixedDim = tones.accentFixedDim.cyan;

    error = dracula.standard.red;
    onError = tones.onAccent.red;
    errorContainer = tones.accentContainer.red;
    onErrorContainer = tones.onAccentContainer.red;

    success = dracula.standard.green;
    onSuccess = tones.onAccent.green;
    successContainer = tones.accentContainer.green;
    onSuccessContainer = tones.onAccentContainer.green;

    warning = dracula.standard.orange;
    onWarning = tones.onAccent.orange;
    warningContainer = tones.accentContainer.orange;
    onWarningContainer = tones.onAccentContainer.orange;
  };

  inherit (m3) shape;

  # Component dimensions that no specification fixes, but which GTK CSS needs
  # spelled out because it cannot express "distribute evenly" or "align".
  sizes =
    let
      controlCentre = 500;
      columns = 4;
      # .control-center padding, plus the .widget margin and padding around the
      # button grid, on both sides.
      insets = 2 * m3.shape.extraSmall + 4 * m3.shape.small;
      gaps = (columns - 1) * m3.shape.small;
    in
    {
      swayncWidth = controlCentre;
      # Giving every cell the same width is what makes the labels centre
      # evenly. GTK CSS has no homogeneous or align property, so the width has
      # to be stated rather than derived by the toolkit. Column gaps are
      # subtracted so four cells can never overflow onto a second row.
      swayncButtonCell = (controlCentre - insets - gaps) / columns;
      swayncIcon = 24;
      swayncAlbumArt = 96;
      notificationImage = 48;
    };

  # Material 3 publishes no spacing token set. Its layout guidance is a 4dp
  # grid, and the shape ladder is the published set of 4dp multiples, so it is
  # reused here rather than inventing a second scale.
  space = {
    inherit (m3.shape)
      none
      extraSmall
      small
      medium
      large
      extraLarge
      ;
  };

  font = {
    inherit family;

    scale = builtins.mapAttrs (_: role: role // { family = family.${role.typeface}; }) m3.typescale;
  };

  motion = {
    inherit (m3.motion) duration easing;

    css = builtins.mapAttrs (_: bezier) m3.motion.easing;
  };
}
