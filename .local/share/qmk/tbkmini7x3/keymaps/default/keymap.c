#include QMK_KEYBOARD_H

enum layer_names {
    QWERTY,
    QWERTY_LEFT,
    QWERTY_RIGHT,
    FUN_LAYER
};

enum custom_keycodes {
    MO_NO_MOD = SAFE_RANGE
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    // clang-format off
    [QWERTY] = LAYOUT(
        // Left
           KC_TAB,                        KC_Q,       KC_W,       KC_E,        KC_R,          KC_T,         KC_LCTL,
           KC_ESC,                        KC_A,       KC_S,       KC_D,        KC_F,          KC_G,         LM(QWERTY_RIGHT, MOD_LALT),
           KC_LSFT,                       KC_Z,       KC_X,       KC_C,        KC_V,          KC_B,         KC_SPC,
        // Right
           KC_RCTL,                       KC_Y,       KC_U,       KC_I,        KC_O,          KC_P,         KC_LBRC,
           LM(QWERTY_LEFT, MOD_RALT),     KC_H,       KC_J,       KC_K,        KC_L,          KC_SCLN,      KC_QUOTE,
           KC_RGUI,                       KC_N,       KC_M,       KC_COMM,     KC_DOT,        KC_SLSH,      KC_RSFT
        ),
    [QWERTY_LEFT] = LAYOUT(
        // Left
           KC_TAB,        KC_Q,       KC_W,       KC_E,        KC_R,          KC_T,         KC_LCTL,
           KC_ESC,        KC_A,       KC_S,       KC_D,        KC_F,          KC_G,         MO(FUN_LAYER),  // Changed to MO
           KC_LSFT,       KC_Z,       KC_X,       KC_C,        KC_V,          KC_B,         KC_SPC,
        // Right
           KC_RCTL,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      KC_LBRC,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      KC_QUOTE,
           KC_RGUI,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      KC_RSFT
        ),
    [QWERTY_RIGHT] = LAYOUT(
        // Left
           KC_TAB,        XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      KC_LCTL,
           KC_ESC,        XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           KC_LSFT,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      KC_SPC,
        // Right
           KC_RCTL,       KC_Y,       KC_U,       KC_I,        KC_O,          KC_P,         KC_LBRC,
           MO(FUN_LAYER), KC_H,       KC_J,       KC_K,        KC_L,          KC_SCLN,      KC_QUOTE,      // Changed to MO
           KC_RGUI,       KC_N,       KC_M,       KC_COMM,     KC_DOT,        KC_SLSH,      KC_RSFT
        ),
    [FUN_LAYER] = LAYOUT(
        // Left
           KC_F1,         KC_F2,      KC_F3,      KC_F4,       KC_F5,         KC_F6,        KC_LCTL,
           KC_ESC,        XXXXXXX,    XXXXXXX,    KC_MS_BTN2,  KC_MS_BTN1,    XXXXXXX,      XXXXXXX,
           XXXXXXX,       QK_BOOT,    XXXXXXX,    KC_MS_WH_UP, KC_MS_WH_DOWN, XXXXXXX,      XXXXXXX,
        // Right
           KC_RCTL,       KC_F7,      KC_F8,      KC_F9,       KC_F10,        KC_F11,       KC_F12,
           XXXXXXX,       KC_MS_LEFT, KC_MS_DOWN, KC_MS_UP,    KC_MS_RIGHT,   XXXXXXX,      XXXXXXX,
           KC_RGUI,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    // clang-format on
};

// Function to handle custom layer state changes
layer_state_t layer_state_set_user(layer_state_t state)
{
    // Clear mods when entering FUN_LAYER
    if (layer_state_cmp(state, FUN_LAYER)) {
        clear_mods();
        clear_weak_mods();
        clear_oneshot_mods();
        unregister_mods(MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT | MOD_MASK_GUI);
    }
    return state;
}

uint8_t mod_state;
bool process_record_user(uint16_t keycode, keyrecord_t* record)
{
    // Store mod state when pressing any key
    if (record->event.pressed) {
        mod_state = get_mods();
    }

    switch (keycode) {
    case KC_MS_WH_UP:
    case KC_MS_WH_DOWN:
        if (IS_LAYER_ON(FUN_LAYER)) {
            clear_mods();
            clear_weak_mods();
            clear_oneshot_mods();
            unregister_mods(MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT | MOD_MASK_GUI);
        }
        return true;
    }
    return true;
}
