
{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$IFDEF Dpmi}                                                         {!!.20}
  !! This unit cannot be used in protected mode !!                    {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                   OPSWAP1.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1989, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpSwap1;

interface

uses
  Dos,
  OpInline;

const
  MaxPopups = 8;             {maximum number of user popups}
  MaxIsrs = 15;              {maximum number of ISRs}
  MaxScanCode = $58;         {highest scan code we can use -- do not change}
  {.Z+}
  NumIsrTable = 13;

  isrInt5      = 1;
  isrInt8      = 2;
  isrInt9      = 3;
  isrInt13     = 4;
  isrInt16     = 5;
  isrInt25     = 6;
  isrInt26     = 7;
  isrInt28     = 8;
  isrInt10     = 9;
  isrInt14     = 10;
  isrInt17     = 11;
  isrNOP       = 12;
  isrCmd       = 13;
  {.Z-}
  SwapFileMaxLen  = 67;
  EMSError     = 4;          {error code to indicate EMS error}
  DiskError    = 5;          {error code to indicate disk error}

  {OPSWAP option flags}      {!!.01}
  {changed to word            !!.02}
  SafeMouse    = $0001;      {use code to safely disable any mouse event
                              handlers when popping up in swapping mode}
  MSQuickFix   = $0002;      {uses special code to correct problem with
                              Microsoft Quick IDEs (only has meaning in
                              non-swapping mode}
  SingleSwap   = $0004;      {use single swap file}          {!!.02}
  EmsFlag      = $0008;      {using EMS}                     {!!.02}
  XmsFlag      = $0010;      {using XMS}                     {!!.02}
  SaveUarts    = $0020;      {saving/disabling UARTs while popped} {!!.13}

  SwappingEnabled : Boolean = False;      {True when swapping is active}
  SideKickLoaded : Boolean = False; {if True, SideKick is loaded}

  SwapUseEMS : Boolean = True;      {if False, EMS will not be used
                                     for swap even if available}
{$IFDEF SupportXms}
  SwapUseXms : Boolean = False;     {if False, XMS will not be used   !!.02}
  EmsOverXms : Boolean = True;      {if False, XMS will be checked    !!.02
                                     for sufficient space before EMS  !!.02}
{$ENDIF}
  ReleaseEms : Boolean = False;

type
  PopupProc = procedure;
  BytePtr   = ^Byte;

  {the following types are used internally by OsSwap}
  PopArray = array[1..MaxPopups] of PopupProc;
  StackArray = array[1..MaxPopups] of Pointer;
  PopBoolArray = array[1..MaxPopups] of Boolean;
  KeyArray = array[0..MaxScanCode] of Byte;
  Str20 = String[20];
  IsrRecord =
    record
      IntNum : Byte;         {Interrupt vector number}
      OrigAddr : Pointer;    {Original vector}
      NewAddr : Pointer;     {New vector}
      Captured : Boolean;    {Used for error checking}
    end;

  {global array of ISR records}
  IsrArrayType= array[1..MaxIsrs] of IsrRecord;
  CSSwapDataPtr = ^CSSwapDataType;
  IfcPtr = ^IfcRecord;
  IfcRecord =
    record                   {** don't change order **}
      NamePtr : ^string;
      Version : Word;
      CmdEntryPtr : PopupProc;
      PrevIfc,
      NextIfc : IfcPtr;
      CSDataPtr : CSSwapDataPtr;
      UserData  : Pointer;
    end;
  AsciiZ = Array[0..SwapFileMaxLen] of Char;

  {The following data type represents a data area within the code segment
   of the OPSwap unit.}
  CSSwapDataType =
    record
      PopupAddrs : PopArray;
      PopupStacks : StackArray;
      PopupInUse : PopBoolArray;
      PopUpKeys : KeyArray;
      ShiftKeys : KeyArray;
      IsrArray : IsrArrayType;
      PopTicker : Word;
      PopupToCall : Byte;
      PopupsEnabled : Boolean;
      DosVersion : Word;
      (* UsedEMS : Boolean; !!.02 *)
      PagesInEMS : Word;
      BytesSwapped : LongInt;
      EMSHandle : Word;
      FrameSeg : Word;
      FileHandle : Word;
      NewPrefixSeg : Word;
      EMSAllocated : Boolean;
      FileAllocated : Boolean;
      SwapMsgOn : Boolean;
      SwapMsgAttr : Byte;
      SwapMsgRow  : Byte;
      ThisIFC : IFCRecord;
      ModuleName : Str20;
      IFCInstalled : Boolean;
      Disable : Boolean;
      SwapEnabled : Boolean;
      SwapFile1,
      SwapFile2 : AsciiZ;
      IsrTable : Array[1..NumIsrTable] of Word;
      Vectors : Array[0..255] of Pointer;
      UartInts : Array[0..3] of Word; {!!.13}
      CmdEntryHandle : Byte;
      UserExitProc : PopupProc;
      LastEntrySS : Word;
      LastEntrySP : Word;
      LastEntryIP : Word;
      LastEntryCS : Word;
      NewInt3F    : Pointer;
      SwapFlags   : Word;            {!!.02}
      MouseSavePtr    : Pointer;
      MouseSaveFlags  : Word;
      FileAttr        : Word;        {!!.02}
      DosInUsePtr     : BytePtr;
      AllOfMem        : Word;        {!!.02}
      StartMCB        : Word;        {!!.02}
      XmsControlCS    : Pointer;     {!!.02}
    end;

  Dummy5 = array[1..5] of Word;
  {The IntRegisters type (from OpInt)}
  IntRegisters =
    record
      case Byte of
        1 : (BP, ES, DS, DI, SI, DX, CX, BX, AX, IP, CS, Flags : Word);
        2 : (Dummy : Dummy5; DL, DH, CL, CH, BL, BH, AL, AH : Byte);
    end;

const
  NilPointer       : Pointer = Nil;   {a pointer initialized to Nil}

var
  CSSwapData       : CSSwapDataPtr;   {a global pointer to the data in the
                                       OpSwap code segment}
  SaveSSeg         : Word;            {save our stack segment}
{$IFNDEF Heap6}                                                          {!!.10}
  TopOfHeap        : Pointer;         {pointer to the top of the TP heap}{!!.10}
{$ENDIF}                                                                 {!!.10}
  IntercomPtr      : function(Func : Byte) : Pointer; {for internal use}
  NoExternalIfc    : PopupProc absolute NilPointer; {a do nothing CmdEntryPtr}

{.Z+}
procedure InitCSSwapData;
  {-initialize the data in the code segment of OpSwap - for internal use}

procedure InitPops;
  {-Must be called before any other popup specific routines.}
{.Z-}

function AllocateStack(var P : Pointer; SizeInBytes : Word) : Boolean;
  {-Allocates a stack of size SizeInBytes}

procedure DeallocateStack(P : Pointer);
  {-Frees an allocated stack}

procedure PopupsOn;
  {-Turns popups on}

procedure PopupsOff;
  {-Turns popups off}

function ChangeHotKey(OldHotKey, NewHotKey : Word) : Boolean;
  {-Change a popup's hotkey from OldHotKey to NewHotKey}

function AddHotKey(PrimaryHotKey, SecondaryHotKey : Word) : Boolean;
  {-Add a second hot key for the popup with the specified primary hot key}

function DefinePop(HotKey : Word; Routine : PopupProc;
                   StackPtr : Pointer) : Boolean;
 {-Defines a popup routine associated with a particular hotkey. Returns
   False if no more Popup handles are available.}

procedure RestoreAllVectors;
  {-Restores all captured interrupt vectors}

function SwapSize(ParasToKeep : Word) : LongInt;
  {-Return the size in bytes of the area of memory to be swapped}

function WillSwapUseEms(ParasToKeep : Word) : Boolean;
  {-Returns True if OpSwap will use EMS memory for swapping}

{$IFDEF SupportXms}
function WillSwapUseXms(ParasToKeep : Word) : Boolean;        {!!.02}
  {-Returns True if OpSwap will use XMS memory for swapping}
{$ENDIF}

function ParagraphsToKeep : Word;
  {-Returns # of paragraphs currently used for code, data, stack, and heap}

function MaxParagraphsToKeep : Word;
  {-Maximum number of paragraphs to keep when going resident}

procedure StayResSwap(ParasToKeep : Word;
                      ExitCode : Byte;
                      SwapFileName1,
                      SwapFileName2 : String;
                      UseSwapping : Boolean);
 {-Terminate and stay resident.
   If UseSwapping is False, then the TSR does not use the swapping techniques
   and behaves like a normal TSR written with OpTSR (or TpTSR) }

function DisableTSR : Boolean;
 {-Disable TSR by restoring interrupt vectors and releasing memory. This
   does *not* halt the program. Returns false if it's not safe.}

function SafeToDisable : Boolean;
  {-Returns True if it is safe to disable the TSR}

procedure DisablePopup;
  {-An external interface procedure that attempts to disable the popup and
    reports the results in the UserData field of the IfcRecord. UserData is
    set to 1 on success.}

procedure InstallModule(var ModName : string; CmdEntryPtr : PopupProc);
 {-Installs this program as a resident module that can be located and
   accessed by other programs.}

procedure UninstallModule;
  {-Uninstalls the module from the linked list of modules.}

procedure SetSwapMsgAttr(Attr : Byte);
  {-Sets the attribute used by Swap manager for swap message}

procedure SetSwapMsgOn(On : Boolean);
  {-Turns Swap message on or off}

procedure SetSwapMsgRow(Row : Byte);
  {-Sets the row where swapping messages are to appear}

procedure SetUserExitProc(UserExitProc : PopupProc);
  {-Sets a pointer to a far procedure that is to be called before disabling
    the TSR}

function ModulePtrByName(var ModuleName : string) : IfcPtr;
  {-Returns a pointer to the IfcRecord for the module named ModuleName or Nil.}

function ModuleInstalled(var ModuleName : string) : Boolean;
  {-Returns true if ModuleName is installed.}

procedure EmulateInt(var Regs : IntRegisters; IntAddr : Pointer);
  {-Emulates an interrupt by filling the CPU registers with the values in Regs,
    clearing interrupts, pushing the flags, and calling far to IntAddr.}

function DosBusyFlag : Byte;
  {-Returns current value of DOS busy flag}

procedure SetVecOnReturn(IntNum : Byte; ISR : Pointer);
  {-Set int vector in ISR table (takes affect when popup returns)}

procedure SetQuickFixMode(On : Boolean); {!!.01}
  {-Enable or disable special fix for MS Quick (Basic, C) IDE problem. This
    option only has meaning when operating in non-swapping mode. When On is
    True, all ISR's will be swapped to the state they were in when the TSR
    loaded.}

procedure SetSingleSwapFile(On : Boolean);           {!!.02}
  {-If On is true, then uses single swap file. This cuts swapping disk
    space requirements in half. When using a single swap file, a small buffer
    is used in the resident kernel as an I/O buffer. This may reduce swap
    performance significantly compared to the default two swap file technique.

    This routine also has meaning when applied to XMS swapping. If the swap
    will be done to XMS, and SetSingleSwapFile has been called, then the XMS
    swap will be performed in a manner similar to that described above for
    single disk file swapping. This cuts the amount of XMS memory needed in
    half.

    The setting of single swap mode is relevant only when swapping to disk or
    XMS. If swapping to EMS, it is ignored.

    This routine must be called before StayResSwap, SwapSize,
    WillSwapUseEms, or WillSwapUseXms. Any calls made to SetSingleSwapFile
    routine after going resident will be ignored.

    Single swap file mode is recommended for use only on RAM disks. RAM disks
    will offer adequate performance despite the small I/O buffer since only
    memory access is required to read and write the swap file. The 50%
    reduction in swap file size is also very beneficial on a RAM disk.

    The size of the temporary buffer is dicated by the EQUate BufSize in
    OPSWAP.ASM. When in single swap file mode, BufSize bytes (plus a small
    amount of code overhead) are added to the always resident kernel. When
    operating in the default two swap file mode or when swapping to EMS or XMS
    memory, this extra space is not taken in the resident kernel (it is still
    a part of the program, so it is contained in the memory image written to
    the swap file or EMS).}

procedure SetSwapFileAttr(Hidden : Boolean);   {!!.02}
  {-If Hidden is True, then swap files will be created with attribute 6
    (hidden+ system), otherwise they will be created with attribute 0
    (normal)}

function WasCommandActive : Boolean;                           {!!.02}
  {-Returns True if COMMAND.COM was active at time of last popup}

procedure SetSaveComPorts(Enable : Boolean);
  {-Enables/disables saving of UART interrupt states while popped}

procedure InterruptsOn;
  {-Turn interrupts on}
  inline($FB);               {sti}

procedure InterruptsOff;
  {-Turn interrupts off}
  inline($FA);               {cli}

  {==========================================================================}

implementation

{$IFDEF SupportXms}          {!!.02}
uses OpXms;                  {!!.02}
{$ENDIF}                     {!!.02}

{$L OPSwap1}

type
  StackRecord =
    record
      Size : Word;
      Address : Pointer;
    end;

const
  EmsPageSize = 16384;            {Bytes in a standard EMS page}
  WentResident : Boolean = False;
  IfcSignature = $0F0F0;     {*** do not change!! ***}
  IfcSignature2 = $0E0E0;    {*** do not change!! ***}
  IfcVersion = $400;         {version number of interface}
  IRET : Byte = $CF;

  Int5Handle = 1;            {ISR handles used by our interrupt handlers}
  Int8Handle = 2;
  Int9Handle = 3;
  Int10Handle = 4;
  Int13Handle = 5;
  Int14Handle = 6;
  Int16Handle = 7;
  Int17Handle = 8;
  Int25Handle = 9;
  Int26Handle = 10;
  Int28Handle = 11;
  CmdEntryHandle = 14;

  Initialized : Boolean = False;  {internal semaphore to flag need to init}
  TSRInitialized : Boolean = False;
  HiddenAttr  = 6;           {file attribute for hidden/system file}  {!!.02}
  NormalAttr  = 0;           {file attribute for normal file}         {!!.02}
  CommandBit  = $8000;       {bit set in SwapFlags if COMMAND active} {!!.02}

var
  SaveExitProc : Pointer;             {Exit chain pointer}

  {used internally}
  SwapOut : function : Boolean;
  GoResident : procedure(ExitCode : Byte);
  GoResidentNoSwap : procedure(ParasToKeep : Word; ExitCode : Byte);

  procedure Save3FVector;
    {Saves the current value of the overlay handler interrupt (3Fh)}
  begin
    with CSSwapData^ do
      GetIntVec($3F,NewInt3F);
  end;

  procedure DeallocateSwapFile(Handle : Word;
                               var Swap1, Swap2 : AsciiZ); external;
    {-Free disk space used by swap files}

  procedure DeallocateEmsHandle(Handle : Word); external;
    {-Free EMS memory used for swap}


  {$F+}
  procedure EmergencyExit(LastSS,LastSP,LastCS,LastIP : Word); external;
    {-Called by exit/error handler in case of runtime error while popped up}

  {routines used internally by swap manager}
  function EmsInstalled : Boolean; external;
  function EmsPageFrame : Word; external;
  function AllocateEmsPages(NumPages : Word) : Word; external;
  function EmsPagesAvail : Word; external;
  function DefaultDrive : Char; external;
  function DiskFree(Drive : Byte) : LongInt; external;

  procedure EmulateInt(var Regs : IntRegisters; IntAddr : Pointer); external;
    {-Emulates an interrupt}
  {$F-}

  function DosBusyFlag : Byte;
    {-Returns current value of DOS busy flag}
  begin
    DosBusyFlag := CsSwapData^.DosInUsePtr^;
  end;

  procedure SetUserExitProc(UserExitProc : PopupProc);
    {-Sets a pointer to a far procedure that is to be called before disabling
      the TSR}
  begin
    CSSwapData^.UserExitProc := UserExitProc;
  end;

  procedure InitCSSwapData;
    {-initializes the code segment relative data}
  begin
    @GoResident := IntercomPtr(0);       {init the go resident pointer}
    @SwapOut := IntercomPtr(1);          {init the swap out pointer}
    @GoResidentNoSwap := IntercomPtr(3); {init the go resident no swap pointer}
    Initialized := True;
    InitPops;
  end;

  function PtrDiff(H, L : Pointer) : LongInt;
  begin
    PtrDiff := (LongInt(OS(H).S) shl 4+OS(H).O)-
               (LongInt(OS(L).S) shl 4+OS(L).O);
  end;

  function InitVector(IntNumber, Handle : Byte; UserRoutine : Pointer) : Boolean;
    {-Sets up an interrupt service routine}
  begin
    with CSSwapData^ do begin
      {assume failure}
      InitVector := False;

      case Handle of
        1..MaxIsrs :
          with IsrArray[Handle] do
            if not Captured then begin
              {Setup variables}
              IntNum := IntNumber;
              GetIntVec(IntNumber, OrigAddr);

              {Set the vector}
              SetIntVec(IntNumber, UserRoutine);
              NewAddr := UserRoutine;
              Captured := True;
              InitVector := True;
            end;
      end;
    end;
  end;

  procedure RestoreVector(Handle : Byte);
    {-Restores an interrupt vector to its original value}
  begin
    with CSSwapData^ do
      case Handle of
        1..MaxIsrs :
          with IsrArray[Handle] do
            if Captured then begin
              SetIntVec(IntNum, OrigAddr);
              Captured := False;
              OrigAddr := nil;
            end;
      end;
    end;

  procedure SetVecOnReturn(IntNum : Byte; ISR : Pointer);
    {-Set int vector in ISR table (takes affect when popup returns)}
  begin
    CSSwapData^.Vectors[IntNum] := ISR;
  end;

  procedure SpecialRestoreAllVectors;
  var
    I : Byte;
  begin
    with CSSwapData^ do
      for I := MaxIsrs downto 1 do
        with IsrArray[I] do
          if Captured then
            Vectors[IntNum] := OrigAddr;
  end;

  procedure RestoreAllVectors;
    {-Restores all captured interrupt vectors}
  var
    I : Word;
  begin
    {restore in reverse order}
    for I := MaxIsrs downto 1 do
      RestoreVector(I);
  end;

  function SwapSize(ParasToKeep : Word) : LongInt;
    {-Return the size in bytes of the area of memory to be swapped}
  var
    P : Pointer;
    LastToSave : Pointer;
  begin
    {calculate last to save}
    LastToSave := Ptr(PrefixSeg+ParasToKeep,0);
    with CSSwapData^ do begin
      P := IntercomPtr(2);
      SwapSize := PtrDiff(LastToSave, P);
    end;
  end;

  function WillSwapUseEms(ParasToKeep : Word) : Boolean;
    {-Returns True if OpSwap will use EMS memory for swapping}
  var                                 {!!.02}
    SaveFlags : Word;                 {!!.02}
  begin
    with CSSwapData^ do
      if SwapUseEMS and EmsInstalled and (EmsPageFrame <> 0) then begin {!!.01}
        {$IFDEF SupportXms}                           {!!.02}
        if not EmsOverXms then                        {!!.02}
          if WillSwapUseXms(ParasToKeep) then begin   {!!.02}
            WillSwapUseEms := False;                  {!!.02}
            Exit;                                     {!!.02}
          end;                                        {!!.02}
        {$ENDIF}                                      {!!.02}
        SaveFlags := SwapFlags;                       {!!.02}
        ClearFlag(SwapFlags,SingleSwap);              {!!.02}
        PagesInEms := (SwapSize(ParasToKeep)+EmsPageSize-1) div EmsPageSize;
        SwapFlags := SaveFlags;                       {!!.02}
        WillSwapUseEms := PagesInEms <= EmsPagesAvail;
      end
      else
        WillSwapUseEms := False;
  end;

{!!.02 begin}
{$IFDEF SupportXms}
  function WillSwapUseXms(ParasToKeep : Word) : Boolean;
    {-Returns True if OpSwap will use XMS memory for swapping}
  var
    Largest, Total : Word;
    TotalL  : LongInt;                                   {!!.03}
  begin
    WillSwapUseXms := False;
    if SwapUseXms and XmsInstalled then begin
      if EmsOverXms then
        if WillSwapUseEms(ParasToKeep) then {works independent of B+/-}
          Exit;
      if QueryFreeExtMem(Total, Largest) <> 0 then
        Exit;
      TotalL := SwapSize(ParasToKeep);                   {!!.03}
      with CSSwapData^ do
        if not FlagIsSet(SwapFlags, SingleSwap) then
          TotalL := TotalL * 2;                          {!!.03}
      TotalL := (TotalL + (1024-1)) div 1024;            {!!.03}
      WillSwapUseXms := TotalL <= LongInt(Largest);      {!!.03}
    end;
  end;
{$ENDIF}
{!!.02 end}

  {!!.13 new}
  procedure CheckComActive;
  var
    BiosBaseAddr : array[0..3] of Word absolute $0040:$0000;
  var
    BaseAddr : Word;
    I : Word;
    Ints : Byte;
  begin
    with CSSwapData^ do
      for I := 0 to 3 do begin
        BaseAddr := BiosBaseAddr[I];
        if BaseAddr <> 0 then begin
          Ints := Port[BaseAddr+1];
          if Ints <> 0 then
            UartInts[I] := $FF00;
        end;
      end;
  end;

  function InitTSRSwap(LastToSave : Pointer;
                       SwapFileName1, SwapFileName2 : String) : Boolean;
  var
    BytesFree : LongInt;            {Bytes free on swap file drive}
    DriveChar : Char;               {Drive letter for swap file}
    P         : Pointer;
    L1        : Byte absolute SwapFileName1;
    L2        : Byte absolute SwapFileName2;
    Ems, Xms  : Boolean;                                            {!!.02}

  begin
    InitTSRSwap := False;

    if FlagIsSet(CSSwapData^.SwapFlags, SaveUarts) then               {!!.21}
      {Set "DontUse" Flag for any COM ports with interrupts active}   {!!.13}
      CheckComActive;                                                 {!!.13}

    with CSSwapData^ do begin
      Ems := WillSwapUseEms(Seg(LastToSave^) - PrefixSeg);          {!!.02}{!!.12}
      {if the swap is using EMS, then clear the single swap flag}   {!!.02}
      if Ems then                                                   {!!.02}
        ClearFlag(SwapFlags, SingleSwap);                           {!!.02}

      {$IFDEF SupportXms}                                           {!!.02}
      if not Ems then                                               {!!.02}
        Xms :=  WillSwapUseXms(Seg(LastToSave^) - PrefixSeg)        {!!.02}{!!.12}
      else                                                          {!!.02}
        Xms := False;                                               {!!.02}
      {$ENDIF}                                                      {!!.02}

      {Call Intercom routine to return FirstToSave pointer}
      P := IntercomPtr(2);
      BytesSwapped := PtrDiff(LastToSave, P);

      if BytesSwapped <= 0 then
        Exit;

      if Ems then begin                      {!!.01} {!!.02}
        FrameSeg := EmsPageFrame;
        if FrameSeg <> 0 then begin
          PagesInEms := (BytesSwapped+EmsPageSize-1) div EmsPageSize;
          EmsHandle := AllocateEmsPages(PagesInEms);
          if EmsHandle <> $FFFF then begin
            EmsAllocated := True;
            InitTSRSwap := True;
            SetFlag(SwapFlags, EmsFlag);
            if not SwapOut then begin
              WriteLn('Error attempting to swap memory - program aborting');
              Halt(1);
            end;
            Exit;
          end;
        end;
      end;

      {$IFDEF SupportXms}        {!!.02 begin}
      if Xms then begin
        BytesFree  := BytesSwapped;
        if not FlagIsSet(SwapFlags,SingleSwap) then
          BytesFree := BytesFree * 2;
        {for XMS, we use PagesInEms to hold the kilobytes allocated in XMS,
         and EmsHandle to store the XMS handle}
        PagesInEms := (BytesFree + (1024-1)) div 1024;
        if AllocateExtMem(PagesInEms, EmsHandle) = 0 then begin
          InitTSRSwap := True;
          SetFlag(SwapFlags, XmsFlag);
          XmsControlCS := OpXms.XmsControl;
          if not SwapOut then begin
            WriteLn('Error attempting to swap memory - program aborting');
            Halt(1);
          end;
          Exit;
        end;
      end;
      {$ENDIF}                   {!!.02 end}

      if (L1 = 0) or (L1 > SwapFileMaxLen) or
         (L2 = 0) or (L2 > SwapFileMaxLen) then
        Exit;

      Move(SwapFileName1[1],SwapFile1,Length(SwapFileName1));
      Move(SwapFileName2[1],SwapFile2,Length(SwapFileName2));
      if Pos(':', SwapFileName1) = 2 then
        DriveChar := Upcase(SwapFileName1[1])
      else
        DriveChar := DefaultDrive;
      BytesFree := DiskFree(Byte(DriveChar)-$40);
      if FlagIsSet(SwapFlags, SingleSwap) then                     {!!.02}
        FileAllocated := (BytesFree > BytesSwapped)                {!!.02}
      else                                                         {!!.02}
        FileAllocated := (BytesFree > (BytesSwapped*2));           {!!.02}
      if FileAllocated then begin
        InitTSRSwap := True;
        if not SwapOut then begin
          WriteLn('Error attempting to swap memory - program aborting');
          Halt(1);
        end;
      end;
    end;
  end;

  procedure InitPops;
    {-Must be called before any other popup specific routines.}
  {$IFDEF ThwartSideKick}
  type
    Array4 = array[0..3] of Char;
  {$ENDIF}
  const
    {                I B K S}
    SideKickFlag = $49424B53;
    SideKickPlus = $CB;
  {$IFDEF ThwartSideKick}
    SideKickCode : Array4 = (
      #$8C, #$CB,  {MOV  BX,CS}
      #$3B, #$C3); {CMP  AX,BX}
     {#$74          JZ   xxxx <-- if found, change the JZ to a JMP SHORT}
  {$ENDIF}
  var
    P : Pointer;
    PSO : OS absolute P;
    IsrCS : Word;
    {$IFDEF ThwartSideKick}
    PB : ^Byte absolute P;
    PA4 : ^Array4 absolute P;
    I : Word;
    {$ENDIF}

    procedure InitVectorPrim(IntNumber, Handle : Byte; UserRoutine : Pointer);
      {-Sets up an interrupt service routine}
    begin
      if not InitVector(IntNumber, Handle, UserRoutine) then begin
        WriteLn('Unable to install TSR manager');
        Halt(1);
      end;
    end;

  begin
    {don't do this twice}
    if TSRInitialized then
      Exit;

    {test for SideKick: 'SKBI' just before start of INT $8 handler. A RETF
     instruction just before SKBI signals SideKickPlus, which we can load
     after.}
    GetIntVec($08, P);
    SideKickLoaded :=
      (MemL[PSO.S:PSO.O-4] = SideKickFlag) and
      (Mem[PSO.S:PSO.O-5] <> SideKickPlus);

    {$IFDEF ThwartSideKick}
    if SideKickLoaded then begin
      {see if we can thwart its INT 9 grabber so we can go resident}
      {search for the tell-tale code}
      for I := 0 to 100 do begin
        {have we found it?}
        if PA4^ = SideKickCode then begin
          {if so, disable the INT 9 grabber...}
          Inc(PSO.O, 4);
          {make sure it's OK to change it}
          case PB^ of
            $74, $EB :
              begin
                {turn the conditional jump into a short jump...}
                InterruptsOff;
                PB^ := $EB;
                InterruptsOn;

                {...and clear the SideKick flag}
                SideKickLoaded := False;
              end;
          end;
        end;
        Inc(PSO.O);
      end;
    end;
    {$ENDIF}

    with CSSwapData^ do begin
      IsrCS := OS(@IntercomPtr).S;

      {initialize our interrupt vectors}
      InitVectorPrim($05, Int5Handle, Ptr(IsrCS,IsrTable[isrInt5]));
      InitVectorPrim($08, Int8Handle, Ptr(IsrCS,IsrTable[isrInt8]));
      InitVectorPrim($09, Int9Handle, Ptr(IsrCS,IsrTable[isrInt9]));
      InitVectorPrim($13, Int13Handle, Ptr(IsrCS,IsrTable[isrInt13]));
      InitVectorPrim($16, Int16Handle, Ptr(IsrCS,IsrTable[isrInt16]));
      InitVectorPrim($25, Int25Handle, Ptr(IsrCS,IsrTable[isrInt25]));
      InitVectorPrim($26, Int26Handle, Ptr(IsrCS,IsrTable[isrInt26]));
      InitVectorPrim($28, Int28Handle, Ptr(IsrCS,IsrTable[isrInt28]));

      {don't filter the following interrupts unless we're running under OS/2}
      if Hi(DosVersion) >= 10 then begin
        InitVectorPrim($10, Int10Handle, Ptr(IsrCS,IsrTable[isrInt10]));
        InitVectorPrim($14, Int14Handle, Ptr(IsrCS,IsrTable[isrInt14]));
        InitVectorPrim($17, Int17Handle, Ptr(IsrCS,IsrTable[isrInt17]));
      end;
      SetFlag(SwapFlags, SaveUarts);                                   {!!.13}
    end;
    TSRInitialized := True;
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
      GetMem(P, Word(ActualSize));

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
      FreeMem(Address, Size);
  end;

  function ParagraphsToKeep : Word;
    {-Returns # of paragraphs currently used for code, data, stack, and heap.}
  begin
    {keep everything from PSP to top of heap}
    ParagraphsToKeep := Succ(Seg(HeapPtr^)-PrefixSeg);
  end;

  function MaxParagraphsToKeep : Word;
    {-Maximum number of paragraphs to keep when going resident}
  var
    TopOfMem : Pointer;
  begin
    TopOfMem := Ptr(PrefixSeg, 2);
    MaxParagraphsToKeep := Word(TopOfMem^)-PrefixSeg;
  end;

{$IFNDEF Heap6} {!!.10}
  function HeapEnd : Pointer;
    {-Returns a pointer to the end of the free list}
  begin
    if Ofs(FreePtr^) = 0 then
      {Free list is empty}
      HeapEnd := Ptr(Seg(FreePtr^)+$1000, 0)
    else
      HeapEnd := Ptr(Seg(FreePtr^)+Ofs(FreePtr^) shr 4, Ofs(FreePtr^) and $F);
  end;
{$ENDIF} {!!.10}

  procedure PopupsOn;
    {-Turns popups on}
  const
    Saved3F : Boolean = False;
  begin
    CSSwapData^.PopupsEnabled := True;

    if not Saved3F then begin
      {save the current INT $3F vector}
      Save3Fvector;
      Saved3F := True;
    end;
  end;

  procedure PopupsOff;
    {-Turns popups off}
  begin
    CSSwapData^.PopupsEnabled := False;
  end;

  function ChangeHotKey(OldHotKey, NewHotKey : Word) : Boolean;
    {-Change a hotkey from OldHotKey to NewHotKey}
  var
    Handle : Byte;
    OldScan : Byte absolute OldHotKey;
    NewScan : Byte absolute NewHotKey;
  begin
    with CSSwapData^ do begin
      ChangeHotKey := False;
      case NewScan of
        1..MaxScanCode : {ok} ;
        else Exit;
      end;
      case Lo(OldHotKey) of
        1..MaxScanCode :
          if (PopupKeys[OldScan] <> 0) and
          ((OldScan = NewScan) or (PopupKeys[NewScan] = 0)) then begin
            {with interrupts off, switch hot keys}
            InterruptsOff;

            {get rid of the current assignment}
            Handle := PopupKeys[OldScan];
            PopupKeys[OldScan] := 0;
            ShiftKeys[OldScan] := 0;

            PopupKeys[NewScan] := Handle;
            ShiftKeys[NewScan] := Hi(NewHotKey);
            InterruptsOn;
            ChangeHotKey := True;
          end;
      end;
    end;
  end;

  function AddHotKey(PrimaryHotKey, SecondaryHotKey : Word) : Boolean;
    {-Add a second hot key for the popup with the specified primary hot key}
  var
    PScan : Byte absolute PrimaryHotKey;
    SScan : Byte absolute SecondaryHotKey;
  begin
    AddHotKey := False;
    with CSSwapData^ do
      case SScan of
        1..MaxScanCode :
          if (PopupKeys[PScan] <> 0) and (PopupKeys[SScan] = 0) then begin
            {with interrupts off, add the hot key}
            InterruptsOff;
            PopupKeys[SScan] := PopupKeys[PScan];
            ShiftKeys[SScan] := Hi(SecondaryHotKey);
            InterruptsOn;

            AddHotKey := True;
          end;
      end;
  end;

  function DefinePopProc(var Handle : Byte; Routine : PopupProc;
                         StackPtr : Pointer) : Boolean;
    {-Defines a routine that can be triggered by calling SetPopTicker. Returns
      false if no more Popup handles are available.}
  var
    B : Byte;
  begin
    with CSSwapData^ do
      {search for an available handle}
      for B := 1 to MaxPopups do
        if (@PopupAddrs[B] = nil) then begin
          {assign the handle}
          Handle := B;

          {install the popup}
          PopupAddrs[B] := Routine;
          PopupStacks[B] := StackPtr;
          PopupInUse[B] := False;

          {signal success}
          DefinePopProc := True;
          Exit;
        end;

    {if we get to here we failed}
    DefinePopProc := False;
  end;

  procedure DeletePopProc(Handle : Byte);
    {-Deletes a popup routine defined with DefinePopProc.  Its handle may then
      be used for other popups.}
  begin
    with CSSwapData^ do
      case Handle of
        1..MaxPopups : @PopupAddrs[Handle] := nil;
      end;
  end;

  function DefinePop(HotKey : Word; Routine : PopupProc;
                     StackPtr : Pointer) : Boolean;
    {-Defines a popup routine associated with a particular hotkey. Returns
      False if no more Popup handles are available.}
  var
    B : Byte;
  begin
    with CSSwapData^ do begin
      {assume failure}
      DefinePop := False;

      case Lo(HotKey) of
        1..MaxScanCode :
          if PopupKeys[Lo(HotKey)] = 0 then
            if DefinePopProc(B, Routine, StackPtr) then begin
              {set the shift key}
              ShiftKeys[Lo(HotKey)] := Hi(HotKey);

              {If popups are on, next statement makes this one active}
              PopupKeys[Lo(HotKey)] := B;
              DefinePop := True;
            end;
      end;
    end;
  end;

  procedure DisablePopup;
    {-An external interface procedure that attempts to disable the popup and
      reports the results in the UserData field of the IfcRecord. UserData is
      set to 1 on success.}
  begin
    LongInt(CSSwapData^.ThisIFC.UserData) := LongInt(Ord(DisableTSR));
  end;

  procedure StayResSwap(ParasToKeep : Word;
                        ExitCode : Byte;
                        SwapFileName1,
                        SwapFileName2 : String;
                        UseSwapping : Boolean);
   {-Terminate and stay resident. If UseSwapping is True, then everything
     linked before the label FirstToSave in the OpSwap unit is released.
     If UseSwapping is False, then this call releases all memory except
     ParasToKeep.}
  var
    LastToSave : Pointer;
{$IFDEF Heap6}                 {!!.10}
    SaveHeapEnd : Pointer;     {!!.10}
{$ELSE}                        {!!.10}
    SaveFreePtr : Pointer;
    NewFreePtr : Pointer;
    NewFreeSeg : Word;
    FreeListSize : Word;
{$ENDIF}                       {!!.10}
    SavePopupState : Boolean;

Label
  ExitPoint;

  begin
    {if we return from this call, we failed to go resident}
    {save the current value of FreePtr}
{$IFDEF Heap6}                           {!!.10}
    SaveHeapEnd := HeapEnd;              {!!.10}
{$ELSE}                                  {!!.10}
    {save the current value of FreePtr}
    SaveFreePtr := FreePtr;
{$ENDIF}                                 {!!.10}

    {save state of popups (on or off) and temporarily turn them off}
    SavePopupState := CSSwapData^.PopupsEnabled;
    CSSwapData^.PopupsEnabled := False;

    {calculate last to save}
    LastToSave := Ptr(PrefixSeg+ParasToKeep,0);

    {exit if SideKick is loaded and couldn't be thwarted}
    if SideKickLoaded then
      Goto ExitPoint;

    {reject requests for less than the bare minimum or more than the maximum}
    if (ParasToKeep < ParagraphsToKeep) or (ParasToKeep > MaxParagraphsToKeep) then
      Goto ExitPoint;

    CSSwapData^.AllOfMem := ParasToKeep;                  {!!.02}

{$IFDEF Heap6}                                            {!!.10}
    HeapEnd := LastToSave;                                {!!.10}
{$ELSE}                                                   {!!.10}
    {Calculate the number of bytes to move}
    FreeListSize := PtrDiff(TopOfHeap, HeapEnd);


    {calculate new location of the free list}
    NewFreeSeg := (PrefixSeg+ParasToKeep)-$1000;
    if FreeListSize = 0 then
      NewFreePtr := Ptr(NewFreeSeg, 0)
    else
      NewFreePtr := Ptr(NewFreeSeg, Ofs(FreePtr^));

    {Move the free list down}
    if FreeListSize <> 0 then
      Move(FreePtr^, NewFreePtr^, FreeListSize);
    FreePtr := NewFreePtr;
{$ENDIF}                                                  {!!.10}

    {set flag for error/exit handler}
    WentResident := True;

    {restore vectors captured by runtime library}
    SetIntVec($00, SaveInt00);
    SetIntVec($02, SaveInt02);
    SetIntVec($1B, SaveInt1B);
    SetIntVec($23, SaveInt23);
    SetIntVec($24, SaveInt24);
    SetIntVec($34, SaveInt34);
    SetIntVec($35, SaveInt35);
    SetIntVec($36, SaveInt36);
    SetIntVec($37, SaveInt37);
    SetIntVec($38, SaveInt38);
    SetIntVec($39, SaveInt39);
    SetIntVec($3A, SaveInt3A);
    SetIntVec($3B, SaveInt3B);
    SetIntVec($3C, SaveInt3C);
    SetIntVec($3D, SaveInt3D);
    SetIntVec($3E, SaveInt3E);
    SetIntVec($3F, SaveInt3F);
    SetIntVec($75, SaveInt75);

    {Init the TSRSwap system}
    if UseSwapping then begin
      SwappingEnabled := True;
      if not InitTSRSwap(LastToSave,SwapFileName1,SwapFileName2) then
        Goto ExitPoint;
    end;

    {restore the state of popups}
    CSSwapData^.PopupsEnabled := SavePopupState;
    if SwappingEnabled then
      GoResident(ExitCode)
    else
      GoResidentNoSwap(ParasToKeep, ExitCode);

  ExitPoint:
{$IFDEF Heap6}                                            {!!.10}
    HeapEnd := SaveHeapEnd;                               {!!.10}
{$ELSE}                                                   {!!.10}
    {if we get this far, we failed, so restore FreePtr}
    FreePtr := SaveFreePtr;
{$ENDIF}                                                  {!!.10}
    WentResident := False;
    {restore the state of popups}
    CSSwapData^.PopupsEnabled := SavePopupState;
  end;

  function GetLastModulePtr : Pointer;
    {-Return a pointer to the last TPRO TSR loaded before us}
  var
    FoundIfc : Boolean;
    P : IfcPtr;
    IACAptr : Pointer absolute $40:$F0;
    SaveIACA : Pointer;
  begin
    {assume failure}
    P := nil;
    SaveIACA := IACAptr;
    IACAptr := nil;
    FoundIfc := False;                                    {!!.13}

    {since Intr() in TP 4.0 is not re-entrant, and this might be called from
     inside a popup, we use inline}
    Inline(
      $B8/>IFCSIGNATURE/     {mov ax,>IfcSignature   ;standard interface function code}
      $31/$FF/               {xor di,di              ;es:di = nil}
      $8E/$C7/               {mov es,di}
      $CD/$16/               {int $16                ;call INT 16}
      $F7/$D0/               {not ax                 ;flip bits}
      $3D/>IFCSIGNATURE/     {cmp ax,>IfcSignature   ;AX = IfcSignature only if INT 16 flipped bits}
      $75/$22/               {jne Done               ;Ifc handler not found? !!.21}
      $8C/$C0/               {mov ax,es              ;use second method if es = 0 !!.21}
      $09/$C0/               {or ax,ax               ;!!.21}
      $74/$0C/               {jz NotFound            ;!!.21}
      $09/$FF/               {or di,di               ;or di = 0 !!.21}
      $74/$08/               {jz NotFound}
      $89/$7E/<P/            {mov [bp+<P],di         ;offset of list pointer in P}
      $8C/$46/<P+2/          {mov [bp+<P+2],es       ;segment of list pointer in P}
      $EB/$0C/               {jmp short Found}
                             {NotFound:              ;try second method - SuperKey can defeat the first}
      $B8/>IFCSIGNATURE2/    {mov ax,>IfcSignature2  ;secondary function code}
      $CD/$16/               {int $16                ;call INT 16}
      $F7/$D0/               {not ax                 ;AX = not AX}
      $3D/>IFCSIGNATURE2/    {cmp ax,>IfcSignature2  ;AX = IfcSignature2?}
      $75/$04/               {jne Done               ;Ifc handler not found?}
                             {Found:}
      $C6/$46/<FOUNDIFC/$01);{mov byte ptr [bp+<FoundIfc],1   ;set Found flag}
                             {Done:}

    if not FoundIfc then
      GetLastModulePtr := nil
    else if P <> nil then
      GetLastModulePtr := P
    else
      GetLastModulePtr := IACAptr;

    {restore intra-applications comm. area}
    IACAptr := SaveIACA;
  end;

  procedure InstallCmdEntryPtr(ProcPtr : PopupProc);
    {-Sets up a user-defined CmdEntryPtr}
  begin
    with CSSwapData^, ThisIfc do
      if @ProcPtr = Nil then
        @CmdEntryPtr := Nil
      else begin
        @CmdEntryPtr := Ptr(OS(@IntercomPtr).S, IsrTable[isrCmd]);
        if not DefinePopProc(CmdEntryHandle, ProcPtr, Ptr(SSeg, SPtr)) then
          @CmdEntryPtr := Nil;
      end;
  end;

  procedure InstallModule(var ModName : string; CmdEntryPtr : PopupProc);
   {-Installs this program as a resident module that can be located and
     accessed by other programs.}
  var
    P : IfcPtr;
  begin
    with CSSwapData^ do begin
      if not IfcInstalled then
        with ThisIfc do begin
          {see if anyone else is home}
          P := GetLastModulePtr;
          if P <> nil then begin
            P^.NextIfc := @ThisIfc;
            PrevIfc := P;
          end
          else
            PrevIfc := nil;

          {initialize the other fields in the record}
          ModuleName := ModName;
          NamePtr := @ModuleName;
          NextIfc := nil;
          Version := IfcVersion;
          CSDataPtr := CSSwapData;
          IfcInstalled := True;
        end;
      InstallCmdEntryPtr(CmdEntryPtr);
    end;
  end;

  procedure UninstallModule;
    {-Uninstalls the module from the linked list of modules.}
  begin
    with CSSwapData^ do begin
      if IfcInstalled then
        with ThisIfc do begin
          {fix the linked list of modules}
          if PrevIfc <> nil then
            PrevIfc^.NextIfc := NextIfc;
          if NextIfc <> nil then
            NextIfc^.PrevIfc := PrevIfc;
          IfcInstalled := False;
        end;
    end;
  end;

  function ModulePtrByName(var ModuleName : string) : IfcPtr;
    {-Returns a pointer to the IfcRecord for the module named ModuleName or Nil}
  var
    P : IfcPtr;
  begin
    {get pointer to previous module}
    P := GetLastModulePtr;
    ModulePtrByName := nil;

    {search backward through the list}
    while (P <> nil) do
      with P^ do
        if NamePtr^ = ModuleName then begin
          ModulePtrByName := P;
          Exit;
        end
        else
          P := P^.PrevIfc;
  end;

  function SafeToDisable : Boolean;
    {-Returns True if it is safe to disable the TSR}
  var
    I : Word;
    P : Pointer;
    VecsGrabbed : set of Byte;

  begin
    SafeToDisable := False;

    {not safe if we never went resident}
    if not WentResident then
      Exit;

    {initialize VecsGrabbed entries to false}
    FillChar(VecsGrabbed, SizeOf(VecsGrabbed), 0);

    {go backwards, looking for changed vectors that have been grabbed only once}
    with CSSwapData^ do
      for I := MaxIsrs downto 1 do
        with IsrArray[I] do
          if Captured then begin
            if SwapEnabled or FlagIsSet(SwapFlags, MsQuickFix) then {!!.02}
              P := Vectors[IntNum]                                  {!!.02}
            else                                                    {!!.02}
              GetIntVec(IntNum, P);                                 {!!.02}
            if (IntNum <> 5) and (P <> NewAddr)
                and not(IntNum in VecsGrabbed) then
              Exit;
            VecsGrabbed := VecsGrabbed+[Lo(IntNum)];
          end;

    {if we get here it's safe}
    SafeToDisable := True;
  end;

  function DisableTSR : Boolean;
    {-Disable TSR by restoring interrupt vectors and releasing memory. This
      does *not* halt the program. Returns false if it's not safe.}
  var
    Regs : Registers;
    I : Word;
  begin
    with CSSwapData^ do                           {!!.01}
      if @UserExitProc <> nil then                {!!.01}
        UserExitProc;                             {!!.01}

    {don't disable if it's not safe}
    DisableTSR := False;
    if not SafeToDisable then
      Exit;

    {disable popups and restore any other vectors taken over}
    PopupsOff;


    Initialized := False;

    with CSSwapData^ do                                        {!!.02}
      if SwapEnabled or FlagIsSet(SwapFlags, MsQuickFix) then  {!!.02}
        SpecialRestoreAllVectors
      else
        RestoreAllVectors;

    UninstallModule;
    CSSwapData^.Disable := True;

    with Regs do begin
      {close all file handles, ignoring error codes}
      for I := 0 to 19 do begin
        AH := $3E;           {close file handle function}
        BX := I;             {handle}
        MsDos(Regs);
      end;

      {$IFNDEF StonyBrook}     {!!.13}
      if ReleaseEms then begin
        DX := OvrEmsHandle;
        AH := $45;
        Intr($67, Regs);
      end;
      {$ENDIF}
    end;
    DisableTSR := True;
  end;

  function ModuleInstalled(var ModuleName : string) : Boolean;
    {-Returns true if ModuleName is installed}
  begin
    {let ModulePtrByName do the searching}
    ModuleInstalled := ModulePtrByName(ModuleName) <> nil;
  end;

  {$F+}
  procedure TsrSwapExit;
    {-Error/exit handler}
  begin
    {restore previous exit handler}
    ExitProc := SaveExitProc;
    if (not Initialized) then
      Exit;

    {uninstall the module and turn popups off}

    UninstallModule;
    PopupsOff;

    if WentResident then begin
      {try to disable the TSR}
      if DisableTSR then
        with CSSwapData^ do
          EmergencyExit(LastEntrySS,LastEntrySP,LastEntryCS,LastEntryIP);
    end;

    if (not SwappingEnabled) or (not CSSwapData^.SwapEnabled) then {!!!!!!}
      RestoreAllVectors;
  end;
  {$F-}

  procedure SetSingleSwapFile(On : Boolean);           {!!.02}
  begin
    {this must be set before going resident, otherwise it is ignored}
    if WentResident then
      Exit;
    if On then
      SetFlag(CSSwapData^.SwapFlags, SingleSwap)
    else
      ClearFlag(CSSwapData^.SwapFlags, SingleSwap);
  end;

  procedure SetQuickFixMode(On : Boolean); {!!.01}
    {-Enable or disable special fix for MS Quick (Basic, C) IDE bug. This option
      only has meaning when operating in non-swapping mode. When On is True, all
      ISR's will be swapped to the state they were in when the TSR loaded.}
  begin
    if On then
      SetFlag(CSSwapData^.SwapFlags, MSQuickFix)       {!!.02}
    else
      ClearFlag(CSSwapData^.SwapFlags, MSQuickFix);        {!!.02}
  end;

  procedure SetSwapMsgAttr(Attr : Byte);
    {-Sets the attribute used by Swap manager for swap message}
  begin
    CSSwapData^.SwapMsgAttr := Attr;
  end;

  procedure SetSwapMsgOn(On : Boolean);
    {-Turns Swap message on or off}
  begin
    CSSwapData^.SwapMsgOn := On;
  end;

  procedure SetSwapMsgRow(Row : Byte);
    {-Sets the row where swapping messages are to appear}
  begin
    CSSwapData^.SwapMsgRow := Pred(Row);
  end;

  procedure SetSwapFileAttr(Hidden : Boolean);    {!!.02}
    {-If Hidden is True, then swap files will be created with attribute 6
      (hidden+ system), otherwise they will be created with attribute 0
      (normal)}
  begin
    if Hidden then
      CSSwapData^.FileAttr := HiddenAttr
    else
      CSSwapData^.FileAttr := NormalAttr;
  end;

  function WasCommandActive : Boolean;                           {!!.02}
    {-Returns True if COMMAND.COM was active at time of last popup}
  begin
    WasCommandActive := FlagIsSet(CSSwapData^.SwapFlags, CommandBit);
  end;

  procedure SetSaveComPorts(Enable : Boolean);
    {-Enables/disables saving of UART interrupt states while popped}
  begin
    with CSSwapData^ do
      if Enable then
        SetFlag(SwapFlags, SaveUarts)
      else
        ClearFlag(SwapFlags, SaveUarts);
  end;

begin
{$IFNDEF Heap6}                                {!!.10}
  {save top of heap for later}
  TopOfHeap := Ptr(Seg(FreePtr^)+$1000, 0);
{$ENDIF}                                       {!!.10}

  {save SSeg for later}
  SaveSSeg := SSeg;

  {set up error/exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @TSRSwapExit;
end.
