		AREA datos,DATA
			
VICIntEnable 	EQU 0XFFFFF010
VICIntEnClr		EQU 0XFFFFF014
VICVectAddr0	EQU 0xFFFFF100
VICVectAddr		EQU 0xFFFFF030
	
R_DAT			EQU 0xE0010000		;Registro de datos del teclado
T0_IR 			EQU 0xE0004000		;Para bajar petición del Timer
timer_so		DCD 0
tecl_so			DCD 0
	
pantalla 		EQU 0x40007E00		;Comienzo carretera
finpantalla		EQU 0x40007FFF		;Fin carretera
alertsup 		EQU 0x40007E1F		;Para controlar límites superiores
seed 			EQU 0x77777777		;Semilla que genera la carretera aleatoria
	
espacio2		EQU 0x20202020		;Para limpiar pantalla más eficientemente(GAMEOVER)
coche 			DCD 0x40007FEC		;Posición inicial del coche
iniGO			EQU 0x40007F0B		;Referencia para escribir GAME OVER
Mensaje_GO		DCB  'G','A','M','E',' ','O','V','E','R','!'
	
	ALIGN
velocidad		DCD 8				;velocidad en centésimas
cont			DCD 0				;Contador de centésimas de segundo
teclaLeida		DCB 0				;Guarda en mayúsculas la última tecla pulsada (se resetea tras operar con ella)
terminar		DCB 0				;(1/0) Detecta si se ha de acabar el programa
	


		AREA codigo,CODE
		EXPORT inicio			; forma de enlazar con el startup.s
		IMPORT srand			; para poder invocar SBR srand
		IMPORT rand				; para poder invocar SBR rand
inicio	; se recomienda poner punto de parada (breakpoint) en la primera
		; instruccion de código para poder ejecutar todo el Startup de golpe
		
		;Utilizamos la semilla para inicializar la secuencia de números pseudoaleatorios
		LDR r0, =seed	
		mov r0, r0, LSR #3
        PUSH {r0}
        bl srand
        add sp,sp,#4
		
		;Ponemos en timer_so y tecl_so la dirección que había en VIC4 y VIC7 antes del cambio
		LDR r0, =VICVectAddr0
		LDR r1, =timer_so
		LDR r2, =tecl_so
		mov r3, #4
		ldr r5, [r0, r3, LSL #2]
		str r5, [r1]
		mov r4, #7
		ldr r5, [r0, r4, LSL #2]
		str r5, [r2]

		;Colocamos en VIC4 y en VIC7 las direcciones de las RSIs
		LDR r1, =RSI_timer
		str r1, [r0, r3, LSL #2]
		LDR r2, =RSI_teclado
		str r2, [r0, r4, LSL #2]
		
		;Habilitamos los bits 4 y 7 en la máscara de interrupciones
		LDR r2, =VICIntEnable
		mov r0, #2_10010000
		str r0, [r2]
		
		
*********************************************************************************************
;Programa principal (PP):

		;Dibujamos la pantalla principal
		LDR r0, =pantalla
		PUSH{r0}
		bl PANTALLA_INICIAL		;SBR que dibuja la pantalla y el coche en sus posiciones iniciales
		add sp, sp, #4			;Corregimos sp
		
		;Comprobamos si se debe terminar el programa (terminar = 1)
buc		LDR r0, =terminar
		ldrb r1, [r0]
		cmp r1, #1
		beq desact
		
		;En función de la tecla detectada por R_DAT ejecutamos unas instrucciones u otras:
		LDR r0, =teclaLeida
		ldrb r0, [r0]			;r0=Última tecla pulsada por el usuario
		cmp r0, #0				;Si teclaLeida no tiene ningún dato nuevo, no actualizamos 
		beq detChoq				;la velocidad ni la posición del coche			
		
		cmp r0, #81				;Compruebo si es 'Q'
		bne noq
		
		;Detecto 'Q'
		LDR r1, =terminar
		mov r0, #1
		strb r0, [r1]			;Si se ha pulsado 'Q', pongo terminar a 1
		b finDet
		
noq		LDR r1, =coche
		ldr r1, [r1]
		mov r2, r1				;Copio la posición anterior para borrar coche si fuese necesario
		
		LDR r4, =alertsup
		cmp r1, r4				;Compruebo si está en riesgo de exceder el límite superior
		blt sig2				;Si lo está, ignoro las instrucciones correspondientes a 
								;la tecla 'I', por si acaso ha sido pulsada dicha tecla
								;De esta forma, evitamos que se salga de la pantalla
		
		cmp r0, #73				;Detecto I
		bne sig2
		sub r1, r1, #32			;Actualizo posición del coche
		b movercoche
		
sig2	LDR r4, =finpantalla
		sub r4, r4, #32
		cmp r1, r4				;Compruebo si está en riesgo de exceder el límite inferior
		bgt sig3				;Si lo está, ignoro las instrucciones correspondientes a 
								;la tecla 'K', por si acaso ha sido pulsada dicha tecla
								;De esta forma, evitamos que se salga de la pantalla
		
		cmp r0, #75				;Detecto K
		bne sig3
		add r1, r1, #32			;Actualizo posición del coche
		b movercoche
		
sig3	cmp r0, #74				;Detecto J
		bne sig4
		sub r1, r1, #1			;Actualizo posición del coche
		b movercoche
		
sig4	cmp r0, #76				;Detecto L
		bne sig5
		add r1, r1, #1			;Actualizo posición del coche
		b movercoche
				
movercoche
        ldrb r4, [r1]			;Detecto si ha chocado
		cmp r4, #35
		bne nochoq
		mov r4, #1				;Si ha chocado, pongo la variable 'terminar' a 1
		LDR r3, =terminar
		strb r4, [r3]			;Guardo terminar = 1
		b finDet

		;Si no ha chocado:
nochoq	mov r3, #72				;'H'
		strb r3, [r1]			;Muevo el coche
		LDR r0, =coche
		str r1, [r0]			;Actualizo posición
		mov r1, #32
		strb r1, [r2]			;Borro el coche de su posición anterior
		b finDet
		
sig5	LDR r1, =velocidad
		ldr r2, [r1]			;r2=velocidad
		LDR r3, =cont			;r3=@cont
		
		cmp r0, #11				;Detecto '+'
		bne sig6
		mov r2, r2, LSR #1		;Multiplico x2 velocidad
		
		mov r4,#1				;Control límites vmax
		cmp r2, r4
		movls r2,#1
		b actV
				
sig6	cmp r0, #13				;Detecto '-'
		bne finDet
		mov r2, r2, LSL #1		;Divido x2 velocidad
				
		mov r4,#128				;Control límites vmin
		cmp r2, r4
		movge r2,#128
		
actV	str r2, [r1]			;Actualizo velocidad
		mov r2, #0				
		str r2, [r3]			;Reseteo cont

finDet LDR r0, =teclaLeida		;Reseteamos datoLeido
		mov r1, #0
		strb r1, [r0]		
		
		
		;El coche puede chocarse debido a un mal movimiento del jugador o a que al mover 
		;la carretera, esta se ha colocado donde estaba el coche. Detectaremos ambos casos:
		
detChoq	;Compruebo si al mover la carretera se ha chocado solo
		LDR r1, =coche
		ldr r1, [r1]			;r1=posicion del coche
		ldrb r2, [r1]			;Contenido de la posición del coche
		LDR r1, =terminar		;r1=@terminar
		cmp r2, #35				;Comparo el contenido de la posición con '#'
		beq escTer
		
		;Comprobamos si el coche ha chocado al ser movido
malMov	ldrb r2, [r1]
		cmp r2, #1				;Compruebo si hemos detectado choque al mover el coche
		bne actualizar_carretera
		
		;Si ha chocado:
escTer	mov r0, #1
		strb r0, [r1]			;Pongo la variable 'terminar' a 1
		
		;Limpiamos la pantalla
		bl LIMPIARPANTALLA		;SBR que limpia toda la pantalla
		
		bl GAMEOVER				;SBR que escribe 'GAME OVER!' en pantalla
		b buc					;Volvemos al principio del bucle para definir que el programa ha terminado
		
		;Si no ha chocado, actualizamos la carretera
actualizar_carretera
		;Primero comprobamos si cont=velocidad
		LDR r0, =cont
		ldr r2, [r0]			;r2=cont
		LDR r1, =velocidad
		ldr r1, [r1]			;r1=velocidad
		cmp r2, r1				;Comprobamos si el contador indica actualización necesaria
		bne buc					;Sino, volvemos al principio del bucle
		mov r2, #0		
		strb r2, [r0]			;Reseteamos cont
		
		;Bajamos carretera
		bl BAJAR_CARRETERA		;SBR que baja la carretera fila a fila (la baja 1 sola fila en cada llamada)		
		
		;Generamos carretera aleatoria
		
		;Primero, detectamos la posición de la carretera en su último estado
		LDR r0, =pantalla
		add r0, r0, #32				;Comprobamos la segunda fila ya que la primera 
		mov r5, #35					;aún no ha sido colocada
		mov r3, #32					;Número de iteraciones
		
buscCar	ldrb r2, [r0]				;r2=Contenido de la posición de memoria leída
		cmp r2, r5					;Si es igual a '#':
		mov r4, r0					;Guardamos la posición
		beq aleat					;Saltamos a los procedimientos aleatorios
incrind	add r0, r0, #1				;Sino, sigo comprobando hasta encontrar la carretera
		subs r3, r3, #1
		bne buscCar		
	
	
aleat	sub sp, sp, #4
		bl rand						;Llamamos a la subrutina rand que nos devolverá por pila 
		POP{r0}						;un número aleatorio
		
		mov r0, r0, LSR #25			;No utilizaremos los bits de menos significancia ya que cuanto
									;menores sean los bits analizado, los resultados serán menos aleatorios
		and r0, r0, #3				;Selecciono 3 bits y borro el resto
		mov r1, r0					;Guardo el número resultante
		mov r0, r0, LSR #1			;Cojo [1] de r0
		
		mov r2, #1				
		cmp r0, r2					;Si [1]=1, -> recto
		beq recto
		
		and r1, r1, #1
		cmp r1, r2					;Sino, si [0]=1 -> derecha. Se moverá a la izquierda en caso contrario
		beq der
		
		;Mover a la izquierda
		sub r4, r4, #33				;Corregimos: r4('#' detectado) - 32(pasamos a la 1ª fila) -1(movemos 1 a la izq)
		LDR r2, =0X40007E03
		cmp r4, r2					;Compruebo si hay riesgo de exceder los límites
		ble corrizq					;Si lo hay, salto a la corrección
		strb r5, [r4]				;Sino, dibujo el límite izquierdo de la carretera
		strb r5, [r4, #8]			;Límite derecho de la carretera
		b yaConstruida	
		
corrizq	add r4, r4, #2				;Corrijo la posición
		strb r5, [r4]				;Dibujo la carretera
		strb r5, [r4, #8]
		b yaConstruida
		
		
der		sub r4, r4, #31				;Corregimos: r4('#' detectado) - 32(pasamos a la 1ª fila) +1(movemos 1 a la der)
		LDR r2, =0X40007E14
		cmp r4,r2					;Compruebo si hay riesgo de exceder los límites
		bge corrder					;Si lo hay, salto a la corrección
		strb r5, [r4]				;Sino, dibujo el límite izquierdo de la carretera
		strb r5, [r4, #8]			;Límite derecho de la carretera
		b yaConstruida
		
corrder	sub r4, r4, #2				;Corrijo la posición
		strb r5, [r4]				;Dibujo la carretera
		strb r5, [r4, #8]
		b yaConstruida
		
				
recto	sub r4, r4, #32				;Si se sigue recto, no hay que desplazar la carretera ni comprobar límites
		strb r5, [r4]				;Dibujo la carretera
		strb r5, [r4, #8]		
			
yaConstruida 
		b buc
		
*********************************************************************************************
;Restauración del sistema de E/S:

		;Deshabilitamos los bits 4 y 7 en la máscara de interrupciones
desact	LDR r0, =VICIntEnClr
		mov r1, #2_10010000
		str r1, [r0]
		
		;Recuperamos las direcciones originales que se guardaban en VIC 4 y VIC7
		LDR r0, =VICVectAddr0
		LDR r1, =timer_so
		ldr r1, [r1]
		LDR r2, =tecl_so
		ldr r2, [r2]
		mov r3, #4
		str r1, [r0, r3, LSL #2]
		mov r3, #7
		str r2, [r0, r3, LSL #2]
		
fin		b fin
		
*********************************************************************************************
;Rutinas de Servicio de Interrupciones (RSI):

RSI_timer	; Le llega una interrupción cada 0,01seg

		;Prólogo
		sub lr,lr, #4
		PUSH{lr}				;Apilar @retorno_pp
		mrs r14, spsr			
		PUSH{r14}				;Apilar cpsr_pp
		msr cpsr_c, #2_01010010	;Activar interrupciones IRQ
		
		PUSH{r0, r1}			;Apilo registros a utilizar
		
		;Bajamos petición (escribiendo un 1 en el T0_IR)
		LDR r0, =T0_IR
		mov r1, #1
		str r1, [r0]
		
		;cont = cont+1
		LDR r0, =cont			;r0=@cont
		ldr r1, [r0]			;r1=cont
		add r1, r1, #1
		str r1, [r0]
		
		POP{r0, r1}				;Desapilo registros utilizados
		
		;Epílogo
		msr cpsr_c, #2_11010010	;Desactivar interrupciones IRQ
		POP{r14}				;r14=cpsr_pp
		msr spsr_fsxc, r14		;spsr=cpsr_pp
		LDR r14, =VICVectAddr	;EOI
		str r14, [r14]
		POP{pc}^				;pc=@ret_pp y cpsr=spsr=cpsr_pp
		
RSI_teclado

		;Prólogo
		sub lr,lr, #4
		PUSH{lr}				;Apilar @retorno_pp
		mrs r14, spsr			
		PUSH{r14}				;Apilar cpsr_pp
		msr cpsr_c, #2_01010010	;Activar interrupciones IRQ
		
		PUSH{r0-r1}				;Apilo registros a utilizar
		
		;Transferencia
		LDR r1, =R_DAT
		ldrb r0, [r1]
		
		;Paso a mayúsculas y almaceno lo leído para tratarlo en el PP
		bic r0, r0, #2_100000
		LDR r1, =teclaLeida
		strb r0, [r1]

		POP{r0-r1}				;Desapilo registros utilizados
		
		;Epílogo
		msr cpsr_c, #2_11010010	;Desactivar interrupciones IRQ
		POP{r14}				;r14=cpsr_pp
		msr spsr_fsxc, r14		;spsr=cpsr_pp
		LDR r14, =VICVectAddr	;EOI
		str r14, [r14]
		POP{pc}^				;pc=@ret_pp y cpsr=spsr=cpsr_pp
		
*********************************************************************************************
;Subrutinas:

PANTALLA_INICIAL
		PUSH{lr}
		PUSH{r11}
		mov fp, sp
		
		PUSH{r0-r4}				;Apilo registros a utilizar

		ldr r0, [fp, #8]		;r0=@pantalla
		eor r1, r1, r1			;r1=i
		eor r2, r2, r2			;r2=j
		mov r3, #32				;r3=' '
		mov r4, #35				;r4='#'
				
buc1	cmp r1, #16
		bge escCoch
		
buc2	cmp r2, #32
		bge incri
		
		cmp r2, #8				;Si columna=8, salto a escribir almohadilla
		beq escAlm
		cmp r2, #16				;Sino, si columna=16, salto a escribir almohadilla
		beq escAlm
		strb r3, [r0], #1		;Sino, escribo espacio
		b incrj
		
escAlm	strb r4, [r0], #1		;Escribo almohadilla
incrj	add r2, r2, #1			;Incremento j
		b buc2
		
incri	mov r2, #0				;Reinicio j
		add r1, r1, #1			;Incremento i
		b buc1
		
		;Dibujamos el coche en su posición inicial
escCoch	LDR r1, =coche
		ldr r1, [r1]
		mov r0, #72
		strb r0, [r1]
		
		POP{r0-r4}				;Desapilo registros utilizados
		
		POP{r11}
		POP{pc}
		

LIMPIARPANTALLA
		PUSH{lr}
		PUSH{r11}
		mov fp, sp
		
		PUSH{r0-r2}				;Apilo registros a utilizar
		LDR r0, =pantalla
		LDR r1, =espacio2
		mov r2, #128			;Número de iteraciones 
		
buclimp	str r1, [r0], #4		; Escribimos ' ' en toda la pantalla
		subs r2, r2, #1
		bne buclimp	

		POP{r0-r2}				;Desapilo registros utilizados
		
		POP{r11}
		POP{pc}


GAMEOVER
		PUSH{lr}
		PUSH{r11}
		mov fp, sp
		
		PUSH{r0-r3}				;Apilo registros a utilizar
		
		LDR r0, =Mensaje_GO		;r0=@mensaje
		LDR r1, =iniGO			;r1=@donde_escribir_el_mensaje
		mov r2, #0				;r2=i
		
bucGO	ldrb r3, [r0, r2]		;r3=Carácter a escribir				
		strb r3, [r1, r2]		;Escribimos el carácter
		add r2, r2, #1			;Incremento i						
		cmp r2, #10										
		blt bucGO

		POP{r0-r3}				;Desapilo registros utilizados
		
		POP{r11}
		POP{pc}
		
		
BAJAR_CARRETERA		
		PUSH{lr}
		PUSH{r11}
		mov fp, sp
		
		PUSH{r0-r5}				;Apilo registros a utilizar
		
		LDR r0, =finpantalla	;Posición a partir de la que empezaremos a bajar la carretera
		LDR r2, =pantalla
		sub r2, r2, #1			;r2=@pantalla (posición anterior a la primera)
		mov r1, #35				;r1='#'
		mov r3, #32				;r3=' '
		
		;Primero, borramos la carretera de la última fila
		mov r4, #32				;r4=Número de iteraciones
limpUlt	ldrb r5, [r0]			;r5=Contenido de posición a comprobar (comprobar si es '#' o no)
		cmp r1 ,r5
		bne incrLU
		strb r3, [r0]			;Si en la posición indicada hay un '#', la limpiamos
		
incrLU	sub r0, r0, #1			;Actualizamos r0 (que recorre toda la última fila)
		subs r4, r4, #1			;Restamos 1 iteración
		bne limpUlt
		
		
		;Una vez limpiada la última fila, procedemos a bajar el resto de filas una posición
		;La fila de arriba del todo
Baj		ldrb r4, [r0]			;r4=@ a comprobar
		cmp r4, r1
		bne incrBaj
		strb r3, [r0]			;Si en la posición indicada hay un '#', la limpiamos
		strb r1, [r0, #32]		;Escribimos el '#' en la siguiente fila (misma columna)
		
incrBaj	sub r0, r0, #1			;Actualizamos r0 (que recorre la pantalla)
		cmp r0, r2				;Comprobamos si r0 = última posición a comprobar
		bge Baj
		
		POP{r0-r5}				;Desapilo registros utilizados
		
		POP{r11}
		POP{pc}

		END