unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  LCLType, BGRABitmap, BGRABitmapTypes, uGameTypes, uGameState, uGameEngine,
  uAudioManager, uSaveManager, uPanelRenderer, uRadarRenderer, uSaveLoadForm;

type
  { Struktur data untuk antrean efek ketikan log }
  TLogQueueItem = record
    FullText: string;
    CurrentLength: Integer;
    MaxLen: Integer;
  end;

  { TMainForm }
  TMainForm = class(TForm)
    btnAddCrew: TButton;
    btnDirectiveCargo: TButton;
    btnDirectiveShield: TButton;
    btnRemoveCrew: TButton;
    btnRepair: TButton;
    btnToggleComms: TButton;
    btnToggleLab: TButton;
    btnToggleLS: TButton;
    btnToggleShield: TButton;
    btnUpgrade: TButton;

    { Tombol untuk Transmisi Misterius (Encounter) }
    btnDecrypt: TButton;
    btnIgnore: TButton;

    cmbTargetModule: TComboBox;
    GroupBox1: TGroupBox;
    lbEventLog: TListBox;
    Panel1: TPanel;
    pbCoreStatus: TPaintBox;
    pnlLeftControls: TPanel;
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblSol: TLabel;
    pnlBottom: TPanel;
    lblStatusText: TLabel;
    lblUptime: TLabel;
    pnlLeft: TPanel;
    pbModules: TPaintBox;

    pnlCenter: TPanel;
    pbRadar: TPaintBox;
    pnlRight: TPanel;
    pnlRightControls: TPanel;

    { Komponen untuk Filter Visual (Layar Radar) }
    cmbVisualFilter: TComboBox;
    lblFilter: TLabel;

    btnNewGame: TButton;
    btnSaveGame: TButton;
    btnLoadGame: TButton;
    TimerLoop: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TimerLoopTimer(Sender: TObject);
    procedure pbModulesPaint(Sender: TObject);
    procedure pbRadarPaint(Sender: TObject);
    procedure pbCoreStatusPaint(Sender: TObject);
    procedure btnToggleLSClick(Sender: TObject);
    procedure btnToggleShieldClick(Sender: TObject);
    procedure btnToggleLabClick(Sender: TObject);
    procedure btnToggleCommsClick(Sender: TObject);
    procedure btnRepairClick(Sender: TObject);
    procedure btnNewGameClick(Sender: TObject);
    procedure btnSaveGameClick(Sender: TObject);
    procedure btnLoadGameClick(Sender: TObject);

    { Event handlers untuk fitur Upgrade & Kru }
    procedure btnUpgradeClick(Sender: TObject);
    procedure btnAddCrewClick(Sender: TObject);
    procedure btnRemoveCrewClick(Sender: TObject);
    procedure cmbVisualFilterChange(Sender: TObject);

    { Event handlers untuk Protokol Darurat }
    procedure btnDirectiveShieldClick(Sender: TObject);
    procedure btnDirectiveCargoClick(Sender: TObject);

    { Event handlers untuk Deep Space Encounter }
    procedure btnDecryptClick(Sender: TObject);
    procedure btnIgnoreClick(Sender: TObject);
  private
    FEngine: TGameEngine;
    FRadarAngle: Double;
    FLastTick: QWord;

    { Variabel untuk efek Screen Shake }
    FIsShaking: Boolean;
    FOrigLeft: Integer;
    FOrigTop: Integer;

    { Variabel untuk Typewriter Effect Log }
    FLogQueue: array of TLogQueueItem;
    FTypewriterTimer: Double;

    procedure HandleLogMessage(const Msg: string; IsCritical: Boolean);
    procedure HandleGameOver(IsVictory: Boolean);
    procedure HandleUpdateUI(Sender: TObject);
    function GetSaveFilePath(SlotIndex: Integer): string;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FRadarAngle := 0.0;
  FLastTick := GetTickCount64;
  FIsShaking := False;
  FTypewriterTimer := 0.0;
  SetLength(FLogQueue, 0);

  { Aktifkan DoubleBuffered pada form agar rendering mulus }
  DoubleBuffered := True;

  { Aktifkan KeyPreview agar Form bisa membaca ketukan keyboard pemain (untuk Y/N) }
  Self.KeyPreview := True;

  { Inisialisasi ComboBox target modul untuk Upgrade/Kru }
  if Assigned(cmbTargetModule) then
  begin
    cmbTargetModule.Items.Clear;
    cmbTargetModule.Items.Add('Life Support');
    cmbTargetModule.Items.Add('Deflector Shield');
    cmbTargetModule.Items.Add('Research Lab');
    cmbTargetModule.Items.Add('Comms Array');
    cmbTargetModule.Items.Add('Main Generator');
    cmbTargetModule.ItemIndex := 0;
  end;

  { Inisialisasi ComboBox untuk Mode Filter Visual }
  if Assigned(cmbVisualFilter) then
  begin
    cmbVisualFilter.Items.Clear;
    cmbVisualFilter.Items.Add('MODE: STANDARD');
    cmbVisualFilter.Items.Add('MODE: CRT GLITCH');
    cmbVisualFilter.Items.Add('MODE: RED ALERT');
    cmbVisualFilter.Items.Add('MODE: STARFIELD');
    cmbVisualFilter.ItemIndex := 1; { Default ke CRT Glitch }
  end;

  FEngine := TGameEngine.Create;
  FEngine.OnLogMessage := @HandleLogMessage;
  FEngine.OnGameOver := @HandleGameOver;
  FEngine.OnUpdateUI := @HandleUpdateUI;

  FEngine.StartNewGame;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FEngine);
end;

function TMainForm.GetSaveFilePath(SlotIndex: Integer): string;
var
  SaveDir: string;
begin
  SaveDir := ExtractFilePath(Application.ExeName) + 'data' + PathDelim + 'saves';
  if not DirectoryExists(SaveDir) then
    ForceDirectories(SaveDir);
  Result := SaveDir + PathDelim + 'slot' + IntToStr(SlotIndex) + '.json';
end;

procedure TMainForm.HandleLogMessage(const Msg: string; IsCritical: Boolean);
var
  Prefix: string;
  NewItem: TLogQueueItem;
  Len: Integer;
begin
  if IsCritical then
    Prefix := '[CRIT] '
  else
    Prefix := '[LOG]  ';

  NewItem.FullText := FormatDateTime('hh:nn:ss ', Now) + Prefix + Msg;
  NewItem.CurrentLength := 0;
  NewItem.MaxLen := Length(NewItem.FullText);

  { Masukkan ke dalam antrean log (queue) untuk efek ketikan }
  Len := Length(FLogQueue);
  SetLength(FLogQueue, Len + 1);
  FLogQueue[Len] := NewItem;
end;

procedure TMainForm.HandleGameOver(IsVictory: Boolean);
begin
  TimerLoop.Enabled := False;
  if IsVictory then
  begin
    lblStatusText.Caption := 'STATUS: MISSION SUCCESS - CYCLE COMPLETED';
    ShowMessage('SELAMAT! Anda berhasil mempertahankan stasiun melewati 14 Siklus Sol.');
  end
  else
  begin
    lblStatusText.Caption := 'STATUS: CRITICAL FAILURE - STATION LOST';
    ShowMessage('STATION COLLAPSE! Integritas stasiun atau suplai oksigen telah habis.');
  end;
end;

procedure TMainForm.HandleUpdateUI(Sender: TObject);
var
  TotalSec: Int64;
  Hours, Mins, Secs: Integer;
begin
  lblSol.Caption := Format('[ SOL : %3.3d ]', [FEngine.GameState.Station.Data.SolCycle]);

  TotalSec := FEngine.GameState.Station.Data.UptimeSeconds;
  Hours := TotalSec div 3600;
  Mins := (TotalSec mod 3600) div 60;
  Secs := TotalSec mod 60;
  lblUptime.Caption := Format('UPTIME: %.2d:%.2d:%.2d', [Hours, Mins, Secs]);

  if FEngine.GameState.Crisis.IsWarning then
    lblStatusText.Caption := 'STATUS: WARNING - ANOMALY DETECTED'
  else if FEngine.GameState.Crisis.CurrentCrisis <> ctNone then
    lblStatusText.Caption := 'STATUS: ALERT - IMPACT IN PROGRESS'
  else
    lblStatusText.Caption := 'STATUS: NOMINAL';

  { Mengontrol visibilitas tombol interaksi sinyal berdasarkan status Encounter }
  if Assigned(btnDecrypt) then
    btnDecrypt.Visible := (FEngine.GameState.Station.Data.ActiveEncounter <> etNone);
  if Assigned(btnIgnore) then
    btnIgnore.Visible := (FEngine.GameState.Station.Data.ActiveEncounter <> etNone);
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not Assigned(FEngine) or (FEngine.GameState.Phase <> gpPlaying) then Exit;

  { Cek apakah ada transmisi yang menunggu keputusan }
  if FEngine.GameState.Station.Data.ActiveEncounter <> etNone then
  begin
    if (Key = VK_Y) then
    begin
      FEngine.HandleEncounterAction(eaDecrypt);
      pbCoreStatus.Invalidate;
      pbRadar.Invalidate;
      Key := 0; { Konsumsi event tombol }
    end
    else if (Key = VK_N) then
    begin
      FEngine.HandleEncounterAction(eaIgnore);
      pbCoreStatus.Invalidate;
      pbRadar.Invalidate;
      Key := 0; { Konsumsi event tombol }
    end;
  end;
end;

procedure TMainForm.TimerLoopTimer(Sender: TObject);
var
  NowTick: QWord;
  DeltaSec: Double;
  j: Integer;
begin
  NowTick := GetTickCount64;
  DeltaSec := (NowTick - FLastTick) / 1000.0;
  FLastTick := NowTick;

  if DeltaSec > 0.2 then DeltaSec := 0.2;

  { --- TYPEWRITER EFFECT LOG --- }
  if Length(FLogQueue) > 0 then
  begin
    FTypewriterTimer := FTypewriterTimer + DeltaSec;
    if FTypewriterTimer >= 0.02 then
    begin
      FTypewriterTimer := 0.0;
      Inc(FLogQueue[0].CurrentLength);

      if FLogQueue[0].CurrentLength = 1 then
        lbEventLog.Items.Insert(0, '');

      lbEventLog.Items[0] := Copy(FLogQueue[0].FullText, 1, FLogQueue[0].CurrentLength);

      if FLogQueue[0].CurrentLength >= FLogQueue[0].MaxLen then
      begin
        for j := 0 to Length(FLogQueue) - 2 do
          FLogQueue[j] := FLogQueue[j + 1];
        SetLength(FLogQueue, Length(FLogQueue) - 1);
      end;
    end;

    while lbEventLog.Items.Count > 50 do
      lbEventLog.Items.Delete(lbEventLog.Items.Count - 1);
  end;

  FRadarAngle := FRadarAngle + (1.75 * DeltaSec);
  if FRadarAngle > (2 * Pi) then
    FRadarAngle := FRadarAngle - (2 * Pi);

  FEngine.GameState.Station.AddUptime(Round(DeltaSec));
  FEngine.Update(DeltaSec);

  { Efek Screen Shake pada Form Utama }
  if FEngine.ShakeIntensity > 0 then
  begin
    if not FIsShaking then
    begin
      FIsShaking := True;
      FOrigLeft := Self.Left;
      FOrigTop := Self.Top;
    end;
    Self.Left := FOrigLeft + Round((Random - 0.5) * FEngine.ShakeIntensity * 2);
    Self.Top := FOrigTop + Round((Random - 0.5) * FEngine.ShakeIntensity * 2);
  end
  else if FIsShaking then
  begin
    FIsShaking := False;
    Self.Left := FOrigLeft;
    Self.Top := FOrigTop;
  end;

  pbModules.Invalidate;
  pbRadar.Invalidate;
  pbCoreStatus.Invalidate;
end;

procedure TMainForm.pbModulesPaint(Sender: TObject);
var
  Bmp: TBGRABitmap;
begin
  if (pbModules.Width <= 0) or (pbModules.Height <= 0) then Exit;
  Bmp := TBGRABitmap.Create(pbModules.Width, pbModules.Height);
  try
    TPanelRenderer.RenderSystemModules(Bmp, Rect(0, 0, pbModules.Width, pbModules.Height), FEngine.GameState, FEngine.GlobalBlink);
    Bmp.Draw(pbModules.Canvas, 0, 0, False);
  finally
    Bmp.Free;
  end;
end;

procedure TMainForm.pbRadarPaint(Sender: TObject);
var
  Bmp: TBGRABitmap;
  ActiveFilter: TVisualFilterMode;
begin
  if (pbRadar.Width <= 0) or (pbRadar.Height <= 0) then Exit;

  ActiveFilter := vfmNone;
  if Assigned(cmbVisualFilter) and (cmbVisualFilter.ItemIndex >= 0) then
    ActiveFilter := TVisualFilterMode(cmbVisualFilter.ItemIndex);

  Bmp := TBGRABitmap.Create(pbRadar.Width, pbRadar.Height);
  try
    TRadarRenderer.RenderRadar(Bmp, Rect(0, 0, pbRadar.Width, pbRadar.Height), FEngine.GameState, FRadarAngle, FEngine.GlobalBlink, ActiveFilter);
    Bmp.Draw(pbRadar.Canvas, 0, 0, False);
  finally
    Bmp.Free;
  end;
end;

procedure TMainForm.pbCoreStatusPaint(Sender: TObject);
var
  Bmp: TBGRABitmap;
begin
  if (pbCoreStatus.Width <= 0) or (pbCoreStatus.Height <= 0) then Exit;
  Bmp := TBGRABitmap.Create(pbCoreStatus.Width, pbCoreStatus.Height);
  try
    TPanelRenderer.RenderCoreStatus(Bmp, Rect(0, 0, pbCoreStatus.Width, pbCoreStatus.Height), FEngine.GameState, FEngine.GlobalBlink);
    Bmp.Draw(pbCoreStatus.Canvas, 0, 0, False);
  finally
    Bmp.Free;
  end;
end;

procedure TMainForm.btnToggleLSClick(Sender: TObject);
begin
  FEngine.GameState.Modules.ToggleModule(mtLifeSupport);
  FEngine.AudioManager.PlaySound(sfxClick);
  pbModules.Invalidate;
end;

procedure TMainForm.btnToggleShieldClick(Sender: TObject);
begin
  FEngine.GameState.Modules.ToggleModule(mtDeflectorShield);
  FEngine.AudioManager.PlaySound(sfxClick);
  pbModules.Invalidate;
end;

procedure TMainForm.btnToggleLabClick(Sender: TObject);
begin
  FEngine.GameState.Modules.ToggleModule(mtResearchLab);
  FEngine.AudioManager.PlaySound(sfxClick);
  pbModules.Invalidate;
end;

procedure TMainForm.btnToggleCommsClick(Sender: TObject);
begin
  FEngine.GameState.Modules.ToggleModule(mtCommsArray);
  FEngine.AudioManager.PlaySound(sfxClick);
  pbModules.Invalidate;
end;

procedure TMainForm.btnRepairClick(Sender: TObject);
var
  m: TModuleType;
  Repaired: Boolean;
begin
  Repaired := False;
  for m := Low(TModuleType) to High(TModuleType) do
  begin
    if FEngine.GameState.Modules[m]^.Status = msDamaged then
    begin
      FEngine.GameState.Modules.StartRepair(m);
      FEngine.LogEvent('DRONE DISPATCHED: REPAIRING MODULE ' + IntToStr(Integer(m)), False);
      Repaired := True;
      Break;
    end;
  end;

  if Repaired then
    FEngine.AudioManager.PlaySound(sfxRepair)
  else
  begin
    FEngine.LogEvent('ALL MODULES FUNCTIONAL. NO REPAIRS NEEDED.', False);
    FEngine.AudioManager.PlaySound(sfxError);
  end;
end;

procedure TMainForm.btnNewGameClick(Sender: TObject);
begin
  lbEventLog.Clear;
  SetLength(FLogQueue, 0);
  FEngine.StartNewGame;
  FEngine.AudioManager.PlaySound(sfxClick);
  TimerLoop.Enabled := True;
end;

procedure TMainForm.btnSaveGameClick(Sender: TObject);
var
  frm: TSaveLoadForm;
  SelectedSlot: Integer;
begin
  TimerLoop.Enabled := False;
  frm := TSaveLoadForm.Create(Self);
  try
    if frm.ShowModal = mrOk then
    begin
      SelectedSlot := frm.SelectedSlot;
      if TSaveManager.SaveGame(GetSaveFilePath(SelectedSlot), FEngine.GameState) then
      begin
        FEngine.LogEvent('GAME SAVED SUCCESSFULLY TO SLOT ' + IntToStr(SelectedSlot) + '.', False);
        FEngine.AudioManager.PlaySound(sfxSuccess);
      end
      else
      begin
        FEngine.LogEvent('ERROR: FAILED TO SAVE GAME STATE.', True);
        FEngine.AudioManager.PlaySound(sfxError);
      end;
    end;
  finally
    frm.Free;
    if FEngine.GameState.Phase = gpPlaying then TimerLoop.Enabled := True;
  end;
end;

procedure TMainForm.btnLoadGameClick(Sender: TObject);
var
  frm: TSaveLoadForm;
  SelectedSlot: Integer;
begin
  TimerLoop.Enabled := False;
  frm := TSaveLoadForm.Create(Self);
  try
    if frm.ShowModal = mrOk then
    begin
      SelectedSlot := frm.SelectedSlot;
      if TSaveManager.LoadGame(GetSaveFilePath(SelectedSlot), FEngine.GameState) then
      begin
        FEngine.LogEvent('GAME LOADED SUCCESSFULLY FROM SLOT ' + IntToStr(SelectedSlot) + '.', False);
        FEngine.AudioManager.PlaySound(sfxSuccess);
        TimerLoop.Enabled := True;
        pbModules.Invalidate;
        pbCoreStatus.Invalidate;
      end
      else
      begin
        FEngine.LogEvent('ERROR: SAVE FILE NOT FOUND OR INVALID.', True);
        FEngine.AudioManager.PlaySound(sfxError);
      end;
    end;
  finally
    frm.Free;
    if FEngine.GameState.Phase = gpPlaying then TimerLoop.Enabled := True;
  end;
end;

{ --- HANDLER FITUR UPGRADE & KRU --- }

procedure TMainForm.btnUpgradeClick(Sender: TObject);
var
  ModType: TModuleType;
  Cost: Double;
begin
  if not Assigned(cmbTargetModule) or (cmbTargetModule.ItemIndex < 0) then Exit;

  ModType := TModuleType(cmbTargetModule.ItemIndex);
  Cost := FEngine.GameState.Modules.GetUpgradeCost(ModType);

  if FEngine.GameState.Station.Stats.TechPoints >= Cost then
  begin
    if FEngine.GameState.Modules.ApplyUpgrade(ModType) then
    begin
      FEngine.GameState.Station.AddTechPoints(-Cost);
      FEngine.LogEvent('UPGRADE SUCCESS: ' + cmbTargetModule.Text + ' (LVL ' +
                       IntToStr(FEngine.GameState.Modules[ModType]^.UpgradeLevel) + ')', False);
      FEngine.AudioManager.PlaySound(sfxSuccess);
      pbModules.Invalidate;
      pbCoreStatus.Invalidate;
    end
    else
    begin
      FEngine.LogEvent('UPGRADE FAILED: MAX LEVEL REACHED', True);
      FEngine.AudioManager.PlaySound(sfxError);
    end;
  end
  else
  begin
    FEngine.LogEvent('UPGRADE FAILED: INSUFFICIENT TECH POINTS', True);
    FEngine.AudioManager.PlaySound(sfxError);
  end;
end;

procedure TMainForm.btnAddCrewClick(Sender: TObject);
var
  ModType: TModuleType;
begin
  if not Assigned(cmbTargetModule) or (cmbTargetModule.ItemIndex < 0) then Exit;
  ModType := TModuleType(cmbTargetModule.ItemIndex);

  if FEngine.GameState.Station.AssignCrew then
  begin
    if FEngine.GameState.Modules.AddCrew(ModType) then
    begin
      FEngine.LogEvent('CREW ASSIGNED TO: ' + cmbTargetModule.Text, False);
      FEngine.AudioManager.PlaySound(sfxSuccess);
      pbModules.Invalidate;
      pbCoreStatus.Invalidate;
    end
    else
    begin
      FEngine.GameState.Station.UnassignCrew;
      FEngine.LogEvent('ASSIGN FAILED: MODULE AT MAX CREW CAPACITY', True);
      FEngine.AudioManager.PlaySound(sfxError);
    end;
  end
  else
  begin
    FEngine.LogEvent('ASSIGN FAILED: NO IDLE CREW AVAILABLE', True);
    FEngine.AudioManager.PlaySound(sfxError);
  end;
end;

procedure TMainForm.btnRemoveCrewClick(Sender: TObject);
var
  ModType: TModuleType;
begin
  if not Assigned(cmbTargetModule) or (cmbTargetModule.ItemIndex < 0) then Exit;
  ModType := TModuleType(cmbTargetModule.ItemIndex);

  if FEngine.GameState.Modules.RemoveCrew(ModType) then
  begin
    FEngine.GameState.Station.UnassignCrew;
    FEngine.LogEvent('CREW RECALLED FROM: ' + cmbTargetModule.Text, False);
    FEngine.AudioManager.PlaySound(sfxSuccess);
    pbModules.Invalidate;
    pbCoreStatus.Invalidate;
  end
  else
  begin
    FEngine.LogEvent('RECALL FAILED: NO CREW ASSIGNED TO THIS MODULE', True);
    FEngine.AudioManager.PlaySound(sfxError);
  end;
end;

procedure TMainForm.cmbVisualFilterChange(Sender: TObject);
begin
  FEngine.AudioManager.PlaySound(sfxClick);
  pbRadar.Invalidate;
end;

{ --- HANDLER FITUR PROTOKOL DARURAT --- }

procedure TMainForm.btnDirectiveShieldClick(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.ExecuteDirective(edShieldBoost);
    pbCoreStatus.Invalidate;
  end;
end;

procedure TMainForm.btnDirectiveCargoClick(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.ExecuteDirective(edJettisonCargo);
    pbCoreStatus.Invalidate;
  end;
end;

{ --- HANDLER FITUR DEEP SPACE ENCOUNTER --- }

procedure TMainForm.btnDecryptClick(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.HandleEncounterAction(eaDecrypt);
    pbCoreStatus.Invalidate;
    pbRadar.Invalidate;
  end;
end;

procedure TMainForm.btnIgnoreClick(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.HandleEncounterAction(eaIgnore);
    pbCoreStatus.Invalidate;
    pbRadar.Invalidate;
  end;
end;

end.
