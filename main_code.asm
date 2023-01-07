	include <p18F4520.inc>
	config wdt = off ;wdt controlled by software
	config wdtps = 256 ; watchdog = 1024 ms
	config pbaden = off ; portb digital
	config osc = INTIO7 ; set to internal clock
	config pwrt = on ; powerup timer on +66ms
	config boren = off ; brown out reset
	config mclre = on ; re0 used as reset pin
	config lvp = off ; 
	config stvren = on ; resets if pc is overloaded
	config debug = off ; rb5 and 6 normal io pins
	
loadtimer0  macro ; load timer0 with 60 536
	movlw 0xec
	movwf tmr0h
	movlw 0x78
	movwf tmr0l
	endm
	
	numberofint equ 0x00 ; counts number of interruptions
	var equ 0x02 ; adds to table pointer
	tmh equ 0x04 ; save tmr1h value
	
	org 0x00
	bra init
	
	org 0x08
	bra hp
	
	

	
	
checkbacksensor

	bcf t0con,7 ; stop timer0
	loadtimer0 ; reload timer0
	
	bsf latb,7 ; set trigger to high
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bcf latb,7 ; set trigger to low

	clrf tmr1h
	clrf tmr1l

waitechohighback
	btfss portb,6 ; check if echo is high
	bra waitechohighback
	

	bsf t1con,0 ; start timer1
	
waitecholowback
	btfsc portb,6
	bra waitecholowback
	
	bcf t1con,0 ; stops timer1
	bsf t0con,7 ; start timer0
    movf tmr1l,w
	movff tmr1h,tmh
	movlw 0x03 ; time for 13 cm
	cpfslt tmh
	retfie
	movlw b'00000000' ; stop
	movwf latc
	retfie
	
	
	
hp
	bcf t0con,7 ; stop timer0
	loadtimer0 ; reload timer0 
	bcf intcon,tmr0if ; lowers interrupt flag for timer0
	incf numberofint,f ; increment numberofint
	
	movlw b'00001010' ; reverse motors
	cpfslt latc ; check if motors are in reverse
	bra checkbacksensor
	
	
	bsf latb,0 ; set trigger to high
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bcf latb,0 ; set trigger to low
	
	clrf tmr1h
	clrf tmr1l
	
waitechohigh
	btfss portb,1 ; check if echo is high
	bra waitechohigh
	
	
	bsf t1con,0 ; start timer1
	
waitecholow
	btfsc portb,1
	bra waitecholow
	
	bcf t1con,0 ; stops timer1
	bsf t0con,7  ; starts timer0
    movf tmr1l,w
	movff tmr1h,tmh
	movlw 0x04 ; time for 17 cm
	cpfslt tmh
	retfie
	movlw 0x02 ; time for 8.5 cm
	cpfsgt tmh
	bra tooclose ; actions to take if obstacle too close
	movlw b'00001001' ; move left
	movwf latc
	retfie
	
tooclose
	movlw b'00001010' ; reverse motors
	movwf latc
	bra checkbacksensor
	
	
init
	movlw b'01101010'
	movwf osccon ; set internal clock to 4 MHz
	movlw 0x00
	movwf osctune
	bsf wdtcon,swdten ; enables software controlled watchdog timer
	
	clrf numberofint ; clears number of interruptions
	clrf var ; clears var that gives action to take
	
	movlw 0x02
	movwf pclath			; pclath = 2
	
	;configuring IO ports 
	bcf latb,0
	bcf trisb,0
	clrf latc
	movlw b'11110000'
	movwf trisc
	
	; back sensor config uses rb6 and 7
	bcf latb,7
	bcf trisb,7
	
	
	; configuring timer0 to interrupt every 100ms
	loadtimer0
	movlw b'10000000' ; using 16bits 
	movwf t0con
	
	; configuring timer1 to be able to count the time taken by the signal to make a roundtrip
	clrf tmr1h
	clrf tmr1l
	movlw b'10000000'
	movwf t1con
	
	bsf rcon,ipen
	bcf intcon,tmr0if
	movlw b'11100000' ; high priority timer0
	movwf intcon
	
bcl
	clrwdt ; clear watchdog timer
	movlw d'50'
	cpfslt numberofint ; counts 50 interruptions
	call switchaction ; if 50 interruptions or more, change action taken by car
	bra bcl
	
	org 0x200
table
	addwf pcl,f 
	retlw b'00000101' ; to go straight
	retlw b'00000101'
	retlw b'00000101'
	retlw b'00000101'
	retlw b'00000001'
	retlw b'00000101' ; to go straight
	retlw b'00000101'
	retlw b'00000101'
	retlw b'00000101'
	retlw b'00000101'
	retlw b'00000100'
	retlw b'00001010' ; go back
	retlw b'00001010'
	retlw b'00001010'
	retlw b'00001010'
	
	
switchaction
	clrf numberofint ; resets number of interruptions
	movf var,w ; increments pcl value in table
	call table ; gets value of action from table
	movwf latc ; sets new action in latc
	movlw d'28' ; checks if var reached the end of the table
	cpfslt var ; (x-1) * 2
	bra clearvar
	movlw 0x02 ; increment var by 2
	addwf var,f
	return
	
clearvar
	clrf var ; if yes, clears var
	return
	
	end