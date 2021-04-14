/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Device Tree defines for Advantech Embedded Controller (AHC1EC0)
 */

#ifndef _DT_BINDINGS_MFD_AHC1EC0_H
#define _DT_BINDINGS_MFD_AHC1EC0_H

/* Sub-device Definitions */
#define AHC1EC0_SUBDEV_BRIGHTNESS 0x0
#define AHC1EC0_SUBDEV_EEPROM     0x1
#define AHC1EC0_SUBDEV_GPIO       0x2
#define AHC1EC0_SUBDEV_HWMON      0x3
#define AHC1EC0_SUBDEV_LED        0x4
#define AHC1EC0_SUBDEV_WDT        0x5

/* HWMON Profile Definitions */
#define AHC1EC0_HWMON_PRO_TEMPLATE 0x0
#define AHC1EC0_HWMON_PRO_TPC5XXX  0x1
#define AHC1EC0_HWMON_PRO_PRVR4    0x2
#define AHC1EC0_HWMON_PRO_UNO2271G 0x3
#define AHC1EC0_HWMON_PRO_UNO1172A 0x4
#define AHC1EC0_HWMON_PRO_UNO1372G 0x5

#endif /* _DT_BINDINGS_MFD_AHC1EC0_H */
