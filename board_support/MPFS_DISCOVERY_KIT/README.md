# Microchip MPFS DISCOVERY KIT

This document provides instructions on how to set up the **MPFS DISCOVERY KIT** development board from **Microchip** to implement and use the **SCHOLAR_RISC-V** core. It includes steps for configuring the board, running tests, and evaluating the performance of the RISC-V core.<br>
If you haven’t already, please refer to the [**simulation README**](../../simulation_env/README.md), which contains useful information about the tests that can be executed to validate the **SCHOLAR RISC-V**.

> ⚠️ The following instructions are written for **Ubuntu 20.04 LTS** and **Ubuntu 24.04 LTS**. If you are using another Linux distribution or version, you can still follow the general steps, but you may need to make slight adjustments to install the required dependencies or tools.

> 📝
>
> **Default tools location** for **Microchip** tools are **/opt/microchip/**. This path can be changed in the installation script, but make sure to consistently use the paths matching your actual **Microchip** installation throughout this tutorial. 
> Additionally, the following values in the [**setup_microchip_tools.sh**](https://github.com/Kawanami-git/MPFS_DISCOVERY_KIT/blob/fff23f566f2a48d2af81f11f2bf8db901abfa79d/scripts/setup_microchip_tools.sh) script and the [**run_license_daemon.sh**](https://github.com/Kawanami-git/MPFS_DISCOVERY_KIT/blob/fff23f566f2a48d2af81f11f2bf8db901abfa79d/scripts/run_license_daemon.sh) script must be updated:
>- **SC_INSTALL_DIR**	 : Path to the SoftConsole installation directory.
>- **LIBERO_INSTALL_DIR**: Path to the Libero installation directory.
>- **LICENSE_DAEMON_DIR**: Path to the License Daemon executable.
>- **LICENSE_FILE_DIR**	 : Path to the License directory.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Table of Contents

- [Required Hardware](#required-hardware)
- [Required Tools](#required-tools)
- [Microchip License](#microchip-license)
- [Retrieving or Building the Linux Image and Programming it](#retreiving-or-building-the-linux-image-and-programming-it)
- [Building and Programming the FPGA Bitstream](#building-and-programming-the-fpga-bitstream)
- [Running Tests on the Board](#running-tests-on-the-board)
- [Running Your Own Tests](#running-your-own-tests)
- [Known Issues](#known-issues)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## **Required Hardware**
The following hardware is required to be able to use the **SCHOLAR RISC-V** with the **MPFS DISCOVERY KIT**:
- The [MPFS DISCOVERY KIT](https://www.microchip.com/en-us/development-tool/mpfs-disco-kit)
- An Ethernet cable (optional)
- A class A1 or A2 microSD card (preferably SanDisk) with at least 16GB capacity

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## **Required Tools**
To successfully run the simulation and tests, the following tools are required:

-	[Libero SoC Design Suite](https://www.microchip.com/en-us/products/fpgas-and-plds/fpga-and-soc-design-tools/fpga/libero-software-later-versions): Required for FPGA design, place & route, bitstream generation, and FPGA/bootloader programming on the board. Be sure to install the full suite.

-	[SoftConsole](https://www.microchip.com/en-us/products/fpgas-and-plds/fpga-and-soc-design-tools/soc-fpga/softconsole): Required for HSS compilation.

- The Linux **repo, chrpath, diffstat, lz4...** commands: Required to build the Linux image.

-	The Linux **dd** command: Required to flash the Linux image onto a SD card.

- The Linux **ssh** command:  Required to communicate with the board over SSH.

These tools can be installed through the Makefile target:
```bash
make install_microchip_env
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Microchip License

To use the Microchip tools suite, a Microchip License is necessary.

<br>
<br>

### Get a License

The Microchip License can be requested from their [website](https://www.microchip.com/en-us/products/fpgas-and-plds/fpga-and-soc-design-tools/fpga/licensing) by clicking on **Request a Free License or Register and Manage Licenses** and then **Request Free License**.

The license to take is the **Libero Silver 1Yr Floating License for Windows/Linux Server**:
![Microchip_free_license.png](img/Microchip_free_license.png)

A MAC ID will be asked by Microchip:
![Microchip_mac_id_request.png](img/Microchip_mac_id_request.png)

It can be found by using the following command:
```bash
ip -br link
```

![Microchip_mac_id.png](img/Microchip_mac_id.png)

An example of MAC: ab:ef:12:23:45:cd.

The license will be sent by email.

<br>
<br>

### Install the License

The license must be placed in `/opt/microchip/` (same path as the tools).<br>
If not, the **run_license_daemon.sh** script shall be modified to specify the path of the license file:<br>
`export LICENSE_FILE_DIR=/opt/microchip/` -> `export LICENSE_FILE_DIR=path/to/dir`

The license has to be modified, by replacing **<put.hostname.here>** with your computer name in its top line:<br>
**SERVER <put.hostname.here> abef122345cd 1702**.<br>

You can now switch to one of the available branches, such as **Single-Cycle**.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Retrieving or Building the Linux Image and Programming It

The **MPFS DISCOVERY KIT** contains the **PolarFire MPFS095T** from **Microchip**. This chip is a Linux-capable SoC with an FPGA.
To avoid running baremetal applications, a Linux image can be installed on the board using a microSD card.

<br>
<br>

### Retrieving the Linux Image
The custom Linux image and the SDK can be found [here](https://github.com/Kawanami-git/MPFS_DISCOVERY_KIT/releases/tag/2025-11-04).

They can be retrieved with the following commands:
```bash
make mpfs_disco_kit_get_linux
```

<br>
<br>

### Building the Linux image 
Alternatively, to build the custom Linux image, simply run the following command in your terminal:

```bash
make mpfs_disco_kit_linux
```

This command will build the custom Linux developed in this project for the **MPFS DISCOVERY KIT**.

> 📝 
>
> Please note that this build can take several hours and requires at least 75GB of available storage on your computer.
>
> During the build, several packages installation may be required by Yocto. Please, install all of these packages.
>
> Issues can occur during the build. Please, see the [**Known issues**](#🐞-known-issues) section.


<br>
<br>

### Programming the Linux Image onto the SD Card

Once the SD card is plugged into your computer, you can flash the Linux image using one of the following commands:
```bash
make mpfs_disco_kit_program_linux
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Building and Programming the HSS Bootloader
The **Microchip Hart Software Services** (**HSS**) bootloader can be built using the following command:

```bash
make mpfs_disco_kit_hss
```

If the **MPFS DISCOVERY KIT** board is connected to your computer via the USB-C cable, you can build and program the **HSS** directly with:

```bash
make mpfs_disco_kit_program_hss
```
> 📝
>
> This command will rebuild the HSS before flashing it onto the board.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Building and Programming the FPGA Bitstream

First, the Microchip license must be activated:
```bash
make mpfs_disco_kit_license
```

Then, the FPGA bitstream can be built using the following command:

```bash
make mpfs_disco_kit_bitstream
```

If the **MPFS DISCOVERY KIT** board is connected to your computer via the USB-C cable, you can build and program the bitstream directly with:

```bash
make mpfs_disco_kit_program_bitstream
```
> 📝
>
> This command will flash the bitstream onto the board.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Tests on the Board

Except for the ISA tests, all other tests can be executed directly on the **MPFS DISCOVERY KIT** board.  
To do so, make sure the board is connected to your computer via **USB-C** and eventually **Ethernet**.

<br>
<br>

### Setup the board

Use one of the following commands to set up the board with either the USB or the Ethernet:

```bash
make mpfs_disco_kit_ssh_setup

make mpfs_disco_kit_usb_setup
```
These commands will compile all the firmware (loader, echo, cyclemark) and the software allowing to load firmware in the RISC-V softcore and to communicate with them.<br>
It will also copy the built binaries to the board and a Makefile.

<br>
<br>

### Connect to the Board via USB or SSH
To interact with the board through an SSH session (Ethernet required):
```bash
make mpfs_disco_kit_ssh
```

Through a USB session:
```bash
make mpfs_disco_kit_minicom
```

<br>
<br>

### Run the Tests

Once connected, run one of the following commands to execute a test:
```bash
make loader
make echo
make cyclemark
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Your Own Tests
If you haven’t already, please refer to the [**🏃‍♂️ Running Your Own Firmwares**](../../simulation_env/README.md) section of the simulation environment README — it contains mandatory steps required before running your own tests on the boards.<br>

Please, also refer to the [Running Tests on the Board](#running-tests-on-the-board) section for detailed instructions on how to run a test on the board.

<br>
<br>

### Modify the main Makefile

Once your firmware is running correctly in the simulation environment, you can modify the main Makefile to build and send your custom firmware to the board.

Locate the target:
```
# MPFS_DISCO_KIT: Build firmware & MSS application and send them through uart
.PHONY: mpfs_disco_kit_usb_setup
mpfs_disco_kit_usb_setup: MPFS_DISCO_KIT_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
mpfs_disco_kit_usb_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
mpfs_disco_kit_usb_setup:
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
	@$(SDK_ACTIVATE) $$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(MPFS_DISCO_KIT_BOARD)platform

	@for f in $(FIRMWARE_BUILD_DIR)/*.hex; do \
	  $(MAKE) --no-print-directory uart_ft UART_FILE="$$f" \
	  UART_DEST_DIR="./$(MPFS_DISCO_KIT_FIRMWARE_DIR)"; \
	done

	@$(MAKE) --no-print-directory uart_ft UART_FILE=$(MPFS_DISCO_KIT_BOARD)platform \
	UART_DEST_DIR="./"

	@$(MAKE) --no-print-directory uart_ft UART_FILE=$(PLATFORM_DIR)Makefile \
	UART_DEST_DIR="./"
```

And add it to your firmware build command:
```
# MPFS_DISCO_KIT: Build firmware & MSS application and send them through uart
.PHONY: mpfs_disco_kit_usb_setup
mpfs_disco_kit_usb_setup: MPFS_DISCO_KIT_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
mpfs_disco_kit_usb_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
mpfs_disco_kit_usb_setup:
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
->  @$(MAKE) --no-print-directory custom_firmware
	@$(SDK_ACTIVATE) $$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(MPFS_DISCO_KIT_BOARD)platform

	@for f in $(FIRMWARE_BUILD_DIR)/*.hex; do \
	  $(MAKE) --no-print-directory uart_ft UART_FILE="$$f" \
	  UART_DEST_DIR="./$(MPFS_DISCO_KIT_FIRMWARE_DIR)"; \
	done

	@$(MAKE) --no-print-directory uart_ft UART_FILE=$(MPFS_DISCO_KIT_BOARD)platform \
	UART_DEST_DIR="./"

	@$(MAKE) --no-print-directory uart_ft UART_FILE=$(PLATFORM_DIR)Makefile \
	UART_DEST_DIR="./"
```

This will build your firmware along the others and send it to the board. If you work with ssh, you can apply the same process to **mpfs_disco_kit_ssh_setup**.

<br>
<br>

### Modify the platform Makefile

The **platform makefile** is meant to be used on a development board supporting Linux.<br>
Its purpose is to make the use of the built binaries easier.

To add your firmware, just add the following variables:
```
CUSTOM_FIRMWARE = $(FIRMWARE_DIR)custom.hex
CUSTOM_LOG      = $(LOG_DIR)custom.log
```

And add the following target:
```
.PHONY: custom
custom:
	./platform --firmware $(CUSTOM_FIRMWARE) --log $(CUSTOM_LOG)
```

You can now run your test on the board by running the following command on the board:
```bash
make custom
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Known Issues

- **Yocto Build Failures** 

Yocto may occasionally fail to fetch some external dependencies, leading to a Linux build failure.  
If this happens, simply rerun the build process **without cleaning** it:

```bash
make mpfs_disco_kit_linux
```

Yocto will resume from where it left off and attempt to fetch the missing files again.

<br>
<br>

- **Firmware Switching and Memory Corruption**

Running different firmwares successively may cause shared memory corruption between the platform and the core.
If this occurs, reprogramming the FPGA with the latest bitstream usually solves the problem:
```bash
make mpfs_disco_kit_program_bitstream
```
⚠️ The issue is under investigation and will be fixed in a future update.

<br>
<br>

---