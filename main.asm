; Header file inclusions for 8051
#include <reg51.h>
#include <intrins.h>

; Define constants for LCD control pins
LCDrs EQU P2.0 ; Register select Pin
LCDrw EQU P2.1 ; Read/Write Pin
LCDen EQU P2.2 ; Enable Pin

; Define constants for sensor pins
trig EQU P3.5 ; Timer 1
echo EQU P3.2 ; INT0

; Data memory variables
range DB 0 ; Variable to store the measured range

; Code memory variables (to store strings)
str1 DB "OBSTACLE  AT ", 0
str2 DB "0000 CM", 0

; Code memory constants
TIMER_DELAY EQU 1275 ; Delay value for the delay function

; Code memory initialization
ORG 0 ; Start the code at address 0

MAIN:
    ; Initialize LCD
    MOV A, #0x30
    CALL COMMAND ; 1 line and 5x7 matrix
    CALL DELAY

    MOV A, #0x38
    CALL COMMAND ; 2 lines and 5x7 matrix
    CALL DELAY

    MOV A, #0x0C
    CALL COMMAND ; Display on, cursor off
    CALL DELAY

    MOV A, #0x01
    CALL COMMAND ; Clear display Screen
    CALL DELAY

    MOV A, #0x06
    CALL COMMAND ; Shift cursor to right
    CALL DELAY

    MOV DPTR, #str1
    CALL DISPLAY_LCD ; Display "OBSTACLE  AT "

    ; Timer 0 initialization
    MOV TMOD, #0x09 ; Timer0 in 16-bit mode with gate enable
    SETB TR0 ; Timer run enabled
    MOV TH0, #0x00
    MOV TL0, #0x00

    SETB echo ; Set echo pin (P3.2) as input

LOOP:
    CALL GET_RANGE
    CALL DELAY ; Delay for 2 ms
    SJMP LOOP ; Infinite loop

; Subroutine to generate delay
DELAY:
    MOV R1, #TIMER_DELAY
DELAY_LOOP:
    DJNZ R1, DELAY_LOOP
    RET

; Subroutine to send commands to the LCD
COMMAND:
    CLR LCDrs
    CLR LCDrw
    SETB LCDen ; Strobe the enable pin
    MOV P1, A ; Put the value on the pins
    CLR LCDrs
    CLR LCDrw
    CLR LCDen
    RET

; Subroutine to display a string on the LCD
DISPLAY_LCD:
    MOV R1, A ; Load the address of the string
DISPLAY_LOOP:
    MOV A, @R1 ; Load the character from the code memory
    CJNE A, #0, DISPLAY_CHAR ; If not the null terminator, display the character
    RET ; End of string, return

DISPLAY_CHAR:
    SETB LCDrs ; Set RS to 1 for data mode
    CLR LCDrw
    SETB LCDen ; Strobe the enable pin
    MOV P1, A ; Put the character on the pins
    CLR LCDrs
    CLR LCDrw
    CLR LCDen
    INC R1 ; Move to the next character in the string
    ACALL DELAY ; 10 ms delay
    SJMP DISPLAY_LOOP ; Continue displaying the string

; Subroutine to measure the range using ultrasonic sensor
GET_RANGE:
    ; Send the pulse
    CLR TR0 ; Stop Timer0
    MOV TH0, #0x00
    MOV TL0, #0x00
    SETB trig ; Pull trigger pin (P3.5) HIGH
    NOP ; Delay for trigger pulse
    NOP
    NOP
    NOP
    NOP
    CLR trig ; Pull trigger pin LOW

WAIT_FOR_ECHO:
    JB echo, WAIT_FOR_ECHO ; Wait until echo pulse is detected
    JNB echo, WAIT_FOR_ECHO ; Wait until echo changes its state

    ; Read the timer value
    MOV A, TH0
    MOV B, TL0
    MOV R7, A ; Store high byte in R7
    MOV R6, B ; Store low byte in R6
    MOV A, R7
    MOV B, R6
    ACALL CALCULATE_RANGE ; Calculate the range
    RET

; Subroutine to calculate and display the range
CALCULATE_RANGE:
    MOV A, R7 ; High byte of timer value
    MOV B, R6 ; Low byte of timer value

    ; Convert the timer value to microseconds
    MOV R0, #54 ; 1 clock cycle is 1/12 MHz = 83.3 ns, 1 us = 12 clock cycles
    MUL AB ; Multiply high and low bytes by 54
    MOV R2, A ; Store the result in R2
    MOV R3, B

    MOV A, #0 ; Clear accumulator

    ; Check if the range is less than 34300 microseconds (34.3 ms)
    MOV R1, #0xD4 ; Load the threshold value (34300 / 1000 = 34.3 ms)
    CJNE R2, R1, RANGE_OK ; If range is less than 34.3 ms, skip the division
    CJNE R3, #0x2C, RANGE_OK

    ; Range is greater than or equal to 34.3 ms, set range to 0
    SJMP DISPLAY_RANGE

RANGE_OK:
    ; Divide the timer value by 54 to get the range in centimeters
    MOV A, R2 ; High byte of multiplied value
    MOV B, R3 ; Low byte of multiplied value
    MOV R2, #0 ; Clear R2 and R3 for division
    MOV R3, #0
    MOV R4, #54 ; Divisor for division
    DIV AB ; Divide R1R0 by R3R2
    MOV A, R0 ; Quotient (range in centimeters) in accumulator

    ; Convert the range to a 4-digit number in ASCII
    MOV R5, #4 ; Number of digits (4 digits)
CONVERT_TO_ASCII:
    MOV A, #0x30 ; ASCII '0'
    ADD A, R0 ; Add the remainder to '0'
    MOV R0, A ; Update R0 with the ASCII digit
    MOV A, R5 ; Load the digit position
    ADD A, #0x0C ; Add the ASCII offset for the LCD display
    MOV @R0, A ; Store the digit in the output string
    DEC R5 ; Move to the next digit
    DJNZ CONVERT_TO_ASCII ; Repeat for all digits

DISPLAY_RANGE:
    ; Display the range on the LCD
    MOV DPTR, #str2 ; Point DPTR to the output string
    CALL DISPLAY_LCD ; Display the string

    RET ; Return from the subroutine
