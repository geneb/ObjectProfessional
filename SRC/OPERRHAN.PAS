{*********************************************************}
{*                  OPERRHAN.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{*                 All rights reserved.                  *}
{*********************************************************}

{!!.20 Numerous changes for DOS pmode operation}

{$IFDEF Windows}
  !! ERROR: This unit is not compatible with Windows applications !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$IFDEF Dpmi}                               {!!.20}
  {$C FIXED PRELOAD PERMANENT}              {!!.20}
{$ENDIF}                                    {!!.20}

{$I OPDEFINE.INC}

unit OpErrHan;
  {-Allow recovery from some Turbo runtime errors}

interface

uses
  Dos;

var
  CanRecover : Boolean;      {True when the error handler is successfully installed}

procedure ErrorRecovery(On : Boolean; UserRoutine : Pointer);
  {-Turn error recovery on and off, and attach to a user error routine}

  {==========================================================================}

implementation

{$IFDEF Dpmi}
const
  OvrLoadList : Word = 0;
{$ENDIF}

type
  PatchArray = array[1..5] of Byte;
  OS = {Convenient record for typecasting pointers}
    record
      O : Word;
      S : Word;
    end;

var
  Int0 : Pointer;
  UserHandler : Pointer;
  SystemHandler : Pointer;
  SystemContinue : Pointer;
  SaveErrorEntry : PatchArray;
  NewErrorEntry : PatchArray;
  ErrorCode : Word absolute ExitCode; {!!.13}
  PMode : Boolean;
  FloatError : Byte;
  CSToDSInc : Word;

  {$L OPERRHAN.OBJ}
  procedure ErrHanInt0; external;
    {-Interrupt 0 handler}
  procedure Handler; external;
    {-Handle recovery from errors}
  procedure Trap8087errors; external;
    {-Install INT 2 and INT 75 handlers}

  procedure ErrorRecovery(On : Boolean; UserRoutine : Pointer);
    {-Patch into or out of system error handler to allow error recovery}
  begin
    if not CanRecover then
      Exit;

    if On then begin
      {Patch the system error handler}
      Move(NewErrorEntry, SystemHandler^, 5);

      {Assure current error value is zeroed out}
      ExitCode := 0;

      {Store the address of the UserHandler}
      UserHandler := UserRoutine;

      {Take over interrupt 0 so we can balance the stack}
      SetIntVec(0, @ErrHanInt0);

    end else begin
      {Unpatch the system error handler}
      Move(SaveErrorEntry, SystemHandler^, 5);

      {Give interrupt 0 back to SYSTEM}
      SetIntVec(0, Int0);
    end;
  end;

{$IFDEF Ver55}

type
  BytePtr = ^Byte;
  CharPtr = ^Char;

  function AddPtr(P : Pointer; Num : Word) : Pointer;
    {-Add Num to a pointer - no normalization}
  begin
    AddPtr := Ptr(Seg(P^), Ofs(P^)+Num);
  end;

  function Search(Start : Pointer; MaxLen : Word; Match : string) : Pointer;
    {-Search memory starting at Start for the string Match, returning nil if not found}
  var
    MemPos : Word;
    MatPos : Word;
    Matched : Boolean;
    P : Pointer;
    Q : Pointer;
  begin
    P := Start;
    for MemPos := 1 to MaxLen do begin
      if CharPtr(P)^ = Match[1] then begin
        {First byte matches, check the rest}
        Q := P;
        Matched := True;
        MatPos := 1;
        while Matched and (MatPos <= Length(Match)) do begin
          Matched := (CharPtr(Q)^ = Match[MatPos]);
          Q := AddPtr(Q, 1);
          Inc(MatPos);
        end;
        if Matched then begin
          {Matched entire length, return pointer to beginning of match}
          Search := P;
          Exit;
        end;
      end;
      P := AddPtr(P, 1);
    end;

    {Not found}
    Search := nil;
  end;

  function Initialize : Boolean;
    {-Find system error handler, returning true if found}
  var
    Int23 : Pointer;
    P : Pointer;
    E1 : Pointer;
    E2 : Pointer;
  begin
    {Assume failure}
    Initialize := False;

    {The system error handler is near the int0 and int23 handlers}
    GetIntVec(0, Int0);
    GetIntVec($23, Int23);
    if OS(Int0).S <> OS(Int23).S then
      {Both routines are not in the system library}
      Exit;

    {Search for the error handler two ways and make sure they agree}
    P := Search(Int0, 32, #$59#$5B#$EB);
    if P = nil then
      Exit;
    P := AddPtr(P, 3);
    E1 := AddPtr(P, BytePtr(P)^+1);

    P := Search(Int23, 32, #$33#$C9#$33#$DB);
    if P = nil then
      Exit;
    E2 := AddPtr(P, 4);

    if E1 <> E2 then
      Exit;

    {Save the five bytes at the start of the system handler}
    Move(E1^, SaveErrorEntry, 5);

    {Store the patch code for a jump to the recovery handler}
    NewErrorEntry[1] := $EA; {JMP DWORD PTR}
    P := @Handler;
    Move(P, NewErrorEntry[2], SizeOf(Pointer));

    {Store address of system error handler}
    SystemHandler := E1;
    {Store address after the jump to be patched in}
    SystemContinue := AddPtr(E1, 5);

    {Take over interrupt 0 so we can balance the stack}
    SetIntVec(0, @ErrHanInt0);

    {Take over interrupts 2 and 75 so we can catch floating point errors}
    Trap8087errors;

    {Successful initialization}
    Initialize := True;
  end;

{$ELSE}

  function GetSystemErrorHandler : Pointer;
  label JumpError;
  begin
    Goto JumpError;
    RunError(255);
  JumpError:
    asm
      mov     bx,offset JumpError
      sub     bx,4
      mov     ax,cs:[bx]
      mov     dx,cs:[bx+2]
      {$IFDEF Dpmi}
      add     ax,8
      {$ELSE}
      add     ax,11
      {$ENDIF}
      mov     word ptr @Result,ax
      mov     word ptr @Result+2,dx
    end;
  end;

  function Initialize : Boolean;
    {-Find system error handler, returning true if found}
  var
    P : Pointer;
  begin
    {Always succeeds under TP6.0 or later}

    {Save the int 0 vector, which we'll grab later}
    GetIntVec(0, Int0);

    SystemHandler := GetSystemErrorHandler;
    Move(SystemHandler^, SaveErrorEntry, 5);

    {Store the patch code for a jump to the recovery handler}
    NewErrorEntry[1] := $EA; {JMP DWORD PTR}
    P := @Handler;
    Move(P, NewErrorEntry[2], SizeOf(Pointer));

    SystemContinue := SystemHandler;
    Inc(Word(SystemContinue), 5);
    OS(SystemHandler).S:= OS(SystemHandler).S+CSToDSInc;

    {Take over interrupt 0 so we can balance the stack}
    SetIntVec(0, @ErrHanInt0);

    {Take over interrupts 2 and 75 so we can catch floating point errors}
    Trap8087errors;

    {Successful initialization}
    Initialize := True;
  end;
{$ENDIF}

begin
  {$IFDEF Dpmi}
  PMode := True;
  CSToDSInc := SelectorInc;
  {$ELSE}
  PMode := False;
  CSToDSInc := 0;
  {$ENDIF}

  {No floating point errors yet}
  FloatError := 0;

  {Find the system error handler}
  CanRecover := Initialize;
  if CanRecover then
    {Turn on error recovery}
    ErrorRecovery(True, nil);
end.
