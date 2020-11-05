program samples;

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Horse, Horse.Jhonson, fpjson, SysUtils;

procedure PostPing(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LBody: TJSONObject;
begin
  LBody := Req.Body<TJSONObject>;
  Res.Send<TJSONObject>(LBody);
end;

procedure OnListen(Horse: THorse);
begin
  Writeln(Format('Server is runing on %s:%d', [Horse.Host, Horse.Port]));
end;

begin
  THorse.Use(Jhonson);

  THorse.Post('/ping', PostPing);

  THorse.Listen(9000, OnListen);
end.
