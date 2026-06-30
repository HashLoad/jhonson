unit Test.Horse.Jhonson;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.Diagnostics,
  System.Net.HttpClient,
  System.Net.URLClient,
  Horse;

type
  TTestHorseJhonson = class(TTestCase)
  private
    FClient: THTTPClient;
    class var FServerThread: TThread;
    class procedure StartServer;
    class procedure StopServer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  public
    class destructor Destroy;
  published
    procedure TestPing;
    procedure TestValidJSONObject;
    procedure TestValidJSONArray;
    procedure TestInvalidJSON;
    procedure TestEmptyBody;
    procedure TestResponseJSONSerialization;
    procedure TestCharsetHeaderUTF8;
    procedure TestPerformanceBenchmark;
  end;

implementation

uses
  System.JSON,
  System.SyncObjs,
  Horse.Jhonson;

const
  BASE_URL = 'http://localhost:9091';

class procedure TTestHorseJhonson.StartServer;
begin
  if Assigned(FServerThread) then
    Exit;

  // Registrar middleware global Jhonson
  THorse.Use(Jhonson());

  // Rota basica para testar se o servidor responde
  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('pong');
    end);

  // Rota /json_object (retorna a string do JSON para compatibilidade e performance)
  THorse.Post('/json_object',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LObj: TJSONObject;
    begin
      LObj := Req.Body<TJSONObject>;
      Res.Send(LObj.ToJSON);
    end);

  // Rota /json_array
  THorse.Post('/json_array',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LArr: TJSONArray;
      I, LSum: Integer;
    begin
      LArr := Req.Body<TJSONArray>;
      LSum := 0;
      for I := 0 to LArr.Count - 1 do
        LSum := LSum + LArr.Items[I].AsType<Integer>;
      Res.Send(LSum.ToString);
    end);

  // Rota /json_response (retorna string JSON e Content-Type explicito para compatibilidade robusta)
  THorse.Get('/json_response',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LObj: TJSONObject;
    begin
      LObj := TJSONObject.Create;
      try
        LObj.AddPair('ping', 'pong');
        Res.Send(LObj.ToJSON);
        Res.ContentType('application/json; charset=UTF-8');
      finally
        LObj.Free;
      end;
    end);

  // Inicializar o servidor em thread separada
  FServerThread := TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(9091);
    end);
  FServerThread.FreeOnTerminate := False;
  FServerThread.Start;

  // Aguardar o servidor iniciar
  Sleep(1000);
end;

class procedure TTestHorseJhonson.StopServer;
begin
  if not Assigned(FServerThread) then
    Exit;
    
  THorse.StopListen;
  FServerThread.WaitFor;
  FreeAndNil(FServerThread);
end;

class destructor TTestHorseJhonson.Destroy;
begin
  StopServer;
end;

procedure TTestHorseJhonson.SetUp;
begin
  inherited;
  StartServer;
  FClient := THTTPClient.Create;
end;

procedure TTestHorseJhonson.TearDown;
begin
  FreeAndNil(FClient);
  inherited;
end;

procedure TTestHorseJhonson.TestPing;
var
  LResponse: IHTTPResponse;
begin
  LResponse := FClient.Get(BASE_URL + '/ping');
  CheckEquals(200, LResponse.StatusCode, 'Ping falhou');
  CheckEquals('pong', LResponse.ContentAsString, 'Resposta de ping incorreta');
end;

procedure TTestHorseJhonson.TestValidJSONObject;
var
  LResponse: IHTTPResponse;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
begin
  LStream := TStringStream.Create('{"ping":"pong"}', TEncoding.UTF8);
  try
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
    LResponse := FClient.Post(BASE_URL + '/json_object', LStream, nil, LHeaders);
    CheckEquals(200, LResponse.StatusCode, 'Status code incorreto');
    CheckTrue(Pos('pong', LResponse.ContentAsString) > 0, 'Resposta incorreta');
  finally
    LStream.Free;
  end;
end;

procedure TTestHorseJhonson.TestValidJSONArray;
var
  LResponse: IHTTPResponse;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
begin
  LStream := TStringStream.Create('[10, 20, 30]', TEncoding.UTF8);
  try
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
    LResponse := FClient.Post(BASE_URL + '/json_array', LStream, nil, LHeaders);
    CheckEquals(200, LResponse.StatusCode, 'Status code incorreto');
    CheckEquals('60', LResponse.ContentAsString, 'Soma incorreta');
  finally
    LStream.Free;
  end;
end;

procedure TTestHorseJhonson.TestInvalidJSON;
var
  LResponse: IHTTPResponse;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
begin
  LStream := TStringStream.Create('{"ping":"pong"', TEncoding.UTF8);
  try
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
    LResponse := FClient.Post(BASE_URL + '/json_object', LStream, nil, LHeaders);
    CheckEquals(400, LResponse.StatusCode, 'Devia retornar Bad Request');
    CheckTrue(Pos('Invalid JSON', LResponse.ContentAsString) > 0, 'Mensagem de erro incorreta');
  except
    on E: Exception do
      Fail('Excecao nao esperada: ' + E.Message);
  end;
  LStream.Free;
end;

procedure TTestHorseJhonson.TestEmptyBody;
var
  LResponse: IHTTPResponse;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
begin
  LStream := TStringStream.Create('', TEncoding.UTF8);
  try
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
    LResponse := FClient.Post(BASE_URL + '/json_object', LStream, nil, LHeaders);
    CheckEquals(400, LResponse.StatusCode, 'Devia retornar Bad Request para body vazio');
  finally
    LStream.Free;
  end;
end;

procedure TTestHorseJhonson.TestResponseJSONSerialization;
var
  LResponse: IHTTPResponse;
begin
  LResponse := FClient.Get(BASE_URL + '/json_response');
  CheckEquals(200, LResponse.StatusCode);
  CheckEquals('{"ping":"pong"}', LResponse.ContentAsString);
end;

procedure TTestHorseJhonson.TestCharsetHeaderUTF8;
var
  LResponse: IHTTPResponse;
  LContentType: string;
begin
  LResponse := FClient.Get(BASE_URL + '/json_response');
  CheckEquals(200, LResponse.StatusCode);
  LContentType := LResponse.GetHeaderValue('Content-Type');
  CheckTrue(Pos('charset=UTF-8', LContentType) > 0, 'Deveria retornar Content-Type com UTF-8');
end;

procedure TTestHorseJhonson.TestPerformanceBenchmark;
var
  LPayload: string;
  LStopwatch: TStopwatch;
  LSuccessCount, LFailedCount: Integer;
  LTotalMs: Int64;
  
  procedure RunCarga(const ALabel: string; ARequests: Integer; ASizeKB: Integer);
  begin
    LPayload := StringOfChar('x', ASizeKB * 1024 - 15);
    LPayload := '{"ping":"' + LPayload + '"}';
    LSuccessCount := 0;
    LFailedCount := 0;
    
    LStopwatch := TStopwatch.StartNew;
    TParallel.For(1, ARequests,
      procedure(Idx: Integer)
      var
        LLocalClient: THTTPClient;
        LLocalStream: TStringStream;
        LLocalResponse: IHTTPResponse;
        LLocalHeaders: TNetHeaders;
      begin
        LLocalClient := THTTPClient.Create;
        LLocalStream := TStringStream.Create(LPayload, TEncoding.UTF8);
        try
          SetLength(LLocalHeaders, 1);
          LLocalHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
          try
            LLocalResponse := LLocalClient.Post(BASE_URL + '/json_object', LLocalStream, nil, LLocalHeaders);
            if LLocalResponse.StatusCode = 200 then
              TInterlocked.Increment(LSuccessCount)
            else
              TInterlocked.Increment(LFailedCount);
          except
            TInterlocked.Increment(LFailedCount);
          end;
        finally
          LLocalStream.Free;
          LLocalClient.Free;
        end;
      end);
    LStopwatch.Stop;
    LTotalMs := LStopwatch.ElapsedMilliseconds;
    
    Writeln('    ' + ALabel + ' - Requests: ' + ARequests.ToString + 
            ', Tempo: ' + LTotalMs.ToString + ' ms' +
            ', Sucesso: ' + LSuccessCount.ToString + 
            ', Falhas: ' + LFailedCount.ToString +
            ', RPS: ' + FormatFloat('#,##0.00', (LSuccessCount / (LTotalMs / 1000))));
  end;

begin
  Writeln;
  Writeln('  === INICIANDO BENCHMARK DE PERFORMANCE ===');
  RunCarga('Carga Leve (1KB) ', 1000, 1);
  RunCarga('Carga Media (10KB)', 500, 10);
  RunCarga('Carga Pesada (1MB)', 50, 1024);
  Writeln('  =========================================');
  CheckTrue(True);
end;

initialization
  RegisterTest(TTestHorseJhonson.Suite);

end.
