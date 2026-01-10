# FRISC-V

FRISC-V is a [RISC-V](https://en.wikipedia.org/wiki/RISC-V) core developed at [FER](https://www.fer.unizg.hr/en), University of Zagreb. It is designed for the [Pynq-Z2](https://www.tulembedded.com/fpga/ProductsPYNQ-Z2.html) FPGA board and supports the RV32I base instruction set.

## Getting Started

Development on Linux and Windows is supported. See the appropriate guide below.

<details>
<summary>Linux</summary>

1. **Prerequisites:**

    - Vivado 2022.2 - Get it on the official AMD [download page](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html#accordion-2022)
    - `make` - On Ubuntu, run `sudo apt install make`
    - `riscv32-unknown-elf` - Follow instructions on the official [repository](https://github.com/riscv-collab/riscv-gnu-toolchain)

2. **Clone the repository**

    ```bash
    git clone git@github.com:friscv/friscv-system-hw.git
    cd ./friscv-system-hw
    ```

3. **Recreate the Vivado project**

    ```bash
    make
    ```

</details>

<details>
<summary>Windows</summary>

1. **Prerequisites:**

    - Vivado 2022.2 - Get it on the official AMD [download page](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html#accordion-2022)
    - WSL2 - Follow the official [guide](https://learn.microsoft.com/en-us/windows/wsl/install) from Microsoft, and in WSL
        - `make` - On Ubuntu, run `sudo apt install make`
        - `riscv32-unknown-elf` - Follow instructions on the official [repository](https://github.com/riscv-collab/riscv-gnu-toolchain)
    - Vivado added in Path

        <details>
        <summary>Instructions</summary>

        ```powershell
        $vivadoPath = "C:\Xilinx\Vivado\2022.2\bin"
        [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$vivadoPath", [EnvironmentVariableTarget]::User)
        ```
        <details>

    - Powershell scripts executable

        <details>
        <summary>Instructions</summary>

        ```powershell
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
        ```

        </details>

2. **Clone the repository**

    ```powershell
    git clone git@github.com:friscv/friscv-system-hw.git
    cd .\friscv-system-hw\
    ```

3. **Recreate the Vivado project**

    ```powershell
    .\build.ps1
    ```

</details>
