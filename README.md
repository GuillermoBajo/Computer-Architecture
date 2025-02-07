## Computer Architecture

The project focuses on controlling a car that moves along a road on a text-based screen. The road boundaries are defined by the `#` character (ASCII 35), and the car is represented by the `H` character (ASCII 72). Key functionalities include:

- **Peripheral Management**: The keyboard and timer are controlled to handle user inputs and timer interrupts.
- **Interrupts**: The project uses interrupts to manage the keyboard (`IRQ7 of VIC`) and the timer (`IRQ4 of VIC`), enabling precise event synchronization.
- **Movement Control**: The user can move the car using the keys `J` (left), `L` (right), `I` (up), and `K` (down). Speed can also be adjusted with the `+` (increase speed) and `-` (decrease speed) keys.

## Technologies Used

- **ARM Assembly**: The code is written in ARM assembly, providing detailed control over the microcontroller’s resources.
- **Keil Simulator**: The Keil simulator is used for compiling and running the project, providing a complete development environment for debugging and testing.
- **Random Number Generation Subroutines**: Subroutines in the `rand.s` file are included to generate pseudo-random numbers necessary for the game's randomness.
- **NXP LPC 2105 Microcontroller**: The project is configured for this microcontroller, utilizing its input/output system for peripheral control and interrupt handling.

## Execution

1. Compile the project in Keil.
2. Run the program and control the car using the specified keys.
3. Observe the game's movement using the `View > Periodic Window Update` option in the debugging session.
