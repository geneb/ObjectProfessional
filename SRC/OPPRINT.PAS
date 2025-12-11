
{$IFDEF Windows}                                                      {!!.20}
  !! ERROR: This unit is not compatible with Windows applications !!  {!!.20}
{$ENDIF}                                                              {!!.20}

{$S-,R-,V-,I-,B-,F+,O+,A-}

{Conditional defines that may affect this unit}
{$I OPDEFINE.INC}

{*********************************************************}
{*                   OPPRINT.PAS 1.30                    *}
{*     Copyright (c) TurboPower Software 1989, 1992.     *}
{*                 All rights reserved.                  *}
{*********************************************************}

Unit OpPrint;

interface

uses
  Dos,
  OpConst,     {!!.20}
  OpInline,
  OpString,
  OpRoot,
  OpDos,
  OpPrnLow;

const
  {Option Flags for PrintMode}
  pmFont              = $0001;   {indicates that the mode represents a font}
  pmProportional      = $0002;   {indicates font is proportional}

  pmChangesLPI        = $0004;
  pmChangesLPP        = $0008;
  pmChangesCPI        = $0010;
  pmChangesPoint      = $0020;
  pmChangesTopMargin  = $0040;
  pmChangesLandscape  = $0080;
  pmChangesStrike     = $0100;
  pmCallsSpecialProc  = $0200;

  NewFontPitch        = pmFont + pmChangesCPI;
  NewFont             = pmFont + pmChangesCPI + pmChangesPoint;

  {Print Mode internal flags}
  pmModeEnabled       = $8000;   {used internally to indicate a print mode
                                  is enabled}

  pMaxPrintModes      = 255;     {maximum number of print modes that can be
                                  associated with a given printer}

  {Options Flags for Printer object}
  pPositionable       = $0001;          {Print head positionable?}
  pBackSpaceAllowed   = $0002;          {Back spacing allowed}
  pNoFormFeed         = $0004;          {Don't send ^L at EOP}
  pSoftFormFeed       = $0008;
  pSupportsHPRules    = $0010;          {Supports HP LJ+ Rules and boxes}
  pUseDeciPoints      = $0020;          {use HP decipoint positioning}
  pNoFontStack        = $0040;          {do not use the font stack}
  pNoSortPositionable = $0080; {!!.03}  {Do not sort if positionable printer.
                                         This can speed up the printing of
                                         complex forms significantly.
                                         NOTE: if you are using Print
                                         directives in OPFORM, you should
                                         not use this option.}
  pLJColAdjust        = $0100; {!!.13}  {Correct off by one error for Laserjets}
  pGenericLineFields  = $0200; {!!.20}  {Use new Generic line field option}

  {Option Flags for internal use by Printer object}
  pDeviceDealloc      = $8000;   {used internally}
  pModesDealloc       = $4000;   {used internally}
  pInDoubleStrike     = $2000;   {used internally to track double strike mode}
  pInLandscape        = $1000;   {used internally to track Landscape mode}

  MaxByteArray        = 65520;

  FontStackSize       = 255;           {maximum size of a font stack}
  DoubleStrike        = 255;           {print attr for multi-strike}
  PrinterReset        = 254;           {print attr for Reset printer}
  Italics             = 253;           {print attr for Italics}
  Bold                = 252;           {print attr for Bold}
  Dim                 = 251;           {print attr for Dim (opposit of Bold)}
  Compressed          = 250;           {print attr for Condensed}
  Underline           = 249;           {print attr for underline}
  Unidirectional      = 248;           {print attr for unidirectional printing}
  DoubleWidth         = 247;           {print attr for double width mode}
  LetterQuality       = 246;           {(near) letter quality mode}
  DefaultFont         = 243;           {print attr for default font}
  Normal              = 242;           {normal print}
  SelectPrimaryFont   = 245;           {selects the primary font for LJ}
  SelectSecondaryFont = 244;           {selects the secondary font for LJ}


  pPlain              = 0;             {indicates a plain printer, no
                                        specific hardware type registered}
type
  {$IFOPT N+}
  Dimension           = Double;
  {$ELSE}
  Dimension           = Real;
  {$ENDIF}
  RelativeType        = (rtAbsolute,rtCurrent);
  PrinterPtr          = ^Printer;
  PrintModePtr        = ^PrintMode;
  PrintErrorFunc      = function (P   : PrinterPtr;
                                  ErrorCode : Word;
                                  Recoverable : Boolean) : Boolean;

  PrinterPosFunc      = function (Row, Col : Dimension;
                                  Relative : RelativeType;
                                  P : PrinterPtr) : Word;

  IntensityProc       = procedure (Intensity : ShortInt;
                                   P : PrinterPtr);

  PrinterModeProc     = procedure (On : Boolean; P : PrinterPtr);

  {procedure type for printer hardware registration routines}
  PrnRegProc          = procedure (P : PrinterPtr);


  {.Z+}
  {types for simple byte stack used by Printer object}
  ByteArray       = Array[1..MaxByteArray] of Byte;
  ByteArrayPtr    = ^ByteArray;
  ByteStackPtr    = ^ByteStack;
  ByteStack =
    object(Root)
      bsTop       : Word;
      bsSize      : Word;
      bsStatus    : Word;
      bsBase      : ByteArrayPtr;
      constructor Init(Max : Word);
      destructor Done; Virtual;
      function Size : Word;
        {-Return the size of the stack}
      procedure Push(B : Byte);
        {-Push B onto the stack}
      function Pop : Byte;
        {-Pop the topmost Byte off the stack}
      function SP : Word;
        {-Return the current top of stack index}
      function Peek(Index : Word) : Byte;
        {-Return Base^[Index]}
      function PeekTop : Byte;
        {-Return Byte at top of stack}
      procedure Poke(B : Byte; Index : Word);
        {-Directly set a stack element}
      procedure Clear;
        {-Remove all elements from the stack}
      procedure Remove(Index : Byte);
        {-Remove the element at Index, and adjust rest the of the stack}
      function GetStatus : Word;
        {-Return latest status code and reset internal status to zero}
      {no stream support required here}
      {...for internal use...}
      procedure Error(Code : Word);
    end;
  {.Z-}

  {object definitions for Printer Modes}
  PrintMode =
    object(SingleListNode)
      pmModeName     : StringPtr;
      pmOnEscSeq     : StringPtr;
      pmOffEscSeq    : StringPtr;
      pmID           : Byte;
      pmOptions      : Word;

      pmWidth        : Dimension;
      pmHeight       : Dimension;
      {.Z+}
      constructor Init(Name,OnEscSeq,OffEscSeq : String;
                       Width, Height : Dimension;
                       ID : Byte;
                       OptionFlags : Word);
        {-Initialize a Print Mode}
      destructor Done; Virtual;
        {-Destroy a Print Mode}
      procedure TurnOn(PrinterP : PrinterPtr);
        {-Enable the option associated with this Print Mode}
      procedure TurnOff(PrinterP : PrinterPtr);
        {-Disable the option associated with this Print Mode}

      procedure pmOptionsOn(OptionFlags : Word);
        {-Turn on multiple Print Mode options}
      procedure pmOptionsOff(OptionFlags : Word);
        {-Turn off multiple Print Mode options}
      function pmOptionsAreOn(OptionFlags : Word) : Boolean;
        {-Return true of Options specified by OptionFlags are on}
      function PrintModeID : Byte;
        {-Return the ID of this Print Mode}
      function PrintModeName : String;
        {-Return the name of this Print Mode}
      function PrintModeOnSeq : String;
        {-Return the escape sequence to turn this option on}
      function PrintModeOffSeq : String;
        {-Return the escape sequence to turn this option off}
      function PrintModeOptions : Word;
        {-Return the Options for this PrintMode}
      procedure PrintModeDimensions(var Width,Height : Dimension);
        {-Return the width and height of this print mode}

    {$IFDEF UseStreams}
      {...stream support...}
      constructor Load(var S : IdStream);
        {-Load a PrintMode from a stream}
      procedure Store(var S : IdStream);
        {-Store a PrintMode in a stream}
    {$ENDIF}
      {...for internal use...}
      procedure pmTurnOnPrim(PrinterP : PrinterPtr);
      procedure pmRemoveFromFontStack(PrinterP : PrinterPtr);
      procedure pmFontStackEmpty(PrinterP : PrinterPtr);
      {.Z-}
    end;

  {The high level Printer object used by the Form object}
  Printer =
    object(Root)
      pOptions        : Word;                {Options and flags}
      pLastError      : Word;
      pHardwareType   : Word;
      pNumModes       : Word;
      pLastX          : Dimension;
      pLastY          : Dimension;
      pXRatio         : Dimension;
      pYRatio         : Dimension;

      pLinesPerInch   : Dimension;
      pCharsPerInch   : Dimension;
      pCharPoint      : Dimension;
      pLinesPerPage   : Dimension;
      pPhyTopMargin   : Dimension;           {the physical top margin}
      pStrikeCount    : ShortInt;            {number of times the print head
                                              is to strike in multi-strike
                                              mode}
      pDefaultFont    : Byte;
      pCurrentMode    : PrintModePtr;
      pVertCursor     : StringPtr;
      pHorizCursor    : StringPtr;
      pDeciVert       : StringPtr;
      pDeciHoriz      : StringPtr;

      pDriver         : BasePrinterPtr;      {The base printer driver}
      pPrinterModes   : SingleList;          {a linked list of print modes
                                              associated with this printer}
      pFontStack      : ByteStack;           {a stack of active fonts}
      pActiveModes    : BitSet;              {a bitset to store active modes}
      pPositionPrim   : PrinterPosFunc;      {procedure pointer to Print head
                                              positioning routine}
      pGraphicsProc   : PrinterModeProc;     {proc to turn on/off graphics}
      pSpecialProc    : PrinterModeProc;     {special mode procedure}
      pErrorPrim      : PrintErrorFunc;      {function pointer to error
                                              handler}
      pSetIntensity   : IntensityProc;       {optional routine to set printer
                                              intensity}
      constructor Init(Name : String; DeviceType : PrnType;
                       OptionFlags : Word);
        {-Initialize a Printer}
      constructor InitCustom(Device : BasePrinterPtr;
                             LPI, CPI, Point, LPP : Dimension;
                             OptionFlags : Word);
        {-Initialize a printer with full control over Printer Device,
          PrinterModes}
      destructor Done; Virtual;
        {-Destroy a printer}
      procedure PrintStr(S : String); Virtual;
        {-Print a String at the current position}
      procedure PrintStrPos(S : String;
                            Row, Col : Dimension;
                            Relative : RelativeType); Virtual;
        {-Print a string at the specified position}
      procedure Position(Row, Col : Dimension; Relative : RelativeType); Virtual;
        {-Position the printer to the desired place on the page}
      procedure FormFeed;
        {-Advance to next page}
      procedure AdvanceLine(NumLines : Byte);
        {-Advances NumLines number of lines}
      procedure AdvanceSingleLine; Virtual;
        {-Advances to the top of the next line}
      procedure AdvanceLinePreserveX(NumLines : Byte);                 {!!.11}
        {-Advances a NumLines lines preserving the current column}
      procedure ResetPage;
        {-Reset position information}
      procedure SetPrinterInfo(LPI, CPI, Point, LPP : Dimension);
        {-Sets lines per inch, chars per inch, and lines per page}
      procedure GetPrinterInfo(var LPI, CPI, Point, LPP : Dimension);
        {-Returns lines per inch, chars per inch, and lines per page}

      procedure SetLPI(LPI : Dimension);
        {-Sets lines per inch}
      procedure SetCPI(CPI : Dimension);
        {-Sets chars per inch}
      procedure SetPoint(Point : Dimension);
        {-Sets the character point}
      procedure SetLPP(LPP : Dimension);
        {-Sets lines per page}
      procedure SetYRatio(Ratio : Dimension);
        {-Sets the Y printer ratio}
      procedure SetXRatio(Ratio : Dimension);
        {-Sets the X printer ratio}

      function GetLPI : Dimension;
        {-Returns lines per inch}
      function GetCPI : Dimension;
        {-Returns chars per inch}
      function GetPoint : Dimension;
        {-Returns the character point}
      function GetLPP : Dimension;
        {-Returns lines per page}
      function GetYRatio : Dimension;
        {-Returns the Y printer ratio}
      function GetXRatio : Dimension;
        {-Returns the X printer ratio}

      function GetRegisteredType : Word;
        {-Returns the hardware type registered to this Printer}
      procedure SetRegisteredType(HardwareType : Word);
        {-Sets the registered hardware type}
      function GetBasePrinter : BasePrinterPtr;
        {-Returns the BasePrinterPtr}
      procedure GetPhysicalTopMargin(var Top : Dimension);
        {-Returns the physical top margin}
      procedure SetPhysicalTopMargin(Top : Dimension);
        {-Sets the physical top margin. NOTE: does not send any codes to the
          printer, simply updates data field in Printer object.}

      function GetPrnOptions : Word;
        {-Returns the Option Flags for this printer}
      procedure SetPrnOptions(OptionFlags : Word);
        {-Sets the option flags for this printer}

      function GetCurrentFont : Byte;
        {-Returns the current font's Mode ID or zero if no current font}

      procedure SetPrintErrorFunc(PEF : PrintErrorFunc);
        {-Set the print error function}
      procedure SetPositionPrim(PosFunc : PrinterPosFunc);
        {-Set printer position primitive}

      procedure SetSpecialProc(SpecProc : PrinterModeProc);
        {-Sets the special procedure}

      procedure AddPrintMode(Name,OnEscSeq,OffEscSeq : String;
                             Width, Height : Dimension;
                             ID : Byte; OptionFlags : Word);
        {-Add a Print Mode to the linked list of modes}

      procedure SetDefaultFont(Attr : Byte);
        {-Sets the default font for this printer}
      function GetDefaultFont : Byte;
        {-Returns the Attr of the default font}
      procedure EnableDefaultFont;
        {-Enables the default font}

      procedure TurnOnByID(ID : Byte);
        {-Turn a print mode on by ID}
      procedure TurnOffByID(ID : Byte);
        {-Turn a print mode off by ID}

      procedure TurnOnByName(Name : String);
        {-Turn a print mode on by Name}
      procedure TurnOffByName(Name : String);
        {-Turn a print mode off by Name}

      function PrinterReady : Boolean;
        {-Returns true if printer ready}

      procedure pOptionsOn(OptionFlags : Word);
        {-Turn on multiple Printer options}
      procedure pOptionsOff(OptionFlags : Word);
        {-Turn off multiple printer options}
      function pOptionsAreOn(OptionFlags : Word) : Boolean;
        {-Return True if all of the specified OptionFlags are on}
      function pGetLastError : Word;
        {-Return the last error code and reset to zero}
      procedure EnableDoubleStrike;
        {-Enable multi-strike mode}
      procedure DisableDoubleStrike;
        {-Disable Multi-strike mode}
      function InDoubleStrike : Boolean;
        {-Returns true if more than one strike is required}

      function InLandscape : Boolean;
        {-Returns true if in Landscape mode}
      function StrikeCount : ShortInt;
        {-Returns the current value of pStrikeCount}
      procedure SetStrikeCount(Strikes : ShortInt);
        {-Set the number of strikes needed when double strike is enabled}
      function CurrentStrikes : ShortInt;
        {-Returns the number of strikes currently being applied, 1 if double
          strike is disabled, or pStrikeCount otherwise}
      procedure TurnOffAllActiveModes;
        {-Turn off all the currently active print modes}
      procedure DisposeAllModes;
        {-Disposes of all print modes associated with this printer}
      procedure GetPosition(var Row, Col : Dimension); {!!.14}
        {-Return the current position of the print head.}
    {$IFDEF UseStreams}
      {...stream support...}
      constructor Load(var S : IdStream);
        {-Load a Printer from a stream}
      procedure Store(var S : IdStream);
        {-Store a Printer in a stream}
    {$ENDIF}

      {...methods to establish links to Printers and modes...}
      procedure LinkToPrinter(Device : BasePrinterPtr);
        {-Links the object with the specified Device}
      procedure LinkToModes(var Modes : SingleList);
        {-Links the object to the specified Print Mode List}
      {.Z+}
      {...methods for internal use...}
      function GetPrintModeByID(ID : Byte) : PrintModePtr;
      function GetPrintModeByName(Name : String) : PrintModePtr;
      procedure SetIntensityProc(IP : IntensityProc);
      function PrintError(ErrorCode : Word;
                          Recoverable : Boolean) : Boolean; Virtual;
        {-Call user Error handler}
      procedure DisposePosData;
        {-Disposes of a PositionDataType}
      procedure SetPosData(VCurs,HCurs,VDeci,HDeci : String);
        {-Set the Position data}
      procedure SetGraphicsProc(GraphProc : PrinterModeProc);
        {-Sets the Graphics mode procedure}
      procedure CallGraphicsProc(On : Boolean);
        {-Calls the graphics procedure}
      procedure CallSpecialProc(On : Boolean);
        {-Calls the special procedure}
      function XlatChar(C : Char) : Char;
        {-Return the character C translated from the XlatTable}
      procedure AddToActiveModes(ModeID : Byte);
      procedure RemoveFromActiveModes(ModeID : Byte);
      procedure ClearActiveModes;
      function IsModeActive(ModeID : Byte) : Boolean;
      function IsErrorHandler : Boolean;
      procedure PrintStrPrim(S : String);
      procedure BackSpace(NumChars : Byte);
      procedure AdvanceSpace(NumChars : Byte);
      procedure pTurnFontOn(ID : Byte);
      procedure pZeroPtrs;
      procedure Landscape(On : Boolean);
        {-Turns internal landscape mode flag on or off}
      {.Z-}
    end;

const
  OpFormErrorLevel    : Byte = 1; {Errorlevel set when fatal print error and
                                   no Printer error handler installed}
  DefaultStrikes      : Byte = 2; {the default number of strikes in
                                   multi-strike mode}
  BackSpaceChar       : Char = #8;
  LineAdvanceStr      : String[11] = #13#10;
  LineFeedStr         : String[11] = #10;               {!!.03}
  FormFeedStr         : String[11] = ^L;
  PutSuccessMask      : Byte = $10;
  DefPrinterTest      : Byte = 1;

  DefaultLPI          : Dimension = 6.0;
  DefaultCPI          : Dimension = 10.0;
  DefaultPoint        : Dimension = 12.0;
  DefaultLPP          : Dimension = 66.0;

  PosUnit             : Dimension = 1.0;
  DefaultXRatio       : Dimension = 1.0;
  DefaultYRatio       : Dimension = 1.0;

{.Z+}
{$IFDEF UseStreams}

procedure PrintModeStream(SPtr : IdStreamPtr);
  {-Registers types needed for streams containing PrintModes}

procedure PrinterStream(SPtr : IdStreamPtr);
  {-Registers types needed for streams containing Printers}

{$ENDIF}
{.Z-}
  {==========================================================================}

implementation

  constructor ByteStack.Init(Max : Word);
    {-Allocate a stack of pointers that can manage up to Max items}
  begin
    bsBase := nil;
    if not Root.Init then
      Fail;
    if Max <> 0 then
      if Max > MaxStackSize then begin
        Done;
        InitStatus := epFatal+ecBadParam;
        Fail;
      end else if not GetMemCheck(bsBase, Max*SizeOf(Byte)) then begin
        Done;
        InitStatus := epFatal+ecOutOfMemory;
        Fail;
      end;
    bsSize := Max;
    bsTop := 0;
    bsStatus := 0;
  end;

  destructor ByteStack.Done;
    {-Deallocate the stack}
  begin
    FreeMemCheck(bsBase, bsSize*SizeOf(Byte));
    bsSize := 0;
    bsTop := 0;
    Root.Done;
  end;

  function ByteStack.GetStatus : Word;
    {-Return latest status code and reset internal status to zero}
  begin
    GetStatus := bsStatus;
    bsStatus := 0;
  end;

  function ByteStack.Size : Word;
    {-Return the size of the stack}
  begin
    Size := bsSize;
  end;

  procedure ByteStack.Push(B : Byte);
    {-Push B onto the stack}
  begin
    if bsTop >= bsSize then begin
      Error(epWarning + ecByteStkOverflow);
      Exit;
    end;
    inc(bsTop);
    bsBase^[bsTop] := B;
  end;

  function ByteStack.Pop : Byte;
    {-Pop the topmost RootPtr off the stack}
  begin
    if bsTop = 0 then
      Pop := 0
    else begin
      Pop := bsBase^[bsTop];
      dec(bsTop);
    end;
  end;
  procedure ByteStack.Remove(Index : Byte);
    {-Remove the element at Index, and adjust rest the of the stack}
  var
    B : Byte;
  begin
    if (Index > bsTop) or (Index = 0) then
      Exit;
    B := bsTop - Index;
    Move(bsBase^[Succ(Index)], bsBase^[Index], B);
    Dec(bsTop);
  end;

  function ByteStack.SP : Word;
    {-Return the current top of stack index}
  begin
    SP := bsTop;
  end;

  function ByteStack.Peek(Index : Word) : Byte;
    {-Return Base^[Index]}
  begin
    if (Index = 0) or (Index > bsSize) then
      Peek := 0
    else
      Peek := bsBase^[Index];
  end;

  function ByteStack.PeekTop : Byte;
    {-Return Byte at top of stack}
  begin
    if bsTop = 0 then
      PeekTop := 0
    else
      PeekTop := bsBase^[bsTop];
  end;

  procedure ByteStack.Poke(B : Byte; Index : Word);
    {-Directly set a stack element}
  begin
    bsBase^[Index] := B;
  end;

  procedure ByteStack.Clear;
    {-Remove all elements from the stack}
  begin
    bsTop := 0;
  end;

  procedure ByteStack.Error(Code : Word);
    {-Assign error code}
  begin
    bsStatus := Code;
  end;

{...print mode methods...}

  constructor PrintMode.Init(Name,OnEscSeq,OffEscSeq : String;
                             Width, Height : Dimension;
                             ID : Byte;
                             OptionFlags : Word);
  begin
    pmOnEscSeq       := NIL;
    pmOffEscSeq      := NIL;
    pmModeName       := NIL;

    pmID             := ID;
    pmOptions        := OptionFlags;
    pmWidth          := Width;
    pmHeight         := Height;

    if not SingleListNode.Init then
      Fail;
    if Length(Name) <> 0 then begin
      if not GetMemCheck(pmModeName,Succ(Length(Name))) then begin
        InitStatus := ecOutOfMemory;
        Done;
        Fail;
      end;
      pmModeName^ := StUpcase(Name);
    end;
    if not GetMemCheck(pmOnEscSeq,Succ(Length(OnEscSeq))) then begin
      InitStatus := ecOutOfMemory;
      Done;
      Fail;
    end;
    pmOnEscSeq^ := OnEscSeq;

    if not GetMemCheck(pmOffEscSeq,Succ(Length(OffEscSeq))) then begin
      InitStatus := ecOutOfMemory;
      Done;
      Fail;
    end;
    pmOffEscSeq^ := OffEscSeq;
  end;

  destructor PrintMode.Done;

  begin
    FreeMemCheck(pmOffEscSeq,Succ(Length(pmOffEscSeq^)));
    FreeMemCheck(pmOnEscSeq,Succ(Length(pmOnEscSeq^)));
    if pmModeName <> nil then                                          {!!.22}
      FreeMemCheck(pmModeName,Succ(Length(pmModeName^)));              {!!.22}
    SingleListNode.Done;                                               {!!.13}
  end;

{$IFDEF UseStreams}

  procedure PrintModeStream(SPtr : IdStreamPtr);
    {-Registers types needed for streams containing PrintModes}
  begin
    with SPtr^ do
      RegisterType(otPrintMode,vePrintMode,TypeOf(PrintMode),
                   @PrintMode.Store,@PrintMode.Load);
  end;

  constructor PrintMode.Load(var S : IdStream);
  var
    St : String;
    L  : Byte;
  begin
    {init pointers to Nil}
    pmModeName  := Nil;
    pmOnEscSeq  := Nil;
    pmOffEscSeq := Nil;
    {read the string data first}
    St := S.ReadString;
    L := Length(St);
    if L > 0 then
      if GetMemCheck(pmModeName,Succ(L)) then
        pmModeName^ := St
      else
        Fail;
    St := S.ReadString;
    L := Length(St);
    (* if L > 0 then *)                                    {!!.02}
      if GetMemCheck(pmOnEscSeq,Succ(L)) then
        pmOnEscSeq^ := St
      else begin
        Done;
        Fail;
      end;
    St := S.ReadString;
    L := Length(St);
    (* if L > 0 then *)                                    {!!.02}
      if GetMemCheck(pmOffEscSeq,Succ(L)) then
        pmOffEscSeq^ := St
      else begin
        Done;
        Fail;
      end;
    {read the non-string data}
    S.Read(pmID,(Ofs(pmHeight) - Ofs(pmID)) + SizeOf(pmHeight));
  end;

  procedure PrintMode.Store(var S : IdStream);

  var
    St : String;

  begin
    {store the strings}
    if pmModeName = Nil then
      St := ''
    else
      St := pmModeName^;
    S.WriteString(St);
    if pmOnEscSeq = Nil then
      St := ''
    else
      St := pmOnEscSeq^;
    S.WriteString(St);
    if pmOffEscSeq = Nil then
      St := ''
    else
      St := pmOffEscSeq^;
    S.WriteString(St);
    {store the non-string data}
    S.Write(pmID,(Ofs(pmHeight) - Ofs(pmID)) + SizeOf(pmHeight));
  end;

{$ENDIF}

  procedure PrintMode.TurnOn(PrinterP : PrinterPtr);

  begin
    with PrinterP^ do begin
      pCurrentMode := @Self;
      {see if this mode changes the strike count}
      if FlagIsSet(pmOptions,pmChangesStrike) then
        if pmHeight > PosUnit then begin
          SetStrikeCount(Round(pmHeight));
          if pLastError <> 0 then
            Exit;
        end;
      {see if this mode enables doublestrike}
      if pmID = DoubleStrike then begin
        EnableDoubleStrike;
        if pLastError <> 0 then
          Exit;
      end
      else begin
        {if this mode resets the printer, then clear font stack}
        if pmID = PrinterReset then begin
          pActiveModes.ClearAll;
          pFontStack.Clear;
        end;
        if FlagIsSet(pmOptions, pmFont) then begin               {!!.03}
          if FlagIsSet(pmOptions,pmChangesLandscape) then
            Landscape(True)
          else
            Landscape(False);
          {if this mode enables a font, push it onto the font stack}
          if (not FlagIsSet(pOptions, pNoFontStack)) then begin
            pFontStack.Push(pmID);
            if pLastError <> 0 then
              Exit;
          end;
        end;
        {send printer control ON sequence to the output device}
        PrintStrPrim(pmOnEscSeq^);
        if pLastError <> 0 then
          Exit;
        {indicate to the mode that it is enabled}
        SetFlag(pmOptions,pmModeEnabled);
        {tell the printer object it is enabled}
        AddToActiveModes(pmID);
        {check for other specific printer characteristic changes}
        if FlagIsSet(pmOptions,pmChangesLPI) then
          SetLPI(pmHeight);
        if FlagIsSet(pmOptions,pmChangesCPI) then
          SetCPI(pmWidth);
        if FlagIsSet(pmOptions,pmChangesLPP) then
          SetLPP(pmHeight);
        if FlagIsSet(pmOptions,pmChangesPoint) then
          SetPoint(pmHeight);
        if FlagIsSet(pmOptions,pmChangesTopMargin) then
          SetPhysicalTopMargin(pmHeight);
      end;
    end;
  end;

  procedure PrintMode.pmFontStackEmpty(PrinterP : PrinterPtr);
    {-Inform user font stack is empty (via error handler), and enable default
      stack if user error handler returns True}
  begin
    with PrinterP^ do
      if PrintError(epWarning+ecFontStackError, True) then
        EnableDefaultFont;
  end;

  procedure PrintMode.pmRemoveFromFontStack(PrinterP : PrinterPtr);
    {-Remove this PrintMode from the font stack}
  var
    Index, Font : Byte;
  begin
    with PrinterP^, pFontStack do begin
      Index := SP;
      while Index <> 0 do
        if Peek(Index) = pmID then begin
          Remove(Index);
          Font := PeekTop;
          if Font = 0 then
            pmFontStackEmpty(PrinterP)
          else
            pTurnFontOn(Font);
          Exit;
        end
        else
          Dec(Index);
    end;
  end;

  procedure PrintMode.TurnOff(PrinterP : PrinterPtr);
  begin
    with PrinterP^ do
      if pmID = DoubleStrike then
        DisableDoubleStrike
      else begin
        PrinterP^.PrintStrPrim(pmOffEscSeq^);
        if pLastError <> 0 then
          Exit;
        ClearFlag(pmOptions,pmModeEnabled);
        PrinterP^.RemoveFromActiveModes(pmID);

        {if this PrintMode is a font, then deal with the font stack}
        if (not FlagIsSet(pOptions, pNoFontStack)) and
           FlagIsSet(pmOptions,pmFont) then
          pmRemoveFromFontStack(PrinterP);
      end;
  end;

  procedure PrintMode.pmTurnOnPrim(PrinterP : PrinterPtr);

  begin
    with PrinterP^ do
      if pmID = DoubleStrike then
        EnableDoubleStrike
      else begin
        PrintStrPrim(pmOnEscSeq^);
        if pLastError <> 0 then
          Exit;
        SetFlag(pmOptions,pmModeEnabled);
        AddToActiveModes(pmID);
        if FlagIsSet(pmOptions,pmChangesLPI) then
          SetLPI(pmHeight);
        if FlagIsSet(pmOptions,pmChangesCPI) then
          SetCPI(pmWidth);
        if FlagIsSet(pmOptions,pmChangesLPP) then
          SetLPP(pmHeight);
        if FlagIsSet(pmOptions,pmChangesPoint) then
          SetPoint(pmHeight);
        if FlagIsSet(pmOptions,pmChangesTopMargin) then
          SetPhysicalTopMargin(pmHeight);
      end;
  end;

  procedure Printer.Position(Row,Col : Dimension; Relative : RelativeType);

  var
    DeltaX,DeltaY : Dimension;
  begin
    if (not FlagIsSet(pOptions,pPositionable)) then begin
      case Relative of
        rtAbsolute : begin
                       DeltaY := Round(Row * pYRatio) - pLastY; {!!.10}{!!.22}
                       if DeltaY >= 0.0 then begin
                         AdvanceLine(Round(DeltaY));                   {!!.22}
                       end
                       else
                         if PrintError(epNonFatal+ecPosOutOfRange,False) then ;
                       DeltaX := Round(Col * pXRatio) - pLastX; {!!.10}{!!.22}
                       if DeltaX >= 0.0 then
                         AdvanceSpace(Round(DeltaX))                   {!!.22}
                       else
                         BackSpace(Round(-1 * DeltaX));         {!!.10}{!!.22}
                     end;
        rtCurrent  : begin
                       if Row >= 0.0 then                         {!!.03}
                         AdvanceLinePreserveX(Round(pYRatio * Row)){!!.03}{!!.11}
                       else
                         if PrintError(epNonFatal+ecPosOutOfRange,False) then ;
                       if Col > 0.0 then                          {!!.03}
                         AdvanceSpace(Round(pXRatio * Col))       {!!.03}
                       else                                       {!!.03}
                         BackSpace(Round(pXRatio * Col * -1.0));  {!!.03}{!!.10}
                     end;
      end;
    end
    else
      if @pPositionPrim <> Nil then
        pLastError := pPositionPrim(pYRatio * Row, pXRatio * Col,
                                    Relative, @Self)
      else
        if PrintError(epFatal+ecNoPositionPrim, False) then ;
  end;

  procedure Printer.FormFeed;
    {-Advances to next page of paper}
  var
    Num    : Word;
    R      : Dimension;

  begin
    if not FlagIsSet(pOptions,pNoFormFeed) then
      if FlagIsSet(pOptions,pSoftFormFeed) then begin
        R   := (pLinesPerPage * pYRatio) - pLastY;
        Num := Round(R / pYRatio);
        AdvanceSingleLine;                            {!!.03}
        AdvanceLine(Byte(Num));                       {!!.03}{!!.11}
      end else
        PrintStrPrim(FormFeedStr);
    ResetPage;
  end;

  procedure Printer.TurnOffAllActiveModes;
    {-Turns off all the currently active print modes}
  var
    Mode : LongInt;

  begin
    Mode := 0;
    {for each mode that is on, turn it off}
    while Mode <> NoMoreBits do
      with pActiveModes do begin
        if BitIsSet(Mode) then
          TurnOffByID(Byte(Mode));
        Mode := NextSet(Mode);     {get next bit set}
      end;
  end;

  procedure Printer.DisposeAllModes;
    {-Disposes of all print modes associated with this printer}
  begin
    pPrinterModes.Done;
    pNumModes := 0;
  end;

  procedure Printer.AddToActiveModes(ModeID : Byte);
  begin
    pActiveModes.SetBit(ModeID);
  end;

  procedure Printer.RemoveFromActiveModes(ModeID : Byte);
  begin
    pActiveModes.ClearBit(ModeID);
  end;

  procedure Printer.ClearActiveModes;
  begin
    pActiveModes.ClearAll;
  end;

  function Printer.IsModeActive(ModeID : Byte) : Boolean;

  begin
    IsModeActive := pActiveModes.BitIsSet(ModeID);
  end;

  function Printer.IsErrorHandler : Boolean;

  begin
    IsErrorHandler := @pErrorPrim <> Nil;
  end;

  function Printer.pGetLastError : Word;

  begin
    pGetLastError := pLastError;
    pLastError := 0;
  end;

  procedure PrintMode.pmOptionsOn(OptionFlags : Word);
  begin
    SetFlag(pmOptions,OptionFlags);
  end;

  procedure PrintMode.pmOptionsOff(OptionFlags : Word);
  begin
    ClearFlag(pmOptions,OptionFlags);
  end;

  function PrintMode.pmOptionsAreOn(OptionFlags : Word) : Boolean;

  begin
    pmOptionsAreOn := FlagIsSet(pmOptions,OptionFlags);
  end;

  function PrintMode.PrintModeID : Byte;

  begin
    PrintModeID := pmID;
  end;

  function PrintMode.PrintModeName : String;

  begin
    if pmModeName = Nil then
      PrintModeName := ''
    else
      PrintModeName := pmModeName^;
  end;

  function PrintMode.PrintModeOnSeq : String;
    {-Return the escape sequence to turn this option on}
  begin
    PrintModeOnSeq := pmOnEscSeq^;
  end;

  function PrintMode.PrintModeOffSeq : String;
    {-Return the escape sequence to turn this option off}
  begin
    PrintModeOffSeq := pmOffEscSeq^;
  end;

  function PrintMode.PrintModeOptions : Word;
    {-Return the Options for this PrintMode}
  begin
    PrintModeOptions := pmOptions;
  end;

  procedure PrintMode.PrintModeDimensions(var Width,Height : Dimension);
    {-Return the width and height of this print mode}
  begin
    Width  := pmWidth;
    Height := pmHeight;
  end;


  {...Printer methods...}

  constructor Printer.Init(Name : String;
                           DeviceType : PrnType;
                           OptionFlags : Word);
    {-Initialize a Printer}

  begin
    if not Root.Init then                 {call constructor for root}
      Fail;
    pZeroPtrs;
    pOptions       := OptionFlags;
    pNumModes      := 0;
    pLastError     := 0;
    pDefaultFont   := 0;
    pLastX         := PosUnit;
    pLastY         := PosUnit;
    pXRatio        := DefaultXRatio;
    pYRatio        := DefaultYRatio;
    pLinesPerInch  := DefaultLPI;
    pCharsPerInch  := DefaultCPI;
    pCharPoint     := DefaultPoint;
    pLinesPerPage  := DefaultLPP;

    pHardwareType  := pPlain;

    pPhyTopMargin  := 0.0;

    pStrikeCount   := DefaultStrikes;

    if not pPrinterModes.Init then        {Init the linked list of Print Modes}
      Fail;
    if not pFontStack.Init(FontStackSize) then begin
      Done;
      Fail;
    end;
    if not pActiveModes.Init(pMaxPrintModes) then begin
      Done;
      Fail;
    end;
    pActiveModes.ClearAll;

    {initialize the printer object}
    case DeviceType of
      LPT1..LPT3   : pDriver := New(BiosPrinterPtr,Init(LPTType(DeviceType)));
      Prn,DiskFile : pDriver := New(DosPrinterPtr,Init(Name,DeviceType));
      else begin
        {an invalid printer type was passed (possibly UserDefined)}
        InitStatus := epFatal + ecInvalidPrinter;
        Done;
        Fail;
      end;
    end;
    {Make sure Printer constructor succeeded}
    if pDriver = Nil then begin
      InitStatus := epFatal + ecOutOfMemory;
      Done;
      Fail;
    end
    else
      SetFlag(pOptions,pDeviceDealloc);   {set internal flag indicating we
                                             need to deallocate this object
                                             in the destructor}
  end;

  destructor Printer.Done;

  begin
    {Free memory allocated to Printer if necessary}
    if (pDriver <> Nil) and FlagIsSet(pOptions,pDeviceDealloc) then
      Dispose(pDriver,Done);
    pPrinterModes.Done;          {call destructor for linked list of Modes}
    pFontStack.Done;
    pActiveModes.Done;
    DisposePosData;                      {!!.13}
    Root.Done;
  end;

  constructor Printer.InitCustom(Device : BasePrinterPtr;
                                 LPI, CPI, Point, LPP : Dimension;
                                 OptionFlags : Word);

  begin
    Root.Init;
    pZeroPtrs;
    pOptions       := OptionFlags;
    pDriver        := Device;
    pNumModes      := 0;              {!!.01}
    pLastError     := 0;
    pDefaultFont   := 0;
    pLastX         := PosUnit;
    pLastY         := PosUnit;
    pXRatio        := DefaultXRatio;
    pYRatio        := DefaultYRatio;

    pLinesPerInch  := LPI;
    pCharsPerInch  := CPI;
    pCharPoint     := Point;
    pLinesPerPage  := LPP;

    pPhyTopMargin  := 0.0;

    pStrikeCount   := DefaultStrikes;
    pHardwareType  := pPlain;

    if not pPrinterModes.Init then     {Init the linked list of Print Modes}
      Fail;
    if not pFontStack.Init(FontStackSize) then begin
      Done;
      Fail;
    end;
    if not pActiveModes.Init(pMaxPrintModes) then begin
      Done;
      Fail;
    end;
    pActiveModes.ClearAll;
  end;

{$IFDEF UseStreams}

  constructor Printer.Load(var S : IdStream);
  var
    St : String;
    L  : Byte;
  begin
    pZeroPtrs;
    S.ReadRange(pOptions,pVertCursor);
    St := S.ReadString;
    if S.PeekStatus <> 0 then begin
      InitStatus := epFatal + ecOutOfMemory;
      Done;
      Fail;
    end;
    L := Length(St);
    if L > 0 then begin
      if GetMemCheck(pVertCursor,Succ(L)) then
        pVertCursor^ := St
      else begin
        InitStatus := epFatal + ecOutOfMemory;
        Done;
        Fail;
      end;
    end;
    St := S.ReadString;
    if S.PeekStatus <> 0 then begin
      InitStatus := epFatal + ecOutOfMemory;
      Done;
      Fail;
    end;
    L := Length(St);
    if L > 0 then begin
      if GetMemCheck(pHorizCursor,Succ(L)) then
        pHorizCursor^ := St
      else begin
        InitStatus := epFatal + ecOutOfMemory;
        Done;
        Fail;
      end;
    end;
    St := S.ReadString;
    if S.PeekStatus <> 0 then begin
      InitStatus := epFatal + ecOutOfMemory;
      Done;
      Fail;
    end;
    L := Length(St);
    if L > 0 then begin
      if GetMemCheck(pDeciVert,Succ(L)) then
        pDeciVert^ := St
      else begin
        InitStatus := epFatal + ecOutOfMemory;
        Done;
        Fail;
      end;
    end;
    St := S.ReadString;
    if S.PeekStatus <> 0 then begin
      InitStatus := epFatal + ecOutOfMemory;
      Done;
      Fail;
    end;
    L := Length(St);
    if L > 0 then begin
      if GetMemCheck(pDeciHoriz,Succ(L)) then
        pDeciHoriz^ := St
      else begin
        InitStatus := epFatal + ecOutOfMemory;
        Done;
        Fail;
      end;
    end;

    pDriver := BasePrinterPtr(S.GetPtr);
    SetFlag(pOptions, pDeviceDealloc);

    if (S.PeekStatus <> 0) or (pDriver = Nil) then begin
      InitStatus := epFatal + ecNoPrnDriver;
      Done;
      Fail;
    end;
    if not pPrinterModes.Load(S) then begin
      Done;
      Fail;
    end;
    if not pFontStack.Init(FontStackSize) then begin
      Done;
      Fail;
    end;
    if not pActiveModes.Init(pMaxPrintModes) then begin
      Done;
      Fail;
    end;
    pActiveModes.ClearAll;
    @pPositionPrim     := S.ReadPointer;
    @pGraphicsProc     := S.ReadPointer;
    @pSpecialProc      := S.ReadPointer;
    @pErrorPrim        := S.ReadUserPointer(Nil);
    @pSetIntensity     := S.ReadPointer;
    if S.PeekStatus <> 0 then begin
      InitStatus := ecOutOfMemory;
      Done;
      Fail;
    end;
(*                                                {!!.03}
    if pDefaultFont <> 0 then
      EnableDefaultFont;
*)                                                {!!.03}
  end;

  procedure Printer.Store(var S : IdStream);
  var
    St : String;

  begin
    S.WriteRange(pOptions,pVertCursor);
    if pVertCursor = Nil then
      St := ''
    else
      St := pVertCursor^;
    S.WriteString(St);
    if pHorizCursor = Nil then
      St := ''
    else
      St := pHorizCursor^;
    S.WriteString(St);
    if pDeciVert = Nil then
      St := ''
    else
      St := pDeciVert^;
    S.WriteString(St);
    if pDeciHoriz = Nil then
      St := ''
    else
      St := pDeciHoriz^;
    S.WriteString(St);

    S.PutPtr(pDriver);
    pPrinterModes.Store(S);

    S.WritePointer(@pPositionPrim);
    S.WritePointer(@pGraphicsProc);
    S.WritePointer(@pSpecialProc);
    S.WriteUserPointer(@pErrorPrim,ptNil);
    S.WritePointer(@pSetIntensity);
  end;

  procedure PrinterStream(SPtr : IdStreamPtr);

  begin
    PrintModeStream(SPtr);
    DosPrinterStream(SPtr);
    BiosPrinterStream(SPtr);
    SingleListStream(SPtr);

    with SPtr^ do
      RegisterType(otPrinter,vePrinter,TypeOf(Printer),
                   @Printer.Store,@Printer.Load);
  end;

{$ENDIF}

  procedure Printer.pZeroPtrs;
    {-sets all pointers to Nil}
  begin
    pVertCursor    := Nil;
    pHorizCursor   := Nil;
    pDeciVert      := Nil;
    pDeciHoriz     := Nil;
    pCurrentMode   := Nil;
    @pPositionPrim := Nil;
    @pErrorPrim    := Nil;
    @pSetIntensity := Nil;
    @pGraphicsProc := Nil;
    @pSpecialProc  := Nil;
  end;

  function Printer.GetPrnOptions : Word;
    {-Returns the Option Flags for this printer}
  begin
    GetPrnOptions := pOptions;
  end;

  procedure Printer.SetPrnOptions(OptionFlags : Word);
    {-Sets the option flags for this printer}
  begin
    pOptions := OptionFlags;
  end;

  function Printer.GetCurrentFont : Byte;
    {-Returns the current font's Mode ID or zero if no current font}

  begin
    GetCurrentFont := pFontStack.PeekTop;
  end;

  procedure Printer.SetPrinterInfo(LPI, CPI, Point, LPP : Dimension);
    {-Sets lines per inch, chars per inch, and lines per page}

  begin
    pLinesPerInch := LPI;
    pCharsPerInch := CPI;
    pCharPoint    := Point;
    pLinesPerPage := LPP;
  end;

  procedure Printer.GetPrinterInfo(var LPI, CPI, Point, LPP : Dimension);
    {-Returns lines per inch, chars per inch, and lines per page}

  begin
    LPI   := pLinesPerInch;
    CPI   := pCharsPerInch;
    Point := pCharPoint;
    LPP   := pLinesPerPage;
  end;

  procedure Printer.SetLPI(LPI : Dimension);
    {-Sets lines per inch}
  begin
    pLinesPerInch := LPI;
  end;

  procedure Printer.SetCPI(CPI : Dimension);
    {-Sets chars per inch}
  begin
    pCharsPerInch := CPI;
  end;

  procedure Printer.SetPoint(Point : Dimension);
    {-Sets char point}
  begin
    pCharPoint := Point;
  end;

  procedure Printer.SetLPP(LPP : Dimension);
    {-Sets lines per page}
  begin
    pLinesPerPage := LPP;
  end;

  procedure Printer.SetYRatio(Ratio : Dimension);
    {-Sets the Y printer ratio}
  begin
    pYRatio := Ratio;
  end;

  procedure Printer.SetXRatio(Ratio : Dimension);
    {-Sets the X printer ratio}
  begin
    pXRatio := Ratio;
  end;

  procedure Printer.GetPhysicalTopMargin(var Top : Dimension);
    {-Returns the physical top margin}
  begin
    Top      := pPhyTopMargin;
  end;

  function Printer.GetLPI : Dimension;
    {-Returns lines per inch}
  begin
    GetLPI := pLinesPerInch;
  end;

  function Printer.GetCPI : Dimension;
    {-Returns chars per inch}
  begin
    GetCPI := pCharsPerInch;
  end;

  function Printer.GetPoint : Dimension;
    {-Returns the character point}
  begin
    GetPoint := pCharPoint;
  end;

  function Printer.GetLPP : Dimension;
    {-Returns lines per page}
  begin
    GetLPP := pLinesPerPage;
  end;

  function Printer.GetYRatio : Dimension;
    {-Returns the Y printer ratio}
  begin
    GetYRatio := pYRatio;
  end;

  function Printer.GetXRatio : Dimension;
    {-Returns the X printer ratio}
  begin
    GetXRatio := pXRatio;
  end;

  procedure Printer.SetPhysicalTopMargin(Top : Dimension);
    {-Sets the physical top margin. NOTE: does not send any codes to the
      printer, simply updates data field in Printer object.}
  begin
    pPhyTopMargin := Top;
  end;

  procedure Printer.SetIntensityProc(IP : IntensityProc);
  begin
    pSetIntensity := IP;
  end;

  procedure Printer.SetPositionPrim(PosFunc : PrinterPosFunc);
    {-Set printer position primitive and pointer to data}

  begin
    pPositionPrim := PosFunc;
  end;

  procedure Printer.SetGraphicsProc(GraphProc : PrinterModeProc);
    {-Sets the Graphics mode procedure}
  begin
    pGraphicsProc := GraphProc;
  end;

  procedure Printer.SetSpecialProc(SpecProc : PrinterModeProc);
    {-Sets the special procedure}
  begin
    pSpecialProc := SpecProc;
  end;

  procedure Printer.CallGraphicsProc(On : Boolean);
    {-Calls the graphics procedure}
  begin
    if @pGraphicsProc <> Nil then
      pGraphicsProc(On,@Self);
  end;

  procedure Printer.CallSpecialProc(On : Boolean);
    {-Calls the special procedure}
  begin
    if @pSpecialProc <> Nil then
      pSpecialProc(On,@Self);
  end;

  procedure Printer.SetPrintErrorFunc(PEF : PrintErrorFunc);
    {-Set the print error function}
  begin
    pErrorPrim := PEF;
  end;

  procedure Printer.SetDefaultFont(Attr : Byte);
    {-Sets the default font for this printer}
  begin
    pDefaultFont := Attr;
  end;

  procedure Printer.EnableDefaultFont;

  begin
    TurnOnByID(pDefaultFont);
  end;

  function Printer.GetDefaultFont : Byte;
    {-Returns the Attr of the default font}
  begin
    GetDefaultFont := pDefaultFont;
  end;

  function Printer.PrintError(ErrorCode : Word;
                              Recoverable : Boolean) : Boolean;

  begin
    PrintError := False;
    pLastError := ErrorCode;
    if @pErrorPrim <> Nil then
      if pErrorPrim(@Self,ErrorCode,Recoverable) then begin
        PrintError := True;
        pLastError := 0;
      end;
  end;

  procedure Printer.BackSpace(NumChars : Byte);
  var
    S : String;
    Temp : Dimension;
  begin
    S := PadCh('',BackSpaceChar,NumChars);
    PrintStrPrim(S);
    if pLastError <> 0 then
      Exit;
    Temp   := pxRatio * PosUnit;
    Temp   := Temp * Length(S);
    pLastX := pLastX - Temp;
  end;

  procedure Printer.AdvanceSingleLine;
  begin
    PrintStrPrim(LineAdvanceStr);
    if pLastError <> 0 then
      Exit;
    pLastY := pLastY + (pYRatio * PosUnit);
    pLastX := PosUnit;
  end;

  procedure Printer.AdvanceLine(NumLines : Byte);
  var
    I : Byte;
  begin
    for I := 1 to NumLines do
      AdvanceSingleLine;
  end;

  procedure Printer.AdvanceLinePreserveX(NumLines : Byte);     {!!.11}
    {-Advances a NumLines lines preserving the current column}
  var
    I : Byte;
    SaveX : Dimension;
  begin
    if NumLines = 0 then Exit;                                 {!!.12}
    SaveX := pLastX;
    AdvanceLine(NumLines);
    AdvanceSpace(Round(pXRatio * SaveX) - 1);
  end;

  procedure Printer.AdvanceSpace(NumChars : Byte);
  var
    S : String;
    Temp : Dimension;
  begin
    S := PadCh('',' ',NumChars);
    PrintStrPrim(S);
    if pLastError <> 0 then
      Exit;
    Temp   := pXRatio * Length(S);
    pLastX := pLastX + Temp;
  end;

  procedure Printer.PrintStrPrim(S : String);
  var
    ErrorCode   : Word;
    Finished    : Boolean;
    Len         : Byte;

  begin
    if pLastError <> 0 then
      Exit;
    Len := Length(S);
    {Double striking is not performed in this routine}
    Finished := False;
    repeat
      with pDriver^ do begin
        PrnPutBlock(S[1],Length(S));
        ErrorCode := PrnError;
        if ErrorCode = 0 then
          Finished := True
        else begin
          Finished := not PrintError(ErrorCode,True);
          S := Copy(S,Succ(PrnLastPut),Length(S));
        end;
      end;
    until Finished;
  end;

  procedure Printer.PrintStr(S : String);
  var
    Temp  : Dimension;
    Count : ShortInt;

  begin
    Count := CurrentStrikes;
    if (Count = 0) or (pLastError <> 0) then
      Exit;
    repeat
      PrintStrPrim(S);
      if pLastError <> 0 then
        Exit;
      Temp := pXRatio * Length(S);
      pLastX := pLastX + Temp;
      Dec(Count);
      if Count > 0 then begin
        BackSpace(Length(S));
        if pLastError <> 0 then
          Exit;
      end;
    until Count = 0;;
  end;

  procedure Printer.PrintStrPos(S : String; Row,Col : Dimension;
                                Relative : RelativeType);

  var
    Temp  : Dimension;
    Count : ShortInt;

  begin
    {Perform positioning}
    Count := CurrentStrikes;
    if Count = 0 then
      Exit;
    Position(Row,Col,Relative);
    if pLastError <> 0 then
      Exit;
    repeat
      PrintStrPrim(S);
      if pLastError <> 0 then
        Exit;
      Temp := pXRatio * Length(S);
      pLastX := pLastX + Temp;
      Dec(Count);
      if Count > 0 then begin
        BackSpace(Length(S));
        if pLastError <> 0 then
          Exit;
      end;
    until Count = 0;;
  end;

  procedure Printer.AddPrintMode(Name,OnEscSeq,OffEscSeq : String;
                                 Width, Height : Dimension;
                                 ID : Byte; OptionFlags : Word);

  var
    M : PrintModePtr;


  begin
    if pNumModes >= 255 then begin
      if PrintError(epNonFatal+ecOutOfMemory,False) then ;
      Exit;
    end;
    M := New(PrintModePtr,Init(Name,OnEscSeq,OffEscSeq,Width,Height,
                               ID,OptionFlags));
    if M = NIL then begin
      {insufficient memory to add print mode}
      if PrintError(epNonFatal+ecOutOfMemory,False) then ;
      Exit;
    end;
    Inc(pNumModes);
    pPrinterModes.Append(M);
  end;

  function Printer.GetPrintModeByID(ID : Byte) : PrintModePtr;
  var
    Found : Boolean;
    M : PrintModePtr;
  begin
    if ID = 0 then begin
      GetPrintModeByID := Nil;
      Exit;
    end;
    with pPrinterModes do begin
      M := PrintModePtr(Head);
      Found := False;
      while (not Found) and (M <> Nil) do begin
        if M^.PrintModeID = ID then
          Found := True
        else
          M := PrintModePtr(Next(M));
      end;
    end;
    GetPrintModeByID := M;
  end;

  procedure Printer.TurnOnByID(ID : Byte);
    {-Turn a print mode on by ID}
  var
    Mode : PrintModePtr;
  begin
    if ID = 0 then
      Exit;
    Mode := GetPrintModeByID(ID);
    if Mode <> Nil then
      Mode^.TurnOn(@Self);
  end;

  procedure Printer.pTurnFontOn(ID : Byte);
    {-Turn a print font on by ID}
  var
    Mode : PrintModePtr;
  begin
    if ID = 0 then
      Exit;
    Mode := GetPrintModeByID(ID);
    if Mode <> Nil then
      Mode^.pmTurnOnPrim(@Self);
  end;

  procedure Printer.TurnOffByID(ID : Byte);
    {-Turn a print mode off by ID}
  var
    Mode : PrintModePtr;
  begin
    if ID = 0 then
      Exit;
    Mode := GetPrintModeByID(ID);
    if Mode <> Nil then
      Mode^.TurnOff(@Self);
  end;

  procedure Printer.TurnOnByName(Name : String);
    {-Turn a print mode on by ID}
  var
    Mode : PrintModePtr;
  begin
    if Name = '' then
      Exit;
    Mode := GetPrintModeByName(Name);
    if Mode <> Nil then
      Mode^.TurnOn(@Self);
  end;

  procedure Printer.TurnOffByName(Name : String);
    {-Turn a print mode off by ID}
  var
    Mode : PrintModePtr;
  begin
    if Name = '' then
      Exit;
    Mode := GetPrintModeByName(Name);
    if Mode <> Nil then
      Mode^.TurnOff(@Self);
  end;

  function Printer.GetPrintModeByName(Name : String) : PrintModePtr;
  var
    Found : Boolean;
    M : PrintModePtr;

  begin
    with pPrinterModes do begin
      M := PrintModePtr(Head);
      Found := False;
      Name := StUpcase(Name);
      while (not Found) and (M <> Nil) do begin
        if M^.PrintModeName = Name then
          Found := True
        else
          M := PrintModePtr(Next(M));
      end;
    end;
    GetPrintModeByName := M;
  end;

  function Printer.PrinterReady : Boolean;

  begin
    PrinterReady := (pDriver^.PrnStatus = 0);
  end;

  procedure Printer.EnableDoubleStrike;
    {-Enable multi-strike mode}
  begin
    if @pSetIntensity = Nil then
      SetFlag(pOptions,pInDoubleStrike)
    else
      TurnOnByID(DoubleStrike);
  end;

  procedure Printer.DisableDoubleStrike;
    {-Disable Multi-strike mode}
  begin
    if @pSetIntensity = Nil then
      ClearFlag(pOptions,pInDoubleStrike)
    else
      TurnOffByID(DoubleStrike);
  end;

  function Printer.InDoubleStrike : Boolean;
    {-Returns true if more than one strike is required}
  begin
    if @pSetIntensity = Nil then
      InDoubleStrike := FlagIsSet(pOptions,pInDoubleStrike)
    else
      InDoubleStrike := IsModeActive(DoubleStrike);
  end;

  function Printer.InLandscape : Boolean;

  begin
    InLandscape := FlagIsSet(pOptions,pInLandscape);
  end;

  function Printer.StrikeCount : ShortInt;
    {-Returns the current value of pStrikeCount}
  begin
    StrikeCount := pStrikeCount;
  end;

  procedure Printer.SetStrikeCount(Strikes : ShortInt);
    {-Set the number of strikes needed when double strike is enabled}
  begin
    pStrikeCount := Strikes;
    if @pSetIntensity <> Nil then
      pSetIntensity(Strikes,@Self);
  end;

  function Printer.CurrentStrikes : ShortInt;
    {-Returns the number of strikes currently being applied, 1 if double
      strike is disabled, or pStrikeCount otherwise.  If printer has a
      SetIntensityProc, then one is always returned here}
  begin
    if FlagIsSet(pOptions,pInDoubleStrike) then
      CurrentStrikes := pStrikeCount
    else
      CurrentStrikes := 1;
  end;

  function Printer.XlatChar(C : Char) : Char;
    {-Return the character C translated from the XlatTable}
  begin
    XlatChar := pDriver^.CharXlat(C);
  end;

  procedure Printer.LinkToPrinter(Device : BasePrinterPtr);

  begin
    if (pDriver <> Nil) and FlagIsSet(pOptions,pDeviceDealloc) then
      Dispose(pDriver,Done);

    ClearFlag(pOptions,pDeviceDealloc);
    pDriver := Device;

    {clear any pending errors}
    pLastError := 0;                       {!!.01}
  end;

  procedure Printer.LinkToModes(var Modes : SingleList);
  var
    M : PrintModePtr;
  begin
    pNumModes := 0;
    pPrinterModes := Modes;
    M := PrintModePtr(Modes.Head);
    while M <> Nil do begin
      Inc(pNumModes);
      M := PrintModePtr(Modes.Next(M));
    end;
  end;

  procedure Printer.pOptionsOn(OptionFlags : Word);
  begin
    SetFlag(pOptions,OptionFlags);
  end;

  procedure Printer.pOptionsOff(OptionFlags : Word);
  begin
    ClearFlag(pOptions,OptionFlags);
  end;

  function Printer.pOptionsAreOn(OptionFlags : Word) : Boolean;
  begin
    pOptionsAreOn := FlagIsSet(pOptions,OptionFlags);
  end;

  function Printer.GetRegisteredType : Word;
    {-Returns the hardware type registered to this Printer}
  begin
    GetRegisteredType := pHardwareType;
  end;

  procedure Printer.SetRegisteredType(HardwareType : Word);

  begin
    pHardwareType := HardwareType;
  end;

  function Printer.GetBasePrinter : BasePrinterPtr;
    {-Returns the BasePrinterPtr}
  begin
    GetBasePrinter := pDriver;
  end;

  procedure Printer.DisposePosData;
    {-Disposes of a PositionDataType}
  begin
    if pVertCursor <> nil then                                        {!!.20}
      FreeMemCheck(pVertCursor,Succ(Length(pVertCursor^)));
    if pHorizCursor <> nil then                                       {!!.20}
      FreeMemCheck(pHorizCursor,Succ(Length(pHorizCursor^)));
    if pDeciVert <> nil then                                          {!!.20}
      FreeMemCheck(pDeciVert,Succ(Length(pDeciVert^)));
    if pDeciHoriz <> nil then                                         {!!.20}
      FreeMemCheck(pDeciHoriz,Succ(Length(pDeciHoriz^)));
  end;

  procedure Printer.SetPosData(VCurs,HCurs,VDeci,HDeci : String);

  begin
    if not GetMemCheck(pVertCursor,Succ(Length(VCurs))) then begin
      if PrintError(epNonFatal+ecOutOfMemory,True) then ;
      Exit;
    end;
    pVertCursor^ := VCurs;
    if not GetMemCheck(pHorizCursor,Succ(Length(HCurs))) then begin
      DisposePosData;
      if PrintError(epNonFatal+ecOutOfMemory,True) then ;
      Exit;
    end;
    pHorizCursor^ := HCurs;
    if not GetMemCheck(pDeciVert,Succ(Length(VDeci))) then begin
      DisposePosData;
      if PrintError(epNonFatal+ecOutOfMemory,True) then ;
      Exit;
    end;
    pDeciVert^ := VDeci;
    if not GetMemCheck(pDeciHoriz,Succ(Length(HDeci))) then begin
      DisposePosData;
      if PrintError(epNonFatal+ecOutOfMemory,True) then ;
      Exit;
    end;
    pDeciHoriz^ := HDeci;
  end;

  procedure Printer.ResetPage;

  begin
    pLastX   := PosUnit;
    pLastY   := PosUnit;
  end;

  procedure Printer.Landscape(On : Boolean);
    {-Turns internal landscape mode flag on or off}
  begin
    if On then
      SetFlag(pOptions, pInLandscape)
    else
      ClearFlag(pOptions, pInLandscape);
  end;

  procedure Printer.GetPosition(var Row, Col : Dimension); {!!.14}
  begin
    Row := pLastY;
    Col := pLastX;
  end;

{$IFDEF InitAllUnits}
begin
{$ENDIF}
end.
