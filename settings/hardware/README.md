# Hardware profiles

The "Under the Hood" section of the Settings modal shows switches for the
laptop's own features: battery charge limit, power profile, keyboard
backlight, privacy switches. These differ by vendor and model, so each
machine gets its own page. With no page, the section shows a short brief
that points here.

This guide is for an agent or a person who writes a page for a laptop.
Read it in full before you start.

## Files

The page and its scripts are local to your machine. They live in
`settings/hardware/local/`, which is gitignored, so they never go into a
commit or a pull request.

| File | Role |
| --- | --- |
| `HardwareSection.qml` | loads the first `local/*.qml`, else `Brief.qml`. In the repo. |
| `local/<Label>.qml` | your page. The file name is the sidebar label. |
| `local/<name>.sh` | reads the values. No root. |
| `local/<name>-set` | writes. Root only, through `pkexec`. Installed to `/usr/local/bin`. |
| `local/<name>-set.policy` | polkit action, so one password covers a few minutes. |

The shell is its own polkit agent (`polkit/PolkitPrompt.qml`), so no agent
package is needed.

## Steps

1. **Probe.** Run the commands below and keep the output. Note which files
   exist, their values and their possible values.
2. **Test one write by hand** for each feature, as root, and read the file
   back. Some files accept a write and change nothing (see Known traps).
3. **Pick rows.** Only features that passed step 2. Read-only rows first
   (battery health), then live rows, then firmware rows that apply after a
   reboot.
4. **Write the four files** in `local/`. Start from the ThinkPad example
   below.
5. **Install** the helper and the policy:

   ```sh
   sudo install -m 755 settings/hardware/local/<name>-set /usr/local/bin/
   sudo install -m 644 settings/hardware/local/<name>-set.policy /usr/share/polkit-1/actions/
   ```

6. **Reload** with `qs ipc call shell reload` and open the modal with
   `SUPER + SHIFT + H`.

## Probe commands

```sh
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
cat /sys/class/power_supply/BAT*/charge_control_end_threshold  # charge limit
cat /sys/class/power_supply/BAT*/cycle_count
cat /sys/firmware/acpi/platform_profile_choices                # power profile
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences
ls /sys/class/leds/                                           # kbd_backlight
for h in /sys/class/hwmon/hwmon*; do echo "$h $(cat $h/name) $(ls $h | grep -E 'pwm|fan')"; done
ls /sys/class/firmware-attributes/*/attributes/               # BIOS settings
lsusb                                                         # camera, fingerprint ids
```

Each firmware attribute dir has `type`, `current_value` and
`possible_values`. Values can come with a trailing space; trim them.

## Rules

- Writes go through one root helper and `pkexec`. Never `sudo` from QML,
  never a `NOPASSWD` line.
- The helper takes a closed list of commands and checks every value. A
  name used as a path must not contain `/`.
- A write that fails must not flip the switch. The page re-reads the
  values after every write and shows the helper's last stderr line.
- Do not disable the page while a write runs: that drops focus and the
  modal scrolls. Ignore input in `change()` instead.
- Short labels in the UI, sysfs strings in one table in the page.
- Firmware rows apply after a reboot. Say so in the group label.
- Find hwmon and USB devices by name or id, not by number; the number
  changes at boot.

## Example: ThinkPad

Not tested on a real ThinkPad. Needs `thinkpad_acpi`, which every recent
ThinkPad loads. Three rows: charge limit, power profile, keyboard light.
Check `platform_profile_choices` first; some models have other names.

### `local/ThinkPad.qml`

```qml
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../.."

// Live rows for a ThinkPad. thinkpad.sh reads the values every 2 s;
// writes go through pkexec and thinkpad-set.
ColumnLayout {
    id: section

    required property var form

    // Read by the modal: hint in the footer. A page can also set
    // `header`, a Component shown in the pane header.
    readonly property string hint: "Space toggles · ← → choose"

    property var values: ({})
    property bool busy: false
    property string error: ""

    // Pill label → value in sysfs.
    readonly property var limits: ({ "60 %": "60", "80 %": "80", "100 %": "100" })
    readonly property var profiles: ({ "Quiet": "low-power", "Balanced": "balanced", "Performance": "performance" })

    // Switch and SegmentedChoice read and write through a form. This one
    // answers from the live values and writes at once.
    readonly property QtObject live: QtObject {
        readonly property var pending: ({})
        readonly property int rowPadding: section.form.rowPadding
        readonly property var text: section.form.text
        readonly property var colors: section.form.colors

        function valueOf(key) {
            const v = section.values

            switch (key) {
            case "limit":
                return section.label(section.limits, v.limit)
            case "profile":
                return section.label(section.profiles, v.profile)
            default:
                return v[key] !== undefined && v[key] !== "0"
            }
        }

        // Ignore input while a write runs. Do not disable the page: that
        // drops focus and the modal scrolls.
        function change(key, value) {
            if (section.busy)
                return

            switch (key) {
            case "limit":
                section.set(["limit", section.limits[value]])
                break
            case "profile":
                section.set(["profile", section.profiles[value]])
                break
            case "kbd":
                section.set(["kbd", value ? "2" : "0"])
                break
            }
        }
    }

    spacing: 0

    function parse(text) {
        const result = {}
        for (const line of text.trim().split("\n")) {
            const split = line.indexOf("=")
            if (split > 0)
                result[line.slice(0, split)] = line.slice(split + 1)
        }
        return result
    }

    function label(table, value) {
        return Object.keys(table).find(key => table[key] === value) ?? ""
    }

    function set(args) {
        section.busy = true
        section.error = ""
        section.form.showStatus("Authenticating…", section.form.text.dim)
        setProc.command = ["pkexec", "/usr/local/bin/thinkpad-set"].concat(args)
        setProc.running = true
    }

    Process {
        id: readProc

        command: [Quickshell.shellDir + "/settings/hardware/local/thinkpad.sh"]

        stdout: StdioCollector {
            onStreamFinished: section.values = section.parse(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: section.form.visible
        triggeredOnStart: true
        onTriggered: readProc.running = true
    }

    Process {
        id: setProc

        stderr: StdioCollector {
            onStreamFinished: section.error = text.trim().split("\n").pop()
        }

        // pkexec: 126 is a dismissed prompt, 127 no authorization.
        onExited: code => {
            section.busy = false
            readProc.running = true

            if (code === 0)
                section.form.showStatus("✓ Applied", section.form.colors.green)
            else if (code === 126)
                section.form.showStatus("Cancelled", section.form.colors.yellow)
            else
                section.form.showStatus(section.error || "thinkpad-set exit " + code, section.form.colors.red)
        }
    }

    SegmentedChoice {
        form: section.live
        key: "limit"
        label: "Charge limit"
        options: Object.keys(section.limits)
    }

    SegmentedChoice {
        form: section.live
        key: "profile"
        label: "Power profile"
        options: Object.keys(section.profiles)
    }

    Switch {
        form: section.live
        key: "kbd"
        label: "Keyboard light"
    }
}
```

### `local/thinkpad.sh`

```sh
#!/bin/sh
# Values for the ThinkPad page, one key=value per line. No root needed.

echo "limit=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)"
echo "profile=$(cat /sys/firmware/acpi/platform_profile)"
echo "kbd=$(cat '/sys/class/leds/tpacpi::kbd_backlight/brightness')"
```

### `local/thinkpad-set`

```sh
#!/bin/sh
# Root helper for the ThinkPad page. Installed to /usr/local/bin and run
# through pkexec, so it takes only these commands:
#   thinkpad-set limit 60|80|100
#   thinkpad-set profile low-power|balanced|performance
#   thinkpad-set kbd 0|2
# Anything else exits 2 and writes nothing.

die() {
    echo "thinkpad-set: $1" >&2
    exit 2
}

case "$1 $2" in
"limit 60" | "limit 80" | "limit 100")
    printf '%s' "$2" > /sys/class/power_supply/BAT0/charge_control_end_threshold
    ;;
"profile low-power" | "profile balanced" | "profile performance")
    printf '%s' "$2" > /sys/firmware/acpi/platform_profile
    ;;
"kbd 0" | "kbd 2")
    printf '%s' "$2" > '/sys/class/leds/tpacpi::kbd_backlight/brightness'
    ;;
*)
    die "bad command: $*"
    ;;
esac
```

### `local/thinkpad-set.policy`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <!-- pkexec /usr/local/bin/thinkpad-set: one password covers a few minutes. -->
  <action id="local.quickshell.thinkpad-set">
    <description>Change ThinkPad hardware settings</description>
    <message>Authentication is required to change ThinkPad hardware settings</message>
    <defaults>
      <allow_any>auth_admin_keep</allow_any>
      <allow_inactive>auth_admin_keep</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/thinkpad-set</annotate>
  </action>
</policyconfig>
```

## More rows

- **CPU preference** (any Intel or AMD CPU): write
  `energy_performance_preference` in every `/sys/devices/system/cpu/cpu*/cpufreq/`.
  The kernel resets it at boot.
- **Camera or fingerprint reader off**: write `0` to `authorized` of the
  USB device (find it by `idVendor:idProduct`). It resets at boot, so the
  helper also writes a udev rule:
  `ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="xxxx", ATTR{idProduct}=="yyyy", ATTR{authorized}="0"`.
  Open apps may need a restart to see the camera again.
- **Microphone mute**: `pactl set-source-mute <source> 1` for every
  `alsa_input.pci-*` source. No root, and WirePlumber keeps it after a reboot.
- **BIOS settings**: write `current_value` under
  `/sys/class/firmware-attributes/*/attributes/<name>/`. Applies after a
  reboot; show `pending_reboot` when the driver has it.

## Known traps

- **HP**: `hp_bioscfg` lists the BIOS settings, but on the ZBook X G1i every
  privacy write fails with error 0x4. The `hp` hwmon `pwm1_enable` (0 = max)
  is an Omen/Victus call: the ZBook stores the flag and the fan does not
  change.

## Known paths, by vendor

Not tested here. Start from these, then probe.

- **Lenovo ThinkPad**: `charge_control_start_threshold` and
  `charge_control_end_threshold` in `power_supply/BAT0`; fan in
  `/proc/acpi/ibm/fan` (needs `thinkpad_acpi fan_control=1`); keyboard light
  in `/sys/class/leds/tpacpi::kbd_backlight`.
- **ASUS**: `charge_control_end_threshold`; fan profile in
  `/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy`.
- **Dell**: `dell-wmi-sysman` under `/sys/class/firmware-attributes/`.
- **Framework**: `charge_control_end_threshold` with the `framework_laptop` driver.
- **HP**: `hp-bioscfg` under `/sys/class/firmware-attributes/`; see Known traps.
