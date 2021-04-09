/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef __LINUX_MFD_AHC1EC0_H
#define __LINUX_MFD_AHC1EC0_H

#include <linux/device.h>

#define EC_COMMAND_PORT             0x29A /* EC I/O command port */
#define EC_STATUS_PORT              0x299 /* EC I/O data port */

#define EC_RETRY_UDELAY              200 /* EC command retry delay in microseconds */
#define EC_MAX_TIMEOUT_COUNT        5000 /* EC command max retry count */
#define EC_COMMAND_BIT_OBF          0x01 /* Bit 0 is for OBF ready (Output buffer full) */
#define EC_COMMAND_BIT_IBF          0x02 /* Bit 1 is for IBF ready (Input buffer full) */

/* Analog to digital converter command */
#define EC_AD_INDEX_WRITE   0x15 /* Write ADC port number into index */
#define EC_AD_LSB_READ      0x16 /* Read ADC LSB value from ADC port */
#define EC_AD_MSB_READ      0x1F /* Read ADC MSB value from ADC port */

/* Voltage device ID */
#define EC_DID_SMBOEM0      0x28 /* SMBUS/I2C. Smbus channel 0 */
#define EC_DID_CMOSBAT      0x50 /* CMOS coin battery voltage */
#define EC_DID_CMOSBAT_X2   0x51 /* CMOS coin battery voltage*2 */
#define EC_DID_CMOSBAT_X10  0x52 /* CMOS coin battery voltage*10 */
#define EC_DID_5VS0         0x56 /* 5VS0 voltage */
#define EC_DID_5VS0_X2      0x57 /* 5VS0 voltage*2 */
#define EC_DID_5VS0_X10     0x58 /* 5VS0 voltage*10 */
#define EC_DID_5VS5         0x59 /* 5VS5 voltage */
#define EC_DID_5VS5_X2      0x5A /* 5VS5 voltage*2 */
#define EC_DID_5VS5_X10     0x5B /* 5VS5 voltage*10 */
#define EC_DID_12VS0        0x62 /* 12VS0 voltage */
#define EC_DID_12VS0_X2     0x63 /* 12VS0 voltage*2 */
#define EC_DID_12VS0_X10    0x64 /* 12VS0 voltage*10 */
#define EC_DID_VCOREA       0x65 /* CPU A core voltage */
#define EC_DID_VCOREA_X2    0x66 /* CPU A core voltage*2 */
#define EC_DID_VCOREA_X10   0x67 /* CPU A core voltage*10 */
#define EC_DID_VCOREB       0x68 /* CPU B core voltage */
#define EC_DID_VCOREB_X2    0x69 /* CPU B core voltage*2 */
#define EC_DID_VCOREB_X10   0x6A /* CPU B core voltage*10 */
#define EC_DID_DC           0x6B /* ADC. onboard voltage */
#define EC_DID_DC_X2        0x6C /* ADC. onboard voltage*2 */
#define EC_DID_DC_X10       0x6D /* ADC. onboard voltage*10 */

/* Current device ID */
#define EC_DID_CURRENT              0x74

/* ACPI commands */
#define EC_ACPI_RAM_READ            0x80
#define EC_ACPI_RAM_WRITE           0x81

/*
 *  Dynamic control table commands
 *  The table includes HW pin number, Device ID, and Pin polarity
 */
#define EC_TBL_WRITE_ITEM           0x20
#define EC_TBL_GET_PIN              0x21
#define EC_TBL_GET_DEVID            0x22
#define EC_MAX_TBL_NUM              32

/* LED Device ID table */
#define EC_DID_LED_RUN              0xE1
#define EC_DID_LED_ERR              0xE2
#define EC_DID_LED_SYS_RECOVERY     0xE3
#define EC_DID_LED_D105_G           0xE4
#define EC_DID_LED_D106_G           0xE5
#define EC_DID_LED_D107_G           0xE6

/* LED control HW RAM address 0xA0-0xAF */
#define EC_HWRAM_LED_BASE_ADDR      0xA0
#define EC_HWRAM_LED_PIN(N)         (EC_HWRAM_LED_BASE_ADDR + (4 * (N))) // N:0-3
#define EC_HWRAM_LED_CTRL_HIBYTE(N) (EC_HWRAM_LED_BASE_ADDR + (4 * (N)) + 1)
#define EC_HWRAM_LED_CTRL_LOBYTE(N) (EC_HWRAM_LED_BASE_ADDR + (4 * (N)) + 2)
#define EC_HWRAM_LED_DEVICE_ID(N)   (EC_HWRAM_LED_BASE_ADDR + (4 * (N)) + 3)

/* LED control bit */
#define LED_CTRL_ENABLE_BIT()           BIT(4)
#define LED_CTRL_INTCTL_BIT()           BIT(5)
#define LED_CTRL_LEDBIT_MASK            (0x03FF << 6)
#define LED_CTRL_POLARITY_MASK          (0x000F << 0)
#define LED_CTRL_INTCTL_EXTERNAL        0
#define LED_CTRL_INTCTL_INTERNAL        1

#define LED_DISABLE  0x0
#define LED_ON       0x1
#define LED_FAST     0x3
#define LED_NORMAL   0x5
#define LED_SLOW     0x7
#define LED_MANUAL   0xF

#define LED_CTRL_LEDBIT_DISABLE	0x0000
#define LED_CTRL_LEDBIT_ON		0x03FF
#define LED_CTRL_LEDBIT_FAST	0x02AA
#define LED_CTRL_LEDBIT_NORMAL	0x0333
#define LED_CTRL_LEDBIT_SLOW	0x03E0

/* Get the device name */
#define AMI_ADVANTECH_BOARD_ID_LENGTH	32

/*
 * Advantech Embedded Controller watchdog commands
 * EC can send multi-stage watchdog event. System can setup watchdog event
 * independently to make up event sequence.
 */
#define EC_COMMANS_PORT_IBF_MASK	0x02
#define EC_RESET_EVENT				0x04
#define	EC_WDT_START				0x28
#define	EC_WDT_STOP					0x29
#define	EC_WDT_RESET				0x2A
#define	EC_WDT_BOOTTMEWDT_STOP		0x2B

#define EC_HW_RAM					0x89

#define EC_EVENT_FLAG				0x57
#define EC_ENABLE_DELAY_H			0x58
#define EC_ENABLE_DELAY_L			0x59
#define EC_POWER_BTN_TIME_H			0x5A
#define EC_POWER_BTN_TIME_L			0x5B
#define EC_RESET_DELAY_TIME_H		0x5E
#define EC_RESET_DELAY_TIME_L		0x5F
#define EC_PIN_DELAY_TIME_H			0x60
#define EC_PIN_DELAY_TIME_L			0x61
#define EC_SCI_DELAY_TIME_H			0x62
#define EC_SCI_DELAY_TIME_L			0x63

/* EC ACPI commands */
#define EC_ACPI_DATA_READ			0x80
#define EC_ACPI_DATA_WRITE			0x81

/* Brightness ACPI Addr */
#define BRIGHTNESS_ACPI_ADDR		0x50

/* EC HW RAM commands */
#define EC_HW_EXTEND_RAM_READ		0x86
#define EC_HW_EXTEND_RAM_WRITE		0x87
#define	EC_HW_RAM_READ				0x88
#define EC_HW_RAM_WRITE				0x89

/* EC Smbus commands */
#define EC_SMBUS_CHANNEL_SET		0x8A	 /* Set selector number (SMBUS channel) */
#define EC_SMBUS_ENABLE_I2C			0x8C	 /* Enable channel I2C */
#define EC_SMBUS_DISABLE_I2C		0x8D	 /* Disable channel I2C */

/* Smbus transmit protocol */
#define EC_SMBUS_PROTOCOL			0x00

/* SMBUS status */
#define EC_SMBUS_STATUS				0x01

/* SMBUS device slave address (bit0 must be 0) */
#define EC_SMBUS_SLV_ADDR			0x02

/* SMBUS device command */
#define EC_SMBUS_CMD				0x03

/* 0x04-0x24 Data In read process, return data are stored in this address */
#define EC_SMBUS_DATA				0x04

#define EC_SMBUS_DAT_OFFSET(n)	(EC_SMBUS_DATA + (n))

/* SMBUS channel selector (0-4) */
#define EC_SMBUS_CHANNEL			0x2B

/* EC SMBUS transmit Protocol code */
#define SMBUS_QUICK_WRITE			0x02 /* Write Quick Command */
#define SMBUS_QUICK_READ			0x03 /* Read Quick Command */
#define SMBUS_BYTE_SEND				0x04 /* Send Byte */
#define SMBUS_BYTE_RECEIVE			0x05 /* Receive Byte */
#define SMBUS_BYTE_WRITE			0x06 /* Write Byte */
#define SMBUS_BYTE_READ				0x07 /* Read Byte */
#define SMBUS_WORD_WRITE			0x08 /* Write Word */
#define SMBUS_WORD_READ				0x09 /* Read Word */
#define SMBUS_BLOCK_WRITE			0x0A /* Write Block */
#define SMBUS_BLOCK_READ			0x0B /* Read Block */
#define SMBUS_PROC_CALL				0x0C /* Process Call */
#define SMBUS_BLOCK_PROC_CALL		0x0D /* Write Block-Read Block Process Call */
#define SMBUS_I2C_READ_WRITE		0x0E /* I2C block Read-Write */
#define SMBUS_I2C_WRITE_READ		0x0F /* I2C block Write-Read */

/* GPIO control commands */
#define EC_GPIO_INDEX_WRITE			0x10
#define EC_GPIO_STATUS_READ			0x11
#define EC_GPIO_STATUS_WRITE		0x12
#define EC_GPIO_DIR_READ			0x1D
#define EC_GPIO_DIR_WRITE			0x1E

/* One Key Recovery commands */
#define EC_ONE_KEY_FLAG				0x9C

/* ASG OEM commands */
#define EC_ASG_OEM					0xEA
#define EC_ASG_OEM_READ				0x00
#define EC_ASG_OEM_WRITE			0x01
#define EC_OEM_POWER_STATUS_VIN1	0X10
#define EC_OEM_POWER_STATUS_VIN2	0X11
#define EC_OEM_POWER_STATUS_BAT1	0X12
#define EC_OEM_POWER_STATUS_BAT2	0X13

/* GPIO DEVICE ID */
#define EC_DID_ALTGPIO_0			0x10    /* 0x10 AltGpio0 User define gpio */
#define EC_DID_ALTGPIO_1			0x11    /* 0x11 AltGpio1 User define gpio */
#define EC_DID_ALTGPIO_2			0x12    /* 0x12 AltGpio2 User define gpio */
#define EC_DID_ALTGPIO_3			0x13    /* 0x13 AltGpio3 User define gpio */
#define EC_DID_ALTGPIO_4			0x14    /* 0x14 AltGpio4 User define gpio */
#define EC_DID_ALTGPIO_5			0x15    /* 0x15 AltGpio5 User define gpio */
#define EC_DID_ALTGPIO_6			0x16    /* 0x16 AltGpio6 User define gpio */
#define EC_DID_ALTGPIO_7			0x17    /* 0x17 AltGpio7 User define gpio */

/* Lmsensor Chip Register */
#define NSLM96163_CHANNEL			0x02

/* NS_LM96163 address 0x98 */
#define NSLM96163_ADDR				0x98

/* LM96163 index(0x00) Local Temperature (Signed MSB) */
#define NSLM96163_LOC_TEMP			0x00

/* HWMON registers */
#define INA266_REG_VOLTAGE          0x02    /* 1.25mV */
#define INA266_REG_POWER            0x03    /* 25mW */
#define INA266_REG_CURRENT          0x04    /* 1mA */

struct ec_hw_pin_table {
	unsigned int vbat[2];
	unsigned int v5[2];
	unsigned int v12[2];
	unsigned int vcore[2];
	unsigned int vdc[2];
	unsigned int ec_current[2];
	unsigned int power[2];
};

struct ec_dynamic_table {
	unsigned char device_id;
	unsigned char hw_pin_num;
};

struct ec_smbuso_em0 {
	unsigned char hw_pin_num;
};

struct pled_hw_pin_tbl {
	unsigned int pled[6];
};

struct adv_ec_platform_data {
	char *bios_product_name;
	int sub_dev_nb;
	u32 sub_dev_mask;
	struct mutex lock;
	struct device *dev;
	struct class *adv_ec_class;

	struct ec_dynamic_table *dym_tbl;
};

int read_ad_value(struct adv_ec_platform_data *adv_ec_data, unsigned char hwpin,
			unsigned char multi);
int read_acpi_value(struct adv_ec_platform_data *adv_ec_data, unsigned char addr,
			unsigned char *pvalue);
int write_acpi_value(struct adv_ec_platform_data *adv_ec_data, unsigned char addr,
			unsigned char value);
int read_hw_ram(struct adv_ec_platform_data *adv_ec_data, unsigned char addr,
			unsigned char *data);
int write_hw_ram(struct adv_ec_platform_data *adv_ec_data, unsigned char addr,
			unsigned char data);
int write_hwram_command(struct adv_ec_platform_data *adv_ec_data, unsigned char data);
int read_gpio_status(struct adv_ec_platform_data *adv_ec_data, unsigned char PinNumber,
			unsigned char *pvalue);
int write_gpio_status(struct adv_ec_platform_data *adv_ec_data, unsigned char PinNumber,
			unsigned char value);
int read_gpio_dir(struct adv_ec_platform_data *adv_ec_data, unsigned char PinNumber,
			unsigned char *pvalue);
int write_gpio_dir(struct adv_ec_platform_data *adv_ec_data, unsigned char PinNumber,
			unsigned char value);

#endif /* __LINUX_MFD_AHC1EC0_H */
