{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$IFDEF Dpmi}                                                         {!!.20}
  !! This unit cannot be used in protected mode !!                    {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F+,O+,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                  OPEXTMEM.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpExtMem;
  {-Extended memory management routines}

  {
  These routines allow you to access extended memory under DOS 3.x without
  colliding with VDISK or Microsoft's RAMDRIVE.SYS. To access the memory, you
  should:

  1. Find out how much is available with ExtMemAvail.
  2. Use GetExtMem to allocate the total amount that you will use.
  3. Use MoveExtMem to access the memory.
  4. Keep in mind that the memory you allocate may not be accessable to other
     programs even after you deallocate it. For this reason, you should not
     allocate more memory than you need for any purpose.
  5. Allocated memory must be deallocated in reverse order.
  }

interface

type
  {a HugePtr holds a 24 bit physical address - can be cast to a LongInt and
   vice versa for indexing purposes}
  HugePtr = Pointer;

function PtrToHuge(P : Pointer) : HugePtr;
  {-Converts a pointer to a huge pointer. The pointer must be in the range
    $0:$0 to $FFFF:$000F.}

procedure MoveExtMem(Src, Dest : HugePtr; WCount : Word);
  {-Move WCount words of extended memory from Src to Dest.}

function ExtMemTotal : LongInt;
  {-Returns total number of bytes of extended memory in the system.}

function ExtMemAvail : Word;
  {-Returns the number of KB of extended memory that is actually free.}

function GetExtMem(N : Word) : HugePtr;
  {-Allocate N Kb of extended memory.  Returns Nil if insufficient memory.}

function FreeExtMem(P : HugePtr) : Boolean;
  {-Deallocates extended memory which has been allocated with GetExtMem. It
    works only if the block to deallocate is the last block allocated by your
    program or any other. Returns false if deallocation failed.}

procedure MarkExtMem(var P : HugePtr);
  {-Store the location of the next extended memory block in P}

procedure ReleaseExtMem(P : HugePtr);
  {-Release all extended memory above P. P *must* have been set by
    MarkExtMem. It cannot be a huge pointer returned by GetExtMem.}

  {==========================================================================}

implementation

type
  GDTEntry =
    record
      Limit : Word;          {Limit of segment}
      PhysLo : Word;         {Low word of physical address}
      PhysHi : Byte;         {High word of physical address}
      Access : Byte;         {Access rights}
      Rs386 : Word;          {Reserved for 386}
    end;
  VDiskName = array[1..5] of Char;
  VDiskBase =
    record
      JmpCode : array[1..3] of Byte;
      Name : VDiskName;
      Version : array[1..3] of Char;
      ByteSect : Word;
      SecsClust : Byte;
      ResSecs : Word;
      NumFATs : Byte;
      NumDirs : Word;
      NumSecs : Word;
      MediaD : Byte;
      SecsFat : Word;
    end;
  SegOfs =
    record
      Offset, Segment : Word;
    end;
  AllocationMethod = (VDiskMethod, MSoftMethod);
  DataBlock =
    record
      W1, W2 : Word;         {always 3 and 1?}
      StartAt : HugePtr;     {starting address for the block}
      Size : Word;           {size of the block in KB}
    end;
  MSCtrlBlock =
    record
      Name : array[1..51] of Char; {identifies the control block}
      Flag : Byte;           {? have seen values of 5 and 1}
      KBAvail : Word;        {KB of extended RAM still available}
      FirstBlock : DataBlock; {has address of first block}
      Blocks : array[0..94] of DataBlock; {array of DataBlocks}
      JunkBlock : DataBlock; {? filled with A's and R's}
    end;
  MSoftName = array[1..18] of Char;
  MarkRecord =
    record
      Avail, Index : Word;
    end;
const
  OneMeg = $100000;
  ReadWriteCode = $93;
const
  VDISK : VDiskName = 'VDISK';
const
  MSOFT : MSoftName = 'MICROSOFT EMM CTRL';
const
  FirstBlock : HugePtr = nil;
  ExtMemBasePtr : HugePtr = nil;
  ATclass = $FC;
  Model80 = $F8;
  Method : AllocationMethod = VDiskMethod;
var
  MachineId : Byte absolute $FFFF : $000E;
  GDT : array[0..5] of GDTEntry;
  VDBptr : HugePtr;
  VDB : VDiskBase;
var
  AllowAllocation : Boolean;
  SaveExitProc : Pointer;

  function PtrToHuge(P : Pointer) : HugePtr;
    {-Converts a pointer to a huge pointer. The pointer must be in the range
      $0:$0 to $FFFF:$000F.}
  begin
    with SegOfs(P) do
      PtrToHuge := HugePtr((LongInt(Segment) shl 4)+LongInt(Offset));
  end;

  procedure MoveExtMemPrim(var GDT; WCount : Word);
    {-Primitive routine to move WCount bytes to/from extended memory}
  inline(
    $59/                     {pop cx               ;CX = WCount}
    $5E/                     {pop si               ;point ES:SI to GDT}
    $07/                     {pop es}
    $B4/$87/                 {mov ah,$87           ;function for block move}
    $CD/$15);                {int $15              ;move memory}

  procedure MoveExtMem(Src, Dest : HugePtr; WCount : Word);
    {-Move WCount words of extended memory from Src to Dest.}
  begin
    {exit if pointer is nil or word count is 0}
    if (Src = nil) or (Dest = nil) or (WCount = 0) or not AllowAllocation then
      Exit;

    GDT[2].PhysLo := Ofs(Src^); {low word of Src in PhysLo}
    GDT[2].PhysHi := Lo(Seg(Src^)); {low byte of high word in PhysHi}
    GDT[3].PhysLo := Ofs(Dest^); {low word of Dest in PhysLo}
    GDT[3].PhysHi := Lo(Seg(Dest^)); {low byte of high word in PhysHi}
    MoveExtMemPrim(GDT, WCount); {now do the move}
  end;

  function ExtMemTotalPrim : LongInt;
    {-Returns total number of bytes of extended memory in the system.}
  inline(
    $B4/$88/                 {mov ah,$88     ;get extended memory function}
    $CD/$15/                 {int $15        ;returns KB avail in AX}
    $B9/$00/$04/             {mov cx,1024    ;CX = 1024 = bytes per KB}
    $F7/$E1);                {mul cx         ;DX:AX has result}

  function ExtMemTotal : LongInt;
    {-Returns total number of bytes of extended memory in the system.}
  begin
    if AllowAllocation then
      ExtMemTotal := ExtMemTotalPrim
    else
      ExtMemTotal := 0;
  end;

  function ExtMemAvailPrim(var MSCB : MSCtrlBlock) : Word;
    {-Primitive routine to return the number of KB of extended memory that is
      actually free.}
  var
    NumBytes, L : LongInt;
    I : Word;
    ValidBlock : Boolean;
    MSN : MSoftName absolute MSCB;
  begin
    {assume no memory available}
    ExtMemAvailPrim := 0;

    {exit if we're not running DOS 3.0}
    if not AllowAllocation then
      Exit;

    {get amount of extended memory above 1MB}
    NumBytes := ExtMemTotalPrim+OneMeg;

    if NumBytes > OneMeg then begin
      {see if there's a Microsoft control block}
      MoveExtMem(HugePtr(OneMeg), PtrToHuge(@MSCB), SizeOf(MSCB) shr 1);
      if MSN = MSOFT then
        Method := MSoftMethod
      else
        Method := VDiskMethod;

      if Method = MSoftMethod then
        {MICROSOFT method: use extended memory control block}
        with MSCB, MarkRecord(ExtMemBasePtr) do begin
          {find first free data block}
          I := 0;
          while (Blocks[I].StartAt <> nil) and (I <= 94) do
            Inc(I);

          {store KBAvail and index of first free data block in ExtMemBasePtr}
          Avail := KBAvail;
          Index := I;

          {return KB available if I <= 94}
          if I <= 94 then
            ExtMemAvailPrim := KBAvail;
        end
      else
        {VDISK method: search for memory blocks starting at 1MB}
        with VDB do begin
          L := OneMeg;
          repeat
            MoveExtMem(HugePtr(L), VDBptr, SizeOf(VDB) shr 1);
            ValidBlock := (Name = VDISK);
            if ValidBlock then begin
              {deal with problem caused by Oracle's TSR}
              if (ByteSect or NumSecs) = 0 then begin
                AllowAllocation := False;
                ExtMemBasePtr := nil;
                ExtMemAvailPrim := 0;
                Exit;
              end;
              Inc(L, LongInt(ByteSect)*NumSecs);
            end;
          until (L >= NumBytes) or not(ValidBlock);

          if not(ValidBlock) then begin
            {side effect! set ExtMemBasePtr}
            ExtMemBasePtr := HugePtr(L);
            L := (NumBytes-L)-SizeOf(VDiskBase);
            if L > 0 then
              {divide bytes by 1024}
              ExtMemAvailPrim := L shr 10;
          end;
        end;
    end;
  end;

  function ExtMemAvail : Word;
    {-Returns the number of KB of extended memory that is actually free.}
  var
    MSCB : MSCtrlBlock;
  begin
    {call primitive routine}
    ExtMemAvail := ExtMemAvailPrim(MSCB);
  end;

  function GetExtMem(N : Word) : HugePtr;
    {-Allocate N KB of extended memory.  Returns Nil if insufficient memory.}
  var
    P : HugePtr;
    MSCB : MSCtrlBlock;
  begin
    {reject request if too small/large, or if we're not running DOS 3.x}
    if (LongInt(N) > ExtMemAvailPrim(MSCB)) or (N = 0) or not AllowAllocation then
      GetExtMem := nil
    else if Method = VDiskMethod then
      with VDB do begin
        {set up fake disk base for other programs}
        FillChar(VDB, SizeOf(VDB), 0);

        {reduce overhead of extra VDB sector for small blocks}
        if N > 4096 then begin
          {Block greater than 4MB}
          ByteSect := 512;   {512 bytes per sector}
          NumSecs := Succ(N shl 1); {2 sectors per KB, 1 extra for fake disk base}
        end
        else begin
          {Block less than or equal to 4MB}
          ByteSect := 128;   {128 bytes per sector}
          NumSecs := Succ(N shl 3); {8 sectors per KB, 1 extra for fake disk base}
        end;

        {make it look real}
        Name := VDISK;
        Version := '2.0';

        {install fake disk base}
        MoveExtMem(VDBptr, ExtMemBasePtr, SizeOf(VDB) shr 1);

        {return huge pointer to usable memory block}
        GetExtMem := HugePtr(LongInt(ExtMemBasePtr)+SizeOf(VDB));
      end
    else
      with MSCB, MarkRecord(ExtMemBasePtr) do begin
        {calculate starting address for our block}
        with Blocks[Pred(Index)] do
          P := HugePtr(LongInt(StartAt)+(LongInt(Size) shl 10));

        {fix memory control block}
        Dec(KBAvail, N);
        Blocks[Index] := Blocks[Pred(Index)];
        with Blocks[Index] do begin
          StartAt := P;
          Size := N;
        end;
        MoveExtMem(PtrToHuge(@MSCB), HugePtr(OneMeg), SizeOf(MSCB) shr 1);

        {fix ExtMemBasePtr}
        Inc(Index);
        Avail := KBAvail;

        {return huge pointer to the memory block}
        GetExtMem := P;
      end;
  end;

  function FreeExtMem(P : HugePtr) : Boolean;
    {-Deallocates extended memory which has been allocated with GetExtMem. It
      works only if the block to deallocate is the last block allocated by your
      program or any other. Returns false if deallocation failed.}
  var
    I, J, N : Word;
    NumBytes, L,
    BaseAddress, LastL : LongInt;
    ValidBlock : Boolean;
    MSCB : MSCtrlBlock;
    Blank : DataBlock;
  label
    Found;
  begin
    {assume failure}
    FreeExtMem := False;

    {exit if pointer is nil}
    if (P = nil) or not AllowAllocation then
      Exit;

    {see if we're using the MicroSoft method}
    if Method = MSoftMethod then
      with MSCB do begin
        {get a copy of the control block}
        MoveExtMem(HugePtr(OneMeg), PtrToHuge(@MSCB), SizeOf(MSCB) shr 1);

        {get base address to search for}
        BaseAddress := LongInt(P);

        {search for the appropriate entry in the table of data blocks}
        for I := 0 to 94 do
          if Blocks[I].StartAt = HugePtr(BaseAddress) then
            goto Found;

        {if we get here we failed}
        Exit;
Found:
        {find the next available block}
        N := I;
        while Blocks[N].StartAt <> nil do
          Inc(N);
        Dec(N);

        {reset available memory}
        for J := I to N do
          Inc(KBAvail, Blocks[J].Size);

        {wipe out the appropriate records}
        FillChar(Blank, SizeOf(Blank), 0);
        for J := I to N do
          Blocks[J] := Blank;

        {move the fixed control block into place}
        MoveExtMem(PtrToHuge(@MSCB), HugePtr(OneMeg), SizeOf(MSCB) shr 1);

        {reset ExtMemBasePtr}
        MarkRecord(ExtMemBasePtr).Index := I;
        MarkRecord(ExtMemBasePtr).Avail := KBAvail;

        {success}
        FreeExtMem := True;
      end
    else begin
      {get amount of extended memory above 1MB}
      NumBytes := ExtMemTotalPrim+OneMeg;

      {get base address to search for}
      BaseAddress := LongInt(P)-SizeOf(VDB);

      if (NumBytes > OneMeg) then
        with VDB do begin
          {search for target memory block starting at 1MB}
          L := OneMeg;
          LastL := 0;
          repeat
            MoveExtMem(HugePtr(L), VDBptr, SizeOf(VDB) shr 1);
            ValidBlock := (Name = VDISK);
            if ValidBlock then begin
              {save the current value of L}
              LastL := L;
              {point to start of next block}
              Inc(L, LongInt(ByteSect)*NumSecs);
            end;
          until (L >= NumBytes) or not(ValidBlock);

          if (LastL = BaseAddress) then begin
            {wipe out the fake disk base at the address}
            FillChar(VDB, SizeOf(VDB), 0);
            MoveExtMem(VDBptr, HugePtr(BaseAddress), SizeOf(VDB) shr 1);
            FreeExtMem := True;
          end;
        end;
    end;
  end;

  procedure MarkExtMem(var P : HugePtr);
    {-Store the location of the next extended memory block in P}
  var
    I : Word;
  begin
    {this initializes ExtMemBasePtr}
    I := ExtMemAvail;

    {store info about the next free block}
    P := ExtMemBasePtr;
  end;

  procedure ReleaseExtMem(P : HugePtr);
  {-Release all extended memory above P. P *must* have been set by
    MarkExtMem. It cannot be a huge pointer returned by GetExtMem.}
  var
    NumBytes : LongInt;
    SizeOfBlock : LongInt;
    Total, L : LongInt;
    I : Word;
    ValidBlock : Boolean;
    MSCB : MSCtrlBlock;
    Blank : DataBlock;
  begin
    Total := ExtMemTotalPrim;
    {do nothing if P is nil}
    if P <> nil then
      if Method = MSoftMethod then
        with MSCB, MarkRecord(P) do begin
          {make sure numbers look valid}
          if (Index > 94) or (Avail > Total) then
            Exit;

          {get a copy of the control block}
          MoveExtMem(HugePtr(OneMeg), PtrToHuge(@MSCB), SizeOf(MSCB) shr 1);

          {wipe out the appropriate records}
          FillChar(Blank, SizeOf(Blank), 0);
          for I := Index to MarkRecord(ExtMemBasePtr).Index do
            Blocks[I] := Blank;

          {reset available memory}
          KBAvail := Avail;

          {move the fixed control block into place}
          MoveExtMem(PtrToHuge(@MSCB), HugePtr(OneMeg), SizeOf(MSCB) shr 1);

          {reset ExtMemBasePtr}
          ExtMemBasePtr := P;
        end
      else begin
        {get amount of extended memory above 1MB}
        NumBytes := Total+OneMeg;

        {cast to longint}
        L := LongInt(P);

        {make sure address looks valid}
        if (L >= LongInt(FirstBlock)) and (L < NumBytes) then
          with VDB do
            {search for memory blocks starting at specified block}
            repeat
              MoveExtMem(HugePtr(L), VDBptr, SizeOf(VDB) shr 1);
              ValidBlock := (Name = VDISK);
              if ValidBlock then begin
                SizeOfBlock := LongInt(ByteSect)*NumSecs;

                {wipe out the fake disk base at the address}
                FillChar(VDB, SizeOf(VDB), 0);
                MoveExtMem(VDBptr, HugePtr(L), SizeOf(VDB) shr 1);

                {Move to next block}
                Inc(L, SizeOfBlock);
              end;
            until (L >= NumBytes) or not(ValidBlock);
      end;
  end;

  function DosVersion : Word;
    {-Returns major version in high byte, minor in low}
  inline(
    $B8/$00/$30/             {mov ax,$3000 ;get DOS version number}
    $CD/$21/                 {int $21      ;call DOS}
    $86/$C4);                {xchg ah,al   ;major in high, minor in low}

  procedure InitializeExtMem;
    {-Initialization stuff}
  var
    I : Word;
    P : HugePtr;
  begin
    {intialize GDT}
    FillChar(GDT, SizeOf(GDT), 0);

    {loop through}
    for I := 1 to 5 do begin
      {limit on all is $FFFF}
      GDT[I].Limit := $0FFFF;

      {assume all have data R/W byte}
      GDT[I].Access := ReadWriteCode;
    end;

    {get huge pointer to GDT[0] in P}
    P := PtrToHuge(@GDT[0]);

    GDT[1].PhysLo := Ofs(P^); {low word of address in PhysLo}
    GDT[1].PhysHi := Lo(Seg(P^)); {lo byte of hi word in PhysHi}

    {get huge pointer to VDB}
    VDBptr := PtrToHuge(@VDB);

    {don't allow allocation if running PC or XT, or under DOS 2.x or OS/2}
(*
    AllowAllocation := False;                         !!.12
    case Hi(DosVersion) of
      3..4 :
        case MachineId of
          ATclass, Model80 : AllowAllocation := True;
        end;
    end;
*)
    case Hi(DosVersion) of                            {!!.12}
      1, 2, 10 : AllowAllocation := False;            {!!.12}
      else                                            {!!.12}
        case MachineId of                             {!!.12}
          ATClass, Model80 : AllowAllocation := True; {!!.12}
          else AllowAllocation := False;              {!!.12}
        end;                                          {!!.12}
    end;                                              {!!.12}
    {$IFDEF Debug}
      writeln('DosVersion = ', Hi(DosVersion), '.', Lo(DosVersion));
      writeln('MachineId = ', MachineId);
      writeln('AllowAllocation = ', AllowAllocation);
      writeln('ExtMemTotalPrim = ', ExtMemTotalPrim);
    {$ENDIF}

    {mark the location of the next memory block}
    if AllowAllocation then
      MarkExtMem(FirstBlock);
  end;

  procedure ExtMemExitProc;
    {-Exit handler to free allocated extended memory}
  begin
    {restore previous exit handler}
    ExitProc := SaveExitProc;

    {release any memory we've allocated}
    ReleaseExtMem(FirstBlock);
  end;

begin
  {initialize}
  InitializeExtMem;

  {set up exit proc}
  SaveExitProc := ExitProc;
  ExitProc := @ExtMemExitProc;
end.
