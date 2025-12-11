{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                    OPEXEC.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1988, 1992.     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpExec;
  {-Dos shell with swapping to Ems or disk}

{Special thanks to Chris Franzen of O.K.SOFT Software, West Germany,
 who added the swap-to-disk capability to our EMSEXEC unit}

interface

uses
  Dos
  {$IFNDEF Dpmi}                      {!!.20}
  {$IFDEF SupportXms}                 {!!.03}
  , OpXms                             {!!.03}
  {$ENDIF}                            {!!.03}
  {$ENDIF}                            {!!.20}
  ;

const
  ExecSaveScreen    = 0;
  ExecShowMemory    = 1;    {!!.20-This portion not used in protected mode}
  ExecPauseAfterRun = 2;
  ExecRestoreScreen = 3;
type
  ActionCodeType = ExecSaveScreen..ExecRestoreScreen;

{$IFNDEF Dpmi}                                                    {begin !!.20}
const
  UseEmsIfAvailable : Boolean = True;
  NoSwapMsgForEms   : Boolean = True;
  AllowRemovable    : Boolean = False; {!!.02}
  HideSwapFile      : Boolean = True;  {!!.02}
  {$IFDEF SupportXms}
  UseXmsIfAvailable : Boolean = False; {!!.03}
  UseEmsOverXms     : Boolean = True;  {!!.03}
  {$ENDIF}

var
  NoOfBytesSwapped : LongInt;     {Bytes to swap to EMS/disk}
  EmsAllocated : Boolean;         {True when EMS allocated for swap}
  SwapFileAllocated : Boolean;    {True when file allocated for swap}
  XmsAllocated : Boolean;         {True when XMS allocated for swap} {!!.03}

procedure SetSwapMsgOn(On : Boolean);
  {-Turns Swap message on or off}

procedure ExecWithSwap(Path, CmdLine : String);
  {-DOS shell with swapping to EMS, XMS or disk}

function PrepareExecWithSwap(LastToSave : Pointer;
                             SwapFileName : PathStr) : Boolean;
  {-Set up for a shell with swapping, returning true if successful}

procedure RemoveExecWithSwap;
  {-Deallocate EMS space or erase swap file, whichever was allocated}
{$ENDIF}                                                          {end   !!.20}

function ExecDosSwap(Command : string;
                     UseSecond : Boolean;
                     EDP : Pointer;
                     SwapFName : PathStr) : Integer;
 {-Execute any DOS command. Call with Command = '' for a new shell.
   If UseSecond is false, Command must be the full pathname of a program to
   be executed. EDP is a pointer to a routine to save/restore the screen, etc.
   SwapFName is the name of the swap file to use. ExecDosSwap return codes are
   as follows:

       0 : Success
      -1 : Insufficient memory to store free list
      -5 : Unable to allocate EMS or open swap file
      else a DOS error code
  }

  {---------------------------------------------------------------}
  {Following routines are interfaced for other general purpose use}

{$IFNDEF Dpmi}                                                    {begin !!.20}
{.Z+}
function EmsInstalled : Boolean;
  {-Return true if EMS driver installed}

function EmsPageFrame : Word;
  {-Returns the page frame base segment}

function AllocateEmsPages(NumPages : Word) : Word;
  {-Allocate the indicated number of pages and returns a handle}

procedure DeallocateEmsHandle(Handle : Word);
  {-Deallocate the memory associated with the indicated handle}
{.Z-}
{$ENDIF}                                                          {end   !!.20}

  {==================================================================}

implementation

{$IFNDEF Dpmi}                                                    {begin !!.20}
const
  EmsPageSize = 16384;
var
  EmsHandle : Word;
  FrameSeg : Word;

const
  SwapFileAttr = 6;               {Swap file attribute; hidden+system bits set}
var
  SwapFileHandle : Word;
  SwapName : String[80];          {Name of file opened for swapping}
  SaveExit : Pointer;
{$ENDIF}                                                          {end   !!.20}

type
  ExecDosProc = procedure(ActionCode : ActionCodeType; Param : Word);

{$IFNDEF Dpmi}                                                    {begin !!.20}
type
  DiskClass = (
    Floppy360, Floppy720, Floppy12, Floppy144, OtherFloppy, Bernoulli,
    HardDisk, RamDisk, SubstDrive, UnknownDisk, InvalidDrive,
    NovellDrive, CDRomDisk); {!!.13}{!!.20}

  {$L OPEXEC.OBJ}
  procedure SetSwapMsgOn(On : Boolean); external;
  {-Turns Swap message on or off}
  procedure ExecWithSwap(Path, CmdLine : String); external;
  {-DOS shell with swapping to EMS or disk}
  procedure FirstToSave; external;
  {-Marks start of region saved to EMS or disk}
  function PtrDiff(H, L : Pointer) : LongInt; external;
  {-Return the number of bytes between H^ and L^. H is the higher address}
  function EmsInstalled : Boolean; external;
  {-Return true if EMS driver installed}
  function EmsPageFrame : Word; external;
  {-Returns the page frame base segment}
  function AllocateEmsPages(NumPages : Word) : Word; external;
  {-Allocates the indicated number of pages and returns a handle}
  procedure DeallocateEmsHandle(Handle : Word); external;
  {-Deallocates the indicated handle and the memory associated with it}
  {$IFDEF SupportXms}                                 {!!.10}
  procedure XmsSupport; External;                     {!!.10}
  {$ELSE}                                             {!!.03} {!!.10}
  procedure NoXmsSupport; External;                   {!!.03}
  {$ENDIF}                                            {!!.03}

  procedure DeallocateFileHandle(FileHandle : Word);
    {-Close, unhide, and erase the swap file}
  var
    Regs : Registers;
  begin
    with Regs do begin
      AH := $3E;                  {DOS close file handle func#}
      BX := FileHandle;
      MsDos(Regs);                {Errors ignored here}
      AH := $43;                  {DOS get/set file attr func#}
      AL := 1;                    {Set attr}
      CX := 0;                    {Reset all attributes}
      DS := Seg(SwapName);
      DX := Ofs(SwapName[1]);
      MsDos(Regs);
      AH := $41;                  {DOS delete file func#}
      MsDos(Regs);                {Errors ignored here}
    end;
  end;

  procedure RemoveExecWithSwap;
    {-Deallocate EMS space or swap file, whichever was allocated}
  begin
    if EmsAllocated then begin
      DeallocateEmsHandle(EmsHandle);
      EmsAllocated := False;
    end
    {$IFDEF SupportXms}                       {!!.03}
    else if XmsAllocated then begin           {!!.03}
      if FreeExtMem(EmsHandle) = 0 then       {!!.03}
        XmsAllocated := False;                {!!.03}
    end                                       {!!.03}
    {$ENDIF}                                  {!!.03}
    else if SwapFileAllocated then begin
      DeallocateFileHandle(SwapFileHandle);
      SwapFileAllocated := False;
    end;
  end;

  function DosVersion : Word;  {!!.02}
    {-Returns the DOS version number. High byte has major version number,
      low byte has minor version number. Eg., DOS 3.1 => $0301.}
    inline(
      $B4/$30/                 {mov ah,$30}
      $CD/$21/                 {int $21}
      $86/$C4);                {xchg ah,al}

  function AllocateSwapFile(var FileHandle : Word) : Boolean;
    {-Create and hide the swap file}
  var
    Regs : Registers;
  begin
    AllocateSwapFile := False;
    with Regs do begin
      AH := $43;                  {DOS get/set file attribute func#}
      AL := 1;                    {Set attr}
      CX := 0;                    {Reset all attributes}
      DS := Seg(SwapName);
      DX := Ofs(SwapName[1]);
      MsDos(Regs);                {Errors are OK}

      AH := $3C;                  {DOS create file handle with overwrite func#}
      if HideSwapFile then        {!!.02}
        CX := SwapFileAttr        {DS,DX still set}
      else                        {!!.02}
        CX := 0;                  {!!.02}
      MsDos(Regs);
      if Odd(Flags) then
        Exit;

      {!!.03} {Mark the file read/write, deny all, not inherited}
      if DosVersion >= $0300 then begin
        BX := AX;                   {Get file handle}
        AH := $3E;                  {DOS close file handle func#}
        MsDos(Regs);
        if Odd(Flags) then
          Exit;
        AX := $3D92;                {Open read/write, deny all, not inherited}
        {DS,DX still set}
        MsDos(Regs);
        if Odd(Flags) then
          Exit;
      end;

      FileHandle := AX;
    end;
    AllocateSwapFile := True;
  end;

  function GetDiskClass(Drive : Char; var SubstDriveChar : Char) : DiskClass;
    {-Return the disk class for the drive with the specified letter}
    {-This routine uses two undocumented DOS function ($32 and $52).
      Information about these functions was obtained from Terry Dettmann's DOS
      Programmer's Reference (Que, 1988) and Undocumented DOS (Addison-Wesley,
      1990).}
  type                                {!!.13} {rewritten}
    NovellTable = array[1..32] of Byte;
    DriveParameterBlock =
      record
        DriveNum, DeviceDriverUnit : Byte;
        BytesPerSector : Word;
        SectorsPerCluster, ShiftFactor : Byte;
        BootSectors : Word;
        FatCopies : Byte;
        RootDirEntries, FirstDataSector, HighestCluster : Word;
        case Byte of
          0 : (SectorsPerFat23 : Byte;
               FirstDirSector23 : Word;
               DeviceDriver23 : Pointer;
               MediaDescriptor23 : Byte;
               AccessFlag23 : Byte;
               Next23 : Pointer;
               Reserved23 : LongInt);
          1 : (SectorsPerFat45 : Word;
               FirstDirSector45 : Word;
               DeviceDriver45 : Pointer;
               MediaDescriptor45 : Byte;
               AccessFlag45 : Byte;
               Next45 : Pointer;
               Reserved45 : LongInt);
      end;
  var
    Ver, DN : Byte;
    MediaDescriptor : Byte;
    SectorsPerFat : Word;
    DPBP : ^DriveParameterBlock;
    NTP : ^NovellTable;
    CDRI : Boolean;                       {!!.20 - begin}
    CDRN : Word;
    Regs : Registers;

    function CDRomInstalled : Boolean;
    var
      R : Registers;
    begin
      FillChar(R, SizeOf(R), 0);
      with R do begin
        AX := $1500;
        Intr($2F, R);
        CDRomInstalled := (AX <> $FFFF) and (BX <> 0);          {!!.21}
      end;
    end;

    {!!.21 - Rewritten}
    function IsDriveCDROM(Drive : Char) : Boolean;
    var
      R : Registers;
      D : Word;
    begin
      IsDriveCDROM := False;
      FillChar(R, SizeOf(R), 0);
      with R do begin
        AX := $1500;
        Intr($2F, R);
        {if AX=$FFFF, GRAPHICS.COM interfered with things}
        if AX = $FFFF then
          Exit;
        if BX <> 0 then begin
          D := Ord(Upcase(Drive))-Ord('A');
          IsDriveCDRom := (D >= CX) and (D <= CX+BX-1);
        end;
      end;
    end;                                  {!!.20 - end}

  begin
    {assume failure}
    GetDiskClass := InvalidDrive;

    {assume that this is not a SUBSTituted drive}
    SubstDriveChar := Drive;

    {convert drive letter to drive number}
    Drive := Upcase(Drive);
    case Drive of
      'A'..'Z' : DN := Ord(Drive)-Ord('A');
      else Exit;
    end;

    {check for CDRom driver installed}              {!!.20}
    CDRI := CDRomInstalled;                         {!!.20}

    {get DOS version number}
    Ver := Hi(DosVersion);

    with Regs do begin
      {get pointer to drive parameter block}
      AH := $32;
      DL := DN+1;
      MsDos(Regs);

      if (AL <> $FF) then
        DPBP := Ptr(DS,BX)
      else if (CDRI) and (IsDriveCDRom(Drive)) then begin    {!!.21 - begin}
        GetDiskClass := CDRomDisk;
        Exit;
      end
      else begin
        {see if it's a Novell drive}
        AX := $EF01;
        ES := 0;
        SI := 0;
        MsDos(Regs);
        NTP := Ptr(ES,SI);
        if NTP <> nil then
          if NTP^[DN+1] and $03 <> 0 then
            GetDiskClass := NovellDrive;
        Exit;                                                {!!.21 - end}
      end;

      with DPBP^ do begin
        if (Ver < 4) or (Ver >= 10) then begin               {!!.21}
          MediaDescriptor := MediaDescriptor23;
          SectorsPerFat := SectorsPerFat23;
        end
        else begin
          MediaDescriptor := MediaDescriptor45;
          SectorsPerFat := SectorsPerFat45;
        end;

        {check for SUBSTituted drive}
        if (DriveNum <> DN) then begin
          GetDiskClass := SubstDrive;
          SubstDriveChar := Char(Ord('A')+DriveNum);
        end
        else if (FatCopies = 1) then
          {RAM disks have one copy of File Allocation Table}
          GetDiskClass := RamDisk
        else if (MediaDescriptor = $F8) then
          {MediaDescriptor of $F8 indicates hard disk}
          GetDiskClass := HardDisk
        else if (MediaDescriptor >= $FC) and (SectorsPerFat <> 2) then
          {Bernoulli drives have more than 2 sectors per FAT}
          GetDiskClass := Bernoulli
        else if (MediaDescriptor >= $F9) then
          {media descriptors >= $F9 are for floppy disks}
          case HighestCluster of
             355 : GetDiskClass := Floppy360;
             714,
            1423 : GetDiskClass := Floppy720;
            2372 : GetDiskClass := Floppy12;
            else   GetDiskClass := OtherFloppy;
          end
        else if (MediaDescriptor = $F0) and (HighestCluster = 2848) then
          {it's a 1.44 meg floppy}
          GetDiskClass := Floppy144
        else if (CDRI) and (IsDriveCDRom(Drive)) then              {!!.20}
          {it's a CDRom}                                           {!!.20}
          GetDiskClass := CDRomDisk                                {!!.20}
        else
          {unable to classify disk/drive}
          GetDiskClass := UnknownDisk;
      end;
    end;
  end;

  function IsRemovable(DriveChar : Char) : Boolean;
    {-Return true if specified drive has removable media}
  var
    Class : DiskClass;
    SubstChar : Char;
  begin
    repeat
      Class := GetDiskClass(DriveChar, SubstChar);
      DriveChar := SubstChar;
    until Class <> SubstDrive;
    case Class of
      Floppy360..OtherFloppy : IsRemovable := True;
    else
      {Note: Bernoulli and Unknown drive types treated as non-removable}
      IsRemovable := False;
    end;
  end;

  function DefaultDrive : Char;
    {-Return default drive letter}
  inline(
    $B4/$19/                      {mov ah,$19}
    $CD/$21/                      {int $21}
    $04/$41);                     {add al,$41}

  function WillUseXms(NoBytes : LongInt) : Boolean;       {begin !!.03}
    {-Return True if XMS will be used over EMS}
 {$IFDEF SupportXms}
  var
    Total, Largest, Needed : Word;
  {$ENDIF}
  begin
    {$IFDEF SupportXms}
    if (not UseEmsOverXms) and (XmsControl <> Nil) then begin {!!.10}
      Needed := (NoBytes + 1023) div 1024;
      if QueryFreeExtMem(Total, Largest) = 0 then
        WillUseXms := Largest >= Needed
      else
        WillUseXms := False;
    end
    else
      WillUseXms := False;
    {$ELSE}
    WillUseXms := False;
    {$ENDIF}
  end;                                                    {end !!.03}

  function PrepareExecWithSwap(LastToSave : Pointer;
                               SwapFileName : PathStr) : Boolean;
    {-Set up for a shell with swapping, returning true if successful}
  var
    PagesInEms : Word;
    DriveChar : Char;
    {$IFDEF SupportXms}                             {!!.03}
    TotalXms, LargestXms, XmsNeeded : Word;         {!!.03}
    {$ENDIF}                                        {!!.03}
  begin
    PrepareExecWithSwap := False;
    if EmsAllocated or SwapFileAllocated then
      Exit;

    {$IFDEF SupportXms}                             {!!.03}
    if XmsAllocated then                            {!!.03}
      Exit;                                         {!!.03}
    {$ENDIF}                                        {!!.03}
    NoOfBytesSwapped := PtrDiff(LastToSave, @FirstToSave);
    if NoOfBytesSwapped <= 0 then
      Exit;

    if UseEmsIfAvailable and EmsInstalled and
       (not WillUseXms(NoOfBytesSwapped)) then begin {!!.01}{!!.03}
      FrameSeg := EmsPageFrame;
      if FrameSeg <> 0 then begin
        PagesInEms := Pred(NoOfBytesSwapped+EmsPageSize) div EmsPageSize;
        EmsHandle := AllocateEmsPages(PagesInEms);
        if EmsHandle <> $FFFF then begin
          EmsAllocated := True;
          if NoSwapMsgForEms then
            SetSwapMsgOn(False);
          PrepareExecWithSwap := True;
          Exit;
        end;
      end;
    end;

    {$IFDEF SupportXms}                                     {begin !!.03}
    if UseXmsIfAvailable and XmsInstalled then begin
      XmsNeeded := (NoOfBytesSwapped + 1023) div 1024;
      if AllocateExtMem(XmsNeeded, EmsHandle) = 0 then begin
        XmsAllocated := True;
        if NoSwapMsgForEms then
          SetSwapMsgOn(False);
        PrepareExecWithSwap := True;
        Exit;
      end;
    end;
    {$ENDIF}                                                {end   !!.03}
    if Length(SwapFileName) <> 0 then begin
      SwapName := SwapFileName+#0;
      if Pos(':', SwapFileName) = 2 then
        {Drive letter specified for swap file}
        DriveChar := Upcase(SwapFileName[1])
      else
        {Swap file on default drive}
        DriveChar := DefaultDrive;
      SwapFileAllocated := ((AllowRemovable or not IsRemovable(DriveChar)) and {!!.02}
                            (DiskFree(Ord(DriveChar)-$40) > NoOfBytesSwapped) and
                            AllocateSwapFile(SwapFileHandle));
      if SwapFileAllocated then
        PrepareExecWithSwap := True;
    end;
  end;
{$ENDIF}                                                         {end   !!.20}

{$IFDEF Dpmi}                                                          {!!.20}

  function ExecDosSwap(Command : string;
                       UseSecond : Boolean;
                       EDP : Pointer;
                       SwapFName : PathStr) : Integer;
   {-Execute any DOS command}
  var
    EProc          : ExecDosProc absolute EDP;
    PathName       : Dos.ComStr;
    CommandTail    : Dos.ComStr;
    BlankPos       : Word;

  begin
    {get parameters for Exec}
    if Command = '' then
      UseSecond := True;
    CommandTail := '';
    if not UseSecond {command processor} then begin
      {Command is assumed to be a full pathname for a program}
      BlankPos := Pos(' ', Command);
      if BlankPos = 0 then
        PathName := Command
      else begin
        CommandTail := Copy(Command, BlankPos, Length(Command));
        PathName := Copy(Command, 1, Pred(BlankPos));
      end;
    end
    else begin
      {Pathname is the full pathname for COMMAND.COM}
      PathName := GetEnv('COMSPEC');

      {if Command is empty, we're doing a shell}
      if Command <> '' then
        {we're asking COMMAND.COM to execute the command}
        CommandTail := '/C '+Command;
    end;

    {Let user routine store and clear the physical screen}
    if EDP <> nil then
      EProc(ExecSaveScreen, 0);

    {save current vectors and put originals back}
    SwapVectors;

    Exec(PathName, CommandTail);                                      {!!.20}

    {restore our vectors}
    SwapVectors;

    if EDP <> nil then begin
      {if not in shell, let user routine allow time to see result}
      if (Command <> '') or (DosError <> 0) then
        EProc(ExecPauseAfterRun, 0);

      {give user routine a chance to restore the screen}
      EProc(ExecRestoreScreen, 0);
    end;

    {If we get to here, our function result is in DosError}
    ExecDosSwap := DosError;
  end;

{$ELSE}                                                                {!!.20}
{$IFDEF Heap6}

  function ExecDosSwap(Command : string;
                       UseSecond : Boolean;
                       EDP : Pointer;
                       SwapFName : PathStr) : Integer;
   {-Execute any DOS command}
  var
    EProc          : ExecDosProc absolute EDP;
    PathName       : Dos.ComStr;
    CommandTail    : Dos.ComStr;
    OldEndOfHeap   : Pointer;
    ParasForDos    : Word;
    BlankPos       : Word;

  begin
    {allocate EMS/XMS/open swap file}
    if not PrepareExecWithSwap(HeapPtr, SwapFname) then begin
      ExecDosSwap := -5;
      Exit;
    end;

    {get parameters for Exec}
    if Command = '' then
      UseSecond := True;
    CommandTail := '';
    if not UseSecond {command processor} then begin
      {Command is assumed to be a full pathname for a program}
      BlankPos := Pos(' ', Command);
      if BlankPos = 0 then
        PathName := Command
      else begin
        CommandTail := Copy(Command, BlankPos, Length(Command));
        PathName := Copy(Command, 1, Pred(BlankPos));
      end;
    end
    else begin
      {Pathname is the full pathname for COMMAND.COM}
      PathName := GetEnv('COMSPEC');

      {if Command is empty, we're doing a shell}
      if Command <> '' then
        {we're asking COMMAND.COM to execute the command}
        CommandTail := '/C '+Command;
    end;

    {Let user routine store and clear the physical screen}
    if EDP <> nil then
      EProc(ExecSaveScreen, 0);

    {let user routine show status info if entering DOS shell}
    if (Command = '') then begin
      {Pass user routine the approximate memory available in KB}
      ParasForDos := Pred(PtrDiff(HeapEnd, @FirstToSave) shr 4);
      if EDP <> nil then
        EProc(ExecShowMemory, (ParasForDos-240) shr 6);
    end;

    {Save the current pointer to the end of the heap}
    OldEndOfHeap := HeapEnd;
    HeapEnd := HeapPtr;

    {save current vectors and put originals back}
    SwapVectors;

    {Call swapping EXEC function}
    ExecWithSwap(PathName, CommandTail);

    {restore our vectors}
    SwapVectors;

    {Put heap end back where it was}
    HeapEnd := OldEndOfHeap;

    if EDP <> nil then begin
      {if not in shell, let user routine allow time to see result}
      if (Command <> '') or (DosError <> 0) then
        EProc(ExecPauseAfterRun, 0);

      {give user routine a chance to restore the screen}
      EProc(ExecRestoreScreen, 0);
    end;

    {If we get to here, our function result is in DosError}
    ExecDosSwap := DosError;

    {give back EMS/delete swap file}
    RemoveExecWithSwap;
  end;

{$ELSE}

  function ExecDosSwap(Command : string;
                       UseSecond : Boolean;
                       EDP : Pointer;
                       SwapFName : PathStr) : Integer;
   {-Execute any DOS command}
  type
    SegOfs =
      record
        O, S : Word;
      end;
  var
    EProc          : ExecDosProc absolute EDP;
    PathName       : Dos.ComStr;
    CommandTail    : Dos.ComStr;
    OldEndOfHeap   : Pointer;
    NewEndOfHeap   : Pointer;
    TopOfHeap      : Pointer;
    ParasForDos    : Word;
    BlankPos       : Word;
    Allocated      : Word;
    SizeOfFreeList : Word;

    function EndOfHeap : Pointer;
      {-Returns a pointer to the end of the free list}
    var
      FreeSegOfs : SegOfs absolute FreePtr;
    begin
      if FreeSegOfs.O = 0 then
        {the free list is empty, add $1000 to the segment}
        EndOfHeap := Ptr(FreeSegOfs.S+$1000, 0)
      else
        EndOfHeap := Ptr(FreeSegOfs.S+(FreeSegOfs.O shr 4), 0);
    end;

    procedure CleanUp;
      {-Clean up after Exec}
    begin
      {Put free list back where it was}
      Move(NewEndOfHeap^, OldEndOfHeap^, SizeOfFreeList);

      if Allocated <> 0 then
        {Deallocate any dynamic memory used}
        FreeMem(NewEndOfHeap, Allocated);
    end;

  begin
    {Calculate number of bytes to save}
    TopOfHeap := Ptr(SegOfs(FreePtr).S+$1000, 0);
    SizeOfFreeList := PtrDiff(TopOfHeap, EndOfHeap);

    {Check for sufficient memory}
    if MaxAvail < LongInt(SizeOfFreeList) then begin
      {Insufficient memory to store free list}
      ExecDosSwap := -1;
      Exit;
    end;

    {Allocate memory for a copy of free list}
    Allocated := SizeOfFreeList;
    if Allocated > 0 then
      GetMem(NewEndOfHeap, Allocated);

    {Recalculate the size of the free list}
    SizeOfFreeList := Word(PtrDiff(TopOfHeap, EndOfHeap));

    {Save the current pointer to the end of the free list}
    OldEndOfHeap := EndOfHeap;

    {Copy the free list to a safe location}
    Move(OldEndOfHeap^, NewEndOfHeap^, SizeOfFreeList);

    {allocate EMS/XMS/open swap file}
    if not PrepareExecWithSwap(HeapPtr, SwapFname) then begin
      ExecDosSwap := -5;
      CleanUp;
      Exit;
    end;

    {get parameters for Exec}
    if Command = '' then
      UseSecond := True;
    CommandTail := '';
    if not UseSecond {command processor} then begin
      {Command is assumed to be a full pathname for a program}
      BlankPos := Pos(' ', Command);
      if BlankPos = 0 then
        PathName := Command
      else begin
        CommandTail := Copy(Command, BlankPos, Length(Command));
        PathName := Copy(Command, 1, Pred(BlankPos));
      end;
    end
    else begin
      {Pathname is the full pathname for COMMAND.COM}
      PathName := GetEnv('COMSPEC');

      {if Command is empty, we're doing a shell}
      if Command <> '' then
        {we're asking COMMAND.COM to execute the command}
        CommandTail := '/C '+Command;
    end;

    {Let user routine store and clear the physical screen}
    if EDP <> nil then
      EProc(ExecSaveScreen, 0);

    {let user routine show status info if entering DOS shell}
    if (Command = '') then begin
      {Pass user routine the approximate memory available in KB}
      ParasForDos := Pred(PtrDiff(TopOfHeap, @FirstToSave) shr 4);
      if EDP <> nil then
        EProc(ExecShowMemory, (ParasForDos-240) shr 6);
    end;

    {save current vectors and put originals back}
    SwapVectors;

    {Call swapping EXEC function}
    ExecWithSwap(PathName, CommandTail);

    {restore our vectors}
    SwapVectors;

    if EDP <> nil then begin
      {if not in shell, let user routine allow time to see result}
      if (Command <> '') or (DosError <> 0) then
        EProc(ExecPauseAfterRun, 0);

      {give user routine a chance to restore the screen}
      EProc(ExecRestoreScreen, 0);
    end;

    {If we get to here, our function result is in DosError}
    ExecDosSwap := DosError;

    {give back EMS/delete swap file}
    RemoveExecWithSwap;

    {restore heap, etc.}
    CleanUp;
  end;

{$ENDIF}
{$ENDIF}                                                               {!!.20}

{$IFNDEF Dpmi}                                                   {begin !!.20}
  {$F+}
  procedure ExecWithSwapExit;
  begin
    ExitProc := SaveExit;
    RemoveExecWithSwap;
  end;
  {$F-}

begin
  EmsAllocated := False;
  XmsAllocated := False;           {!!.03}
  SwapFileAllocated := False;
  NoOfBytesSwapped := 0;
  SaveExit := ExitProc;
  ExitProc := @ExecWithSwapExit;
{$ENDIF}                                                         {end   !!.20}
end.
