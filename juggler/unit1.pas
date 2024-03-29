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
    VPNDefBox: TCheckBox;
    ClearBox: TCheckBox;
    PingMemo: TMemo;
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
    procedure FormResize(Sender: TObject);
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
  showmainform: boolean; //Флаг первого запуска формы (Show)

resourcestring
  SStartVPN = 'Connection attempt, wait...';
  SStopResetVPN = 'Stop/Reset the connection...';
  SCycleCompleted = 'The cycle is completed';

implementation

uses start_trd, status_trd, ping_trd;

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

  //Промотать список вниз
  LogMemo.SelStart := Length(MainForm.LogMemo.Text);
  LogMemo.SelLength := 0;

  Application.ProcessMessages;

  if FileExists('/etc/juggler/juggler.sh') then
    RunCommand('/bin/bash', ['-c', '/etc/juggler/juggler.sh stop'], s);

  RadioGroup1.Enabled := True;
  StartBtn.Enabled := True;
end;

procedure TMainForm.VPNService1Change(Sender: TObject);
begin
  case VPNService1.Text of
    'luntik': Interface1.Text := 'tun0';
    'luntikwg': Interface1.Text := 'wg0';
    'openvpngui': Interface1.Text := 'tun0';
    'protonvpn': Interface1.Text := 'tun0';
    'sstp-connector': Interface1.Text := 'ppp0';
  end;
end;

procedure TMainForm.VPNService2Change(Sender: TObject);
begin
  case VPNService2.Text of
    'luntik': Interface2.Text := 'tun0';
    'luntikwg': Interface2.Text := 'wg0';
    'openvpngui': Interface2.Text := 'tun0';
    'protonvpn': Interface2.Text := 'tun0';
    'sstp-connector': Interface2.Text := 'ppp0';
  end;
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

    if (VPN1 = '') or (IF1 = '') or (VPN2 = '') or (IF2 = '') or (IF1 = IF2) then Exit;

    //Создаём /etc/juggler/juggler.sh
    D.Add('#!/bin/bash');
    D.Add('');

    //Start connection "$1 == start"
    D.Add('if [ "$1" == "start" ]; then');
    D.Add('#PID');
    D.Add('echo $$ > /etc/juggler/pid');

    //Стоп всех возможных сервисов, включая Cloudflare (TM) WARP
    D.Add('#Stopping all possible VPN connections');
    D.Add('systemctl stop protonvpn openvpngui luntik luntikwg sstp-connector ' +
      VPN1 + ' ' + VPN2 + ' 2>/dev/null');
    D.Add('wg-quick down /etc/luntikwg/wg0.conf 2>/dev/null');
    D.Add('warp-cli --accept-tos disconnect > /dev/null 2>&1');

    //Задержка и кол-во попыток
    D.Add('');
    D.Add('delay=5');
    D.Add('attempt=10');

    //Cтарт первого подключения
    D.Add('');
    D.Add('echo "Start of the ' + VPN1 + '.service and ping, wait..."');
    D.Add('systemctl start ' + VPN1);

    D.Add('');
    D.Add('i=0; until [[ $(ip -br a | grep ' + IF1 +
      ') && $(fping google.com) ]]; do sleep 1');
    D.Add('((i++)); if [[ $i -gt $attempt ]]; then systemctl stop ' +
      VPN1 + ' ' + VPN2 + '; exit 1; else echo "' + IF1 +
      ' -> attempt ${i} of ${attempt}"; fi; done');

    //Задержка переходных процессов: интерфейс появляется и пинг не пропадает (SSTP)
    D.Add('');
    D.Add('echo "Transient delay ($delay sec...)"');
    D.Add('sleep $delay');

    //Cтарт второго подключения (google.com меняем на ya.ru чтобы избежать дубликатов/защита сайта)
    D.Add('');
    D.Add('echo "Start of the ' + VPN2 + '.service and ping, wait..."');
    D.Add('systemctl start ' + VPN2);
    //ROSA и другие, свободное изменение DNS
    D.Add('umount -l /etc/resolv.conf 2>/dev/null');

    //Сносим VPN1 default route
    if VPNDefBox.Checked then
    begin
      D.Add('');
      D.Add('#Delete the route of the first VPN');
      D.Add('[[ $(ip r | grep 0.0.0.0) ]] && ip r flush $(ip r | grep "0.0.0.0") | head -n1');
      D.Add('[[ $(ip r show table all | grep "default dev wg0") ]] && ip r flush default dev wg0 table 51820');
      D.Add('[[ $(ip r | grep "default dev ppp0") ]] && ip r flush default dev ppp0');
    end;

    //Важная задержка для WireGuard! Иначе не успевает создать Keypar!
    D.Add('');
    D.Add('echo "Delay in switching the first and second VPN ($delay sec)..."');
    D.Add('sleep $delay');

    D.Add('');
    D.Add('i=0; until [[ $(ip -br a | grep ' + IF2 +
      ') && $(fping ya.ru) ]]; do sleep 1');
    D.Add('((i++)); if [[ $i -gt $attempt ]]; then systemctl stop ' +
      VPN2 + ' ' + VPN1 + '; exit 1; else echo "' + IF2 +
      ' -> attempt ${i} of ${attempt}"; fi; done');

    D.Add('');
    D.Add('systemctl stop ' + VPN1 + '; sleep 1');
    D.Add('echo "Replacing DNS after disconnecting ' + VPN1 + '.service"');
    D.Add('echo -e "# Generated by Juggler\nnameserver 9.9.9.9\nnameserver 1.0.0.1" > /etc/resolv.conf');

    D.Add('     else');

    D.Add('#Stopping connection');
    D.Add('systemctl stop protonvpn openvpngui luntik luntikwg sstp-connector ' +
      VPN1 + ' ' + VPN2 + ' 2>/dev/null; wg-quick down /etc/luntikwg/wg0.conf 2>/dev/null');
    D.Add('warp-cli --accept-tos disconnect > /dev/null 2>&1');

    D.Add('#DNS restore');
    D.Add('if [[ $(systemctl is-active systemd-resolved) == "active" ]]; then');
    D.Add('systemctl restart systemd-resolved');
    D.Add('   else');
    D.Add('pgrep NetworkManager && systemctl restart NetworkManager.service || resolvconf -u');
    D.Add('fi');

    //Убиваем возможно зависший скрипт
    D.Add('kill -9 $(cat /etc/juggler/pid)');
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
  S: ansistring;
  FLEDStatusThread: TThread;
  FCheckPingThread: TThread;
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

  //Проверка AutoStart + флаг проверки AutoStartBox
  showmainform := True;
  AutoStartBox.Checked := CheckAutoStart;
  showmainform := False;

  RunCommand('/bin/bash', ['-c',
    '[[ $(ip -br a | grep -E "wg0|tun0") ]] && echo "yes"'], S);
  if Trim(S) = 'yes' then
  begin
    RadioGroup1.Enabled := False;
    StartBtn.Enabled := False;
  end;

  //Запуск потока проверки состояния локального порта
  FLEDStatusThread := LEDStatus.Create(False);
  FLEDStatusThread.Priority := tpNormal;

  //Поток проверки состояния
  FCheckPingThread := CheckPing.Create(False);
  FCheckPingThread.Priority := tpNormal;
end;

procedure TMainForm.FormCreate(Sender: TObject);

begin
  if not DirectoryExists('/etc/juggler') then MkDir('/etc/juggler');
  IniPropStorage1.IniFileName := '/etc/juggler/juggler.conf';
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  PingMemo.Height := LogMemo.Height div 2;
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
  if not showmainform then
  begin
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;

    if AutoStartBox.Checked then
      RunCommand('/bin/bash', ['-c', 'systemctl enable juggler'], s)
    else
      RunCommand('/bin/bash', ['-c', 'systemctl disable juggler'], s);

    AutoStartBox.Checked := CheckAutoStart;

    Screen.Cursor := crDefault;
  end
  else
    showmainform := False;
end;

end.
