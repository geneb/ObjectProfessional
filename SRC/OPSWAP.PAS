{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$IFDEF Dpmi}                                                         {!!.20}
  !! This unit cannot be used in protected mode !!                    {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                    OPSWAP.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1989, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpSwap;

interface

var
  SaveInt05 : Pointer;

{.Z+}
function SwapOut : Boolean;

procedure CSRelData;
  {-not a procedure, just a label used by OpSwap1}

function Intercom(Func : Byte) : Pointer;
  {-Routine used to get information from OpSwap1 about code segment}
{.Z-}

procedure SetPopTicker(TimeOut : Word);
  {-Sets the pop ticker for the CmdEntry procedure, clears interrupts,
    then returns.}

{$IFDEF SupportXms}        {!!.02}
procedure UsingXms;
{$ELSE}
procedure NotUsingXms;
{$ENDIF}

  {==========================================================================}

implementation

uses
  OpSwap1;

  {$L OPSWAP.OBJ}
  function SwapOut : Boolean; external;
  (* procedure FirstToSave; external; !!.02 *)
  procedure SwapProgIn; external;
  procedure SwapProgOut; external;

  {$F+}
  procedure CSRelData; external;       {not a procedure, just a label}
  function Intercom(Func : Byte) : Pointer; external;
  procedure SwappedFlag; external;
  procedure SwappedOutFlag; external;

  {see OPSWAPI.ASM for documentation}
  procedure Int9; external;
  procedure Int28; external;
  procedure Int8; external;
  procedure Int5; external;
  procedure Int10; external;
  procedure Int13; external;
  procedure Int14; external;
  procedure Int16; external;
  procedure Int17; external;
  procedure Int25; external;
  procedure Int26; external;
  procedure NopISR; external;

  procedure InitCSPops; external;
  {$IFDEF SupportXms}
  procedure UsingXms; external;
  {$ELSE}
  procedure NotUsingXms; external;
  {$ENDIF}

  {$F+}
  procedure SetPopTicker(TimeOut : Word);
  begin
    with CSSwapDataPtr(@CSRelData)^ do begin
      if PopupsEnabled then begin
        if not PopupInUse[CmdEntryHandle] then begin
          InterruptsOff;
          PopupInUse[CmdEntryHandle] := True;
          PopupToCall := CmdEntryHandle;
          PopTicker := TimeOut;
        end;
      end;
    end;
  end;
  {$F-}

begin
  {prepare for popups}
  CSSwapData  := @CSRelData;
  IntercomPtr := Intercom;
  InitCSPops;
  InitCSSwapData;
end.
