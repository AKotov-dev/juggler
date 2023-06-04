unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, Process, DefaultTranslator, IniPropStorage;

type

  { TMainForm }

  TMainForm = class(TForm)
    AutostartBox: TCheckBox;
    ClearBox: TCheckBox;
    VPNService1: TComboBox;
    IniPropStorage1: TIniPropStorage;
    Interface1: TEdit;
    Interface2: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    RadioGroup1: TRadioGroup;
    Shape1: TShape;
    Shape2: TShape;
    StaticText2: TStaticText;
    Timer1: TTimer;
    LogMemo: TMemo;
    StartBtn: TSpeedButton;
    StopBtn: TSpeedButton;
    VPNService2: TComboBox;
    procedure AutostartBoxChange(Sender: TObject);
    procedure ClearBoxClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure VPNService1Change(Sender: TObject);
    procedure VPNService2Change(Sender: TObject);
  private

  public

  end;

var
  MainForm: TMainForm;

resourcestring
  SStartVPN = 'Connection attempt, wait...';
  SStopResetVPN = 'Stop/Reset the connection';
  SCycleCompleted = 'The cycle is completed';

implementation

uses start_trd, status_trd;

{$R *.lfm}

{ TMainForm }

//Проверка чекбокса AutoStart
function CheckAutoStart: boolean;
var
  s: ansistring;
begin
  RunCommand('/bin/bash', ['-c',
    '[[ -n $(systemctl is-enabled juggler | grep "enabled") ]] && echo "yes"'], s);

  if Trim(s) = 'yes' then
    Result := True
  else
    Result := False;
end;

//Стоп
procedure TMainForm.StopBtnClick(Sender: TObject);
var
  s: ansistring;
begin
  LogMemo.Append(SStopResetVPN);

 { RunCommand('/bin/bash', ['-c', 'systemctl stop ' + VPNService1.Text +
    ' ' + VPNService2.Text + '; kill -9 $(cat /etc/juggler/pid) &'], s);}
  Application.ProcessMessages;

  if FileExists('/etc/juggler/juggler.sh') then
    RunCommand('/bin/bash', ['-c', '/etc/juggler/juggler.sh stop'], s);

  RadioGroup1.Enabled := True;
  StartBtn.Enabled := True;
end;

procedure TMainForm.VPNService1Change(Sender: TObject);
begin
  if VPNService1.ItemIndex <> 1 then Interface1.Text := 'tun0'
  else
    Interface1.Text := 'wg0';
end;

procedure TMainForm.VPNService2Change(Sender: TObject);
begin
  if VPNService2.ItemIndex <> 1 then Interface2.Text := 'tun0'
  else
    Interface2.Text := 'wg0';
end;

procedure TMainForm.StartBtnClick(Sender: TObject);
var
  s: ansistring;
  D: TStringList;
  FStart: TThread;
  VPN1, IF1, VPN2, IF2: string;
begin
  try
    D := TStringList.Create;

    //Реверс 1/2 или 2/1
    if RadioGroup1.ItemIndex = 0 then
    begin
      VPN1 := Trim(VPNService1.Text);
      IF1 := Trim(Interface1.Text);
      VPN2 := Trim(VPNService2.Text);
      IF2 := Trim(Interface2.Text);
    end
    else
    begin
      VPN1 := Trim(VPNService2.Text);
      IF1 := Trim(Interface2.Text);
      VPN2 := Trim(VPNService1.Text);
      IF2 := Trim(Interface1.Text);
    end;

    if (VPN1 = '') or (IF1 = '') or (VPN2 = '') or (IF2 = '') then Exit;

    //Создаём /etc/juggler/juggler.sh
    D.Add('#!/bin/bash');
    D.Add('');

    //Start connection "$1 == start"
    D.Add('if [ "$1" == "start" ]; then');
    D.Add('#PID');
    D.Add('echo $$ > /etc/juggler/pid');

    //Стоп всех возможных сервисов
    D.Add('#Stop all VPN connections');
    D.Add('systemctl stop protonvpn openvpngui luntik luntikwg ' +
      VPN1 + ' ' + VPN2 + ' 2>/dev/null');
    D.Add('wg-quick down /etc/luntikwg/wg0.conf  2>/dev/null');

    //Рестарт первого подключения
    D.Add('#Restart of the first VPN');
    D.Add('systemctl restart ' + VPN1);

    //Количество попыток attempt
    D.Add('attempt=8');
    D.Add('i=0; until [[ $(fping google.com) && $(ip -br a | grep ' +
      IF1 + ') ]]; do sleep 1');

    D.Add('((i++)); if [[ $i -gt $attempt ]]; then systemctl stop ' +
      VPN1 + ' ' + VPN2 + '; exit 1; else echo "' + IF1 +
      ' -> attempt ${i} of ${attempt}"; fi; done');

    //Рестарт второго подключения
    D.Add('#Restart of the second VPN');
    D.Add('systemctl restart ' + VPN2);

    D.Add('i=0; until [[ $(fping google.com) && $(ip -br a | grep ' +
      IF2 + ') ]]; do sleep 1');

    D.Add('((i++)); if [[ $i -gt $attempt ]]; then systemctl stop ' +
      VPN2 + ' ' + VPN1 + '; exit 1; else echo "' + IF2 +
      ' -> attempt ${i} of ${attempt}"; fi; done');

    D.Add('systemctl stop ' + VPN1);
    // D.Add('echo -e "# This file was created by Juggler\n\nnameserver 1.1.1.1\nnameserver 9.9.9.9" > /etc/resolv.conf');

    D.Add('   else');

    D.Add('#Stop connection');
    D.Add('systemctl stop protonvpn openvpngui luntik luntikwg ' +
      VPN1 + ' ' + VPN2 + ' 2>/dev/null');
    D.Add('kill -9 $(cat /etc/juggler/pid); wg-quick down /etc/luntikwg/wg0.conf 2>/dev/null');

    D.Add('#DNS restore');
    D.Add('if [[ $(systemctl is-active systemd-resolved) == "active" ]]; then');
    D.Add('systemctl restart systemd-resolved');
    D.Add('   else');
    D.Add('pgrep NetworkManager && systemctl restart NetworkManager.service || resolvconf -u');
    D.Add('fi');

    D.Add('fi');

    //Выход из скрипта не позволит запускать ExecStop отдельно (RemainAfterExit=yes)!
    // D.Add('exit 0');

    D.SaveToFile('/etc/juggler/juggler.sh');

    RunCommand('/bin/bash', ['-c', 'chmod +x /etc/juggler/juggler.sh'], s);

    //Запуск VM
    FStart := Start.Create(False);
    FStart.Priority := tpNormal;
  finally
    D.Free;
  end;
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  FLEDStatusThread: TThread;
begin
  IniPropStorage1.Restore;
  Caption := Application.Title;
  Shape1.Top := RadioGroup1.Height div 4 - Shape1.Height;
  Shape2.Top := RadioGroup1.Height div 2 + RadioGroup1.Height div 8 + Shape2.Height;
  StopBtn.Height := StartBtn.Height;

  //Проверка "Очистка сookies и кеш браузера"
  if FileExists('/etc/juggler/clear_cache') then ClearBox.Checked := True
  else
    ClearBox.Checked := False;

  //Проверка AutoStart
  AutoStartBox.Checked := CheckAutoStart;

  //Запуск потока проверки состояния локального порта
  FLEDStatusThread := LEDStatus.Create(False);
  FLEDStatusThread.Priority := tpNormal;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  if not DirectoryExists('/etc/juggler') then MkDir('/etc/juggler');
  IniPropStorage1.IniFileName := '/etc/juggler/juggler.conf';
end;

procedure TMainForm.ClearBoxClick(Sender: TObject);
begin
  if not ClearBox.Checked then DeleteFile('/etc/juggler/clear_cache')
  else
    LogMemo.Lines.SaveToFile('/etc/juggler/clear_cache');
end;

//Включение AutoStart
procedure TMainForm.AutostartBoxChange(Sender: TObject);
var
  s: ansistring;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;

  if AutoStartBox.Checked then
    RunCommand('/bin/bash', ['-c', 'systemctl enable juggler'], s)
  else
    RunCommand('/bin/bash', ['-c', 'systemctl disable juggler'], s);

  AutoStartBox.Checked := CheckAutoStart;
  Screen.Cursor := crDefault;
end;

end.
