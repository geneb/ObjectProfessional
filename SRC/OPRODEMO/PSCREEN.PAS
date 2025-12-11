{$IFDEF Windows}  {!!.20}
  !! This program is not compatible with Windows !!
{$ENDIF}

{$IFDEF Dpmi}     {!!.20}
  !! This program is not compatible with Protected Mode !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{$M 4096,0,20000}

{*********************************************************}
{*                  PSCREEN.PAS 1.30                     *}
{*    An example program for Object Professional 1.0     *}
{*     Copyright (c) TurboPower Software 1987,1992.      *}
{*                 All rights reserved.                  *}
{*********************************************************}

program PackedScreenUtility;
  {-Utility for saving and displaying packed windows}

uses
  PSMain, OpSwap;

begin
  InitializePScreen;
end.
