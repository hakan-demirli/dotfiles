#pragma once

/* Handedness. */
// #define MASTER_LEFT

// To use the handedness pin, resistors need to be installed on the adapter PCB.
// If so, uncomment the following code, and undefine MASTER_RIGHT above.
// This will read the specified pin. By default, if it's high, then the controller assumes it is the left hand, and if it's low, it's assumed to be the right side.
#define SPLIT_HAND_PIN GP10
#define SPLIT_HAND_PIN_LOW_IS_LEFT  // High -> right, Low -> left.



// // Home row mods
// Configure the global tapping term (default: 200ms)
#define TAPPING_TERM 200
// Enable rapid switch from tap to hold, disables double tap hold auto-repeat.
#define QUICK_TAP_TERM 0


#define MOUSEKEY_INTERVAL 16
#define MOUSEKEY_DELAY 0
#define MOUSEKEY_TIME_TO_MAX 60
#define MOUSEKEY_MAX_SPEED 7
#define MOUSEKEY_WHEEL_DELAY 0

