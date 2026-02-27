#include "maybe_bluetooth.h"
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/stepper.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#ifdef CONFIG_SHELL
#include "shell.h"
#endif
#include "StateMachine.h"
#include "stepper_with_target/StepperWithTarget.h"

LOG_MODULE_REGISTER(main, LOG_LEVEL_INF);

#define STEPPER_NODE DT_NODELABEL(stepper_motor)
#define LED0_NODE DT_ALIAS(led0)

static StepperWithTarget *init_stepper(void) {
  int ret;
  const struct device *stepper_dev = DEVICE_DT_GET(STEPPER_NODE);

  if (!device_is_ready(stepper_dev)) {
    LOG_ERR("Stepper device is not ready");
    return nullptr;
  }

  LOG_INF("Stepper device is ready");

  uint32_t micro_step_res = DT_PROP(STEPPER_NODE, micro_step_res);

  static StepperWithTarget stepper(stepper_dev, 1, 200 * micro_step_res);

  ret = stepper.enable();
  if (ret < 0) {
    LOG_ERR("Failed to enable stepper: %d", ret);
    return nullptr;
  }

  return &stepper;
}

static struct k_timer led_blink_timer;
static const struct gpio_dt_spec *async_led = nullptr;
static int blink_phase = 0;

static void led_blink_timer_handler(struct k_timer *timer) {
  if (async_led && gpio_is_ready_dt(async_led)) {
    if (blink_phase == 1) {
      gpio_pin_set(async_led->port, async_led->pin, 1);
      blink_phase = 0;
      k_timer_stop(&led_blink_timer);
    }
  }
}

static void init_async_led(const struct gpio_dt_spec *led) {
  async_led = led;
  blink_phase = 0;
  k_timer_init(&led_blink_timer, led_blink_timer_handler, nullptr);
  if (async_led && gpio_is_ready_dt(async_led)) {
    gpio_pin_set(async_led->port, async_led->pin, 1);
  }
}

static void trigger_async_led_blink(int blink_duration_ms) {
  if (async_led && gpio_is_ready_dt(async_led) && blink_phase == 0) {
    gpio_pin_set(async_led->port, async_led->pin, 0);
    blink_phase = 1;
    k_timer_start(&led_blink_timer, K_MSEC(blink_duration_ms), K_NO_WAIT);
  }
}

static void stop_async_led() {
  k_timer_stop(&led_blink_timer);
  if (async_led && gpio_is_ready_dt(async_led)) {
    gpio_pin_set(async_led->port, async_led->pin, 0);
  }
}

int main(void) {
  int32_t ret;
  static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);
  const struct device *led_dev = nullptr;

  if (gpio_is_ready_dt(&led)) {
    ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);
    if (ret >= 0) {
      led_dev = led.port;
    }
  }

  init_async_led(&led);
  trigger_async_led_blink(100);
  k_msleep(200);

  SonyRemote *remote = init_maybe_bluetooth();
  if (!remote) {
    LOG_ERR("Failed to initialize Bluetooth");
    return -1;
  }

  trigger_async_led_blink(100);
  k_msleep(200);
  trigger_async_led_blink(100);
  k_msleep(200);

  LOG_INF("initialize stepper ...");
  StepperWithTarget *stepper = init_stepper();
  if (stepper == nullptr) {
    LOG_ERR("Failed to initialize stepper");
    return -1;
  }

  StateMachine sm(stepper, remote);

#ifdef BUILD_COMMIT
  LOG_INF("Build commit: %s", BUILD_COMMIT);
#endif

  LOG_INF("entering main loop ...");
  while (1) {
    LOG_DBG("loop...");
    trigger_async_led_blink(50);
    ret = sm.run_state_machine();
    if (ret) {
      break;
    }
  }

  stop_async_led();
  remote->end();

  return 0;
}

#ifdef CONFIG_SHELL
#endif