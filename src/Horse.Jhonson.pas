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
  HTTPDefs, fpjson, jsonparser, TypInfo, Contnrs,
  {$ELSE}
  System.JSON, Web.HTTPApp, REST.Json,
  {$ENDIF}
  Horse, Horse.Commons;

type
  TJhonsonErrorCallback = {$IF DEFINED(FPC) and not DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}TObject{$ELSE}reference to procedure(ARes: THorseResponse; const AError: string){$ENDIF};

  THorseRequestHelper = class helper for THorseRequest
  public
    function BodyAs<T: class, constructor>: T;
  end;

function Jhonson: THorseCallback; overload;
function Jhonson(const ACharset: string): THorseCallback; overload;
function Jhonson(const ACharset: string; const AErrorCallback: TJhonsonErrorCallback): THorseCallback; overload;

{$IFDEF FPC}
procedure JsonToClassFPC(const AJSONStr: string; AObject: TObject);
function ClassToJsonFPC(AObject: TObject): string;
{$ENDIF}

implementation

{$IFDEF FPC}
procedure JsonToClassFPC(const AJSONStr: string; AObject: TObject);
var
  LJSON: TJsonData;
  LJSONObject: TJSONObject;
  LPropList: PPropList;
  LCount, I: Integer;
  LPropInfo: PPropInfo;
  LValue: TJSONData;
begin
  if AJSONStr = '' then
    Exit;
  LJSON := GetJSON(AJSONStr);
  try
    if not (LJSON is TJSONObject) then
      Exit;
    LJSONObject := TJSONObject(LJSON);
    LCount := GetPropList(AObject.ClassInfo, tkProperties, nil);
    if LCount > 0 then
    begin
      GetMem(LPropList, LCount * SizeOf(PPropInfo));
      try
        GetPropList(AObject.ClassInfo, tkProperties, LPropList);
        for I := 0 to LCount - 1 do
        begin
          LPropInfo := LPropList^[I];
          LValue := LJSONObject.Find(LPropInfo^.Name);
          if Assigned(LValue) then
          begin
            case LPropInfo^.PropType^.Kind of
              tkInteger: SetOrdProp(AObject, LPropInfo, LValue.AsInteger);
              tkInt64: SetOrdProp(AObject, LPropInfo, LValue.AsInt64);
              tkFloat: SetFloatProp(AObject, LPropInfo, LValue.AsFloat);
              tkBool: SetOrdProp(AObject, LPropInfo, Ord(LValue.AsBoolean));
              tkAString, tkWString, tkUString: SetStrProp(AObject, LPropInfo, LValue.AsString);
            end;
          end;
        end;
      finally
        FreeMem(LPropList);
      end;
    end;
  finally
    LJSON.Free;
  end;
end;

function ClassToJsonFPC(AObject: TObject): string;
var
  LPropList: PPropList;
  LCount, I: Integer;
  LPropInfo: PPropInfo;
  LJSONObject: TJSONObject;
  LJSONArray: TJSONArray;
  LList: TObjectList;
  LListItem: TObject;
begin
  Result := '{}';
  if not Assigned(AObject) then
    Exit;

  if AObject.InheritsFrom(TObjectList) then
  begin
    LList := TObjectList(AObject);
    LJSONArray := TJSONArray.Create;
    try
      for I := 0 to LList.Count - 1 do
      begin
        LListItem := LList.Items[I];
        if Assigned(LListItem) then
          LJSONArray.Add(GetJSON(ClassToJsonFPC(LListItem)));
      end;
      Result := LJSONArray.AsJSON;
    finally
      LJSONArray.Free;
    end;
    Exit;
  end;

  LJSONObject := TJSONObject.Create;
  try
    LCount := GetPropList(AObject.ClassInfo, tkProperties, nil);
    if LCount > 0 then
    begin
      GetMem(LPropList, LCount * SizeOf(PPropInfo));
      try
        GetPropList(AObject.ClassInfo, tkProperties, LPropList);
        for I := 0 to LCount - 1 do
        begin
          LPropInfo := LPropList^[I];
          case LPropInfo^.PropType^.Kind of
            tkInteger: LJSONObject.Add(LPropInfo^.Name, GetOrdProp(AObject, LPropInfo));
            tkInt64: LJSONObject.Add(LPropInfo^.Name, GetInt64Prop(AObject, LPropInfo));
            tkFloat: LJSONObject.Add(LPropInfo^.Name, GetFloatProp(AObject, LPropInfo));
            tkBool: LJSONObject.Add(LPropInfo^.Name, Boolean(GetOrdProp(AObject, LPropInfo)));
            tkAString, tkWString, tkUString: LJSONObject.Add(LPropInfo^.Name, GetStrProp(AObject, LPropInfo));
          end;
        end;
      finally
        FreeMem(LPropList);
      end;
    end;
    Result := LJSONObject.AsJSON;
  finally
    LJSONObject.Free;
  end;
end;
{$ENDIF}

{ THorseRequestHelper }

function THorseRequestHelper.BodyAs<T>: T;
var
  LKey: string;
  LObj: TObject;
begin
  LKey := T.ClassName;
  if not Self.State.TryGetValue(LKey, LObj) then
  begin
    {$IF DEFINED(FPC)}
    LObj := T.Create;
    try
      JsonToClassFPC(Self.Body, LObj);
    except
      LObj.Free;
      raise;
    end;
    {$ELSE}
    LObj := TJson.JsonToObject<T>(Self.Body);
    {$ENDIF}
    Self.State.Add(LKey, LObj);
  end;
  Result := T(LObj);
end;

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
        if (Res.Content <> nil) then
        begin
          if Res.Content.InheritsFrom(TJSONValue) then
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
          end
          else if not Res.Content.InheritsFrom(TStream) then
          begin
            Res.RawWebResponse.Content := TJson.ObjectToJsonString(Res.Content);
            Res.RawWebResponse.ContentType := 'application/json; charset=' + ACharset;
            Res.Content(nil);
          end;
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
        if (Res.Content <> nil) then
        begin
          if Res.Content.InheritsFrom(TJsonData) then
          begin
            Res.RawWebResponse.ContentStream := TStringStream.Create(TJsonData(Res.Content).AsJSON);
            Res.RawWebResponse.ContentType := 'application/json; charset=' + ACharset;
          end
          else if not Res.Content.InheritsFrom(TStream) then
          begin
            Res.RawWebResponse.ContentStream := TStringStream.Create(ClassToJsonFPC(Res.Content));
            Res.RawWebResponse.ContentType := 'application/json; charset=' + ACharset;
            Res.Content(nil);
          end;
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
    if (Res.Content <> nil) then
    begin
      if Res.Content.InheritsFrom(TJsonData) then
      begin
        Res.RawWebResponse.ContentStream := TStringStream.Create(TJsonData(Res.Content).AsJSON);
        Res.RawWebResponse.ContentType := 'application/json; charset=' + GCharset;
      end
      else if not Res.Content.InheritsFrom(TStream) then
      begin
        Res.RawWebResponse.ContentStream := TStringStream.Create(ClassToJsonFPC(Res.Content));
        Res.RawWebResponse.ContentType := 'application/json; charset=' + GCharset;
        Res.Content(nil);
      end;
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
