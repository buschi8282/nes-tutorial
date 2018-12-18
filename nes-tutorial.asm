; NES Game Development Tutorial
;
; Author: Jonathan Moody
; Github: https://github.com/jonmoody

  .inesprg 1    ; Defines the number of 16kb PRG banks
  .ineschr 1    ; Defines the number of 8kb CHR banks
  .inesmap 0    ; Defines the NES mapper
  .inesmir 1    ; Defines VRAM mirroring of banks

  .rsset $0000
pointerBackgroundLowByte  .rs 1
pointerBackgroundHighByte .rs 1

;this is a bitmask to keep track of whether a user is holding down a button
;from left to right, the bits reppresent a, b, select, start, d-pad up,
;d-pad down, d-pad left, d-pad right
last_controller_state .rs 1 ;putting this in page 0 so we can access it quickly
current_controller_state .rs 1

A_BUTTON = %10000000
B_BUTTON =%01000000
SELECT_BUTTON = %00100000
START_BUTTON = %00010000
UP_BUTTON = %00001000
DOWN_BUTTON = %00000100
LEFT_BUTTON = %00000010
RIGHT_BUTTON = %00000001

controller1 = $4016
controller2 = $4017

shipTile1Y = $0300
shipTile2Y = $0304
shipTile3Y = $0308
shipTile4Y = $030C
shipTile5Y = $0310
shipTile6Y = $0314

shipTile1X = $0303
shipTile2X = $0307
shipTile3X = $030B
shipTile4X = $030F
shipTile5X = $0313
shipTile6X = $0317

  .bank 0
  .org $C000

RESET:
  JSR LoadBackground
  JSR LoadPalettes
  JSR LoadAttributes
  JSR LoadSprites

  LDA #%10000000   ; Enable NMI, sprites and background on table 0
  STA $2000
  LDA #%00011110   ; Enable sprites, enable backgrounds
  STA $2001
  LDA #$00         ; No background scrolling
  STA $2006
  STA $2006
  STA $2005
  STA $2005

InfiniteLoop:
  JMP InfiniteLoop

LoadBackground:
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006

  LDA #LOW(background)
  STA pointerBackgroundLowByte
  LDA #HIGH(background)
  STA pointerBackgroundHighByte

  LDX #$00
  LDY #$00
.Loop:
  LDA [pointerBackgroundLowByte], y
  STA $2007

  INY
  CPY #$00
  BNE .Loop

  INC pointerBackgroundHighByte
  INX
  CPX #$04
  BNE .Loop
  RTS

LoadPalettes:
  LDA $2002
  LDA #$3F
  STA $2006
  LDA #$00
  STA $2006

  LDX #$00
.Loop:
  LDA palettes, x
  STA $2007
  INX
  CPX #$20
  BNE .Loop
  RTS

LoadAttributes:
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$C0
  STA $2006
  LDX #$00
.Loop:
  LDA attributes, x
  STA $2007
  INX
  CPX #$40
  BNE .Loop
  RTS

LoadSprites:
  LDX #$00
.Loop:
  LDA sprites, x
  STA $0300, x
  INX
  CPX #$18
  BNE .Loop
  RTS

ReadController1:
  LDA #$01
  STA controller1
  STA current_controller_state
  LSR A
  STA controller1
.loop:
  LDA controller1
  LSR A
  ROL current_controller_state
  BCC .loop
  RTS

MoveShip:

ReadUp:
  LDA current_controller_state
  AND #UP_BUTTON
  BEQ EndReadUp

  LDA shipTile1Y
  SEC
  SBC #$08
  STA shipTile1Y
  STA shipTile2Y
  STA shipTile3Y

  LDA shipTile4Y
  SEC
  SBC #$08
  STA shipTile4Y
  STA shipTile5Y
  STA shipTile6Y
EndReadUp:

ReadDown:
  LDA current_controller_state
  AND #DOWN_BUTTON
  BEQ EndReadDown

  LDA shipTile1Y
  CLC
  ADC #$08
  STA shipTile1Y
  STA shipTile2Y
  STA shipTile3Y

  LDA shipTile4Y
  CLC
  ADC #$08
  STA shipTile4Y
  STA shipTile5Y
  STA shipTile6Y
EndReadDown:

ReadLeft:
  LDA current_controller_state
  AND #LEFT_BUTTON
  BEQ EndReadLeft

  LDA shipTile1X
  SEC
  SBC #$08
  STA shipTile1X
  STA shipTile4X

  LDA shipTile2X
  SEC
  SBC #$08
  STA shipTile2X
  STA shipTile5X

  LDA shipTile3X
  SEC
  SBC #$08
  STA shipTile3X
  STA shipTile6X
EndReadLeft:

ReadRight:
  LDA current_controller_state
  AND #RIGHT_BUTTON
  BEQ EndReadRight

  LDA shipTile1X
  CLC
  ADC #$08
  STA shipTile1X
  STA shipTile4X

  LDA shipTile2X
  CLC
  ADC #$08
  STA shipTile2X
  STA shipTile5X

  LDA shipTile3X
  CLC
  ADC #$08
  STA shipTile3X
  STA shipTile6X
EndReadRight:

  RTS

NMI:
  LDA #$00
  STA $2003
  LDA #$03
  STA $4014

  JSR ReadController1
  JSR MoveShip

  RTI

  .bank 1
  .org $E000

background:
  .include "graphics/background.asm"

palettes:
  .include "graphics/palettes.asm"

attributes:
  .include "graphics/attributes.asm"

sprites:
  .include "graphics/sprites.asm"

  .org $FFFA
  .dw NMI
  .dw RESET
  .dw 0

  .bank 2
  .org $0000
  .incbin "graphics.chr"
