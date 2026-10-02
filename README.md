# hoja-device-fw

Fork of [HandHeldLegend/hoja-device-fw](https://github.com/HandHeldLegend/hoja-device-fw)
with extra features for the ProGCC controllers.

## What's different from official HOJA firmware 

- LampArray support (Windows Dynamic Lighting)
- True 1000 Hz switch mode
  - Official HOJA firmware paces the Switch USB core at 8 ms (125 Hz). This fork runs it at a genuine 1 ms / 1000 Hz:

## Firmware downloads

All ProGCC builds live in [`builds/`](builds). Download the `.uf2` for your
model:

| Model | Platform | Firmware |
| --- | --- | --- |
| ProGCC 3 | RP2040 | [progcc_3.uf2](https://github.com/saad-script/hoja-device-fw/raw/main/builds/progcc_3/progcc_3.uf2) |
| ProGCC 3P | RP2040 | [progcc_3p.uf2](https://github.com/saad-script/hoja-device-fw/raw/main/builds/progcc_3p/progcc_3p.uf2) |
| ProGCC 3.1 | RP2040 | [progcc_3.1.uf2](https://github.com/saad-script/hoja-device-fw/raw/main/builds/progcc_3.1/progcc_3.1.uf2) |
| ProGCC 3.2 | RP2040 | [progcc_3.2.uf2](https://github.com/saad-script/hoja-device-fw/raw/main/builds/progcc_3.2/progcc_3.2.uf2) |
| ProGCC 3S | RP2350 | [progcc_3s.uf2](https://github.com/saad-script/hoja-device-fw/raw/main/builds/progcc_3s/progcc_3s.uf2) |

### Flashing

Using the official HOJA 2 Config web app:

1. Go to the official web app: https://handheldlegend.github.io/hoja2
2. Plug in controller to PC.
3. Click the **Connect** button in top left corner.
4. Select your controller in the browser pop-up and click **connect**.
5. On the main page, click on the **Gamepad** button.
6. Scroll down and click on **bootloader** button.
7. Your controller will show as a removable drive (`RPI-RP2` (RP2040) or `RP2350`).
8. Drag the `.uf2` onto that drive. The controller reboots into the new firmware automatically.


Alternatively, you can manually flash the controller:

1. Unplug the controller.
2. Hold **L + Plus** and then plug it into your PC over USB. Keep them held until it mounts.
3. It mounts as a `RPI-RP2` (RP2040) or `RP2350` drive.
4. Drag the `.uf2` onto that drive. The controller reboots into the new firmware automatically.

## Building from source

Requires the Pico SDK (>= 2.2.0) with `PICO_SDK_PATH` exported, plus
`arm-none-eabi-gcc`, `cmake` and `picotool`.

```sh
./build_progcc.sh                   # clean + configure + build every ProGCC model
./build_progcc.sh progcc_3.2        # build a single model
./build_progcc.sh --platform rp2040 # build everything on one platform
./build_progcc.sh --no-clean        # incremental rebuild
./build_progcc.sh --list            # list discovered models
./build_progcc.sh -j 8              # parallel job count
```

