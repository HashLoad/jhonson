program samples;

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Horse, Horse.Jhonson, fpjson, SysUtils;

procedure PostPing(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
begin
  LBody := Req.Body<TJSONObject>;
  Res.Send<TJSONObject>(LBody);
end;

begin
  THorse.Use(Jhonson);
  THorse.Post('/ping', PostPing);
  THorse.Listen(9000);
end.
