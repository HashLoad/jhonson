unit Horse.Jhonson;

{$IF DEFINED(FPC)}
{$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, HTTPDefs, fpjson, jsonparser,
{$ELSE}
  System.Classes, System.JSON, System.SysUtils, Web.HTTPApp,
{$ENDIF}
  Horse, Horse.Commons;

function Jhonson: THorseCallback; overload;
function Jhonson(const ACharset: string): THorseCallback; overload;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});

implementation

var
  Charset: string;

function Jhonson: THorseCallback; overload;
begin
  Result := Jhonson('UTF-8');
end;

function Jhonson(const ACharset: string): THorseCallback; overload;
begin
  Charset := ACharset;
  Result := Middleware;
end;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
var
  LJSON: {$IF DEFINED(FPC)}TJsonData{$ELSE}TJSONValue{$ENDIF};
begin
  if ({$IF DEFINED(FPC)} StringCommandToMethodType(Req.RawWebRequest.Method)
    {$ELSE} Req.RawWebRequest.MethodType{$ENDIF} in [mtPost, mtPut, mtPatch]) and (Req.RawWebRequest.ContentType = 'application/json') then
  begin
    LJSON := {$IF DEFINED(FPC)} GetJSON(Req.Body) {$ELSE}TJSONObject.ParseJSONValue(Req.Body){$ENDIF};
    Req.Body(LJSON);
  end;
  try
    Next;
  finally
    if (Res.Content <> nil) and Res.Content.InheritsFrom({$IF DEFINED(FPC)}TJsonData{$ELSE}TJSONValue{$ENDIF}) then
    begin
      {$IF DEFINED(FPC)}
      Res.RawWebResponse.ContentStream := TStringStream.Create(TJsonData(Res.Content).AsJSON);
      {$ELSE}
      Res.RawWebResponse.Content := {$IF CompilerVersion > 27.0}TJSONValue(Res.Content).ToJSON{$ELSE}TJSONValue(LContent).ToString{$ENDIF};
      {$ENDIF}
      Res.RawWebResponse.ContentType := 'application/json; charset=' + Charset;
    end;
  end;
end;

end.
