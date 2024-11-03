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
           KC_ESC,        KC_A,       KC_S,       KC_D,        KC_F,          KC_G,         MO_NO_MOD,
           KC_LSFT,       KC_Z,       KC_X,       KC_C,        KC_V,          KC_B,         KC_SPC,
        // Right
           KC_RCTL,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      KC_LBRC,
           _______,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      KC_QUOTE,
           KC_RGUI,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      KC_RSFT
        ),
    [QWERTY_RIGHT] = LAYOUT(
        // Left
           KC_TAB,        XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      KC_LCTL,
           KC_ESC,        XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      _______,
           KC_LSFT,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      KC_SPC,
        // Right
           KC_RCTL,       KC_Y,       KC_U,       KC_I,        KC_O,          KC_P,         KC_LBRC,
           MO_NO_MOD,     KC_H,       KC_J,       KC_K,        KC_L,          KC_SCLN,      KC_QUOTE,
           KC_RGUI,       KC_N,       KC_M,       KC_COMM,     KC_DOT,        KC_SLSH,      KC_RSFT
        ),
    [FUN_LAYER] = LAYOUT(
        // Left
           KC_F1,         KC_F2,      KC_F3,      KC_F4,       KC_F5,         KC_F6,        XXXXXXX,
           QK_BOOT,       KC_LGUI,    XXXXXXX,    KC_MS_BTN2,  KC_MS_BTN1,    XXXXXXX,      _______,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    KC_MS_WH_UP, KC_MS_WH_DOWN, XXXXXXX,      XXXXXXX,
        // Right
           XXXXXXX,       KC_F7,      KC_F8,      KC_F9,       KC_F10,        KC_F11,       KC_F12,
           _______,       KC_MS_LEFT, KC_MS_DOWN, KC_MS_UP,    KC_MS_RIGHT,   XXXXXXX,      XXXXXXX,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    // clang-format on
};

bool process_record_user(uint16_t keycode, keyrecord_t* record)
{
    static bool no_mod_active = false;

    switch (keycode) {
    case MO_NO_MOD:
        if (record->event.pressed) {
            no_mod_active = true;
            clear_mods();
            clear_oneshot_mods();
            layer_on(FUN_LAYER);
        } else {
            no_mod_active = false;
            layer_off(FUN_LAYER);
        }
        return false;
    case KC_MS_WH_UP:
    case KC_MS_WH_DOWN:
        if (no_mod_active) {
            clear_mods();
            clear_oneshot_mods();
        }
        return true;
    }
    return true;
}
