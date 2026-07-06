unit Horse.Jhonson;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
  {$IF DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}
    {$MODESWITCH FUNCTIONREFERENCES+}
  {$ENDIF}
{$ENDIF}

interface

uses
  SysUtils, Classes,
  {$IF DEFINED(FPC)}
  HTTPDefs, fpjson, jsonparser,
  {$ELSE}
  System.JSON, Web.HTTPApp,
  {$ENDIF}
  Horse, Horse.Commons;

type
  TJhonsonErrorCallback = {$IF DEFINED(FPC) and not DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}TObject{$ELSE}reference to procedure(ARes: THorseResponse; const AError: string){$ENDIF};

function Jhonson: THorseCallback; overload;
function Jhonson(const ACharset: string): THorseCallback; overload;
function Jhonson(const ACharset: string; const AErrorCallback: TJhonsonErrorCallback): THorseCallback; overload;

implementation

{ ==============================================================================
  SEÇÃO DELPHI (XE7+ até Delphi 12+)
  ============================================================================== }
{$IFNDEF FPC}
procedure HandleErrorDelphi(Res: THorseResponse; const AError: string; const AErrorCallback: TJhonsonErrorCallback);
begin
  if Assigned(AErrorCallback) then
    AErrorCallback(Res, AError)
  else
    Res.Send('Invalid JSON').Status(THTTPStatus.BadRequest);
  raise EHorseCallbackInterrupted.Create;
end;

function JhonsonDelphi(const ACharset: string; const AErrorCallback: TJhonsonErrorCallback): THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LJSON: TJSONValue;
      LBodyStr: string;
      {$IF CompilerVersion >= 36}
      LJSONOutputOption: TJSONValue.TJsonOutputOptions;
      {$IFEND}
    begin
      if (Req.MethodType in [mtPost, mtPut, mtPatch]) and (Pos('application/json', LowerCase(Req.RawWebRequest.ContentType)) > 0) then
      begin
        LBodyStr := Req.Body;
        if LBodyStr.Trim.IsEmpty then
          HandleErrorDelphi(Res, 'Empty JSON', AErrorCallback);

        LJSON := nil;
        try
          LJSON := TJSONObject.ParseJSONValue(LBodyStr);
        except
          on E: Exception do
            HandleErrorDelphi(Res, E.Message, AErrorCallback);
        end;

        if not Assigned(LJSON) then
          HandleErrorDelphi(Res, 'Invalid JSON structure', AErrorCallback);

        Req.Body(LJSON);
      end;

      try
        Next;
      finally
        if (Res.Content <> nil) and Res.Content.InheritsFrom(TJSONValue) then
        begin
          {$IF CompilerVersion >= 36}
            if SameText(ACharset, 'utf-8') then
              LJSONOutputOption := [TJSONValue.TJSONOutputOption.EncodeBelow32]
            else
              LJSONOutputOption := [TJSONValue.TJSONOutputOption.EncodeBelow32, TJSONValue.TJSONOutputOption.EncodeAbove127];
            Res.RawWebResponse.Content := TJSONValue(Res.Content).ToJSON(LJSONOutputOption);
          {$ELSE}
            Res.RawWebResponse.Content := TJSONValue(Res.Content).ToJSON;
          {$ENDIF}
          Res.RawWebResponse.ContentType := 'application/json; charset=' + ACharset;
        end;
      end;
    end;
end;
{$ENDIF}

{ ==============================================================================
  SEÇÃO LAZARUS / FPC (Moderno e Legado)
  ============================================================================= }
{$IFDEF FPC}
procedure HandleErrorFPC(Res: THorseResponse; const AError: string; const AErrorCallback: TJhonsonErrorCallback);
begin
  {$IF DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}
  if Assigned(AErrorCallback) then
    AErrorCallback(Res, AError)
  else
  {$ENDIF}
    Res.Send('Invalid JSON').Status(THTTPStatus.BadRequest);
  raise EHorseCallbackInterrupted.Create;
end;

{$IF DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}
function JhonsonFPCModern(const ACharset: string; const AErrorCallback: TJhonsonErrorCallback): THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TNextProc)
    var
      LJSON: TJsonData;
      LBodyStr: string;
    begin
      if (Req.MethodType in [mtPost, mtPut, mtPatch]) and (Pos('application/json', LowerCase(Req.RawWebRequest.ContentType)) > 0) then
      begin
        LBodyStr := Req.Body;
        if LBodyStr.Trim.IsEmpty then
          HandleErrorFPC(Res, 'Empty JSON', AErrorCallback);

        LJSON := nil;
        try
          LJSON := GetJSON(LBodyStr);
        except
          on E: Exception do
            HandleErrorFPC(Res, E.Message, AErrorCallback);
        end;

        if not Assigned(LJSON) then
          HandleErrorFPC(Res, 'Invalid JSON structure', AErrorCallback);

        if Assigned(Req.Body<TObject>) then
          Req.Body<TObject>.Free;

        Req.Body(LJSON);
      end;

      try
        Next;
      finally
        if (Res.Content <> nil) and Res.Content.InheritsFrom(TJsonData) then
        begin
          Res.RawWebResponse.ContentStream := TStringStream.Create(TJsonData(Res.Content).AsJSON);
          Res.RawWebResponse.ContentType := 'application/json; charset=' + ACharset;
        end;
      end;
    end;
end;
{$ELSE}
var
  GCharset: string;

procedure MiddlewareFPCLegacy(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LJSON: TJsonData;
  LBodyStr: string;
begin
  if (Req.MethodType in [mtPost, mtPut, mtPatch]) and (Pos('application/json', LowerCase(Req.RawWebRequest.ContentType)) > 0) then
  begin
    LBodyStr := Req.Body;
    if Trim(LBodyStr) = '' then
      HandleErrorFPC(Res, 'Empty JSON', nil);

    try
      LJSON := GetJSON(LBodyStr);
    except
      on E: Exception do
        HandleErrorFPC(Res, E.Message, nil);
    end;

    if not Assigned(LJSON) then
      HandleErrorFPC(Res, 'Invalid JSON structure', nil);

    if Assigned(Req.Body<TObject>) then
      Req.Body<TObject>.Free;

    Req.Body(LJSON);
  end;

  try
    Next;
  finally
    if (Res.Content <> nil) and Res.Content.InheritsFrom(TJsonData) then
    begin
      Res.RawWebResponse.ContentStream := TStringStream.Create(TJsonData(Res.Content).AsJSON);
      Res.RawWebResponse.ContentType := 'application/json; charset=' + GCharset;
    end;
  end;
end;
{$ENDIF}
{$ENDIF}

{ ==============================================================================
  MÉTODOS PÚBLICOS DE ENTRADA (Mapeadores Limpos)
  ============================================================================= }
function Jhonson: THorseCallback;
begin
  Result := Jhonson('UTF-8');
end;

function Jhonson(const ACharset: string): THorseCallback;
begin
  Result := Jhonson(ACharset, nil);
end;

function Jhonson(const ACharset: string; const AErrorCallback: TJhonsonErrorCallback): THorseCallback;
begin
  {$IF DEFINED(FPC)}
    {$IF DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}
      Result := JhonsonFPCModern(ACharset, AErrorCallback);
    {$ELSE}
      GCharset := ACharset;
      Result := THorseCallback(@MiddlewareFPCLegacy);
    {$ENDIF}
  {$ELSE}
    Result := JhonsonDelphi(ACharset, AErrorCallback);
  {$ENDIF}
end;

end.
