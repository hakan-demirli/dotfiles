import subprocess
import time


while True:
    battery_status = (
        subprocess.run(
            ["cat", "/sys/class/power_supply/BAT1/status"], stdout=subprocess.PIPE
        )
        .stdout.decode()
        .strip()
    )
    battery_charge = int(
        subprocess.run(
            ["cat", "/sys/class/power_supply/BAT1/capacity"], stdout=subprocess.PIPE
        )
        .stdout.decode()
        .strip()
    )

    if battery_status == "Discharging":
        if battery_charge <= 10:
            subprocess.run(
                [
                    "notify-send",
                    "--urgency=critical",
                    "Battery critical!",
                    f"Battery at {battery_charge}%",
                ]
            )
            time.sleep(180)
        elif battery_charge <= 20:
            subprocess.run(
                ["notify-send", "Battery low!", f"Battery at {battery_charge}%"]
            )
            time.sleep(360)
    time.sleep(600)
