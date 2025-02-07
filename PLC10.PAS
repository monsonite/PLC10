{****************************************************************
Finite State Machine PLC Compiler
Version 1.0
Started   : 12/12/97
Last Edit : 1/3/98
Copyright (c) 1997/98 David L. Jones - TRONNORT Technology
For use with the FSMPLC10 Hardware
Written in Borland Pascal 7.0
*****************************************************************}
{$I-}	{runtime I/O checking OFF}
Program FSM;
uses crt, dos;
Const
	MaxStateNameLength=25;
   MaxOutputStates=255;						{maximum number of output states-1}
   MaxInputStates=127;						{maximum number of input state-1}
type
	StateType=record
		Name:string[MaxStateNameLength];	{output state name}
		Jump:array[0..MaxInputStates] of byte;	 	{jump condition for each input state}
   end;
Var
	State:array[0..MaxOutputStates] of StateType;
   textfile:text;
   filename:string;
   LineCounter:longint;
   NumStates:word;
   DefaultDefined:boolean;				{true if a DEFAULT has already been defined
   											for current state group}
	GroupDefined:boolean;				{true if a state group has been defined}
   IfDefined:boolean;				 	{true if IF has been defined for current group}
   CurrentState:word;					{the current state number (binary output)}

{******************************************************************}
procedure CloseFile;
begin
	Close(textfile);
   if IOResult<>0 then;							{clear IoResult flag}
end;

{******************************************************************}
procedure ErrorAbort(s:string);
begin
	CloseFile;
   if IOResult<>0 then;							{clear IOResult flag}
	writeln('Error in line ',LineCounter,' - ',s);
   writeln;
	halt;
end;

{******************************************************************}
procedure Initialise;
var c,d:word;
begin
	clrscr;
	writeln;
	writeln('FSM PLC Complier v1.0 - 1/3/98');
	writeln('(c)1998 David L. Jones - TRONNORT Technology');
   writeln;
	LineCounter:=0;
   NumStates:=0;
	for c:=0 to MaxOutputStates do begin
		state[c].name:='';
      for d:=0 to MaxInputStates do state[c].jump[d]:=0;
   end;
	GroupDefined:=false;
   IfDefined:=false;
   DefaultDefined:=false;

	if paramcount<1 then begin
   	Writeln('http://www.ozemail.com.au/~dljones');
      Writeln;
   	WriteLn('Program syntax : PLC10 input.ext output.ext');
      WriteLn;
      WriteLn('Text file syntax :');
      WriteLn;
      WriteLn('DEFINE Label=00101010   (State label definition & binary ouput state)');
      WriteLn('DEFINE Label=00000000   (Must define a state for 00000000)');
      WriteLn;
      WriteLn('STATE Label             (Begin state definition)');
      WriteLn('  DEFAULT Label         (Optional default state)');
      WriteLn('  IF 0101xx0 Label      (Optional IF statement x="don''t care"');
      WriteLn;
      Halt;
   end;
end;

{******************************************************************}
procedure OpenFile;
begin
	FileName:=paramstr(1);
	Assign(textfile, FileName);
	FileMode := 0;  					{ Set file access to read only }
 	Reset(textfile);
	if IOResult<>0 then ErrorAbort('Error opening input file');
   Writeln('Compiling '+FileName);
end;

{********************************************************************
	Removes all spaces from the left of a string
********************************************************************}
function DelSpace(s:string):string;
begin
	repeat
		if s[1]=' ' then delete(s,1,1) else break;
   until false;
 DelSpace:=s;
end;

{********************************************************************
	Removes all spaces from the end of a string
********************************************************************}
function DelSpaceEnd(s:string):string;
begin
	repeat
		if s[length(s)]=' ' then delete(s,length(s),1) else break;
   until false;
	DelSpaceEnd:=s;
end;

{********************************************************************
	Converts a string to upper case
********************************************************************}
function UpcaseString(s:string):string;
var c:word;
begin
	for c:=1 to length(s) do s[c]:=upcase(s[c]);
	UpcaseString:=s;
end;

{********************************************************************
	Gets the state name from the string
********************************************************************}
function GetStateName(s:string):string;
var c:word;
	name:string;
begin
	if pos('=',s)=0 then ErrorAbort('No "=" in DEFINE statement');
   s:=DelSpace(s);
   name:=copy(s,1,pos('=',s)-1);					{get the state name}
   name:=UpCaseString(name);
   name:=DelSpace(name);					  		{take out any spaces from name}
   name:=DelSpaceEnd(name);
   if name='' then ErrorAbort('No state name defined');	{abort if no name}
   GetStateName:=name;
end;

{******************************************************************
	Convert 8bit binary string into a byte
*******************************************************************}
function ConvertBinary8(s:string):byte;
var c:byte;
	total:byte;
begin
	for c:=1 to 8 do
		if ((s[c]<>'1') AND (s[c]<>'0')) OR (length(s)<8) then
			ErrorAbort('Not a valid binary state number');
   total:=0;
	if s[1]='1' then inc(total,128);
   if s[2]='1' then inc(total,64);
	if s[3]='1' then inc(total,32);
   if s[4]='1' then inc(total,16);
	if s[5]='1' then inc(total,8);
   if s[6]='1' then inc(total,4);
	if s[7]='1' then inc(total,2);
   if s[8]='1' then inc(total,1);
   ConvertBinary8:=total;
end;

{******************************************************************
	Perform decoding for DEFINE statement
*******************************************************************}
procedure ProcessDefine(s:string);
var c:word;
	name:string;
   binary:string[8];
   statenumber:byte;
begin
   name:=GetStateName(s);				  				{get the state name}
	if length(name)>MaxStateNameLength then		{check state name length}
		ErrorAbort('State definition name too long');
	for c:=0 to MaxOutputStates do				{check for duplicate state name}
   	if state[c].name=name then ErrorAbort('State name is already defined');
   s:=DelSpace(s);
   s:=copy(s,pos('=',s)+1, length(s));  {remove state name & "=" from string}
   s:=DelSpace(s);
	binary:=s;											{get binary state number}
	statenumber:=ConvertBinary8(binary);
   if state[statenumber].name<>'' then
		ErrorAbort('State is already defined');
   state[statenumber].name:=name;				{assign state name}
end;

{******************************************************************
	Perform decoding for IF statement
*******************************************************************}
function MatchBinary(s:string;num:byte):boolean;
var c:byte;
	binary:string[7];
   match:boolean;
begin
							{convert num to binary string}
   if (num AND 64)>0 then binary[1]:='1' else binary[1]:='0';
   if (num AND 32)>0 then binary[2]:='1' else binary[2]:='0';
   if (num AND 16)>0 then binary[3]:='1' else binary[3]:='0';
   if (num AND 8)>0 then binary[4]:='1' else binary[4]:='0';
   if (num AND 4)>0 then binary[5]:='1' else binary[5]:='0';
   if (num AND 2)>0 then binary[6]:='1' else binary[6]:='0';
   if (num AND 1)>0 then binary[7]:='1' else binary[7]:='0';
   match:=true;											{assume match}
   for c:=1 to 7 do
   	case s[c] of
			'1','0':if s[c]<>binary[c] then begin 	{if not a match}
      			match:=false;
         		break;
         	end;
         'X':;										  		{assume 'X' input is match}
         else ErrorAbort('Not a valid IF input condition (0,1,X)');
      end;
   MatchBinary:=match;
end;

{******************************************************************
	Perform decoding for IF statement
*******************************************************************}
procedure ProcessIF(s:string);
var c:word;
	binary:string[7];
   match:boolean;
   JumpState:byte;
begin
   if not GroupDefined then ErrorAbort('Group state label not defined first');
	s:=DelSpace(s);
	if pos(' ',s)<>8 then ErrorAbort('all IF input conditions are not specified');
	binary:=s;										{get the IF input condition}
   s:=copy(s,8,length(s));						{take out the IF input condition}
   s:=DelSpace(s);
   s:=DelSpaceEnd(s);
   s:=UpCaseString(s);							{only the IF label should be left}
   match:=false;						  			{assume state name cannot be found}
   JumpState:=0;
	for c:=0 to MaxOutputStates do begin	{search all output states for match}
		if state[c].name=s then begin
			match:=true;
         JumpState:=c;								{get the jump state}
         break;
      end;
   end;
   if not match then ErrorAbort('State name not defined');
	for c:=0 to MaxInputStates do begin 	{search all state input conditions}
   	if MatchBinary(binary,c) then state[CurrentState].jump[c]:=JumpState;
   end;
   IfDefined:=true;
end;

{******************************************************************
	Perform decoding for DEFAULT statement
*******************************************************************}
procedure ProcessDEFAULT(s:string);
var c,num:byte;
	match:boolean;
begin
	if DefaultDefined then ErrorAbort('Duplicate DEFAULT statement');
   if not GroupDefined then ErrorAbort('Group state label not defined first');
   if IfDefined then ErrorAbort('DEFAULT must be first statement in group');
   s:=DelSpace(s);
   s:=DelSpaceEnd(s);
   s:=UpCaseString(s);							{only the ELSE label should be left}
   if s='' then ErrorAbort('Default statement requires a State label');
   match:=false;						  			{assume state name cannot be found}
   num:=0;
	for c:=0 to MaxOutputStates do begin	{search all output states for match}
		if state[c].name=s then begin
			match:=true;
         num:=c;								{get the jump state}
         break;
      end;
   end;
   if not match then ErrorAbort('State name not defined');
	for c:=0 to MaxInputStates do
   	state[CurrentState].jump[c]:=num;
   DefaultDefined:=true;
end;

{******************************************************************
	Perform decoding for the STATE statement
*******************************************************************}
procedure ProcessSTATE(s:string);
var c,num:byte;
	match:boolean;
begin
   s:=DelSpace(s);
   s:=DelSpaceEnd(s);
   s:=UpCaseString(s);							{only the STATE label should be left}
   if s='' then ErrorAbort('STATE name requires a State label');
   match:=false;						  			{assume state name cannot be found}
   num:=0;
	for c:=0 to MaxOutputStates do begin	{search all states for match}
		if state[c].name=s then begin
			match:=true;
         num:=c;											{get the group state}
         break;
      end;
   end;
   if not match then ErrorAbort('State name not defined');
   CurrentState:=num;
   GroupDefined:=true;
	IfDefined:=false;
   DefaultDefined:=false;
end;

{******************************************************************
	Perform decoding for each line
*******************************************************************}
procedure ProcessLine;
var s:string;
begin
	Readln(textfile,s);
   s:=UpcaseString(s);	  					{convert to upper case}
   s:=DelSpace(s);							{remove all spaces at start of line}
   if s[1]='/' then exit;					{found comment - ignore line}
   if copy(s,1,6)='DEFINE' then ProcessDefine(copy(s,7,length(s)));
   if copy(s,1,2)='IF' then ProcessIF(copy(s,3,length(s)));
   if copy(s,1,7)='DEFAULT' then ProcessDEFAULT(copy(s,8,length(s)));
   if copy(s,1,5)='STATE' then ProcessSTATE(copy(s,6,length(s)));
end;

{******************************************************************}
procedure WriteBinaryFile;
type
   DataArraytype=array[0..32767] of byte;			{binary data array}
Var
   DataPtr:^DataArrayType;								{pointer to binary data array}
	i,o:byte;
   result:word;
   DataFile:file of DataArrayType;            	{data file type}
begin
	new(DataPtr);										{allocate data array}
	for o:=0 to MaxOutputStates do				{A0-A7 address counter}
		for i:=0 to MaxInputStates do 			{A8-A14 address counter}
			DataPtr^[o+(i*256)]:=State[o].Jump[i];	{calculate EPROM data}

	if paramcount<2 then ErrorAbort('No output file specified');
	FileName:=paramstr(2);
	FileMode := 1;  					{ Set file access to write only }
	Assign(DataFile,FileName);
	Rewrite(DataFile);
   if IOResult<>0 then ErrorAbort('Error creating data file');
   Write(DataFile, DataPtr^);
   if IOResult<>0 then ErrorAbort('Error writing binary data to file');
   Close(DataFile);
   if IOResult<>0 then ErrorAbort('Error closing data file');
	Dispose(DataPtr);									{deallocate data array}
   Writeln('Data file '+FileName+' written to disk');
end;

{******************************************************************}
begin
	Initialise;
   OpenFile;
	While not eof(textfile) do begin
   	inc(LineCounter);
      ProcessLine;
   end;
   if state[0].name='' then
		ErrorAbort('No default state (00000000) condition specified');
	Writeln('Compilation complete - No errors');
   LineCounter:=999999;
   CloseFile;
   WriteBinaryFile;
	Writeln('Operation complete');
end.