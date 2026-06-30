program ClientBench;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Threading,
  System.SyncObjs,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Net.Mime;

const
  URL = 'http://127.0.0.1:9091/json_object';

function GenerateJSON(ASizeInKB: Integer): string;
var
  LStringBuilder: TStringBuilder;
  LData: string;
begin
  LStringBuilder := TStringBuilder.Create;
  try
    LStringBuilder.Append('{"ping":"');
    if ASizeInKB * 1024 - 15 > 0 then
      LData := StringOfChar('x', ASizeInKB * 1024 - 15)
    else
      LData := '';
    LStringBuilder.Append(LData);
    LStringBuilder.Append('"}');
    Result := LStringBuilder.ToString;
  finally
    LStringBuilder.Free;
  end;
end;

procedure RunBenchmark(const ALabel: string; ATotalRequests: Integer; ASizeInKB: Integer);
var
  LPayload: string;
  LStopwatch: TStopwatch;
  LSuccessCount: Integer;
  LFailedCount: Integer;
  LTotalMs: Int64;
begin
  Writeln('Gerando payload para: ', ALabel, ' (', ASizeInKB, ' KB)...');
  LPayload := GenerateJSON(ASizeInKB);
  
  LSuccessCount := 0;
  LFailedCount := 0;
  
  Writeln('Iniciando benchmark com ', ATotalRequests, ' requisicoes concorrentes...');
  LStopwatch := TStopwatch.StartNew;
  
  TParallel.For(1, ATotalRequests,
    procedure(I: Integer)
    var
      LClient: THTTPClient;
      LStream: TStringStream;
      LResponse: IHTTPResponse;
      LHeaders: TNetHeaders;
    begin
      LClient := THTTPClient.Create;
      LStream := TStringStream.Create(LPayload, TEncoding.UTF8);
      try
        try
          SetLength(LHeaders, 1);
          LHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
          LResponse := LClient.Post(URL, LStream, nil, LHeaders);
          if LResponse.StatusCode = 200 then
            TInterlocked.Increment(LSuccessCount)
          else
            TInterlocked.Increment(LFailedCount);
        except
          TInterlocked.Increment(LFailedCount);
        end;
      finally
        LStream.Free;
        LClient.Free;
      end;
    end);
    
  LStopwatch.Stop;
  LTotalMs := LStopwatch.ElapsedMilliseconds;
  
  Writeln('--- Resultado ', ALabel, ' ---');
  Writeln('Tempo Total: ', LTotalMs, ' ms');
  Writeln('Sucesso: ', LSuccessCount);
  Writeln('Falhas: ', LFailedCount);
  if LTotalMs > 0 then
    Writeln('RPS (Requests/sec): ', FormatFloat('#,##0.00', (LSuccessCount / (LTotalMs / 1000))))
  else
    Writeln('RPS (Requests/sec): N/A');
  Writeln;
end;

begin
  try
    Writeln('Iniciando benchmark de performance local...');
    Writeln('Certifique-se de que o ServerBench esta rodando na porta 9091!');
    Writeln;
    
    RunBenchmark('Carga Leve (1KB)', 2000, 1);
    RunBenchmark('Carga Media (10KB)', 1000, 10);
    RunBenchmark('Carga Pesada (1MB)', 100, 1024);
    
    Writeln('Benchmark finalizado.');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
