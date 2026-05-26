program Win32DelphiVictim;

{$APPTYPE CONSOLE}

uses
  SysUtils;

function Rotate(Value: Cardinal): Cardinal;
begin
  Result := (Value shl 7) or (Value shr 25);
end;

var
  I: Integer;
  Value: Cardinal;
begin
  Value := 305419896;
  for I := 1 to 32 do
    Value := Rotate(Value xor Cardinal(I * 13));

  Writeln('Win32 Delphi i386 victim');
  Writeln('Checksum: ', IntToHex(Value, 8));
end.
