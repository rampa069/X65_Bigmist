.p816
.include "common.inc"
.include "vera.inc"
.include "vt.inc"


.import vera_init
.import vt_printstr_at
.import vt_putchar, vt_keyq
.import _vidmove, _vt_handle_irq

; assume OF816 starts at $01_0000, i.e. the beginning of the BANK = $01
OF816_START  = $010000

; ========================================================================
.segment "RODATA"
hello_str:
    .asciiz "OF816 port for X65-SBC, see https://github.com/jsyk/of816"

; ========================================================================
.code

.proc start
.i8
.a8
    ; emulation mode, also brings A and X/Y to 8-bit mode
    sec
    xce
    ; restart the stack
    ldx     #255
    txs
    ; go to the 16-bit mode; A and X/Y are still in 8-bit mode
    clc
    xce
    .a8
    .i8

    ; jsr     vera_init     ; initialize the VERA - already done in SBL!!
    ; Now we are in text mode 80 x 60 characters visible, and 128 x 128 chars allocated.

    ; The SBL has printed a logo in the middle of the screen.
    ; The logo is 6 lines high; it begins at the line #27 and ends at the line #33.
    ; The logo is 10 lines high; it begins at the line #25 and ends at the line #35.
    ;
    ; Scroll down by 23 lines so that we put the logo at the top of the screen.
    ACCU_INDEX_16_BIT
    lda     #(256*37)           ; A = number of bytes: one line is 128 chars+attr = 256 bytes, and we scroll (60-23)=37 lines
    ldx     #(256*23)            ; X = source: beginning of line #23
    ldy     #0                  ; Y = destination: beginning of line #0
    jsl     _vidmove

    ; print info message
    ACCU_16_BIT
    INDEX_8_BIT
    lda     #hello_str
    ldx     #0
    ldy     #13
    jsl     vt_printstr_at

    ; reset screen cursor position: X=0, Y=15
    ACCU_8_BIT
    lda     #0
    sta     z:bVT_CURSOR_X
    lda     #15
    sta     z:bVT_CURSOR_Y

    ; enable screen cursor
    lda     #1
    sta     z:bVT_CURSOR_VISIBLE

    ; reset the keyboard buffer and flags
    lda     #0
    sta     z:bKBD_NEXT_ASCII
    sta     z:bKBD_FLAGS
    sta     z:bKBD_LAST_KEYCODE

    ; enable VERA VSYNC interrupts in bit [0]
    lda     #1
    sta     f:VERA_IRQ_ENABLE_REG
    ; enable CPU irq handling
    cli

    ; OF816 assumes full native mode
    ACCU_INDEX_16_BIT
    ; jump to OF816 start
    jmp     f:OF816_START

fin_loop:
    BRA     fin_loop
.endproc

;-------------------------------------------------------------------------------
.proc bios_irq_handler
    ; save all registers
    ACCU_INDEX_16_BIT
    pha
    phx
    phy
    ; trigger VT irq handling
    jsl     _vt_handle_irq
    ; restore all registers
    ACCU_INDEX_16_BIT
    ply
    plx
    pla
    rti
.endproc

; ========================================================================
.segment "LAST256"          ; $00_FF00-$00_FFFF
    ; $00FF00 = vt_putchar
    jmp     f:vt_putchar          ; @ $00_FF00
    ; $00FF04 = vt_keyq
    jmp     f:vt_keyq          ; @ $00_FF00
    

; ========================================================================
; this is placed at the last 32 bytes of CPU BANK = $00
.segment "NATVECTORS"
    ; FFE0,1 = reserved
    .WORD 0
    ; FFE2,3 = reserved
    .WORD 0
    ; FFE4,5 = COP (16-bit mode)
    .WORD start
    ; FFE6,7 = BRK (16-bit mode)
    .WORD start
    ; FFE8,9 = ABORTB (16-bit mode)
    .WORD start
    ; FFEA,B = NMI (16-bit mode)
    .WORD start
    ; FFEC,D = reserved
    .WORD 0
    ; FFEE,F = IRQ (hw)
    .WORD bios_irq_handler

.segment "EMUVECTORS"
    ; FFF0,1 = reserved
    .WORD 0
    ; FFF2,3 = reserved
    .WORD 0
    ; FFF4,5 = COP (816 in Emu mode only)
    .WORD start
    ; FFF6,7 = reserved
    .WORD 0
    ; FFF8,9 = ABORTB (816 in Emu mode only)
    .WORD start
    ; # // FFFA,B = NMI (8-bit mode)
    .WORD start
    ; # // FFFC,D = RES
    .WORD start
    ; # // FFFE,F = BRK, IRQ
    .WORD start
