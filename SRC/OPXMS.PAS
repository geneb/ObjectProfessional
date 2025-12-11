
{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$IFDEF Dpmi}                                                         {!!.20}
  !! This unit cannot be used in protected mode !!                    {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                   OPXMS.PAS 1.30                      *}
{*       Copyright (c) TurboPower Software 1989, 1992.   *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpXms;
  {-XMS memory management routines}

interface

type
  {pointers in XMS are segm:ofs for < 1 meg, and linear for > 1 meg}
  ExtMemPtr      =
    record
      case Boolean of
        False : (RealPtr : Pointer);
        True  : (ProtectedPtr : LongInt);
    end;

  {the record structure used internally by MoveExtMemBlock}
  ExtMemMoveStruct =
    record
      Len        : LongInt;
      SrcHand    : Word;
      SrcOffs    : ExtMemPtr;
      DestHand   : Word;
      DestOffs   : ExtMemPtr;
    end;

var
  XmsControl       : Pointer;          {ptr to XMS control procedure}

const
  FuncNotImplemented   = $80;          {function is not implemented}
  VDiskDeviceDetected  = $81;          {a VDISK compatible device found}
  A20Error             = $82;          {an A20 error occurred}
  GeneralDriverError   = $8E;          {general driver error}
  UnrecoverableError   = $8F;          {unrecoverable driver error}
  HmaDoesNotExist      = $90;          {high memory area does not exist}
  HmaAlreadyInUse      = $91;          {high memory area already in use}
  HmaSizeTooSmall      = $92;          {size requested less than /HMAMIN}
  HmaNotAllocated      = $93;          {high memory area not allocated}
  A20StillEnabled      = $94;          {A20 line is still enabled}
  AllExtMemAllocated   = $A0;          {all extended memory is allocated}
  OutOfExtMemHandles   = $A1;          {extended memory handles exhausted}
  InvalidHandle        = $A2;          {invalid handle}
  InvalidSourceHandle  = $A3;          {invalid source handle}
  InvalidSourceOffset  = $A4;          {invalid source offset}
  InvalidDestHandle    = $A5;          {invalid destination handle}
  InvalidDestOffset    = $A6;          {invalid destination offset}
  InvalidLength        = $A7;          {invalid length}
  OverlapInMoveReq     = $A8;          {overlap in move request}
  ParityErrorDetected  = $A9;          {parity error detected}
  BlockIsNotLocked     = $AA;          {block is not locked}
  BlockIsLocked        = $AB;          {block is locked}
  LockCountOverflowed  = $AC;          {lock count overflowed}
  LockFailed           = $AD;          {lock failed}
  SmallerUMBAvailable  = $B0;          {a smaller upper memory block is avail}
  NoUMBAvailable       = $B1;          {no upper memory blocks are available}
  InvalidUMBSegment    = $B2;          {invalid upper memory block segment}

function XmsInstalled : Boolean;
  {-Returns True if an XMS memory manager is installed}

function RequestHMA(Bytes : Word) : Byte;
  {-Request the High Memory Area (HMA). Bytes is amount of memory if TSR or
    device driver, or $FFFF if application program.

    Possible return codes:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $90 if the HMA does not exist
      $91 if the HMA is already in use
      $92 if Bytes is less than the /HMAMIN= parameter
  }

function ReleaseHMA : Byte;
  {-Release the High Memory Area.

    Possible return codes:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $90 if the HMA does not exist
      $93 if the HMA was not allocated
  }

function GlobalEnableA20 : Byte;
  {-Attempt to enable the A20 line. Should be used only by programs that
    have control of the HMA.

    Possible return codes:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $82 if an A20 error occurs
  }

function GlobalDisableA20 : Byte;
  {-Attempt to enable the A20 line. Should be used only by programs that
    have control of the HMA.

    Possible return codes:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $82 if an A20 error occurs
      $94 if the A20 line is still enabled
  }

function LocalEnableA20 : Byte;
  {-Attempt to enable the A20 line. Should be used only by programs that
    need direct access to extended memory.

    Possible return codes:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $82 if an A20 error occurs
  }

function LocalDisableA20 : Byte;
  {-Attempt to enable the A20 line. Should be used only by programs that
    need direct access to extended memory.

    Possible return codes:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $82 if an A20 error occurs
      $94 if the A20 line is still enabled
  }

function QueryA20 : Byte;
  {-Checks to see if the A20 line is physically enabled.

    Possible return codes:
      $00 A20 line disabled
      $01 A20 line enabled
      $80 if the function is not implemented
      $81 if a VDISK device is detected
  }

function QueryFreeExtMem(var TotalFree, LargestBlock : Word) : Byte;
  {-Return the amount of total free extended memory in TotalFree, and the Size
    of the largest free block of extended memory in LargestBlock. Both values
    are specified in number of kilobytes.

    Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A0 if all extended memory is allocated
  }

function AllocateExtMem(SizeInK : Word; var XmsHandle : Word) : Byte;
  {-Allocate a block of extended memory SizeInK kilobytes in Size, returning
    the XMS handle in XmsHandle.

    Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A0 if all extended memory is allocated
      $A1 if all extended memory handles are in use
  }

function FreeExtMem(XmsHandle : Word) : Byte;
  {-Free a previously allocated block of extended memory. XmsHandle is the XMS
    handle returned by the previous call to AllocateExtMem.

    Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A2 if XmsHandle is invalid
      $AB if XmsHandle is currently locked
  }
function MoveExtMemBlock(BlockLength : LongInt;
                         SourceHandle : Word;
                         SourcePtr : ExtMemPtr;
                         DestHandle : Word;
                         DestPtr : ExtMemPtr) : Byte;
  {-Move a block of memory. Intended primarily for moving data to and from
    extended memory and conventional memory. Can also move memory from
    extended to extended and conventional to conventional. BlockLength must
    always be an even number. Memory areas may overlap ONLY if SourcePtr is at
    a lower address than DestPtr. If SourceHandle is 0, then SourcePtr is
    interpreted as a normal segment:offset dword pointer. If SourceHandle is
    non-zero, then the SourcePtr is interpreted as a 32 bit linear offset into
    the extended memory associated with SourceHandle. The same is true for
    DestHandle and DestPtr. This routine does NOT require that the A20 be
    enabled. Extended memory blocks used as SourcePtr or DestPtr need not be
    locked before calling this routine (although they may be locked).

    Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $82 if an A20 error occurs
      $A3 if SourceHandle is invalid
      $A4 if SourcePtr is invalid
      $A5 if DestHandle is invalid
      $A6 if DestPtr is invalid
      $A7 if BlockLen is invalid
      $A8 if SourcePtr and DestPtr contain an invalid overlap
      $A9 if a memory parity error occurs
  }

function LockExtMemBlock(XmsHandle : Word;
                         var LockedBlock : ExtMemPtr) : Byte;
  {-Locks an extended memory block and returns its base address as a 32 bit
    linear address. Locked extended memory blocks are guaranteed not to move.
    The LockedBlock address is valid only while the block is locked. Locked
    extended memory blocks should be unlocked as quickly as possible. It is
    not necessary to lock a block before calling MoveExtMemBlock. A count of
    the number of locks is maintained by the XMS memory manager and can be
    retrieved with the GetHandleInfo function.

    Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A2 if XmsHandle is invalid
      $AC if the block's lock count overflows
      $AD if the lock fails
  }

function UnlockExtMemBlock(XmsHandle : Word) : Byte;
  {-Unlocks an extended memory block. Any 32 bit linear addresses in use
    obtained by calling LockExtMemBlock are invalid after UnlockExtMemBlock is
    called.

    Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A2 if XmsHandle is invalid
      $AC if the block's lock count overflows
      $AA if the block is not locked
  }

function GetHandleInfo(XmsHandle : Word;
                       var LockCount    : Byte;
                       var HandlesLeft  : Byte;
                       var BlockSizeInK : Word) : Byte;
  {-Return information about an extended memory handle. The lock count for
    this handle, the number of XMS handles left, and the Size in kilobytes of
    this handle are returned. To retrieve the 32 bit linear address of this
    handle, you must call LockExtMemBlock.

  Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A2 if XmsHandle is invalid
  }

function ResizeExtMemBlock(XmsHandle : Word; NewSizeInK : Word) : Byte;
  {-Attempts to resize the memory block associated with XmsHandle. The
    extended memory block must be unlocked. If the NewSizeInK is bigger than
    the previous Size, then all data is preserved. If it is smaller, then all
    data beyond the end of the new block Size is lost.

  Possible function results:
      $00 successful
      $80 if the function is not implemented
      $81 if a VDISK device is detected
      $A0 if all extended memory is allocated
      $A1 if all extended memory handles are in use
      $A2 if XmsHandle is invalid
      $AB if the block is locked
  }

function AllocUpperMemBlock(SizeInParas : Word;
                            var SegmentBase : Word;
                            var Size        : Word) : Byte;
  {-Allocates an upper memory block (UMB). If insufficient memory is available
    in upper memory blocks, then the Size of the largest free upper memory
    block is returned in Size. If this functions succeeds, then SegmentBase
    contains the segment of the allocated upper memory block. Upper memory
    blocks are paragraphed aligned (the offset is always 0).

    By definition, UMBs are located below the 1 meg address boundary.
    Therefore the A20 line need not be enabled to access the memory in a UMB.
    Therefore there are no restrictions on using this memory in DOS calls or
    pointing ISRs into this memory.

    This function is not implemented by most 286 XMS drivers. It is
    implemented by most 386 products like QEMM and 386^MAX.

  Possible function results:
      $00 successful
      $80 if the function is not implemented
      $B0 if a smaller UMB is available
      $B1 if no UMBs are available
  }

function FreeUpperMemBlock(SegmentBase : Word) : Byte;
  {-Frees a previously allocated upper memory block.

  Possible function results:
      $00 successful
      $80 if the function is not implemented
      $82 if SegmentBase does not refer to a valid UMB
  }

function XmsErrorString(ErrorCode : Byte) : String;
  {-Return a string indicating reason for error}

  {==========================================================================}

implementation

  function XmsInstalledPrim : Boolean;
    {-Returns True if an XMS memory manager is installed}
  inline(
    $B8/$00/$43/     {   MOV     AX,$4300           ; XMS Installed function}
    $CD/$2F/         {   INT     $2F                ; DOS Multiplex int}
    $3C/$80/         {   CMP     AL,$80             ; is it there?}
    $75/$04/         {   JNE     NoXmsDriver}
    $B0/$01/         {   MOV     AL,1               ; return True}
    $EB/$02/         {   JMP     SHORT XIExit}
                     {NoXmsDriver:}
    $30/$C0);        {   XOR     AL,AL              ; return False}
                     {XIExit:}

  function XmsInstalled : Boolean;
    {-Returns True if an XMS memory manager is installed}
  begin
    XmsInstalled := XmsControl <> Nil;
  end;

  function RequestHMAPrim(Bytes : Word) : Byte;
  inline(
    $5A/                   {  POP      DX      ; get Bytes}
    $B4/$01/               {  MOV      AH,1    ; XMS function 1 - Request HMA}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $09/$C0/               {  OR       AX,AX}
    $74/$04/               {  JZ       Error}
    $30/$C0/               {  XOR      AL,AL}
    $EB/$02/               {  JMP      SHORT ExitPoint}
                           {Error:}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function RequestHMA(Bytes : Word) : Byte;
    {-Request the High Memory Area (HMA). Bytes is amount of memory if TSR or
      device driver, or $FFFF if application program.

      Possible return codes:
        $00 successful
        $80 if the function is not implemented
        $81 if a VDISK device is detected
        $90 if the HMA does not exist
        $91 if the HMA is already in use
        $92 if Bytes is less than the /HMAMIN= parameter
    }
  begin
    RequestHMA := RequestHMAPrim(Bytes)
  end;

  function ReleaseHMAPrim : Byte;
  inline(
    $B4/$02/               {  MOV      AH,2    ; XMS function 2 - Release HMA}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $09/$C0/               {  OR       AX,AX}
    $74/$04/               {  JZ       Error}
    $30/$C0/               {  XOR      AL,AL}
    $EB/$02/               {  JMP      SHORT ExitPoint}
                           {Error:}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function ReleaseHMA : Byte;
    {-Release the High Memory Area.

      Possible return codes:
        $00 successful
        $80 if the function is not implemented
        $81 if a VDISK device is detected
        $90 if the HMA does not exist
        $93 if the HMA was not allocated
    }
  begin
    ReleaseHMA := ReleaseHMAPrim;
  end;

  function GlobalEnableA20Prim : Byte;
  inline(
    $B4/$03/               {  MOV AH,3      ; XMS function 3 - Global Enable A20}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $09/$C0/               {  OR       AX,AX}
    $74/$04/               {  JZ       Error}
    $30/$C0/               {  XOR      AL,AL}
    $EB/$02/               {  JMP      SHORT ExitPoint}
                           {Error:}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function GlobalEnableA20 : Byte;
    {-Attempt to enable the A20 line. Should be used only by programs that
      have control of the HMA.

      Possible return codes:
        $00 successful
        $80 if the function is not implemented
        $81 if a VDISK device is detected
        $82 if an A20 error occurs
    }
  begin
    GlobalEnableA20 := GlobalEnableA20Prim;
  end;

  function GlobalDisableA20Prim : Byte;
  inline(
    $B4/$04/               {  MOV AH,4      ; XMS function 4 - Global Disable A20}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $09/$C0/               {  OR       AX,AX}
    $74/$04/               {  JZ       Error}
    $30/$C0/               {  XOR      AL,AL}
    $EB/$02/               {  JMP      SHORT ExitPoint}
                           {Error:}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function GlobalDisableA20 : Byte;
    {-Attempt to enable the A20 line. Should be used only by programs that
      have control of the HMA.

      Possible return codes:
        $00 successful
        $80 if the function is not implemented
        $81 if a VDISK device is detected
        $82 if an A20 error occurs
        $94 if the A20 line is still enabled
    }
  begin
    GlobalDisableA20 := GlobalDisableA20Prim;
  end;

  function LocalEnableA20Prim : Byte;
  inline(
    $B4/$05/               {  MOV AH,5      ; XMS function 3 - Local Enable A20}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $09/$C0/               {  OR       AX,AX}
    $74/$04/               {  JZ       Error}
    $30/$C0/               {  XOR      AL,AL}
    $EB/$02/               {  JMP      SHORT ExitPoint}
                           {Error:}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function LocalEnableA20 : Byte;
    {-Attempt to enable the A20 line. Should be used only by programs that
      need direct access to extended memory.

      Possible return codes:
        $00 successful
        $80 if the function is not implemented
        $81 if a VDISK device is detected
        $82 if an A20 error occurs
    }
  begin
    LocalEnableA20 := LocalEnableA20Prim;
  end;

  function LocalDisableA20Prim : Byte;
  inline(
    $B4/$06/               { MOV AH,6 ;XMS function 6 - Local Disable A20 !!.03}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $09/$C0/               {  OR       AX,AX}
    $74/$04/               {  JZ       Error}
    $30/$C0/               {  XOR      AL,AL}
    $EB/$02/               {  JMP      SHORT ExitPoint}
                           {Error:}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function LocalDisableA20 : Byte;
    {-Attempt to enable the A20 line. Should be used only by programs that
      need direct access to extended memory.

      Possible return codes:
        $00 successful
        $80 if the function is not implemented
        $81 if a VDISK device is detected
        $82 if an A20 error occurs
        $94 if the A20 line is still enabled
    }
  begin
    LocalDisableA20 := LocalDisableA20Prim;
  end;

  function QueryA20Prim : Byte;
  inline(
    $B4/$07/               {  MOV      AH,7 ; XMS Function 7 - Query A20 !!.03}
    $FF/$1E/>XmsControl/   {  CALL     DWORD PTR [>XmsControl]}
    $08/$DB/               {  OR       BL,BL}
    $74/$02/               {  JZ       ExitPoint}
    $88/$D8);              {  MOV      AL,BL}
                           {ExitPoint:}

  function QueryA20 : Byte;
    {-Checks to see if the A20 line is physically enabled.

      Possible return codes:
        $00 A20 line disabled
        $01 A20 line enabled
        $80 if the function is not implemented
        $81 if a VDISK device is detected
    }
  begin
    QueryA20 := QueryA20Prim;
  end;

  function QueryFreeExtMem(var TotalFree, LargestBlock : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$08/               {  MOV    AH,$08   ;XMS function 08h - Query Free ext memory}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $09/$C0/               {  OR     AX,AX}
      $74/$10/               {  JZ     SetError}
      $30/$DB/               {  XOR    BL,BL}
      $C4/$BE/>TotalFree/    {  LES    DI,>TotalFree[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV    [DI],DX}
      $C4/$BE/>LargestBlock/ {  LES    DI,>LargestBlock[BP]}
      $26/                   {ES:}
      $89/$05/               {  MOV    [DI],AX}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    QueryFreeExtMem := ErrorCode;
  end;

  function AllocateExtMem(SizeInK : Word; var XmsHandle : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$09/               {  MOV    AH,$09   ;XMS function 09h - Alloc ext memory block}
      $8B/$96/>SizeInK/      {  MOV    DX,>SizeInK[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$09/               {  JZ     SetError}
      $30/$DB/               {  XOR    BL,BL}
      $C4/$BE/>XmsHandle/    {  LES    DI,>XmsHandle[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV    [DI],DX  ;return XMS handle}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    AllocateExtMem := ErrorCode;
  end;

  function FreeExtMem(XmsHandle : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$0A/               {  MOV    AH,$0A   ;XMS function 0Ah - Free ext memory block}
      $8B/$96/>XmsHandle/    {  MOV    DX,>XmsHandle[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$02/               {  JZ     SetError}
      $30/$DB/               {  XOR    BL,BL}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    FreeExtMem := ErrorCode;
  end;

  function MoveExtMemBlockPrim(ParamBlock : Pointer) : Byte;
    {-Call XMS function $0B to move extended memory}
  inline(
    $8C/$D8/               {  MOV    AX,DS}
    $8E/$C0/               {  MOV    ES,AX}
    $5E/                   {  POP    SI}
    $1F/                   {  POP    DS}
    $50/                   {  PUSH   AX}
    $B4/$0B/               {  MOV    AH,$0B   ;XMS function 0Bh - Move Extended}
    $26/                   {ES:}
    $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
    $1F/                   {  POP    DS}
    $A9/$01/$00/           {  TEST   AX,1}
    $75/$04/               {  JNZ    Success}
    $88/$D8/               {  MOV    AL,BL}
    $EB/$02/               {  JMP    SHORT ExitPoint}
                           {Success:}
    $30/$C0);              {  XOR    AL,AL}
                           {ExitPoint:}


  function MoveExtMemBlock(BlockLength : LongInt;
                           SourceHandle : Word;
                           SourcePtr : ExtMemPtr;
                           DestHandle : Word;
                           DestPtr : ExtMemPtr) : Byte;
  var
    ControlBlock : ExtMemMoveStruct;
  begin
    with ControlBlock do begin
      Len := BlockLength;
      SrcHand   := SourceHandle;
      SrcOffs   := SourcePtr;
      DestHand  := DestHandle;
      DestOffs  := DestPtr;
      MoveExtMemBlock := MoveExtMemBlockPrim(@ControlBlock);
    end;
  end;

  function LockExtMemBlock(XmsHandle : Word;
                           var LockedBlock : ExtMemPtr) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$0C/               {  MOV    AH,$0C   ;XMS function 0Ch - Lock ext memory block}
      $8B/$96/>XmsHandle/    {  MOV    DX,>XmsHandle[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$0D/               {  JZ     SetError}
      $C4/$BE/>LockedBlock/  {  LES    DI,>LockedBlock[BP]}
      $26/                   {ES:}
      $89/$1D/               {  MOV    [DI],BX}
      $26/                   {ES:}
      $89/$55/$02/           {  MOV    [DI+2],DX}
      $30/$DB/               {  XOR    BL,BL}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    LockExtMemBlock := ErrorCode;
  end;

  function UnlockExtMemBlock(XmsHandle : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$0D/               {  MOV    AH,$0D   ;XMS function 0Dh - Unlock ext memory block}
      $8B/$96/>XmsHandle/    {  MOV    DX,>XmsHandle[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$02/               {  JZ     SetError}
      $30/$DB/               {  XOR    BL,BL}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    UnlockExtMemBlock := ErrorCode;
  end;

  function GetHandleInfo(XmsHandle : Word;
                         var LockCount    : Byte;
                         var HandlesLeft  : Byte;
                         var BlockSizeInK : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$0E/               {  MOV    AH,$0E   ;XMS function 0Eh - Get EMB Handle Info}
      $8B/$96/>XmsHandle/    {  MOV    DX,>XmsHandle[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$17/               {  JZ     SetError}
      $C4/$BE/>LockCount/    {  LES    DI,>LockCount[BP]}
      $26/                   {ES:}
      $88/$3D/               {  MOV    BYTE PTR [DI],BH}
      $C4/$BE/>HandlesLeft/  {  LES    DI,>HandlesLeft[BP]}
      $26/                   {ES:}
      $88/$1D/               {  MOV    BYTE PTR [DI],BL}
      $C4/$BE/>BlockSizeInK/ {  LES    DI,>BlockSizeInK[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV    [DI],DX}
      $30/$DB/               {  XOR    BL,BL}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    GetHandleInfo := ErrorCode;
  end;

  function ResizeExtMemBlock(XmsHandle : Word; NewSizeInK : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$0F/               {  MOV    AH,$0F   ;XMS function 0Fh - Resize Ext mem block}
      $8B/$96/>XmsHandle/    {  MOV    DX,>XmsHandle[BP]}
      $8B/$9E/>NewSizeInK/   {  MOV    BX,>NewSizeInK[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$02/               {  JZ     SetError}
      $30/$DB/               {  XOR    BL,BL}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    ResizeExtMemBlock := ErrorCode;
  end;

  function AllocUpperMemBlock(SizeInParas : Word;
                              var SegmentBase : Word;
                              var Size        : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$10/               {  MOV    AH,$10   ;XMS function 10h - Alloc UMB}
      $8B/$96/>SizeInParas/  {  MOV    DX,>SizeInParas[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$12/               {  JZ     Error}
      $C4/$BE/>Size/         {  LES    DI,>Size[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV    [DI],DX        ;return actual Size}
      $C4/$BE/>SegmentBase/  {  LES    DI,>SegmentBase[BP]}
      $26/                   {ES:}
      $89/$1D/               {  MOV    [DI],BX        ;return segment base}
      $30/$DB/               {  XOR    BL,BL}
      $EB/$07/               {  JMP    SHORT SetError}
                             {Error:}
      $C4/$BE/>Size/         {  LES    DI,>Size[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV    [DI],DX        ;return largest avail block}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    AllocUpperMemBlock := ErrorCode;
  end;

  function FreeUpperMemBlock(SegmentBase : Word) : Byte;
  var
    ErrorCode : Byte;
  begin
    inline(
      $B4/$11/               {  MOV    AH,$11   ;XMS function 11h - Free UMB}
      $8B/$96/>SegmentBase/  {  MOV    DX,>SegmentBase[BP]}
      $FF/$1E/>XmsControl/   {  CALL   DWORD PTR [>XmsControl]}
      $A9/$01/$00/           {  TEST   AX,1}
      $74/$02/               {  JZ     SetError}
      $30/$DB/               {  XOR    BL,BL}
                             {SetError:}
      $88/$5E/<ErrorCode);   {  MOV    <ErrorCode[BP],BL}
    FreeUpperMemBlock := ErrorCode;
  end;

  function HexB(B : Byte) : string;
    {-Return hex string for byte}
  const
    Digits : array[0..$F] of Char = '0123456789ABCDEF';
  begin
    HexB[0] := #2;
    HexB[1] := Digits[B shr 4];
    HexB[2] := Digits[B and $F];
  end;

  function XmsErrorString(ErrorCode : Byte) : String;
    {-Return a string indicating reason for error}
  begin
    case ErrorCode of
      $00 :
        XmsErrorString := 'no XMS error';
      FuncNotImplemented :
        XmsErrorString := 'function not implemented';
      VDiskDeviceDetected :
        XmsErrorString := 'VDISK compatible device detected';
      A20Error :
        XmsErrorString := 'an A20 error occurred';
      GeneralDriverError :
        XmsErrorString := 'general driver error';
      UnrecoverableError :
        XmsErrorString := 'unrecoverable driver error';
      HmaDoesNotExist :
        XmsErrorString := 'high memory area does not exist';
      HmaAlreadyInUse :
        XmsErrorString := 'high memory area already in use';
      HmaSizeTooSmall :
        XmsErrorString := 'size requested less than /HMAMIN= parameter';
      HmaNotAllocated :
        XmsErrorString := 'high memory area not allocated';
      A20StillEnabled :
        XmsErrorString := 'A20 line is still enabled';
      AllExtMemAllocated :
        XmsErrorString := 'all extended memory is allocated';
      OutOfExtMemHandles :
        XmsErrorString := 'extended memory handles exhausted';
      InvalidHandle :
        XmsErrorString := 'invalid handle';
      InvalidSourceHandle :
        XmsErrorString := 'invalid source handle';
      InvalidSourceOffset :
        XmsErrorString := 'invalid source offset';
      InvalidDestHandle :
        XmsErrorString := 'invalid destination handle';
      InvalidDestOffset :
        XmsErrorString := 'invalid destination offset';
      InvalidLength :
        XmsErrorString := 'invalid length';
      OverlapInMoveReq :
        XmsErrorString := 'overlap in move request';
      ParityErrorDetected :
        XmsErrorString := 'parity error detected';
      BlockIsNotLocked :
        XmsErrorString := 'block is not locked';
      BlockIsLocked :
        XmsErrorString := 'block is locked';
      LockCountOverflowed :
        XmsErrorString := 'lock count overflowed';
      LockFailed :
        XmsErrorString := 'lock failed';
      SmallerUMBAvailable :
        XmsErrorString := 'a smaller upper memory block is available';
      NoUMBAvailable :
        XmsErrorString := 'no upper memory blocks are available';
      InvalidUMBSegment :
        XmsErrorString := 'invalid upper memory block segment';
      else
        XmsErrorString := 'unknown XMS error = $' + HexB(ErrorCode);
    end;
  end;

  function XmsControlAddr : Pointer;
    {-Return address of XMS control function}
  inline(
    $B8/$10/$43/     {MOV     AX,$4310           ; XMS control func addr}
    $CD/$2F/         {INT     $2F}
    $89/$D8/         {MOV     AX,BX              ; ptr in ES:BX to DX:AX}
    $8C/$C2);        {MOV     DX,ES}

  function DosVersion : Word;                    {added !!.12}
    inline(
      $B4/$30/                 {mov ah,$30}
      $CD/$21);                {int $21}

begin
  if Lo(DosVersion) >= 3 then begin               {!!.12}
    if XmsInstalledPrim then
      XmsControl := XmsControlAddr
    else
      XmsControl := Nil;
  end
  else                                            {!!.12}
    XmsControl := Nil;                            {!!.12}
end.
