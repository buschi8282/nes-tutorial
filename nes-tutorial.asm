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

buttons_pressed .rs 1
buttons_held .rs 1
dpad_delay_auto_shift_active .rs 1
dpad_delay_auto_shift_counter .rs 1
sustained_movement_counter .rs 1

;counter to keep track of how many frames have elapsed since initial press of up
up_button_counter .rs 1
;counter to keep track of how many frames since last movement while in sustained
;motion
up_button_active_counter .rs 1

;16 frame delay from initial movement to sustained movement
BUTTON_ACTIVE_DELAY1 = $10
;4 frame delay between sustained movement to throttle the speed of the sprites
BUTTON_ACTIVE_DELAY2 = $04

A_BUTTON = %10000000
B_BUTTON =%01000000
SELECT_BUTTON = %00100000
START_BUTTON = %00010000
UP_BUTTON = %00001000
DOWN_BUTTON = %00000100
LEFT_BUTTON = %00000010
RIGHT_BUTTON = %00000001
DPAD_BUTTONS = %00001111

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
  LDX buttons_held ;register x saves buttons held from last frame
  LDY buttons_pressed ; register y saves buttons initially pressed last frame

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

  ;wipe out buttons_held and buttons_pressed for any button not currently active
  LDA buttons_held
  AND current_controller_state
  STA buttons_held
  LDA buttons_pressed
  AND current_controller_state
  STA buttons_pressed

  ;wipe out delay auto shift status for any D-Pad button not active
  LDA dpad_delay_auto_shift_active
  AND current_controller_state
  AND DPAD_BUTTONS
  STA dpad_delay_auto_shift_active
  BEQ SkipResetDASTimer
  ; reset counter to 0 if no dpad buttons are active
  LDA #$00
  STA dpad_delay_auto_shift_counter
SkipResetDASTimer:
  ;pressed buttons from last frame that are still pressed are now held
  TYA ; fetch last frame button pressed from Y register
  AND current_controller_state ; clear any buttons not currently active
  ORA buttons_held
  STA buttons_held

  ;buttons that are currently active but not held should be considered pressed
  ;assuming buttons_held is still in accumulator a
  EOR current_controller_state
  STA buttons_pressed

  ;calculate delay auto shift status for d-pad
  LDA buttons_held
  AND #DPAD_BUTTONS
  TAX ; store this currently held dpad buttons in case we need it later
  BEQ SkipIncrementDASTimer ; skip if no d-pad buttons are held
  LDA dpad_delay_auto_shift_active
  CMP #$00
  BNE SkipIncrementDASTimer ; if DAS is already active, don't increment
  INC dpad_delay_auto_shift_counter
  LDA dpad_delay_auto_shift_counter
  CMP #BUTTON_ACTIVE_DELAY1
  BCC SkipIncrementDASTimer
  TXA
  STA dpad_delay_auto_shift_active

SkipIncrementDASTimer:

  RTS

MoveShip:

ReadUp:
  LDA current_controller_state
  AND #UP_BUTTON
  BEQ EndReadUp ; do nothing if up is not pressed

;check if up is already pressed
  LDA last_controller_state
  AND #UP_BUTTON
  BNE UpAlreadyHeld ; if it's already pressed skip counter initialization

;if we make it to here, this is the initial up button press
;so we set the up button counters to zero
  LDA #$00
  STA up_button_counter
  STA up_button_active_counter

  ;this code is to do an unconditional branch. there must be better way to do
  ;this
  LDA #$00
  CMP $00
  BEQ MoveTheShipUp ;skip code to increment counter

UpAlreadyHeld: ;if we make it here, up is already held down so we
;increment counter

  INC up_button_counter
  LDA up_button_counter
  CMP #BUTTON_ACTIVE_DELAY1
  BCC EndReadUp ; if button is held down less than delay do nothing

  ;if we make it here, we've already completed the initial delay and are in
  ;sustained movement. let's throttle speed of movement a little bit
  INC up_button_active_counter
  LDA up_button_active_counter
  CMP #BUTTON_ACTIVE_DELAY2
  BCC EndReadUp

MoveTheShipUp:
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

  ;reset sustained movement throttle counter
  LDA #$00
  STA up_button_active_counter
EndReadUp:

ReadDown:

  LDA buttons_pressed
  AND #DOWN_BUTTON
  BNE MoveShipDown

CheckIfDownDAS:
  LDA dpad_delay_auto_shift_active
  AND #DOWN_BUTTON
  BEQ EndReadDown

  INC sustained_movement_counter
  LDA sustained_movement_counter
  CMP #BUTTON_ACTIVE_DELAY2
  BCC EndReadDown

MoveShipDown:
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

;set counter to zero since we're about to go into DAS
  LDA #$00
  STA sustained_movement_counter
EndReadDown:

ReadLeft:
  LDA buttons_held
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
  LDA buttons_held
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

  LDA current_controller_state
  STA last_controller_state
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
