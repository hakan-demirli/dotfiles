#include <pebble.h>

#define RING_THICKNESS 14
#define TICK_INSET 26
#define TICK_RADIUS 3
#define BATTERY_ARC_SPAN 100

static Window *s_window;
static Layer *s_dial_layer;
static TextLayer *s_time_layer;
static TextLayer *s_date_layer;

static char s_time_buffer[8];
static char s_date_buffer[24];

static int s_minute_of_hour;
static int s_hour_of_day;
static uint8_t s_battery_percent;

static GColor prv_accent_for_hour(int hour) {
  if (hour < 6) {
    return GColorVividCerulean;
  }
  if (hour < 12) {
    return GColorChromeYellow;
  }
  if (hour < 18) {
    return GColorOrange;
  }
  return GColorMelon;
}

static void prv_draw_hour_ticks(GContext *ctx, GRect bounds) {
  const GPoint center = grect_center_point(&bounds);
  const int16_t radius = (bounds.size.w / 2) - TICK_INSET;

  graphics_context_set_fill_color(ctx, GColorDarkGray);
  for (int i = 0; i < 12; i++) {
    const int32_t angle = TRIG_MAX_ANGLE * i / 12;
    const GPoint tick = {
      .x = center.x + (int16_t)(sin_lookup(angle) * radius / TRIG_MAX_RATIO),
      .y = center.y - (int16_t)(cos_lookup(angle) * radius / TRIG_MAX_RATIO),
    };
    const uint16_t r = (i % 3 == 0) ? TICK_RADIUS + 2 : TICK_RADIUS;
    graphics_fill_circle(ctx, tick, r);
  }
}

static void prv_draw_minute_ring(GContext *ctx, GRect bounds) {
  const int32_t sweep = TRIG_MAX_ANGLE * s_minute_of_hour / 60;

  graphics_context_set_fill_color(ctx, GColorOxfordBlue);
  graphics_fill_radial(ctx, bounds, GOvalScaleModeFitCircle, RING_THICKNESS, 0, TRIG_MAX_ANGLE);

  graphics_context_set_fill_color(ctx, prv_accent_for_hour(s_hour_of_day));
  graphics_fill_radial(ctx, bounds, GOvalScaleModeFitCircle, RING_THICKNESS, 0, sweep);
}

static void prv_draw_battery_arc(GContext *ctx, GRect bounds) {
  const GRect arc_bounds = grect_inset(bounds, GEdgeInsets(RING_THICKNESS + 6));
  const int32_t half_span = DEG_TO_TRIGANGLE(BATTERY_ARC_SPAN / 2);
  const int32_t start = DEG_TO_TRIGANGLE(180) - half_span;
  const int32_t filled = start + (2 * half_span * s_battery_percent / 100);

  graphics_context_set_stroke_width(ctx, 4);

  graphics_context_set_stroke_color(ctx, GColorDarkGray);
  graphics_draw_arc(ctx, arc_bounds, GOvalScaleModeFitCircle, start, start + (2 * half_span));

  graphics_context_set_stroke_color(ctx,
                                    s_battery_percent <= 20 ? GColorSunsetOrange : GColorLightGray);
  graphics_draw_arc(ctx, arc_bounds, GOvalScaleModeFitCircle, start, filled);
}

static void prv_dial_update_proc(Layer *layer, GContext *ctx) {
  const GRect bounds = layer_get_bounds(layer);

  graphics_context_set_antialiased(ctx, true);
  prv_draw_minute_ring(ctx, bounds);
  prv_draw_hour_ticks(ctx, bounds);
  prv_draw_battery_arc(ctx, bounds);
}

static void prv_render_time(struct tm *tick_time) {
  s_minute_of_hour = tick_time->tm_min;
  s_hour_of_day = tick_time->tm_hour;

  strftime(s_time_buffer, sizeof(s_time_buffer),
           clock_is_24h_style() ? "%H:%M" : "%I:%M", tick_time);
  strftime(s_date_buffer, sizeof(s_date_buffer), "%A %d", tick_time);

  text_layer_set_text(s_time_layer, s_time_buffer);
  text_layer_set_text(s_date_layer, s_date_buffer);
  layer_mark_dirty(s_dial_layer);
}

static void prv_tick_handler(struct tm *tick_time, TimeUnits units_changed) {
  prv_render_time(tick_time);
}

static void prv_battery_handler(BatteryChargeState state) {
  s_battery_percent = state.charge_percent;
  layer_mark_dirty(s_dial_layer);
}

static TextLayer *prv_make_text_layer(Layer *parent, GRect frame, const char *font_key,
                                      GColor color) {
  TextLayer *layer = text_layer_create(frame);
  text_layer_set_background_color(layer, GColorClear);
  text_layer_set_text_color(layer, color);
  text_layer_set_font(layer, fonts_get_system_font(font_key));
  text_layer_set_text_alignment(layer, GTextAlignmentCenter);
  layer_add_child(parent, text_layer_get_layer(layer));
  return layer;
}

static void prv_window_load(Window *window) {
  Layer *root = window_get_root_layer(window);
  const GRect bounds = layer_get_bounds(root);

  s_dial_layer = layer_create(bounds);
  layer_set_update_proc(s_dial_layer, prv_dial_update_proc);
  layer_add_child(root, s_dial_layer);

  const GRect time_frame = GRect(0, (bounds.size.h / 2) - 46, bounds.size.w, 72);
  s_time_layer = prv_make_text_layer(root, time_frame, FONT_KEY_LECO_60_BOLD_NUMBERS_AM_PM,
                                     GColorWhite);

  const GRect date_frame = GRect(0, (bounds.size.h / 2) + 28, bounds.size.w, 34);
  s_date_layer = prv_make_text_layer(root, date_frame, FONT_KEY_GOTHIC_24_BOLD, GColorLightGray);

  const time_t now = time(NULL);
  prv_render_time(localtime(&now));
  prv_battery_handler(battery_state_service_peek());
}

static void prv_window_unload(Window *window) {
  text_layer_destroy(s_date_layer);
  text_layer_destroy(s_time_layer);
  layer_destroy(s_dial_layer);
}

static void prv_init(void) {
  s_window = window_create();
  window_set_background_color(s_window, GColorBlack);
  window_set_window_handlers(s_window, (WindowHandlers) {
    .load = prv_window_load,
    .unload = prv_window_unload,
  });
  window_stack_push(s_window, true);

  tick_timer_service_subscribe(MINUTE_UNIT, prv_tick_handler);
  battery_state_service_subscribe(prv_battery_handler);
}

static void prv_deinit(void) {
  battery_state_service_unsubscribe();
  tick_timer_service_unsubscribe();
  window_destroy(s_window);
}

int main(void) {
  prv_init();
  app_event_loop();
  prv_deinit();
}
