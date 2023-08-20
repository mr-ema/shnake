# SHNAKE
Simple project of the classic snake game implemented in POSIX shell script.

</br>

## Resources
- [Shell Check](https://www.shellcheck.net/)
- [POSIX Standards](https://pubs.opengroup.org/onlinepubs/9699919799/)

</br>
</br>

## Features
- [x] Random fruit generation
- [x] Snake grow longer when eat the fruit
- [x] Full Collition detection
- [x] Simple interface with score counting
- [x] Configurable target FPS

</br>
</br>

## Demo
![Demo](https://github.com/mr-ema/shnake/blob/main/demo.gif)

</br>
</br>

## Tested Shells 
- [x] Zsh
- [x] Bash
- [x] Dash
- [x] Termux

</br>
</br>

## Compatibility and Dependencies
This shell script is designed to be POSIX
compatible, following the standards set by the [POSIX
specification](https://pubs.opengroup.org/onlinepubs/9699919799/). This
means that it should run on any POSIX-compliant shell, which includes
most Unix-like systems.

### Dependencies
However, while the script adheres to POSIX standards, there are a few
commands used that are not guaranteed to be available on all operating
systems and you may need to install:

- **bc:** The script uses `bc` (basic calculator) for performing precise
floating-point arithmetic calculations. While `bc` is POSIX-defined
and commonly available, it might not be installed on some minimal or
specialized environments.

- **tput:** The script uses `tput` to control terminal colors and cursor
movement, enhancing the visual aspect of the game. Like `bc`, `tput`
is POSIX-defined but might be missing on certain systems, especially
headless or minimal installations.

</br>
</br>

## How To Play
1. Clone the repository or download the script or do a copy paste.
2. Open your terminal and navigate to the directory where the script is located.
3. Make sure you have execute permissions for the script: `chmod +x main.sh`.
4. Run the game: `./main.sh`.

</br>
</br>

## License
This game is released under the Zero-Clause BSD license. Feel free
to use, modify, and distribute this software for any purpose with or
without fee. The software comes "as is," and the author disclaims all
warranties regarding its use. The author shall not be liable for any
damages resulting from the use or performance of this software.
