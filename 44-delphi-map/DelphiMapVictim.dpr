program DelphiMapVictim;

{$APPTYPE CONSOLE}

uses
  SysUtils;

function Fnv1a(const Text: string): Cardinal;
var
  I: Integer;
  Wrapped: UInt64;
begin
  Result := 2166136261;
  for I := 1 to Length(Text) do
  begin
    Result := Result xor Ord(Text[I]);
    Wrapped := UInt64(Result) * 16777619;
    Result := Cardinal(Wrapped and $FFFFFFFF);
  end;
end;

var
  Input: string;
begin
  Input := 'delphi-map';
  if ParamCount > 0 then
    Input := ParamStr(1);

  Writeln('Delphi MAP victim');
  Writeln('Input: ', Input);
  Writeln('Checksum: ', IntToHex(Fnv1a(Input), 8));
end.
