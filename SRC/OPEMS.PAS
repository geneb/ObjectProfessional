{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$IFDEF Dpmi}                                                         {!!.20}
  !! This unit cannot be used in protected mode !!                    {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F-,O-,A-}

{$I OPDEFINE.INC}

{*********************************************************}
{*                   OPEMS.PAS 1.30                      *}
{*       Copyright (c) TurboPower Software 1987, 1992.   *}
{* Portions copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit OpEms;
  {-EMS memory management routines}

interface

Uses Dos;                    {!!.03}

const
  EmsErrorCode = $0FFFF;     {Used by several functions to signal an error}

{begin !!.03}
  MaxHandles   = 64;         {maximum number of handles for HandlePagesType}
  {NOTE: Some EMS drivers support up to 255 handles}

  MaxMappablePages = 64;     {maximum number of mappable segments for
                              MappableSegType}
  EmsResult : Byte = 0;      {last EMS error}

type
  PageInfoType =             {used by HandlePagesType type}
    record
      Handle : Word;
      Pages  : Word;
    end;
  HandlePagesType =          {type used by GetPagesForAll}
    record
      NumHandles : Word;
      PageInfo   : Array[1..MaxHandles] of PageInfoType;
    end;
  MappableSegType =          {type used by EMS 4.0 partial mapping routines}
    record
      NumPages : Word;
      Segments : Array[1..MaxMappablePages] of Word;
    end;
  PageMapType =              {type used in PageMapList}
    record
      Logical  : Integer;
      Physical : Word;
    end;
  PageMapList =
    Array[1..MaxMappablePages] of PageMapType; {type used by
                                                MapPagesByNumber and
                                                MapPagesByAddress}
  HandleNameType = Array[1..8] of Char; {native format of EMS handle name}
  HandleNameStr  = String[8];           {TP string format of EMS handle name}
  HandleNameRec  =                      {type used by HandleNameList}
    record
      Handle : Word;
      Name   : HandleNameType;
    end;
  HandleNameList =           {type used by GetAllHandleNames}
    record
      NumNames : Byte;                                  {num names in NameList}
      NameList : Array[1..MaxHandles] of HandleNameRec; {handles and names}
    end;
  MemoryType =
    (Conventional, Expanded); {the two memory type used by EmsPtrRecord}
  EmsPtrRecord =              {used when memory is of type Expanded}
    record
      Offset : Word;
      Page   : Word;
    end;
  EmsPtrType =   {a variant record to represent either a pointer to real or EMS}
    record
      case Boolean of
        False : (ConventionalPtr : Pointer);    {a normal real pointer}
        True  : (ExpandedPtr : EmsPtrRecord);   {a pointer to EMS memory}
    end;
  MoveRecord =   {record structure used internally by MoveMemoryRegion}
    record
      Len               : LongInt;    {number of bytes to move}
      SourceType        : MemoryType; {source memory type}
      SourceHandle      : Word;       {source's EMS handle}
      SourcePtr         : EmsPtrType; {pointer to the source memory}
      DestinationType   : MemoryType; {destination memory type}
      DestinationHandle : Word;       {destination's EMS handle}
      DestinationPtr    : EmsPtrType; {pointer to the destination memory}
    end;
  MappablePageType =   {used in MappablePageList to describe a physical page}
    record
      Segment      : Word;
      PhysicalPage : Word;
    end;
  MappablePageList =   {a list of all mappable pages}
    record
      NumPages : Word;
      Pages    : Array[1..MaxMappablePages] of MappablePageType;
    end;
  HardwareConfigType = {a record of information about the EMS configuration}
    record
      RawPageSize    : Word;    {size of raw EMS pages in paragraphs}
      AltRegSets     : Word;    {number of alternate register sets}
      ContextSize    : Word;    {size of context save area in bytes}
      DMARegSets     : Word;    {number of register sets assignable to DMA}
      DMAOpType      : Word;    {0 = DMA can be used with alternate reg sets
                                 1 = Only one DMA reg set available}
    end;

{end !!.03}

function EmsInstalled : Boolean;
  {-Returns true if the EMM is installed.}

function EmmSigFound : Boolean;
  {-Returns True if EMM signature found}

function EmsStatusOK : Boolean;
  {-Returns true if the EMM reports its status as being OK.}

function EmsPagesAvail : Word;
 {-Returns the number of available pages from the expanded memory manager,
   or EmsErrorCode in case of error.}

function EmsTotalPages : Word;
 {-Returns total number of pages of EMS memory, including allocated pages,
   or EmsErrorCode in case of error.}

function EmsPageFramePtr : Pointer;
  {-Returns the page frame base address as a pointer to the page frame.}

function AllocateEmsPages(NumPages : Word) : Word;
 {-Allocates the indicated number of pages and returns a handle.
   Returns EmsErrorCode in case of error.}

function MapEmsPage(Handle, LogicalPage : Word; PhysicalPage : Byte) : Boolean;
 {-Maps the specified LogicalPage associated with Handle into PhysicalPage
   (0-3). Returns true if successful.}

function DeallocateEmsHandle(Handle : Word) : Boolean;
  {-Deallocates the indicated handle and the memory associated with it.}

function EmsVersion : Byte;
 {-Returns a BCD version number of the EMM handle. To check for version 3.2
   or greater for example, use: 'if EmsVersion >= $32 then'. Returns 0 in
   case of error.}

function SaveEmsContext(Handle : Word) : Boolean;
 {-Saves the EMM context for resident programs. The handle passed must have
   been allocated with a call to AllocateEmsPages. Returns true if
   successful.}

function RestoreEmsContext(Handle : Word) : Boolean;
 {-Restores the mapping context of the EMM driver for the handle specified.
   The handle should the same one used in a prior call to SaveEmsContext.
   Returns true if successful.}

function EmsActiveHandles : Word;
  {-Returns the number of active EMS handles, EmsErrorCode in case of error}

function EmsPagesOwned(Handle : Word) : Word;
  {-Returns the number of pages owned by Handle, or EmsErrorCode in case of error.}

{begin !!.03}
function GetPagesForAll(var HandlePages : HandlePagesType) : Boolean;
  {-Return the number of pages allocated for each active handle.  Function
    result is true if successful in returning the information}

{the following function calls are LIM 3.2 specific (all added !!.03)}

function SavePageMap(var Buffer) : Boolean;
  {-Save the page map to a buffer.  Returns True if successful.  Buffer
    must be at least as big as the value returned by GetSizeOfPageMap.}

function RestorePageMap(var Buffer) : Boolean;
  {-Restore the page map to a buffer.  Returns True if successful.  Buffer
    must contain information obtained by calling SavePageMap.}

function GetSizeOfPageMap : Byte;
  {-Return the size in bytes of the buffer needed to store the page map.
    Returns zero if there is an error.}

{the following function calls are LIM 4.0 specific (all added !!.03)}

function SavePartialPageMap(var MapList : MappableSegType;
                            var Buffer) : Boolean;
  {-Save partial page map into buffer. Returns true if successful. Buffer
    must be at least as big as the value returned by GetSizeOfPartialPageMap
    (given the same number of pages as specified in MapList). Requires EMS
    version 4.0.}

function RestorePartialPageMap(var Buffer) : Boolean;
  {-Restore a partial page map from buffer. Returns True if successful.
    Buffer must have been previously used in a call to SavePartialPageMap.
    Requires EMS version 4.}

function GetSizeOfPartialPageMap(NumPages : Word) : Byte;
  {-Return the size of the buffer needed to save partial page map info for
    NumPages pages. Returns 0 if an error occurs. Requires EMS version 4.}

function MapPagesByNumber(NumPages : Word; Handle : Word;
                          var MappingInfo : PageMapList) : Boolean;
  {-Maps multiple pages by number. NumPages pages are mapped for Handle
    using the information contained within MappingInfo. Returns true if
    successful. If a Logical page number is -1 then the physical page is
    unmapped. The physical field of the PageMapType is used to hold the
    physical page's number. Requires EMS version 4.}

function MapPagesByAddress(NumPages : Word; Handle : Word;
                           var MappingInfo : PageMapList) : Boolean;
  {-Maps multiple pages by Address. NumPages pages are mapped for Handle
    using the information contained within MappingInfo. Returns true if
    successful. If a Logical page number is -1 then the physical page is
    unmapped. The Physical field of the PageMapType is used to hold the
    segment of the page. Requires EMS version 4.}

function ReallocatePages(Handle : Word; NewPages : Word) : Boolean;
  {-Reallocates the number of pages for the specified handle. NewPages may
    be zero (the handle is still active and may be resized later). Returns
    True is successful.}

function GetHandleAttr(Handle : Word; var Volatile : Boolean) : Boolean;
  {-Returns the attribute of the specified handle in Volatile. If Volatile
    is True, then the handle refers to a volatile EMS handle, if false, then
    it is non-volatile (its contents will be maintained across a warm boot).
    Function returns True if successful in returning attribute.}

function SetHandleAttr(Handle : Word; Volatile : Boolean) : Boolean;
  {-Set a handle's attribute. Returns True if successful, False if invalid
    Handle or function not supported. If Volatile is False, and this
    function succeeds, then the contents of the EMS pages allocated to
    Handle will be maintained across a warm boot.}

function AttributeSupported : Boolean;
  {-Returns True if the EMS driver supports the Get/SetHandleAttr functions.}

function GetHandleName(Handle : Word; var Name : HandleNameStr) : Boolean;
  {-Returns the Name of Handle. The name for a handle is set with a call to
    SetHandleName. This function returns True if the name was successfully
    returned. A Handle's name is initialized to the empty string when it is
    allocated or deallocated.}

function SetHandleName(Handle : Word; Name : HandleNameStr) : Boolean;
  {-Set the name of the specified Handle. Returns True if successful.}

function GetAllHandleNames(var List : HandleNameList) : Boolean;
  {-Get the names of all active handles. Returns True as function result if
    successful.}

function SearchForHandleName(Name : HandleNameStr;
                             var Handle : Word) : Boolean;
  {-Search for the specified name and return handle of match if found.
    Returns True as function results if successful. If no match is found,
    function result is false.}

function MoveMemoryRegion(SrcType : MemoryType;
                          SrcHandle : Word;
                          SrcPtr : EmsPtrType;
                          DestType : MemoryType;
                          DestHandle : Word;
                          DestPtr : EmsPtrType;
                          Size : LongInt) : Boolean;
  {-Move a memory region. Returns True as function result if successful.
    Maximum size of region to move is one megabyte. If the length exceeds a
    single page, consecutive pages supply or receive the data. Overlapping
    addresses are handled correctly.

    The type EmsPtrType is used to pass the address of the regions. The
    MemoryType defines how the EmsPtrType is interpreted. If MemoryType
    is Conventional, then the EmsPtrType is interpreted as a regular pointer.
    EmsPtrType is a variant record.  Given the following declarations:

    const
      OurSrcType  : MemoryType = Conventional;
      OurDestType : MemoryType = Expanded;

    var
      OurSrcPtr : EmsPtrType;
      OurDestPtr
      P : Pointer;
      EmsPage : Word;
      EmsOfst : Word;
      EmsHandle : Word;
      OK : Boolean;

    Assume P is pointing to the memory we want to be the source of the move,
    and EmsPage, EmsHandle, and EmsOfst are initialized, then we would do
    the following to call MoveMemoryRegion:

    begin
      OurSrcPtr.ConventionalPtr := P;
      with OurDestPtr.ExpandedPtr do begin
        Offset := EmsOfst;
        Page   := EmsPage;
      end;
      OK := MoveMemoryRegion(OurSrcType, 0, OurSrcPtr, EmsHandle,
                             OurDestType, EmsHandle, OurDestPtr);
    end;
    }

function ExchangeMemoryRegion(SrcType : MemoryType;
                              SrcHandle : Word;
                              SrcPtr : EmsPtrType;
                              DestType : MemoryType;
                              DestHandle : Word;
                              DestPtr : EmsPtrType;
                              Size : LongInt) : Boolean;
  {-Exchange two memory regions. Returns True as function result if
    successful. Parameters have the same meaning as in MoveMemoryRegion. One
    difference is that the memory regions may not overlap in this routine.}

function GetNumberMappablePages : Word;
 {-Return the number of mappable pages.  Returns zero if error.}

function GetAddrMappablePages(var List : MappablePageList) : Boolean;
  {-Return the addresses of all mappable pages. Returns True as function
    result if successful. Will fail if EMS supports more mappable pages
    than the constant MaxMappablePages.}

function GetHardwareConfig(var Config : HardwareConfigType) : Boolean;
  {-Return information about the EMS hardware configuration.  See
    HardwareConfigType definition for description of returned information.
    Returns True as function result if successful.}

function GetNumberOfRawPages(var Total, Free : Word) : Boolean;
  {-Return the number of raw Pages. Returns both the total and the number of
    raw pages free. Returns True as function result if successful. Raw pages
    may have a size other than 16k.}

function EmsErrorMessage(ErrorCode : Byte) : String;
  {-Return an error message for ErrorCode.}

{end !!.03}
  {==========================================================================}

implementation

const
  EmsDevice : String[9] = 'EMMXXXX0'#0;

  function EmsInstalled : Boolean;                      {!!}
    {-Returns true if the EMM is installed.}
  begin
    Inline(
      $C6/$46/<EMSINSTALLED/$00/ {        MOV     BYTE PTR <EmsInstalled[BP],0  ;assume False}
      $B8/$67/$35/           {        MOV     AX,$3567                ;Get INT 67 vector}
      $CD/$21/               {        INT     $21                     ;call DOS}
      $8C/$C0/               {        MOV     AX,ES                   ;is vector nil?}
      $09/$D8/               {        OR      AX,BX}
      $75/$02/               {        JNZ     EInstChk                ;if not, pointing to iret?}
      $EB/$4F/               {        JMP     SHORT EInstDone}
                             {EInstChk:}
      $26/$80/$3F/$CF/       {ES:     CMP     BYTE PTR [BX],$CF       ;is vector pointing to an IRET?}
      $75/$02/               {        JNE     EInstChk2               ;if not, check for the driver}
      $EB/$47/               {        JMP     SHORT EInstDone}
                             {EInstChk2:}
      $BA/>EMSDEVICE/        {        MOV     DX,>EmsDevice}
      $42/                   {        INC     DX                      ;skip length byte}
      $B8/$02/$3D/           {        MOV     AX,$3D02                ;Open for read/write}
      $CD/$21/               {        INT     $21}
      $89/$C3/               {        MOV     BX,AX                   ;Save handle in case one returned}
      $72/$3A/               {        JC      EInstDone               ;Failed if carry flag set}
      $B8/$00/$44/           {        MOV     AX,$4400                ;make sure it is a character device}
      $CD/$21/               {        INT     $21}
      $72/$2F/               {        JC      EInstFail               ;Failed if carry flag set}
      $81/$E2/$80/$00/       {        AND     DX,$80                  ;Bit 7 = 1 if character device}
      $74/$29/               {        JZ      EInstFail}
      $B8/$07/$44/           {        MOV     AX,$4407                ;make sure device is ready for output}
      $CD/$21/               {        INT     $21}
      $72/$22/               {        JC      EInstFail               ;Failed if carry flag set}
      $08/$C0/               {        OR      AL,AL                   ;if AL = 0 EMM is not available}
      $74/$1E/               {        JZ      EInstFail}
      $53/                   {        PUSH    BX}
      $B4/$30/               {        MOV     AH,$30                  ;get DOS version}
      $CD/$21/               {        INT     $21}
      $5B/                   {        POP     BX}
      $86/$C4/               {        XCHG    AH,AL}
      $3D/$0A/$03/           {        CMP     AX,$030A                ;DOS version 3.1 or greater?}
      $72/$0D/               {        JB      ENotDos31               ;no, so skip next IOCtrl call}
      $B8/$0A/$44/           {        MOV     AX,$440A                ;IOCtrl function A, is file local}
      $CD/$21/               {        INT     $21}
      $72/$06/               {        JC      ENotDos31               ;if error, assume local file}
      $81/$E2/$00/$80/       {        AND     DX,$8000                ;local file if bit 15 of DX is clear}
      $75/$04/               {        JNZ     EInstFail}
                             {ENotDos31:}
      $C6/$46/<EMSINSTALLED/$01/ {        MOV     BYTE PTR <EmsInstalled[BP],1  ;Return true}
                             {EInstFail:}
      $B4/$3E/               {        MOV     AH,$3E                  ;Close file to recover handle}
      $CD/$21);              {        INT     $21}
                             {EInstDone:}
  end;

  function EmsStatusOK : Boolean;
    {-Returns true if the EMM reports its status as being OK.}
  begin
  Inline(
    $B4/$40/               {  MOV   AH,$40       ;get manager status function}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $80/$FC/$00/           {  CMP   AH,0         ;set function result}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JE    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<EMSSTATUSOK); {  MOV   <EmsStatusOK[BP],AL}
  end;

  function EmsPagesAvail : Word;
   {-Returns the number of available pages from the expanded memory manager,
     or EmsErrorCode in case of error.}
  begin
  Inline(
    $B4/$42/               {  MOV   AH,$42     ;get number of pages avail}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $89/$D8/               {  MOV   AX,BX      ;num pages in BX}
    $74/$03/               {  JZ    ExitPoint}
    $B8/$FF/$FF/           {  MOV   AX,$FFFF   ;return EmsErrorCode}
                           {ExitPoint:}
    $89/$46/<EMSPAGESAVAIL);{  MOV   <EmsPagesAvail[BP],AX}
  end;

  function EmsTotalPages : Word;
   {-Returns total number of pages of EMS memory, including allocated pages,
     or EmsErrorCode in case of error.}
  begin
  Inline(
    $B4/$42/               {  MOV   AH,$42     ;get number of pages avail}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $89/$D0/               {  MOV   AX,DX      ;total pages in DX}
    $74/$03/               {  JZ    ExitPoint}
    $B8/$FF/$FF/           {  MOV   AX,$FFFF   ;return EmsErrorCode}
                           {ExitPoint:}
    $89/$46/<EMSTOTALPAGES);{  MOV   <EmsTotalPages[BP],AX}

  end;

  function EmsPageFramePtr : Pointer;
    {-Returns the page frame base address as a pointer to the page frame.}
  begin
  Inline(
    $B4/$41/               {  MOV   AH,$41     ;get page frame segment}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH      ;check for error}
    $B8/$00/$00/           {  MOV   AX,0       ;offset is zero in any case}
    $74/$02/               {  JZ    ExitPoint  ;done if no error}
    $31/$DB/               {  XOR   BX,BX      ;return NIL}
                           {ExitPoint:}
    $89/$46/<EMSPAGEFRAMEPTR/  {  MOV   <EmsPageFramePtr[BP],AX}
    $89/$9E/>EMSPAGEFRAMEPTR+$0002);{  MOV   <EmsPageFramePtr[BP+2],BX}
  end;

  function AllocateEmsPages(NumPages : Word) : Word;
   {-Allocates the indicated number of pages and returns a handle.
     Returns EmsErrorCode in case of error.}
  begin
  Inline(
    $B4/$43/               {  MOV   AH,$43             ;alloc memory and get handle}
    $8B/$5E/<NUMPAGES/     {  MOV   BX,<NumPages[BP]   ;bx = NumPages}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $74/$03/               {  JZ    ExitPoint}
    $BA/$FF/$FF/           {  MOV   DX,$FFFF           ;return EmsErrorCode}
                           {ExitPoint:}
    $89/$56/<ALLOCATEEMSPAGES);{  MOV   <AllocateEmsPages[BP],DX}
  end;

  function MapEmsPage(Handle, LogicalPage : Word; PhysicalPage : Byte) : Boolean;
   {-Maps the specified LogicalPage associated with Handle into PhysicalPage
     (0-3). Returns true if successful.}
  begin
  Inline(
    $8A/$46/<PHYSICALPAGE/ {  MOV   AL,<PhysicalPage[BP] ;AL=PhysicalPage}
    $8B/$5E/<LOGICALPAGE/  {  MOV   BX,<LogicalPage[BP]  ;BX=LogicalPage}
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]       ;DX=Handle}
    $B4/$44/               {  MOV   AH,$44               ;map the page}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH                ;success if AH=0}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<MAPEMSPAGE);  {  MOV   <MapEmsPage[BP],AL   ;boolean func result}
  end;

  function DeallocateEmsHandle(Handle : Word) : Boolean;
    {-Deallocates the indicated handle and the memory associated with it.}
  begin
  Inline(
    $B4/$45/               {  MOV   AH,$45}
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<DEALLOCATEEMSHANDLE);{  MOV   <DeallocateEmsHandle[BP],AL}
  end;

  function EmsVersion : Byte;
   {-Returns a BCD version number of the EMM handle. To check for version 3.2
     or greater for example, use: 'if EmsVersion >= $32 then'. Returns 0 in
     case of error.}
  begin
  Inline(
    $B4/$46/               {  MOV   AH,$46     ;get EMM version no.}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH      ;success if AH=0}
    $74/$02/               {  JZ    ExitPoint}
    $30/$C0/               {  XOR   AL,AL}
                           {ExitPoint:}
    $88/$46/<EMSVERSION);  {  MOV   <EmsVersion[BP],AL}
  end;

  function SaveEmsContext(Handle : Word) : Boolean;
   {-Saves the EMM context for resident programs. The handle passed must have
     been allocated with a call to AllocateEmsPages. Returns true if
     successful.}
  begin
  Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]  ;DX=Handle}
    $B4/$47/               {  MOV   AH,$47          ;save EMS context}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<SAVEEMSCONTEXT);{  MOV   <SaveEmsContext[BP],AL}
  end;

  function RestoreEmsContext(Handle : Word) : Boolean;
   {-Restores the mapping context of the EMM driver for the handle specified.
     The handle should the same one used in a prior call to SaveEmsContext.
     Returns true if successful.}
  begin
  Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]  ;DX=Handle}
    $B4/$48/               {  MOV   AH,$48          ;restore EMS context}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<RESTOREEMSCONTEXT);{  MOV   <RestoreEmsContext[BP],AL}
  end;

  function EmsActiveHandles : Word;
    {-Returns the number of active EMS handles, EmsErrorCode in case of error}
  begin
  Inline(
    $B4/$4B/               {  MOV   AH,$4B     ;get active EMM handles}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $74/$03/               {  JZ    ExitPoint}
    $BB/$FF/$FF/           {  MOV   BX,$FFFF   ;return EmsErrorCode}
                           {ExitPoint:}
    $89/$5E/<EMSACTIVEHANDLES);{  MOV   <EmsActiveHandles[BP],BX}
  end;

  function EmsPagesOwned(Handle : Word) : Word;
    {-Returns the number of pages owned by Handle, or EmsErrorCode in case of error.}
  begin
  Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]  ;DX=Handle}
    $B4/$4C/               {  MOV   AH,$4C          ;get pages owned}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $74/$03/               {  JZ    ExitPoint}
    $BB/$FF/$FF/           {  MOV   BX,$FFFF        ;return EmsErrorCode}
                           {ExitPoint:}
    $89/$5E/<EMSPAGESOWNED);{  MOV   <EmsPagesOwned[BP],BX}
  end;

  function EmmSigFound : Boolean;
    {-Returns True if EMM signature found}
  type
    Sig    = array[1..8] of Char;
    SigPtr = ^Sig;
  var
    Int67  : Pointer;                        {!!.03}
    Sig1   : SigPtr;
    Sig2   : SigPtr;
  begin
    GetIntVec($67, Int67);
    if Int67 = nil then
      EmmSigFound := False
    else begin
      {Sig1 points 10 bytes past the start of the segment for INT $67}
      Sig1 := Ptr(Seg(Int67^), $0A);

      {Sig2 points to 'EMMXXXX0'}
      Sig2 := @EmsDevice;
      Inc(Word(Sig2));                       {skip length byte}  {!!.03}
      {match?}
      EmmSigFound := (Sig1^ = Sig2^);
    end;
  end;

{begin !!.03}
  function GetPagesForAll(var HandlePages : HandlePagesType) : Boolean;
    {-Return the number of pages allocated for each active handle.  Function
      result is true if successful in returning the information}
  begin
    if EmsActiveHandles > MaxHandles then begin
      GetPagesForAll := False;
      Exit;
    end;
  Inline(
    $C4/$7E/<HANDLEPAGES/  {  LES   DI, <HandlePages[BP]  ;ES:DI -> HandlePages}
    $47/                   {  INC   DI}
    $47/                   {  INC   DI}
    $B4/$4D/               {  MOV   AH,$4D     ;Get pages for all handles}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$00/               {  MOV   AL,0}
    $75/$07/               {  JNZ   ExitPoint}
    $4F/                   {  DEC   DI}
    $4F/                   {  DEC   DI}
    $26/                   {ES:}
    $89/$1D/               {  MOV   [DI],BX    ;put num active handles in HandlePages.NuHandles}
    $FE/$C0/               {  INC   AL}
                           {ExitPoint:}
    $88/$46/<GETPAGESFORALL);{  MOV   <GetPagesForAll[BP],AL}
  end;

{the following function calls are LIM 3.2 specific (all added !!.03)}

  function SavePageMap(var Buffer) : Boolean;
    {-Save the page map to a buffer.  Returns True if successful.  Buffer
      must be at least as big as the value returned by GetSizeOfPageMap.}
  begin
  Inline(
    $B8/$00/$4E/           {  MOV   AX,$4E00   ;save page map to buffer}
    $C4/$7E/<BUFFER/       {  LES   DI,<Buffer[BP]}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<SAVEPAGEMAP); {  MOV   <SavePageMap[BP],AL}
  end;

  function RestorePageMap(var Buffer) : Boolean;
    {-Restore the page map to a buffer.  Returns True if successful.  Buffer
      must contain information obtained by calling SavePageMap.}
  begin
  Inline(
    $B8/$01/$4E/           {  MOV   AX,$4E01   ;restore page map from buffer}
    $1E/                   {  PUSH  DS}
    $C5/$76/<BUFFER/       {  LDS   SI,<Buffer[BP] ;DS:SI -> Buffer}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<RESTOREPAGEMAP);{  MOV   <RestorePageMap[BP],AL}
  end;

  function SaveAndRestorePageMap(var NewMapping; var OldMapping) : Boolean;
    {-Saves current mapping to OldMapping and restores mapping to NewMapping.
      NewMapping and OldMapping must be at least as big as value returned by
      GetSizeOfPageMap.  NewMapping must have been prepared by a previous call
      to SavePageMap or a previous call to SaveAndRestorePageMap.}
  begin
  Inline(
    $B8/$02/$4E/           {  MOV   AX,$4E02   ;save and restore page map from buffer}
    $1E/                   {  PUSH  DS}
    $C5/$76/<NEWMAPPING/   {  LDS   SI,<NewMapping[BP] ;DS:SI -> NewMapping}
    $C4/$7E/<OLDMAPPING/   {  LES   DI,<OldMapping[BP] ;ES:DI -> OldMapping}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<SAVEANDRESTOREPAGEMAP);{  MOV   <SaveAndRestorePageMap[BP],AL}
  end;

  function GetSizeOfPageMap : Byte;
    {-Return the size in bytes of the buffer needed to store the page map.
      Returns zero if there is an error.}
  begin
  Inline(
    $B8/$03/$4E/           {  MOV   AX,$4E03}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $74/$02/               {  JZ    ExitPoint}
    $30/$C0/               {  XOR   AL,AL}
                           {ExitPoint:}
    $88/$46/<GETSIZEOFPAGEMAP);{  MOV   <GetSizeOfPageMap[BP],AL}
  end;

{the following function calls are LIM 4.0 specific (all added !!.03)}

  function SavePartialPageMap(var MapList : MappableSegType;
                              var Buffer) : Boolean;
    {-Save partial page map into buffer. Returns true if successful. Buffer
      must be at least as big as the value returned by GetSizeOfPartialPageMap
      (given the same number of pages as specified in MapList). Requires EMS
      version 4.0.}
  begin
  Inline(
    $B8/$00/$4F/           {  MOV   AX,$4F00   ;save partial page map}
    $1E/                   {  PUSH  DS}
    $C5/$76/<MAPLIST/      {  LDS   SI,<MapList[BP] ;DS:SI -> MapList}
    $C4/$7E/<BUFFER/       {  LES   DI,<Buffer[BP]  ;ES:DI -> Buffer}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<SAVEPARTIALPAGEMAP);{  MOV   <SavePartialPageMap[BP],AL}
  end;

  function RestorePartialPageMap(var Buffer) : Boolean;
    {-Restore a partial page map from buffer. Returns True if successful.
      Buffer must have been previously used in a call to SavePartialPageMap.
      Requires EMS version 4.}
  begin
  Inline(
    $B8/$01/$4F/           {  MOV   AX,$4F01   ;restore partial page map}
    $1E/                   {  PUSH  DS}
    $C5/$76/<BUFFER/       {  LDS   SI,<Buffer[BP] ;DS:SI -> Buffer}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<RESTOREPARTIALPAGEMAP);{  MOV   <RestorePartialPageMap[BP],AL}
  end;

  function GetSizeOfPartialPageMap(NumPages : Word) : Byte;
    {-Return the size of the buffer needed to save partial page map info for
      NumPages pages. Returns 0 if an error occurs. Requires EMS version 4.}
  begin
  Inline(
    $B8/$02/$4F/           {  MOV   AX,$4F02         ;Get size of partial page map}
    $8B/$5E/<NUMPAGES/     {  MOV   BX,<NumPages[BP] ;BX = NumPages}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $74/$02/               {  JZ    ExitPoint}
    $30/$C0/               {  XOR   AL,AL}
                           {ExitPoint:}
    $88/$46/<GETSIZEOFPARTIALPAGEMAP);{  MOV   <GetSizeOfPartialPageMap[BP],AL}
  end;

  function MapPagesByNumber(NumPages : Word; Handle : Word;
                            var MappingInfo : PageMapList) : Boolean;
    {-Maps multiple pages by number. NumPages pages are mapped for Handle
      using the information contained within MappingInfo. Returns true if
      successful. If a Logical page number is -1 then the physical page is
      unmapped. The physical field of the PageMapType is used to hold the
      physical page's number. Requires EMS version 4.}
  begin
  Inline(
    $B8/$00/$50/           {  MOV   AX,$5000   ;map multiple pages by num}
    $8B/$4E/<NUMPAGES/     {  MOV   CX,<NumPages[BP]    ;CX = NumPages}
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]      ;DX = Handle}
    $1E/                   {  PUSH  DS}
    $C5/$76/<MAPPINGINFO/  {  LDS   SI,<MappingInfo[BP] ;DS:SI -> MappingInfo}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<MAPPAGESBYNUMBER);{  MOV   <MapPagesByNumber[BP],AL}
  end;

  function MapPagesByAddress(NumPages : Word; Handle : Word;
                             var MappingInfo : PageMapList) : Boolean;
    {-Maps multiple pages by Address. NumPages pages are mapped for Handle
      using the information contained within MappingInfo. Returns true if
      successful. If a Logical page number is -1 then the physical page is
      unmapped. The Physical field of the PageMapType is used to hold the
      segment of the page. Requires EMS version 4.}
  begin
  Inline(
    $B8/$01/$50/           {  MOV   AX,$5001   ;map multiple pages by addr}
    $8B/$4E/<NUMPAGES/     {  MOV   CX,<NumPages[BP]    ;CX = NumPages}
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]      ;DX = Handle}
    $1E/                   {  PUSH  DS}
    $C5/$76/<MAPPINGINFO/  {  LDS   SI,<MappingInfo[BP] ;DS:SI -> MappingInfo}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<MAPPAGESBYADDRESS);{  MOV   <MapPagesByAddress[BP],AL}
  end;

  function ReallocatePages(Handle : Word; NewPages : Word) : Boolean;
    {-Reallocates the number of pages for the specified handle. NewPages may
      be zero (the handle is still active and may be resized later). Returns
      True is successful.}
  begin
  Inline(
    $8B/$5E/<NEWPAGES/     {  MOV   BX,<NewPages[BP]  ;BX = NewPages}
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]    ;DX = Handle}
    $B4/$51/               {  MOV   AH,$51            ;reallocate pages for handle}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<REALLOCATEPAGES);{  MOV   <ReallocatePages[BP],AL}
  end;

  function GetHandleAttr(Handle : Word; var Volatile : Boolean) : Boolean;
    {-Returns the attribute of the specified handle in Volatile. If Volatile
      is True, then the handle refers to a volatile EMS handle, if false, then
      it is non-volatile (its contents will be maintained across a warm boot).
      Function returns True if successful in returning attribute.}
  begin
  Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]  ;DX = Handle}
    $B8/$00/$52/           {  MOV   AX,$5200        ;get handle attribute}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B4/$00/               {  MOV   AH,0}
    $75/$0C/               {  JNZ   ExitPoint}
    $FE/$C4/               {  INC   AH}
    $F6/$D0/               {  NOT   AL              ;flip bit}
    $24/$01/               {  AND   AL,1}
    $C4/$7E/<VOLATILE/     {  LES   DI,<Volatile[BP]}
    $26/                   {ES:}
    $88/$05/               {  MOV   [DI],AL}
                           {ExitPoint:}
    $88/$66/<GETHANDLEATTR);{  MOV   <GetHandleAttr[BP],AH}
  end;

  function SetHandleAttr(Handle : Word; Volatile : Boolean) : Boolean;
    {-Set a handle's attribute. Returns True if successful, False if invalid
      Handle or function not supported. If Volatile is False, and this
      function succeeds, then the contents of the EMS pages allocated to
      Handle will be maintained across a warm boot.}
  begin
  Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]  ;DX = Handle}
    $8A/$5E/<VOLATILE/     {  MOV   BL,<Volatile[BP];BL = attribute}
    $F6/$D3/               {  NOT   BL}
    $80/$E3/$01/           {  AND   BL,1}
    $B8/$01/$52/           {  MOV   AX,$5201        ;set handle attribute}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<SETHANDLEATTR);{  MOV   <SetHandleAttr[BP],AL}
  end;

  function AttributeSupported : Boolean;
    {-Returns True if the EMS driver supports the Get/SetHandleAttr functions.}
  begin
  Inline(
    $B8/$02/$52/           {  MOV   AX,$5202   ;get attribute capability}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B3/$00/               {  MOV   BL,0}
    $75/$02/               {  JNZ   ExitPoint  ;return false on ems error}
    $88/$C3/               {  MOV   BL,AL      ;otherwise return true if AL = 1}
                           {ExitPoint:}
    $88/$5E/<ATTRIBUTESUPPORTED);{  MOV   <AttributeSupported[BP],BL}
  end;

  function GetHandleName(Handle : Word; var Name : HandleNameStr) : Boolean;
    {-Returns the Name of Handle. The name for a handle is set with a call to
      SetHandleName. This function returns True if the name was successfully
      returned. A Handle's name is initialized to the empty string when it is
      allocated or deallocated.}
  begin
  Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]  ;DX = Handle}
    $C4/$7E/<NAME/         {  LES   DI,<Name[BP]    ;ES:DI -> Name}
    $47/                   {  INC   DI              ;point past length byte}
    $B8/$00/$53/           {  MOV   AX,$5300        ;Get handle name}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B3/$00/               {  MOV   BL,0            ;assume failure}
    $75/$1D/               {  JNZ   ExitPoint       ;exit if ems error}
    $FE/$C3/               {  INC   BL              ;success}
    $4F/                   {  DEC   DI}
    $26/                   {ES:}
    $C6/$05/$08/           {  MOV   BYTE PTR [DI],8}
    $57/                   {  PUSH  DI}
    $47/                   {  INC   DI}
    $B9/$08/$00/           {  MOV   CX,8}
    $FC/                   {  CLD}
    $30/$C0/               {  XOR   AL,AL           ;look for null char}
    $F2/$AE/               {  REPNE SCASB}
    $5F/                   {  POP   DI}
    $75/$09/               {  JNE   ExitPoint       ;all 8 chars significant}
    $B0/$08/               {  MOV   AL,8}
    $28/$C8/               {  SUB   AL,CL           ;calc length byte}
    $FE/$C8/               {  DEC   AL}
    $26/                   {ES:}
    $88/$05/               {  MOV   [DI],AL         ;set length byte}
                           {ExitPoint:}
    $88/$5E/<GETHANDLENAME);{  MOV   <GetHandleName[BP],BL}
  end;

  function SetHandleName(Handle : Word; Name : HandleNameStr) : Boolean;
    {-Set the name of the specified Handle. Returns True if successfule.}
  var
    NameBuf : Array[1..8] of Char;
  begin
    if Length(Name) > 8 then
      Name[0] := #8;
    FillChar(NameBuf, SizeOf(NameBuf), 0);
    Move(Name[1], NameBuf, Length(Name));
    Inline(
    $8B/$56/<HANDLE/       {  MOV   DX,<Handle[BP]}
    $1E/                   {  PUSH  DS}
    $16/                   {  PUSH  SS}
    $1F/                   {  POP   DS}
    $8D/$76/<NAMEBUF/      {  LEA   SI,<NameBuf[BP]}
    $B8/$01/$53/           {  MOV   AX,$5301}
    $CD/$67/               {  INT   $67}
    $1F/                   {  POP   DS}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $B0/$01/               {  MOV   AL,1}
    $74/$02/               {  JZ    ExitPoint}
    $FE/$C8/               {  DEC   AL}
                           {ExitPoint:}
    $88/$46/<SETHANDLENAME);{  MOV   <SetHandleName[BP],AL}
  end;

  function GetAllHandleNames(var List : HandleNameList) : Boolean;
    {-Get the names of all active handles. Returns True as function result if
      successful.}
  begin
    if EmsActiveHandles > MaxHandles then begin
      {more active handles than we can store}
      GetAllHandleNames := False;
      Exit;
    end;
    Inline(
      $B8/$00/$54/           {  MOV   AX,$5400      ;get all handle names}
      $C4/$7E/<LIST/         {  LES   DI,<List[BP]  ;ES:DI -> List}
      $47/                   {  INC   DI            ;point past NumHandles field}
      $CD/$67/               {  INT   $67}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $4F/                   {  DEC   DI}
      $08/$E4/               {  OR    AH,AH}
      $B3/$00/               {  MOV   BL,0          ;assume failure}
      $75/$05/               {  JNZ   ExitPoint}
      $FE/$C3/               {  INC   BL            ;indicate success}
      $26/                   {ES:}
      $88/$05/               {  MOV   [DI],AL       ;NumHandles = AL}
                             {ExitPoint:}
      $88/$5E/<GETALLHANDLENAMES);{  MOV   <GetAllHandleNames[BP],BL}
  end;

  function SearchForHandleName(Name : HandleNameStr;
                               var Handle : Word) : Boolean;
    {-Search for the specified name and return handle of match if found.
      Returns True as function results if successful. If no match is found,
      function result is false.}
  var
    NameBuf : HandleNameType;
  begin
    if Length(Name) > 8 then
      Name[0] := #8;
    FillChar(NameBuf, SizeOf(NameBuf), 0);
    Move(Name[1], NameBuf, Length(Name));
    Inline(
      $B8/$01/$54/           {  MOV   AX,$5401      ;search for handle name}
      $1E/                   {  PUSH  DS}
      $16/                   {  PUSH  SS}
      $1F/                   {  POP   DS}
      $8D/$76/<NAMEBUF/      {  LEA   SI,<NameBuf[BP]  ;DS:SI -> NameBuf}
      $CD/$67/               {  INT   $67}
      $1F/                   {  POP   DS}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $08/$E4/               {  OR    AH,AH}
      $B0/$00/               {  MOV   AL,0         ;assume failure}
      $75/$08/               {  JNZ   ExitPoint}
      $FE/$C0/               {  INC   AL           ;indicate success}
      $C4/$7E/<HANDLE/       {  LES   DI,<Handle[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV   [DI],DX      ;return Handle}
                             {ExitPoint:}
      $88/$46/<SEARCHFORHANDLENAME);{  MOV   <SearchForHandleName[BP],AL}
  end;

  function GetTotalHandles : Word;
    {-Returns the total number of handles, or zero if an error occurs.}
  begin
  Inline(
    $B8/$02/$54/           {  MOV   AX,$5402      ;get number of handles}
    $CD/$67/               {  INT   $67}
    $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
    $08/$E4/               {  OR    AH,AH}
    $74/$02/               {  JZ    ExitPoint}
    $31/$DB/               {  XOR   BX,BX}
                           {ExitPoint:}
    $89/$5E/<GETTOTALHANDLES);{  MOV   <GetTotalHandles[BP],BX}
  end;

  {NOTE: MapPagesAndJump and MapPagesAndCall not implemented, since they
   make little sense in Pascal}

  function MoveMemoryRegion(SrcType : MemoryType;
                            SrcHandle : Word;
                            SrcPtr : EmsPtrType;
                            DestType : MemoryType;
                            DestHandle : Word;
                            DestPtr : EmsPtrType;
                            Size : LongInt) : Boolean;
    {-Move a memory region. Returns True as function result if successful.
      Maximum size of region to move is one megabyte. If the length exceeds a
      single page, consecutive pages supply or receive the data. Overlapping
      addresses are handled correctly.

      The type EmsPtrType is used to pass the address of the regions. The
      MemoryType defines how the EmsPtrType is interpreted. If MemoryType
      is Conventional, then the EmsPtrType is interpreted as a regular pointer.
      EmsPtrType is a variant record.  Given the following declarations:

      const
        OurSrcType  : MemoryType = Conventional;
        OurDestType : MemoryType = Expanded;

      var
        OurSrcPtr,
        OurDestPtr : EmsPtrType;
        P : Pointer;
        EmsPage : Word;
        EmsOfst : Word;
        EmsHandle : Word;
        OK : Boolean;

      Assume P is pointing to the memory we want to be the source of the move,
      and EmsPage, EmsHandle, and EmsOfst are initialized, then we would do
      the following to call MoveMemoryRegion:

      begin
        OurSrcPtr.ConventionalPtr := P;
        with OurDestPtr.ExpandedPtr do begin
          Offset := EmsOfst;
          Page   := EmsPage;
        end;
        OK := MoveMemoryRegion(OurSrcType, 0, OurSrcPtr, EmsHandle,
                               OurDestType, EmsHandle, OurDestPtr);
      end;
      }
  var
    MoveRec : MoveRecord;

  begin
    with MoveRec do begin
      Len               := Size;
      SourceType        := SrcType;
      SourceHandle      := SrcHandle;
      SourcePtr         := SrcPtr;
      DestinationType   := DestType;
      DestinationHandle := DestHandle;
      DestinationPtr    := DestPtr;
    end;
    Inline(
      $B8/$00/$57/           {  MOV   AX,$5700        ;Move memory region}
      $1E/                   {  PUSH  DS}
      $16/                   {  PUSH  SS}
      $1F/                   {  POP   DS}
      $8D/$B6/>MOVEREC/      {  LEA   SI,>MoveRec[BP] ;DS:SI -> MoveRec}
      $CD/$67/               {  INT   $67}
      $1F/                   {  POP   DS}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $08/$E4/               {  OR    AH,AH}
      $B0/$01/               {  MOV   AL,1}
      $74/$02/               {  JZ    ExitPoint}
      $FE/$C8/               {  DEC   AL}
                             {ExitPoint:}
      $88/$46/<MOVEMEMORYREGION);{  MOV   <MoveMemoryRegion[BP],AL}
  end;

  function ExchangeMemoryRegion(SrcType : MemoryType;
                                SrcHandle : Word;
                                SrcPtr : EmsPtrType;
                                DestType : MemoryType;
                                DestHandle : Word;
                                DestPtr : EmsPtrType;
                                Size : LongInt) : Boolean;
    {-Exchange two memory regions. Returns True as function result if
      successful. Parameters have the same meaning as in MoveMemoryRegion. One
      difference is that the memory regions may not overlap in this routine.}

  var
    MoveRec : MoveRecord;
  begin
    with MoveRec do begin
      Len               := Size;
      SourceType        := SrcType;
      SourceHandle      := SrcHandle;
      SourcePtr         := SrcPtr;
      DestinationType   := DestType;
      DestinationHandle := DestHandle;
      DestinationPtr    := DestPtr;
    end;
    Inline(
      $B8/$01/$57/           {  MOV   AX,$5701        ;Move memory region}
      $1E/                   {  PUSH  DS}
      $16/                   {  PUSH  SS}
      $1F/                   {  POP   DS}
      $8D/$B6/>MOVEREC/      {  LEA   SI,>MoveRec[BP] ;DS:SI -> MoveRec}
      $CD/$67/               {  INT   $67}
      $1F/                   {  POP   DS}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $08/$E4/               {  OR    AH,AH}
      $B0/$01/               {  MOV   AL,1}
      $74/$02/               {  JZ    ExitPoint}
      $FE/$C8/               {  DEC   AL}
                             {ExitPoint:}
      $88/$46/<EXCHANGEMEMORYREGION);{  MOV   <ExchangeMemoryRegion[BP],AL}
  end;

  function GetNumberMappablePages : Word;
   {-Return the number of mappable pages.  Returns zero if error.}
  begin
    Inline(
      $B8/$01/$58/           {  MOV   AX,$5801   ;get number mappable pages}
      $CD/$67/               {  INT   $67}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $08/$E4/               {  OR    AH,AH}
      $74/$02/               {  JZ    ExitPoint}
      $31/$C9/               {  XOR   CX,CX}
                             {ExitPoint:}
      $89/$4E/<GETNUMBERMAPPABLEPAGES);{  MOV   <GetNumberMappablePages[BP],CX}
  end;

  function GetAddrMappablePages(var List : MappablePageList) : Boolean;
    {-Return the addresses of all mappable pages. Returns True as function
      result if successful. Will fail if EMS supports more mappable pages
      than the constant MaxMappablePages.}
  begin
    if GetNumberMappablePages > MaxMappablePages then begin
      GetAddrMappablePages := False;
      Exit;
    end;
    Inline(
      $B8/$00/$58/           {  MOV   AX,$5800     ;get addr of mappable pages}
      $C4/$7E/<LIST/         {  LES   DI,<List[BP] ;ES:DI -> List}
      $47/                   {  INC   DI}
      $47/                   {  INC   DI}
      $CD/$67/               {  INT   $67}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $B0/$01/               {  MOV   AL,1         ;assume success}
      $08/$E4/               {  OR    AH,AH}
      $74/$04/               {  JZ    ExitPoint}
      $FE/$C8/               {  DEC   AL}
      $31/$C9/               {  XOR   CX,CX}
                             {ExitPoint:}
      $88/$46/<GETADDRMAPPABLEPAGES/ {  MOV   <GetAddrMappablePages[BP],AL}
      $4F/                   {  DEC   DI}
      $4F/                   {  DEC   DI}
      $26/                   {ES:}
      $89/$0D);              {  MOV   [DI],CX}
  end;

  function GetHardwareConfig(var Config : HardwareConfigType) : Boolean;
    {-Return information about the EMS hardware configuration.  See
      HardwareConfigType definition for description of returned information.
      Returns True as function result if successful.}
  begin
    Inline(
      $B8/$00/$59/           {  MOV   AX,$5900       ;get hardware config}
      $C4/$7E/<CONFIG/       {  LES   DI,<Config[BP] ;ES:DI -> Config}
      $CD/$67/               {  INT   $67}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $08/$E4/               {  OR    AH,AH}
      $B0/$01/               {  MOV   AL,1}
      $74/$02/               {  JZ    ExitPoint}
      $FE/$C8/               {  DEC   AL}
                             {ExitPoint:}
      $88/$46/<GETHARDWARECONFIG);{  MOV   <GetHardwareConfig[BP],AL}
  end;

  function GetNumberOfRawPages(var Total, Free : Word) : Boolean;
    {-Return the number of raw Pages. Returns both the total and the number of
      raw pages free. Returns True as function result if successful. Raw pages
      may have a size other than 16k.}
  begin
    Inline(
      $B8/$01/$59/           {  MOV   AX,$5901        ;get number of raw pages}
      $CD/$67/               {  INT   $67}
      $88/$26/>EMSRESULT/    {  MOV   [>EmsResult],AH   ;store EMS error code}
      $08/$E4/               {  OR    AH,AH}
      $B0/$00/               {  MOV   AL,0}
      $75/$0E/               {  JNZ   ExitPoint}
      $FE/$C0/               {  INC   AL}
      $C4/$7E/<TOTAL/        {  LES   DI,<Total[BP]}
      $26/                   {ES:}
      $89/$15/               {  MOV   [DI],DX}
      $C4/$7E/<FREE/         {  LES   DI,<Free[BP]}
      $26/                   {ES:}
      $89/$1D/               {  MOV   [DI],BX}
                             {ExitPoint:}
      $88/$46/<GETNUMBEROFRAWPAGES);{  MOV   <GetNumberOfRawPages[BP],AL}
  end;

  function EmsErrorMessage(ErrorCode : Byte) : String;
    {-Return an error message for ErrorCode.}
  begin
    case ErrorCode of
      $00 : EmsErrorMessage := 'Success';
      $8A : EmsErrorMessage := 'Requested logical page is outside the range of pages owned by handle';
      $8B : EmsErrorMessage := 'Illegal physical page number in mapping request';
      $8C : EmsErrorMessage := 'Page mapping hardware-state save area is full';
      $8D : EmsErrorMessage := 'Context saved failed because save area already contains context for handle';
      $8E : EmsErrorMessage := 'Restore context failed because save area does not contain context for handle';
      $8F : EmsErrorMessage := 'No such subfunction';
      $90 : EmsErrorMessage := 'Attribute type not defined';
      $91 : EmsErrorMessage := 'Feature not supported';
      $92 : EmsErrorMessage := 'Source and destination have same handle and overlap; part of source overwritten';
      $93 : EmsErrorMessage := 'Length for source or destination is longer than actual allocated length';
      $94 : EmsErrorMessage := 'Memory overlaps';
      $95 : EmsErrorMessage := 'Specified offset is outside logical page';
      $96 : EmsErrorMessage := 'Region length exceeds 1 megabyte';
      $97 : EmsErrorMessage := 'Source and destination have same handle and overlap; exhange not performed';
      $98 : EmsErrorMessage := 'Source and destination types are undefined';
      $99 : EmsErrorMessage := '<error code unused>';
      $9A : EmsErrorMessage := 'Specified alternate register set is not supported';
      $9B : EmsErrorMessage := 'All alternate register sets allocated';
      $9C : EmsErrorMessage := 'Register sets not supported, and alternate register set is not zero';
      $9D : EmsErrorMessage := 'Specified alternate register set not defined or allocated';
      $9E : EmsErrorMessage := 'Dedicated DMA channels not supported';
      $9F : EmsErrorMessage := 'Specified dedicated DMA channel not supported';
      $A0 : EmsErrorMessage := 'No handle found for specified name';
      $A1 : EmsErrorMessage := 'Handle with same name already exists';
      $A3 : EmsErrorMessage := 'Invalid pointer passed, or contents of source array corrupted';
      $A4 : EmsErrorMessage := 'Access to function denied by operating system';
      else EmsErrorMessage := 'Unknown EMS error';
    end;
  end;
{end !!.03}

{$IFDEF InitAllUnits}
begin
{$ENDIF}
end.
