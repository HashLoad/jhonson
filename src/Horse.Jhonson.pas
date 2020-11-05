unit Horse.Jhonson;

{$IF DEFINED(FPC)}
{$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils, HTTPDefs, fpjson, jsonparser,
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
  LWebRequest: {$IF DEFINED(FPC)}TRequest{$ELSE}TWebRequest{$ENDIF};
  LWebResponse: {$IF DEFINED(FPC)}TResponse{$ELSE}TWebResponse{$ENDIF};
  LContent: TObject;
  LJSON: {$IF DEFINED(FPC)}TJsonData{$ELSE}TJSONValue{$ENDIF};
begin
  LWebRequest := THorseHackRequest(Req).GetWebRequest;

  if ({$IF DEFINED(FPC)} StringCommandToMethodType(LWebRequest.Method)
    {$ELSE} LWebRequest.MethodType{$ENDIF} in [mtPost, mtPut]) and (LWebRequest.ContentType = 'application/json') then
  begin
    LJSON := {$IF DEFINED(FPC)} GetJSON(Req.Body) {$ELSE}TJSONObject.ParseJSONValue(Req.Body){$ENDIF};
    THorseHackRequest(Req).SetBody(LJSON);
  end;
  try
    Next;
  finally
    LWebResponse := THorseHackResponse(Res).GetWebResponse;
    LContent := THorseHackResponse(Res).GetContent;

    if Assigned(LContent) and LContent.InheritsFrom({$IF DEFINED(FPC)}TJsonData{$ELSE}TJSONValue{$ENDIF}) then
    begin
      LWebResponse.Content := {$IF DEFINED(FPC)}TJsonData(LContent).AsJSON {$ELSE}{$IF CompilerVersion > 27.0}TJSONValue(LContent).ToJSON{$ELSE}TJSONValue(LContent).ToString{$ENDIF}{$ENDIF};
      LWebResponse.ContentType := 'application/json; charset=' + Charset;
    end;
  end;
end;

end.
