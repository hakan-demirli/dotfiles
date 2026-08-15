# Vendored Material Design 3 system tokens, design system version v0.192.
# Source: https://github.com/material-components/material-web/tree/main/tokens/versions/v0_192
#   shape     _md-sys-shape.scss
#   typescale _md-sys-typescale.scss  (rem values converted at 1rem = 16px)
#   motion    _md-sys-motion.scss
#   state     _md-sys-state.scss
#   elevation _md-sys-elevation.scss
# Surface tone positions are the dark-scheme values at contrastLevel 0 from
# https://github.com/material-foundation/material-color-utilities
#   typescript/dynamiccolor/color_spec_2021.ts
{
  weight = {
    regular = 400;
    medium = 500;
    bold = 700;
  };

  shape = {
    none = 0;
    extraSmall = 4;
    small = 8;
    medium = 12;
    large = 16;
    extraLarge = 28;
    full = 9999;
  };

  typescale = {
    displayLarge = {
      size = 57;
      lineHeight = 64;
      tracking = -0.25;
      weight = 400;
      typeface = "brand";
    };
    displayMedium = {
      size = 45;
      lineHeight = 52;
      tracking = 0.0;
      weight = 400;
      typeface = "brand";
    };
    displaySmall = {
      size = 36;
      lineHeight = 44;
      tracking = 0.0;
      weight = 400;
      typeface = "brand";
    };

    headlineLarge = {
      size = 32;
      lineHeight = 40;
      tracking = 0.0;
      weight = 400;
      typeface = "brand";
    };
    headlineMedium = {
      size = 28;
      lineHeight = 36;
      tracking = 0.0;
      weight = 400;
      typeface = "brand";
    };
    headlineSmall = {
      size = 24;
      lineHeight = 32;
      tracking = 0.0;
      weight = 400;
      typeface = "brand";
    };

    titleLarge = {
      size = 22;
      lineHeight = 28;
      tracking = 0.0;
      weight = 400;
      typeface = "brand";
    };
    titleMedium = {
      size = 16;
      lineHeight = 24;
      tracking = 0.15;
      weight = 500;
      typeface = "plain";
    };
    titleSmall = {
      size = 14;
      lineHeight = 20;
      tracking = 0.1;
      weight = 500;
      typeface = "plain";
    };

    bodyLarge = {
      size = 16;
      lineHeight = 24;
      tracking = 0.5;
      weight = 400;
      typeface = "plain";
    };
    bodyMedium = {
      size = 14;
      lineHeight = 20;
      tracking = 0.25;
      weight = 400;
      typeface = "plain";
    };
    bodySmall = {
      size = 12;
      lineHeight = 16;
      tracking = 0.4;
      weight = 400;
      typeface = "plain";
    };

    labelLarge = {
      size = 14;
      lineHeight = 20;
      tracking = 0.1;
      weight = 500;
      typeface = "plain";
    };
    labelMedium = {
      size = 12;
      lineHeight = 16;
      tracking = 0.5;
      weight = 500;
      typeface = "plain";
    };
    labelSmall = {
      size = 11;
      lineHeight = 16;
      tracking = 0.5;
      weight = 500;
      typeface = "plain";
    };
  };

  motion = {
    duration = {
      short1 = 50;
      short2 = 100;
      short3 = 150;
      short4 = 200;
      medium1 = 250;
      medium2 = 300;
      medium3 = 350;
      medium4 = 400;
      long1 = 450;
      long2 = 500;
      long3 = 550;
      long4 = 600;
      extraLong1 = 700;
      extraLong2 = 800;
      extraLong3 = 900;
      extraLong4 = 1000;
    };

    easing = {
      emphasized = [
        0.2
        0.0
        0.0
        1.0
      ];
      emphasizedAccelerate = [
        0.3
        0.0
        0.8
        0.15
      ];
      emphasizedDecelerate = [
        0.05
        0.7
        0.1
        1.0
      ];
      standard = [
        0.2
        0.0
        0.0
        1.0
      ];
      standardAccelerate = [
        0.3
        0.0
        1.0
        1.0
      ];
      standardDecelerate = [
        0.0
        0.0
        0.0
        1.0
      ];
      linear = [
        0.0
        0.0
        1.0
        1.0
      ];
      legacy = [
        0.4
        0.0
        0.2
        1.0
      ];
      legacyAccelerate = [
        0.4
        0.0
        1.0
        1.0
      ];
      legacyDecelerate = [
        0.0
        0.0
        0.2
        1.0
      ];
    };
  };

  state = {
    hoverOpacity = 0.08;
    focusOpacity = 0.12;
    pressedOpacity = 0.12;
    draggedOpacity = 0.16;
  };

  elevation = [
    0
    1
    3
    6
    8
    12
  ];

  darkTone = {
    surfaceContainerLowest = 4;
    surface = 6;
    surfaceDim = 6;
    surfaceContainerLow = 10;
    surfaceContainer = 12;
    surfaceContainerHigh = 17;
    surfaceContainerHighest = 22;
    surfaceBright = 24;
    outlineVariant = 30;
    outline = 60;
    onSurfaceVariant = 80;
    onSurface = 90;
  };
}
