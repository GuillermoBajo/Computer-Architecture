AREA datos, DATA  ; Data section of the program

VICIntEnable  EQU 0XFFFFF010  ; Enable Interrupts register address
VICIntEnClr   EQU 0XFFFFF014  ; Clear Interrupts register address
VICVectAddr0  EQU 0xFFFFF100  ; Interrupt vector address 0
VICVectAddr   EQU 0xFFFFF030  ; General Interrupt Vector address

R_DAT          EQU 0xE0010000   ; Keyboard data register
T0_IR          EQU 0xE0004000   ; Timer interrupt request register
timer_so       DCD 0            ; Timer interrupt vector address
tecl_so        DCD 0            ; Keyboard interrupt vector address

pantalla       EQU 0x40007E00   ; Start of the road
finpantalla    EQU 0x40007FFF   ; End of the road
alertsup       EQU 0x40007E1F   ; Control for upper screen limits
seed           EQU 0x77777777   ; Seed for random road generation

espacio2       EQU 0x20202020   ; Space character for cleaning the screen (GAMEOVER)
coche          DCD 0x40007FEC   ; Initial position of the car
iniGO          EQU 0x40007F0B   ; Reference for writing GAME OVER
Mensaje_GO     DCB  'G','A','M','E',' ','O','V','E','R','!'  ; GAME OVER message

ALIGN
velocidad      DCD 8            ; Speed in hundredths
cont           DCD 0            ; Counter for hundredths of a second
teclaLeida     DCB 0            ; Stores the last key pressed (resets after processing)
terminar       DCB 0            ; (1/0) Detects if the program should end

AREA codigo, CODE  ; Code section of the program
EXPORT inicio     ; Exports the 'inicio' label to link with startup.s
IMPORT srand      ; Import srand subroutine
IMPORT rand       ; Import rand subroutine

inicio  ; It is recommended to set a breakpoint at the first instruction of the code
        ; to execute the entire startup process in one go.

        ; Use the seed to initialize the pseudo-random number sequence
        LDR r0, =seed
        mov r0, r0, LSR #3
        PUSH {r0}
        bl srand
        add sp, sp, #4

        ; Set timer_so and tecl_so to the values that were in VIC4 and VIC7 before the change
        LDR r0, =VICVectAddr0
        LDR r1, =timer_so
        LDR r2, =tecl_so
        mov r3, #4
        ldr r5, [r0, r3, LSL #2]
        str r5, [r1]
        mov r4, #7
        ldr r5, [r0, r4, LSL #2]
        str r5, [r2]

        ; Place the addresses of the ISRs (Interrupt Service Routines) in VIC4 and VIC7
        LDR r1, =RSI_timer
        str r1, [r0, r3, LSL #2]
        LDR r2, =RSI_teclado
        str r2, [r0, r4, LSL #2]

        ; Enable interrupt mask bits 4 and 7
        LDR r2, =VICIntEnable
        mov r0, #2_10010000
        str r0, [r2]

*********************************************************************************************
; Main Program (PP):

        ; Draw the main screen
        LDR r0, =pantalla
        PUSH{r0}
        bl PANTALLA_INICIAL   ; Subroutine that draws the screen and the car at its initial position
        add sp, sp, #4         ; Correct the stack pointer
        
        ; Check if the program should end (terminar = 1)
buc     LDR r0, =terminar
        ldrb r1, [r0]
        cmp r1, #1
        beq desact

        ; Depending on the key detected by R_DAT, execute different instructions
        LDR r0, =teclaLeida
        ldrb r0, [r0]          ; r0 = last key pressed by the user
        cmp r0, #0             ; If teclaLeida has no new data, don't update
        beq detChoq            ; the speed or car position

        cmp r0, #81            ; Check if the key is 'Q'
        bne noq

        ; Detect 'Q' key
        LDR r1, =terminar
        mov r0, #1
        strb r0, [r1]          ; Set terminar to 1 if 'Q' was pressed
        b finDet

noq     LDR r1, =coche
        ldr r1, [r1]
        mov r2, r1             ; Copy previous position to remove the car if necessary

        LDR r4, =alertsup
        cmp r1, r4             ; Check if the car is in danger of exceeding the upper limit
        blt sig2               ; If it is, ignore the instructions for 'I' key to avoid the car going out of the screen

        cmp r0, #73            ; Detect 'I' key
        bne sig2
        sub r1, r1, #32        ; Update car position (move up)
        b movercoche

sig2    LDR r4, =finpantalla
        sub r4, r4, #32
        cmp r1, r4             ; Check if the car is in danger of exceeding the lower limit
        bgt sig3               ; If it is, ignore the instructions for 'K' key to avoid the car going out of the screen

        cmp r0, #75            ; Detect 'K' key
        bne sig3
        add r1, r1, #32        ; Update car position (move down)
        b movercoche

sig3    cmp r0, #74            ; Detect 'J' key
        bne sig4
        sub r1, r1, #1         ; Update car position (move left)
        b movercoche

sig4    cmp r0, #76            ; Detect 'L' key
        bne sig5
        add r1, r1, #1         ; Update car position (move right)
        b movercoche

movercoche
        ldrb r4, [r1]          ; Check if the car collided
        cmp r4, #35
        bne nochoq
        mov r4, #1             ; If it collided, set 'terminar' to 1
        LDR r3, =terminar
        strb r4, [r3]          ; Set terminar = 1
        b finDet

        ; If no collision:
nochoq  mov r3, #72            ; 'H' character for the car
        strb r3, [r1]          ; Move the car
        LDR r0, =coche
        str r1, [r0]           ; Update position
        mov r1, #32
        strb r1, [r2]          ; Clear the car from the previous position
        b finDet
sig5    LDR r1, =velocidad
        ldr r2, [r1]           ; r2 = velocity
        LDR r3, =cont          ; r3 = @cont
        
        cmp r0, #11            ; Detect '+' key
        bne sig6
        mov r2, r2, LSR #1     ; Multiply velocity by 2
        
        mov r4, #1             ; Control max speed (vmax)
        cmp r2, r4
        movls r2, #1
        b actV

sig6    cmp r0, #13            ; Detect '-' key
        bne finDet
        mov r2, r2, LSL #1     ; Divide velocity by 2
        
        mov r4, #128           ; Control min speed (vmin)
        cmp r2, r4
        movge r2, #128

actV    str r2, [r1]           ; Update velocity
        mov r2, #0             
        str r2, [r3]           ; Reset counter

finDet  LDR r0, =teclaLeida    ; Reset teclaLeida
        mov r1, #0
        strb r1, [r0]         
        

        ; The car can crash either due to the player's bad movement or
        ; because the road moved into the car's position. We will detect both cases:
        
detChoq ; Check if the car crashed when the road moved on its own
        LDR r1, =coche
        ldr r1, [r1]           ; r1 = car position
        ldrb r2, [r1]          ; Contents of car position
        LDR r1, =terminar      ; r1 = @terminar
        cmp r2, #35            ; Compare position content with '#'
        beq escTer
        
        ; Check if the car crashed due to a bad movement
malMov  ldrb r2, [r1]
        cmp r2, #1             ; Check if crash was detected while moving the car
        bne actualizar_carretera
        
        ; If crashed:
escTer  mov r0, #1
        strb r0, [r1]          ; Set 'terminar' to 1
        
        ; Clear the screen
        bl LIMPIARPANTALLA     ; SBR that clears the screen
        
        bl GAMEOVER            ; SBR that writes 'GAME OVER!' on the screen
        b buc                  ; Go back to the start of the loop, marking the program finished
        
        ; If no crash, update the road
actualizar_carretera
        ; First check if cont == velocidad
        LDR r0, =cont
        ldr r2, [r0]           ; r2 = cont
        LDR r1, =velocidad
        ldr r1, [r1]           ; r1 = velocity
        cmp r2, r1             ; Check if the counter indicates an update is needed
        bne buc                ; If not, go back to the start of the loop
        mov r2, #0            
        strb r2, [r0]          ; Reset counter
        
        ; Move the road down
        bl BAJAR_CARRETERA     ; SBR that moves the road down row by row (moves 1 row per call)
        
        ; Generate random road
        
        ; First, find the position of the road in its last state
        LDR r0, =pantalla
        add r0, r0, #32        ; Check the second row since the first row
        mov r5, #35            ; has not been placed yet
        mov r3, #32            ; Number of iterations
        
buscCar ldrb r2, [r0]          ; r2 = Content of the memory position read
        cmp r2, r5             ; If it's '#':
        mov r4, r0             ; Store the position
        beq aleat              ; Jump to random procedures
incrind add r0, r0, #1         ; Otherwise, continue checking until we find the road
        subs r3, r3, #1
        bne buscCar    
    

aleat   sub sp, sp, #4
        bl rand                ; Call the rand subroutine which will return a random number on the stack 
        POP {r0}               ; Pop the random number into r0
        
        mov r0, r0, LSR #25    ; We won't use the least significant bits because the fewer bits we analyze, 
                                ; the less random the results will be
        and r0, r0, #3         ; Select 3 bits and clear the rest
        mov r1, r0             ; Store the resulting number
        mov r0, r0, LSR #1     ; Get [1] from r0
        
        mov r2, #1             
        cmp r0, r2             ; If [1]=1, -> straight
        beq recto
        
        and r1, r1, #1
        cmp r1, r2             ; Otherwise, if [0]=1 -> right. It will move left in the opposite case
        beq der
        
        ; Move left
        sub r4, r4, #33        ; Correct: r4('#' detected) - 32 (move to 1st row) - 1 (move 1 left)
        LDR r2, =0X40007E03
        cmp r4, r2             ; Check if there's a risk of exceeding the limits
        ble corrizq            ; If there is, jump to correction
        strb r5, [r4]          ; Otherwise, draw the left road boundary
        strb r5, [r4, #8]      ; Right boundary
        b yaConstruida    
        
corrizq add r4, r4, #2        ; Correct the position
        strb r5, [r4]          ; Draw the road
        strb r5, [r4, #8]
        b yaConstruida
        
        
der     sub r4, r4, #31        ; Correct: r4('#' detected) - 32 (move to 1st row) + 1 (move 1 right)
        LDR r2, =0X40007E14
        cmp r4, r2             ; Check if there's a risk of exceeding the limits
        bge corrder            ; If there is, jump to correction
        strb r5, [r4]          ; Otherwise, draw the left road boundary
        strb r5, [r4, #8]      ; Right boundary
        b yaConstruida
        
corrder sub r4, r4, #2         ; Correct the position
        strb r5, [r4]          ; Draw the road
        strb r5, [r4, #8]
        b yaConstruida
        
        
recto  sub r4, r4, #32        ; If moving straight, no need to move the road or check limits
        strb r5, [r4]          ; Draw the road
        strb r5, [r4, #8]      
            
yaConstruida 
        b buc

*********************************************************************************************
;Restoration of the I/O system:

        ;Disable bits 4 and 7 in the interrupt mask
desact  LDR r0, =VICIntEnClr
        mov r1, #2_10010000
        str r1, [r0]
        
        ;Retrieve the original addresses stored in VIC 4 and VIC7
        LDR r0, =VICVectAddr0
        LDR r1, =timer_so
        ldr r1, [r1]
        LDR r2, =tecl_so
        ldr r2, [r2]
        mov r3, #4
        str r1, [r0, r3, LSL #2]
        mov r3, #7
        str r2, [r0, r3, LSL #2]
        
fin     b fin
        
*********************************************************************************************
;Interrupt Service Routines (ISR):

RSI_timer    ; Interrupt arrives every 0.01 seconds

        ;Prologue
        sub lr,lr, #4
        PUSH{lr}              ;Push return address
        mrs r14, spsr
        PUSH{r14}             ;Push cpsr_pp
        msr cpsr_c, #2_01010010    ;Enable IRQ interrupts
        
        PUSH{r0, r1}          ;Push registers to be used
        
        ;Acknowledge interrupt (write 1 to T0_IR)
        LDR r0, =T0_IR
        mov r1, #1
        str r1, [r0]
        
        ;cont = cont + 1
        LDR r0, =cont         ;r0=@cont
        ldr r1, [r0]          ;r1=cont
        add r1, r1, #1
        str r1, [r0]
        
        POP{r0, r1}           ;Pop used registers
        
        ;Epilogue
        msr cpsr_c, #2_11010010    ;Disable IRQ interrupts
        POP{r14}              ;r14=cpsr_pp
        msr spsr_fsxc, r14    ;spsr=cpsr_pp
        LDR r14, =VICVectAddr ;EOI
        str r14, [r14]
        POP{pc}^              ;pc=@ret_pp and cpsr=spsr=cpsr_pp
        
RSI_keyboard

        ;Prologue
        sub lr,lr, #4
        PUSH{lr}              ;Push return address
        mrs r14, spsr
        PUSH{r14}             ;Push cpsr_pp
        msr cpsr_c, #2_01010010    ;Enable IRQ interrupts
        
        PUSH{r0-r1}           ;Push registers to be used
        
        ;Transfer
        LDR r1, =R_DAT
        ldrb r0, [r1]
        
        ;Convert to uppercase and store the read value to process in PP
        bic r0, r0, #2_100000
        LDR r1, =teclaLeida
        strb r0, [r1]

        POP{r0-r1}           ;Pop used registers
        
        ;Epilogue
        msr cpsr_c, #2_11010010    ;Disable IRQ interrupts
        POP{r14}              ;r14=cpsr_pp
        msr spsr_fsxc, r14    ;spsr=cpsr_pp
        LDR r14, =VICVectAddr ;EOI
        str r14, [r14]
        POP{pc}^              ;pc=@ret_pp and cpsr=spsr=cpsr_pp
        
*********************************************************************************************
;Subroutines:

PANTALLA_INICIAL
        PUSH{lr}
        PUSH{r11}
        mov fp, sp
        
        PUSH{r0-r4}           ;Push registers to be used

        ldr r0, [fp, #8]      ;r0=@pantalla
        eor r1, r1, r1        ;r1=i
        eor r2, r2, r2        ;r2=j
        mov r3, #32           ;r3=' '
        mov r4, #35           ;r4='#'
                
buc1    cmp r1, #16
        bge escCoch
        
buc2    cmp r2, #32
        bge incri
        
        cmp r2, #8            ;If column = 8, jump to write hash
        beq escAlm
        cmp r2, #16           ;Otherwise, if column = 16, jump to write hash
        beq escAlm
        strb r3, [r0], #1     ;Else, write space
        b incrj
        
escAlm  strb r4, [r0], #1     ;Write hash
incrj   add r2, r2, #1        ;Increment j
        b buc2
        
incri   mov r2, #0             ;Reset j
        add r1, r1, #1         ;Increment i
        b buc1
        
        ;Draw the car in its initial position
escCoch LDR r1, =coche
        ldr r1, [r1]
        mov r0, #72
        strb r0, [r1]
        
        POP{r0-r4}           ;Pop used registers
        
        POP{r11}
        POP{pc}

LIMPIARPANTALLA
        PUSH{lr}
        PUSH{r11}
        mov fp, sp
        
        PUSH{r0-r2}               ;Push registers to be used
        LDR r0, =pantalla
        LDR r1, =espacio2
        mov r2, #128              ;Number of iterations
        
buclimp str r1, [r0], #4         ;Write ' ' (space) throughout the screen
        subs r2, r2, #1
        bne buclimp  

        POP{r0-r2}               ;Pop used registers
        
        POP{r11}
        POP{pc}


GAMEOVER
        PUSH{lr}
        PUSH{r11}
        mov fp, sp
        
        PUSH{r0-r3}               ;Push registers to be used
        
        LDR r0, =Mensaje_GO       ;r0=@message
        LDR r1, =iniGO            ;r1=@location_to_write_message
        mov r2, #0                ;r2=i
        
bucGO   ldrb r3, [r0, r2]        ;r3=Character to write                
        strb r3, [r1, r2]        ;Write the character
        add r2, r2, #1            ;Increment i                        
        cmp r2, #10
        blt bucGO

        POP{r0-r3}               ;Pop used registers
        
        POP{r11}
        POP{pc}
        
        
BAJAR_CARRETERA        
        PUSH{lr}
        PUSH{r11}
        mov fp, sp
        
        PUSH{r0-r5}               ;Push registers to be used
        
        LDR r0, =finpantalla      ;Position from which we will start lowering the road
        LDR r2, =pantalla
        sub r2, r2, #1            ;r2=@screen (position before the first)
        mov r1, #35               ;r1='#'
        mov r3, #32               ;r3=' '
        
        ;First, clear the road from the last row
        mov r4, #32               ;r4=Number of iterations
limpUlt ldrb r5, [r0]           ;r5=Content of the position to check (check if it's '#' or not)
        cmp r1 ,r5
        bne incrLU
        strb r3, [r0]            ;If the position contains a '#', clear it
        
incrLU  sub r0, r0, #1          ;Update r0 (which scans the last row)
        subs r4, r4, #1          ;Subtract 1 iteration
        bne limpUlt
        
        
        ;Once the last row is cleared, proceed to move the rest of the rows down one position
        ;The topmost row
Baj     ldrb r4, [r0]           ;r4=@ to check
        cmp r4, r1
        bne incrBaj
        strb r3, [r0]            ;If the position contains a '#', clear it
        strb r1, [r0, #32]       ;Write '#' in the next row (same column)
        
incrBaj sub r0, r0, #1          ;Update r0 (which scans the screen)
        cmp r0, r2               ;Check if r0 = last position to check
        bge Baj
        
        POP{r0-r5}               ;Pop used registers
        
        POP{r11}
        POP{pc}

        END
