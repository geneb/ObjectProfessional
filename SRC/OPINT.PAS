{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                    OPINT.PAS 1.30                     *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpInt;
  {-ISR management routines}


interface

uses
  Dpmi,
{$IFDEF Dpmi}
  WinAPI,
{$ENDIF}
  Dos;

const
  MaxISRs = 20;

type
  Dummy5 = array[1..5] of Word;
  IntRegisters =
    record
      case Byte of
        1 : (BP, ES, DS, DI, SI, DX, CX, BX, AX, IP, CS, Flags : Word);
        2 : (Dummy : Dummy5; DL, DH, CL, CH, BL, BH, AL, AH : Byte);
    end;
  IsrRecord =
    record
      IntNum : Byte;         {Interrupt vector number}
      OrigAddr : Pointer;    {Original vector}
      NewAddr : Pointer;     {New vector}
      Captured : Boolean;    {Used for error checking}
    end;
var
  {global array of ISR records}
  IsrArray : array[1..MaxISRs] of IsrRecord;

procedure InterruptsOn;
  {-Turn interrupts on}
  inline($FB);               {sti}

procedure InterruptsOff;
  {-Turn interrupts off}
  inline($FA);               {cli}

procedure SendEOI;
  {-Send an End Of Interrupt command to the Programmable Interrupt Controller}
  inline(
    $B0/$20/                 {mov al,$20}
    $E6/$20);                {out $20,al}

procedure IntReturn(var IntRegs : IntRegisters);
  {-Return from interrupt. Needed only if stack has been changed.}
  inline(
    $58/                     {pop ax      ;old SP into AX}
    $5A/                     {pop dx      ;old SS into DX}
    $FA/                     {cli         ;Interrupts off while changing SS:SP}
    $8E/$D2/                 {mov ss,dx   ;Address of IntRegs.BP is old SS:SP}
    $89/$C4/                 {mov sp,ax}
    $FB/                     {sti         ;Interrupts on}
    $5D/                     {pop bp      ;Restore registers}
    $07/                     {pop es}
    $1F/                     {pop ds}
    $5F/                     {pop di}
    $5E/                     {pop si}
    $5A/                     {pop dx}
    $59/                     {pop cx}
    $5B/                     {pop bx}
    $58/                     {pop ax}
    $CF);                    {iret        ;Return from interrupt}

procedure ChainInt(var Regs : IntRegisters; JumpAddr : Pointer);
  {-Restores stack, registers from Regs and 'jumps' to JumpAddr}
  inline(
    $5B/                     {pop bx          ;BX = Ofs(JumpAddr^)}
    $58/                     {pop ax          ;AX = Seg(JumpAddr^)}
    $5E/                     {pop si          ;SI = Ofs(Regs)}
    $1F/                     {pop ds          ;DS:SI => Regs}
                             {;Change stack so RETF passes control to JumpAddr;
                              restore Flags}
    $87/$5C/$0E/             {xchg bx,[si+14] ;Switch old BX and Ofs(JumpAddr^)}
    $87/$44/$10/             {xchg ax,[si+16] ;Switch old AX and Seg(JumpAddr^)}
    $8B/$54/$16/             {mov  dx,[si+22] ;Old Flags into DX}
    $52/                     {push dx         ;Push altered flags}
    $9D/                     {popf            ;Pop them into place}
                             {;Switch stacks -- make SS:SP point to Regs.BP}
    $8C/$DA/                 {mov dx,ds       ;DX = Seg(Regs)}
    $FA/                     {cli             ;Interrupts off}
    $8E/$D2/                 {mov ss,dx       ;Restore SS from DX}
    $89/$F4/                 {mov sp,si       ;Restore SP from SI}
    $FB/                     {sti             ;Interrupts on}
    $5D/                     {pop bp          ;Restore BP}
    $07/                     {pop es          ;Restore ES}
    $1F/                     {pop ds          ;Restore DS}
    $5F/                     {pop di          ;Restore DI}
    $5E/                     {pop si          ;Restore SI}
    $5A/                     {pop dx          ;Restore DX}
    $59/                     {pop cx          ;Restore CX}
                             {;BX and AX restored earlier; their places on stack}
                             {;now have JumpAddr, which is where return will go}
    $CB);                    {retf            ;Chain to JumpAddr}

procedure SwapStackAndCallNear(Routine : Word; SP : Pointer;
  var Regs : IntRegisters);
  {-Switches to stack designated by SP and calls Routine with Regs as a
    parameter. The Routine must be a NEAR call from the current ISR.}
  inline(
    $9C/                     {pushf        ;Load flags into AX}
    $58/                     {pop ax}
    $5A/                     {pop dx       ;AX = Ofs(Regs)}
    $07/                     {pop es       ;ES = Seg(Regs)}
    $59/                     {pop cx       ;CX = new SP}
    $5F/                     {pop di       ;DI = new SS}
    $5B/                     {pop bx       ;BX = offset of Routine to call}
    $8C/$D6/                 {mov si,ss    ;Save SS in SI}
    $FA/                     {cli          ;Force interrupts off}
    $8E/$D7/                 {mov ss,di    ;Switch stack segments}
    $87/$E1/                 {xchg cx,sp   ;Get new SP and save old in CX}
    $50/                     {push ax      ;Restore flags}
    $9D/                     {popf}
    $9C/                     {pushf        ;Save flags again}
    $56/                     {push si      ;Save old SS on stack}
    $51/                     {push cx      ;Save old SP}
    $06/                     {push es      ;Push Seg(Regs)}
    $52/                     {push dx      ;Push Ofs(Regs)}
    $FF/$D3/                 {call near bx ;Call Routine}
    $FA/                     {cli          ;Interrupts off}
    $58/                     {pop ax       ;Get back old SP}
    $5A/                     {pop dx       ;Get back old SS}
    $59/                     {pop cx       ;Get back old flags}
    $8E/$D2/                 {mov ss,dx    ;Restore SS}
    $89/$C4/                 {mov sp,ax    ;Restore SP}
    $51/                     {push cx      ;Restore flags}
    $9D);                    {popf}

procedure SwapStackAndCall(Routine, SP : Pointer; var Regs : IntRegisters);
  {-Switches to stack designated by SP and calls Routine with Regs as a
    parameter. The Routine must be a FAR call from the current ISR.}
  inline(
    $9C/                     {pushf         ;Save flags}
    $59/                     {pop cx}
    $8C/$D0/                 {mov ax,ss     ;AX = SS}
    $8E/$C0/                 {mov es,ax     ;ES = SS}
    $58/                     {pop ax        ;AX = Ofs(Regs)}
    $5A/                     {pop dx        ;DX = Seg(Regs)}
    $5B/                     {pop bx        ;BX = new SP}
    $5F/                     {pop di        ;DI = new SS}
                             {              ;address of Routine now at SS:SP}
    $FA/                     {cli           ;Force interrupts off}
    $8E/$D7/                 {mov ss,di     ;Switch stack segments}
    $87/$E3/                 {xchg bx,sp    ;Get new SP and save old in BX}
                             {              ;ES:BX now points to Routine}
    $51/                     {push cx       ;Restore flags}
    $9D/                     {popf}
    $9C/                     {pushf         ;Save flags again}
    $06/                     {push es       ;Save old SS on stack}
    $53/                     {push bx       ;Save old SP}
    $52/                     {push dx       ;Push Seg(Regs)}
    $50/                     {push ax       ;Push Ofs(Regs)}
    $26/                     {es:}
    $FF/$1F/                 {call far [bx] ;Call Routine}
    $FA/                     {cli           ;Force interrupts off}
    $58/                     {pop ax        ;Get back old SP}
    $5A/                     {pop dx        ;Get back old SS}
    $59/                     {pop cx        ;Get back old flags}
    $8E/$D2/                 {mov ss,dx     ;Restore SS}
    $89/$C4/                 {mov sp,ax     ;Restore SP}
    $51/                     {push cx       ;Restore flags}
    $9D/                     {popf}
    $83/$C4/$04);            {add sp,4      ;Get Routine off the stack}


procedure EmulateInt(var Regs : IntRegisters; IntAddr : Pointer);
  {-Emulates an interrupt by filling the CPU registers with the values in Regs,
    clearing interrupts, pushing the flags, and calling far to IntAddr.}

function InitVector(IntNumber, Handle : Byte; UserRoutine : Pointer) : Boolean;
  {-Sets up an interrupt service routine}

procedure RestoreVector(Handle : Byte);
  {-Restores an interrupt vector to its original value}

procedure RestoreAllVectors;
  {-Restores all captured interrupt vectors.}

function AllocateStack(var P : Pointer; SizeInBytes : Word) : Boolean;
  {-Allocates a stack of size SizeInBytes}

procedure DeallocateStack(P : Pointer);
  {-Frees an allocated stack}

  {==========================================================================}

implementation

type
  StackRecord =
    record
      Size : Word;
      Address : Pointer;
    end;
var
  SaveExitProc : Pointer;
  CStoDSInc    : Word;                 {!!.20}

  {$L OPINT.OBJ}

  procedure EmulateInt(var Regs : IntRegisters; IntAddr : Pointer);
    {-Emulates an interrupt by filling the CPU registers with the values in Regs,
      clearing interrupts, pushing the flags, and calling far to IntAddr.}
  external {OPINT} ;

  function InitVector(IntNumber, Handle : Byte; UserRoutine : Pointer) : Boolean;
    {-Sets up an interrupt service routine}
  begin
    {assume failure}
    InitVector := False;

    case Handle of
      1..MaxISRs :
        with IsrArray[Handle] do
          if not Captured then begin
            {Setup variables}
            IntNum := IntNumber;
            GetIntVec(IntNumber, OrigAddr);
            SetIntVec(IntNumber, UserRoutine);
            NewAddr := UserRoutine;
            Captured := True;
            InitVector := True;
          end;
    end;
  end;

  procedure RestoreVector(Handle : Byte);
    {-Restores an interrupt vector to its original value}
  begin
    case Handle of
      1..MaxISRs :
        with IsrArray[Handle] do
          if Captured then begin
            SetIntVec(IntNum, OrigAddr);
            Captured := False;
            OrigAddr := nil;
          end;
    end;
  end;

  procedure RestoreAllVectors;
    {-Restores all captured interrupt vectors}
  var
    I : Word;
  begin
    {restore in reverse order}
    for I := MaxISRs downto 1 do
      RestoreVector(I);
  end;

  function AllocateStack(var P : Pointer; SizeInBytes : Word) : Boolean;
    {-This routine allocates a stack of size SizeInBytes}
  var
    StackRecPtr : ^StackRecord absolute P;
    POfs : Word absolute P;
    PTemp : Pointer;
    ActualSize : LongInt;
  begin
    {allocate space for the stack record as well}
    ActualSize := LongInt(SizeInBytes)+6;

    {see if sufficient memory remains}
    if (MaxAvail >= ActualSize) and (ActualSize <= 65521) then begin
      {allocate the memory}
{$IFDEF Dpmi}                                                     {!!.22}
      P := GlobalAllocPtr(gmem_Fixed, ActualSize);                {!!.22}
{$ELSE}                                                           {!!.22}
      GetMem(P, Word(ActualSize));
{$ENDIF}                                                          {!!.22}

      {save the address}
      PTemp := P;

      {point P (hence StackRecPtr) to where the stack record goes}
      Inc(POfs, SizeInBytes);

      {save the address returned by GetMem and the # of bytes allocated}
      with StackRecPtr^ do begin
        Address := PTemp;
        Size := Word(ActualSize);
      end;

      AllocateStack := True;
    end
    else
      AllocateStack := False;
  end;

  procedure DeallocateStack(P : Pointer);
    {-Frees an allocated stack}
  var
    StackRecPtr : ^StackRecord absolute P;
  begin
    with StackRecPtr^ do
{$IFDEF Dpmi}                                                      {!!.22}
      if GlobalFreePtr(Address) = 0 then ;                         {!!.22}
{$ELSE}                                                            {!!.22}
      FreeMem(Address, Size);
{$ENDIF}                                                           {!!.22}
  end;

  {$F+}
  procedure OpIntExit;
    {-Exit/error handler for the unit. Restores all captured interrupt vectors}
  begin
    ExitProc := SaveExitProc;
    RestoreAllVectors;
  end;
  {$F-}

  procedure OpIntInit;
    {-This sets up an array of unused ISR records}
  var
    I : Word;
  begin
    {initialize the array of ISR records}
    for I := 1 to MaxISRs do
      with IsrArray[I] do begin
        IntNum := 0;
        OrigAddr := nil;
        NewAddr := nil;
        Captured := False;
      end;
  end;

begin
  {$IFDEF Dpmi}                                                       {!!.20}
  CStoDSInc := SelectorInc;                                           {!!.20}
  {$ELSE}                                                             {!!.20}
  CStoDSInc := 0;                                                     {!!.20}
  {$ENDIF}                                                            {!!.20}

  {initialize array of ISR records}
  OpIntInit;

  {set up exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @OpIntExit;
end.
