{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$IFDEF Dpmi}                               {!!.20}
  {$C FIXED PRELOAD PERMANENT}              {!!.20}
{$ENDIF}                                    {!!.20}

{$I OPDEFINE.INC}

{*********************************************************}
{*                  OPENHKBD.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpEnhKbd;
  {-Enhanced keyboard routines}

interface

uses
  Dos,                                                                 {!!.20}
  Dpmi;                                                                {!!.20}

const
  EnableEnhanced : Boolean = True; {Set false to temporarily disable handlers}
var
  HasEnhancedKbd : Boolean;  {True when enhanced keyboard is detected}
  FiltersEnhanced : Boolean; {!!.01}{True when keyboard BIOS filters enhanced keys}

procedure RestoreKbdVectors;
  {-Restores original vectors for INT's $09 and $16}

procedure InitKbdVectors;
  {-Save and setup interrupt vectors. This routine should be called only if
    RestoreKbdVectors has been called first}

  {=========================================================================}

implementation

var
  SaveExit   : Pointer;
  PrevInt09  : Pointer;                            {!!.20}
  PrevInt16  : Pointer;                            {!!.20}

const
  Restored  : Boolean = True;

  {$L OPENHKBD.OBJ}

  procedure NewInt09; external;
  procedure EnhInt09; external;                     {!!.20}
  procedure NewInt16; external;
  function EnhancedKbd : Boolean; external;
  function FiltersEnhancedKeys : Boolean; external; {!!.01}

  {$F+}
  procedure FixOldBios; external; {!!.02}

  procedure ExitHandler;
    {-Deactive interrupt handlers}
  begin
    ExitProc := SaveExit;
    RestoreKbdVectors;
  end;
  {$F-}

  procedure InitKbdVectors;
    {-Enable keyboard handling}  {!!.20 - converted from ASM}
  var
    W : Word;
  begin
    Restored := False;
    GetIntVec($09, PrevInt09);
    GetIntVec($16, PrevInt16);
    if EnhancedKbd then
      SetIntVec($09, @EnhInt09)
    else
      SetIntVec($09, @NewInt09);
    SetIntVec($16, @NewInt16);
  end;

  procedure RestoreKbdVectors;
    {-Disable keyboard handling}  {!!.20 - converted from ASM}
  begin
    if Restored then exit;
    SetIntVec($09, PrevInt09);
    SetIntVec($16, PrevInt16);
    Restored := True;
  end;

begin
  {Correct invalid BufferStart and BufferEnd for old BIOS chips that
   don't initialize them}
  FixOldBios; {!!.02}

  {See if enhanced keyboard BIOS installed}
  HasEnhancedKbd := EnhancedKbd;

  {See if the keyboard BIOS will try to filter out the keys we add}
  FiltersEnhanced := FiltersEnhancedKeys; {!!.01}

  {Initialize interrupt vectors}
  InitKbdVectors;

  {Install exit handler}
  SaveExit := ExitProc;
  ExitProc := @ExitHandler;
end.
