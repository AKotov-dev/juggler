unit start_trd;

{$mode objfpc}{$H+}

interface

uses
  Classes, Process, SysUtils, ComCtrls, Forms;

type
  Start = class(TThread)
  private

    { Private declarations }
  protected
  var
    Result: TStringList;
    findex: integer;

    procedure Execute; override;

    procedure ShowLog;
    procedure StartProcess;
    procedure StopProcess;

  end;

implementation

uses Unit1;

{ TRD }

procedure Start.Execute;
var
  ExProcess: TProcess;
begin
  try //Вывод лога и прогресса
    Synchronize(@StartProcess);

    FreeOnTerminate := True; //Уничтожить по завершении
    Result := TStringList.Create;

    //Рабочий процесс
    ExProcess := TProcess.Create(nil);

    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');

    ExProcess.Parameters.Add('/etc/juggler/juggler.sh');

    ExProcess.Options := [poUsePipes, poStderrToOutPut];
    //, poWaitOnExit (синхронный вывод)

    ExProcess.Execute;

    //Выводим лог динамически
    while ExProcess.Running do
    begin
      Result.LoadFromStream(ExProcess.Output);

      if Result.Count <> 0 then
        Synchronize(@ShowLog);
    end;

  finally
    Synchronize(@StopProcess);
    Result.Free;
    ExProcess.Free;
    Terminate;
  end;
end;

{ БЛОК ОТОБРАЖЕНИЯ ЛОГА }

//Запуск
procedure Start.StartProcess;
begin
  with MainForm do
  begin
    RadioGroup1.Enabled := False;

    //Очищаем лог
    LogMemo.Clear;
    LogMemo.Append(SStartVPN);

    LogMemo.Repaint;
  end;
end;

//Запуск завершен
procedure Start.StopProcess;
begin
  with MainForm do
  begin
    LogMemo.Append(SCycleCompleted);
    LogMemo.Repaint;
  end;
end;

//Вывод лога
procedure Start.ShowLog;
var
  i: integer;
begin
  //Вывод построчно
  for i := 0 to Result.Count - 1 do
    MainForm.LogMemo.Lines.Append(Result[i]);

  //Промотать список вниз
  MainForm.LogMemo.SelStart := Length(MainForm.LogMemo.Text);
  MainForm.LogMemo.SelLength := 0;
end;

end.
