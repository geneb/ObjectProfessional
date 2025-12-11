{$S-,R-,V-,I-,B-,F+,O-,A-}

{$IFDEF Dpmi}                               {!!.20}
  {$C FIXED PRELOAD PERMANENT}              {!!.20}
{$ENDIF}                                    {!!.20}

{$I OPDEFINE.INC}

{*********************************************************}
{*                  OPSTRDEV.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OPStrDev;
  {-Routines for reading and writing strings}

interface

var
  TPStr : Text;

procedure ReadStr(var S : string);
  {-'Read' a string into S from our string buffer}

function ReturnStr : string;
  {-Return the contents of our string buffer}

  {==========================================================================}

implementation

type
  {text buffer}
  TextBuffer = array[0..65520] of Byte;

  {structure of a Turbo File Interface Block}
  FIB =
    record
      Handle : Word;
      Mode : Word;
      BufSize : Word;
      Private : Word;
      BufPos : Word;
      BufEnd : Word;
      BufPtr : ^TextBuffer;
      OpenProc : Pointer;
      InOutProc : Pointer;
      FlushProc : Pointer;
      CloseProc : Pointer;
      UserData : array[1..16] of Byte;
      Name : array[0..79] of Char;
      Buffer : array[0..127] of Char;
    end;
const
  FMClosed = $D7B0;
var
  StrBuf : string;
  StrLen : Byte absolute StrBuf;

  procedure ReadStr(var S : string);
    {-'Read' a string into S from our string buffer}
  begin
    S := StrBuf;
    StrLen := 0;
    with FIB(TPStr) do
      BufPos := 0;
  end;

  function ReturnStr : string;
    {-Return the contents of our string buffer}
  begin
    ReturnStr := StrBuf;
    StrLen := 0;
    with FIB(TPStr) do
      BufPos := 0;
  end;

  function StrOut(var F : FIB) : Word;
    {-Update the length byte of StrBuf}
  begin
    {update the length byte}
    with F do
      StrLen := BufPos;

    {return success flag}
    StrOut := 0;
  end;

  function StrZero(var F : FIB) : Word;
    {-Return success flag, but do nothing}
  begin
    StrZero := 0;
  end;

  procedure AssignStr(var F : Text);
    {-Initialize the File Interface Block}
  begin
    with FIB(F) do begin
      Mode := FMClosed;
      OpenProc := @StrZero;
      FlushProc := @StrOut;
      CloseProc := @StrZero;
      InOutProc := @StrOut;
      BufEnd := 0;
      BufPos := 0;
      BufPtr := @StrBuf[1];
      BufSize := 255;
      Name[0] := #0;
    end;

    {start with an empty string buffer}
    StrLen := 0;
  end;

begin
  AssignStr(TPStr);
  Rewrite(TPStr);
end.
