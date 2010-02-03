unit WR_DataSet;
{$IFDEF FPC} {$MODE Delphi} {$ENDIF}
interface
uses KromUtils, Math, SysUtils, Windows;

type
  TDSNode = packed record
    i1: Longint;
    i2: Longint;
    i3: Longint;
  end;


type
  TDataSet = class
  private
    Header:array[1..33]of char;
    DSqty:integer;

    TB:array of record
      Entries:integer; //VA_Entries
      Index:integer;   //VA_Index
      iC:byte;         //VA_iC ?
      Lib:string;      //VA_Lib
      Cond:byte;       //Cond switch
      CondText:array of string; //Cond text
    end;

    CO:array of array of record
      Entries:integer; //VA_Entries
      Index:integer;   //VA_Index
      Lib:string;      //VA_Lib
      iU:byte;         //VA_iU ?
      SM:string;       //VA_database path
      ST:string;       //VA_ST
      IC:string;       //VA_IC
      SC:string;       //VA_SC
    end;

    Value:array of array of array of record
      Typ:byte;
      Int:integer;
      Rel:single;
      Str:string;
    end;

  protected

  public
    constructor Create;
    function LoadDS(FileName:string):boolean;
    procedure SaveDS(FileName:string);

    property DSCount:integer read DSQty;

    function TBCount(iDS:integer):integer;
    function TBIndex(iDS:integer):integer;
    function GetTBLib(iDS:integer):string;
    function GetTBIndexLibString(iDS:integer):string;

    function COCount(iDS,iTB:integer):integer;
    function GetCOLib(iDS,iTB:integer):string;
    function GetCOIndexLibString(iDS,iTB:integer):string;
    function COInfoLines(iDS,iTB:integer):string;

    function GetValueType(iDS,iTB,iCO:integer):byte;
    function GetValueAsString(iDS,iTB,iCO:integer):string;

    procedure SetValueType(iDS,iTB,iCO:integer; aType:byte);
    procedure SetValueAsString(iDS,iTB,iCO:integer; Text:string);

    procedure AddValueAcrossTB(iDS:integer);

    function FindStringInValues(i1,i2,i3:integer; Input:string):TDSNode; //Return Address of found string DS:TB:CO

    function WRTextEn(Input:string):string;
  published

  end;

var
  fDataSet:TDataSet;

implementation

constructor TDataSet.Create;
begin
//
end;


function TDataSet.LoadDS(FileName:string):boolean;
var
  IgnoreTyp:boolean;
  f:file;
  c:array[1..32768]of char;
  ErrS:string;
  iDS,iTB,iCO:integer;
  i:integer;
  MsgRes:integer;

  function ReadString(Len:word):string;
  begin
    Result:='';
    if Len=0 then exit;
    blockread(f,c,Len+1);
    c[Len+1]:=#0;
    Result:=StrPas(@c);
  end;

begin
  Result:=false;
  IgnoreTyp:=false;

  assignfile(f,FileName); FileMode:=0; reset(f,1); FileMode:=2;

  blockread(f,Header,33);
  DSqty:=ord(Header[9]);
  setlength(TB,DSqty+1);
  setlength(CO,DSqty+1);
  setlength(Value,DSqty+1);

  for iDS:=1 to DSqty do begin
  blockread(f,c,33);
  TB[iDS].Entries:=int2(c[9],c[10]);
  TB[iDS].Index:=int2(c[17],c[18]);
  TB[iDS].iC:=ord(c[25]);
  TB[iDS].Lib:=ReadString(ord(c[30]));

  setlength(CO[iDS],TB[iDS].Entries+1);
  setlength(Value[iDS],TB[iDS].Entries+1);

  for iTB:=1 to TB[iDS].Entries do begin
    blockread(f,c,4);
    if c[1]+c[2]+c[3]+c[4]<>'NDCO' then begin
      blockread(f,c,4);
      TB[iDS].Cond:=int2(c[1],c[2]);
      setlength(TB[iDS].CondText,TB[iDS].Cond+1);
        for i:=1 to TB[iDS].Cond do begin
          blockread(f,c,4); //length of entry
          TB[iDS].CondText[i]:=ReadString(int2(c[1],c[2]));
        end;
      blockread(f,c,4); //read upcoming NDCO
    end;

  blockread(f,c,24);                      //VAEn, VAId, VALb
  CO[iDS,iTB].Entries:=int2(c[5],c[6]);
  CO[iDS,iTB].Index:=int2(c[13],c[14]);
  CO[iDS,iTB].Lib:=ReadString(ord(c[21]));

  blockread(f,c,13);                      //VASM
  CO[iDS,iTB].iU:=ord(c[5]);
  CO[iDS,iTB].SM:=ReadString(ord(c[10]));

  blockread(f,c,8);                       //VAST
  CO[iDS,iTB].ST:=ReadString(ord(c[5]));

  blockread(f,c,8);                       //VAIC
  CO[iDS,iTB].IC:=ReadString(ord(c[5]));

  blockread(f,c,8);                       //VASC
  CO[iDS,iTB].SC:=ReadString(ord(c[5]));

  setlength(Value[iDS,iTB],CO[iDS,iTB].Entries+100);//optimistic way to avoid common length mismatches

    for iCO:=1 to CO[iDS,iTB].Entries do begin
    Value[iDS,iTB,iCO].Typ:=0;
    Value[iDS,iTB,iCO].Int:=0;
    Value[iDS,iTB,iCO].Rel:=0;
    Value[iDS,iTB,iCO].Str:='';
    blockread(f,Value[iDS,iTB,iCO].Typ,1);
    case Value[iDS,iTB,iCO].Typ of
      1:  blockread(f,Value[iDS,iTB,iCO].Int,4);
      2:  blockread(f,Value[iDS,iTB,iCO].Rel,4);
      16: begin
            blockread(f,c,4);
            Value[iDS,iTB,iCO].Str:=ReadString(int2(c[1],c[2]));
          end;
      else begin
            blockread(f,c,4);
            if not IgnoreTyp then begin
              ErrS := 'Unknown Typ='+inttostr(ord(c[1]))+#10+inttostr(iDS)+':'+inttostr(iTB)+':'+inttostr(iCO);
              MsgRes:=MessageBox(HWND(nil),@(ErrS)[1],'Error',MB_ABORTRETRYIGNORE or MB_DEFBUTTON3);
              if MsgRes=IDABORT then begin closefile(f); exit; end;
              if MsgRes=IDRETRY then IgnoreTyp:=false;
              if MsgRes=IDIGNORE then IgnoreTyp:=true;
            end;
          end;
    end; //case

    end;//CO.Entries
  end;//TB.Entries
  end; //1..DSqty
  closefile(f);
  Result:=true;
end;


procedure TDataSet.SaveDS(FileName:string);
var
  f:file;
  s:string;
  iDS,iTB,iCO:integer;
  i:integer;
begin
  assignfile(f,FileName); rewrite(f,1);

  blockwrite(f,Header,33); //assume DSQty didn't changed

  for iDS:=1 to DSqty do begin
    s:='NDTBVAEn'+chr2(TB[iDS].Entries,4)+'VAId'+chr2(TB[iDS].Index,4)+'VAiC'+chr(TB[iDS].iC)+
    'VALb'+chr2(length(TB[iDS].Lib),4)+TB[iDS].Lib+#0;
    if TB[iDS].Cond>0 then s:=s+'Cond'+chr2(TB[iDS].Cond,4);
    for i:=1 to TB[iDS].Cond do s:=s+chr2(length(TB[iDS].CondText[i]),4)+TB[iDS].CondText[i]+#0;
    blockwrite(f,s[1],length(s));

    for iTB:=1 to TB[iDS].Entries do begin
      s:='NDCOVAEn'+chr2(CO[iDS,iTB].Entries,4)+'VAId'+chr2(CO[iDS,iTB].Index,4)
      +'VALb'+chr2(length(CO[iDS,iTB].Lib),4)+CO[iDS,iTB].Lib+#0
      +'VAiU'+chr(CO[iDS,iTB].iU);

      s:=s+'VASM'+chr2(length(CO[iDS,iTB].SM),4);
      if CO[iDS,iTB].SM<>'' then s:=s+CO[iDS,iTB].SM+#0;
      s:=s+'VAST'+chr2(length(CO[iDS,iTB].ST),4);
      if CO[iDS,iTB].ST<>'' then s:=s+CO[iDS,iTB].ST+#0;
      s:=s+'VAIC'+chr2(length(CO[iDS,iTB].IC),4);
      if CO[iDS,iTB].IC<>'' then s:=s+CO[iDS,iTB].IC+#0;
      s:=s+'VASC'+chr2(length(CO[iDS,iTB].SC),4);
      if CO[iDS,iTB].SC<>'' then s:=s+CO[iDS,iTB].SC+#0;
      blockwrite(f,s[1],length(s));

      for iCO:=1 to CO[iDS,iTB].Entries do begin
        s:=chr(Value[iDS,iTB,iCO].Typ);
        case Value[iDS,iTB,iCO].Typ of
          1:      s:=s+chr2(Value[iDS,iTB,iCO].Int,4);
          2:      s:=s+unreal2(Value[iDS,iTB,iCO].Rel);
          16:   begin
                  s:=s+chr2(length(Value[iDS,iTB,iCO].Str),4);
                  if Value[iDS,iTB,iCO].Str<>'' then s:=s+Value[iDS,iTB,iCO].Str+#0;
                end;
          else    s:=s+#0+#0+#0+#0;
        end;
        blockwrite(f,s[1],length(s));

      end;//CO.Entries
    end;//TB.Entries
  end; //1..DSqty
  closefile(f);

end;


function TDataSet.TBCount(iDS:integer):integer;
begin
  Result:=TB[iDS].Entries;
end;


function TDataSet.TBIndex(iDS:integer):integer;
begin
  Result:=TB[iDS].Index;
end;


function TDataSet.GetTBLib(iDS:integer):string;
begin
  Result:=TB[iDS].Lib;
end;

function TDataSet.GetTBIndexLibString(iDS:integer):string;
begin
  Result:=inttostr(iDS)+'|'+inttostr(TB[iDS].Index)+'. '+TB[iDS].Lib;
end;


function TDataSet.COCount(iDS,iTB:integer):integer;
begin
  Result:=CO[iDS,iTB].Entries;
end;


function TDataSet.GetCOLib(iDS,iTB:integer):string;
begin
  Result:=CO[iDS,iTB].Lib;
end;


function TDataSet.GetCOIndexLibString(iDS,iTB:integer):string;
begin
  Result:=inttostr(iTB)+'|'+inttostr(CO[iDS,iTB].Index)+'. '+CO[iDS,iTB].Lib;
end;


function TDataSet.COInfoLines(iDS,iTB:integer):string;
begin
  Result:=CO[iDS,iTB].SM+eol+CO[iDS,iTB].ST+eol+CO[iDS,iTB].IC+eol+CO[iDS,iTB].SC;
end;


function TDataSet.GetValueType(iDS,iTB,iCO:integer):byte;
begin
  Result := Value[iDS,iTB,iCO].Typ;
end;


function TDataSet.GetValueAsString(iDS,iTB,iCO:integer):string;
begin
  Result := '';
  if InRange(iCO,1,CO[iDS,iTB].Entries) then //Make sure it's in the range
  case Value[iDS,iTB,iCO].Typ of
    1: Result := inttostr(Value[iDS,iTB,iCO].Int);
    2: Result := float2fix(Value[iDS,iTB,iCO].Rel,3);
   16: Result := Value[iDS,iTB,iCO].Str;
  end;
end;


procedure TDataSet.SetValueType(iDS,iTB,iCO:integer; aType:byte);
begin
  Value[iDS,iTB,iCO].Typ := aType;
end;


procedure TDataSet.SetValueAsString(iDS,iTB,iCO:integer; Text:string);
begin
  case Value[iDS,iTB,iCO].Typ of
    1: Value[iDS,iTB,iCO].Int := strtoint(Text);
    2: Value[iDS,iTB,iCO].Rel := strtofloat(Text);
   16: Value[iDS,iTB,iCO].Str := Text;
  end;
end;

procedure TDataSet.AddValueAcrossTB(iDS:integer);
var iTB,iCO:integer;
begin
  for iTB:=1 to TB[iDS].Entries do
  if CO[iDS,iTB].Entries<>0 then begin
    inc(CO[iDS,iTB].Entries); //Add one new entry
    iCO:=CO[iDS,iTB].Entries;
    Value[iDS,iTB,iCO]:=Value[iDS,iTB,iCO-1]; //Get previous Typ and Value
  end;
end;


{Look for string starting from given node}
function TDataSet.FindStringInValues(i1,i2,i3:integer; Input:string):TDSNode;
var iDS,iTB,iCO:integer; m,l:integer; s:string; Match:boolean;
begin
  Input := UpperCase(Input);
  Match := false;

  for iDS:=i1 to DSqty do begin
    for iTB:=i2 to TB[iDS].Entries do begin
      for iCO:=i3 to CO[iDS,iTB].Entries do begin

        s := UpperCase(GetValueAsString(iDS,iTB,iCO));

        Match := false;
        for m:=0 to length(s)-length(Input) do begin
          Match := true;
          for l:=1 to length(Input) do
            Match := Match and (s[m+l]=Input[l]);
          if Match then break;
        end;

        if Match then begin
          Result.i1 := iDS;
          Result.i2 := iTB;
          Result.i3 := iCO;
          exit;
        end;
      end;
      i3 := 1; //Reset
    end;
    i2 := 1; //Reset
  end;

  if not Match then begin
    Result.i1 := 1;
    Result.i2 := 1;
    Result.i3 := 1;
  end;
end;


function TDataSet.WRTextEn(Input:string):string;
var IDbegin:boolean; i,ID:integer; sTmp:string;
begin
  Result:='';
  //When string is too short to contain anything
  if length(Input)<3 then begin
    Result:=Input;
    exit;
  end;

  IDbegin:=false; sTmp:=''; ID:=0;
  for i:=1 to length(Input) do begin

    if Input[i]='[' then begin
      IDbegin:=true;
      ID:=0;
      sTmp:=Input[i];
    end else
    if Input[i]=']' then begin
      IDbegin:=false;
      sTmp:='';
      Result:=Result+Value[1,3,ID+1].Str;
    end else

    if IDbegin then begin
      sTmp:=Input[i];
      if (Input[i] in ['0'..'9']) then
        ID:=ID*10+strtoint(Input[i])
      else begin
        IDbegin:=false;
        Result:=Result+sTmp;
      end;
    end else
      Result:=Result+Input[i];
  end;
  
{function TForm1.WRTexte(txt:string):string;
var h,m,j:integer; st:string;
begin
if length(txt)<2 then begin WRTexte:=''; exit; end;
h:=2; m:=0;
if txt[1]<>'[' then WRTexte:=txt else begin
repeat
if not (txt[h] in ['0'..'9']) then begin WRTexte:=txt; exit; end;
m:=m*10+strtoint(txt[h]);
inc(h);
until((h=length(txt))or(txt[h]=']')or(txt[h]=':'));
if txt[h]=':' then begin WRTexte:=''; exit; end;
st:=Value[1,3,m+1].Str;
for j:=h+1 to length(txt) do
st:=st+txt[j];
WRTexte:=st;
end;
Result:=txt;
end;}
end;


end.