unit uModuleManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes;

type
  { Struktur data operasional untuk masing-masing modul }
  TModuleData = record
    ModType: TModuleType;
    Status: TModuleStatus;
    BasePowerDraw: Double;     { Konsumsi daya bawaan }
    PowerDraw: Double;         { Konsumsi daya aktual (setelah modifikasi upgrade) }
    BaseRepairTimeReq: Double; { Waktu perbaikan bawaan }
    RepairTimeReq: Double;     { Waktu perbaikan aktual (setelah bantuan kru) }
    RepairProgress: Double;    { Progres perbaikan saat ini dalam detik }
    UpgradeLevel: Integer;     { Level upgrade modul (Maksimal 3) }
    AssignedCrew: Integer;     { Jumlah kru yang ditugaskan ke modul ini (Maksimal 3) }
  end;

  PModuleData = ^TModuleData;

  { TModuleManager menangani status, daya, dan logika semua modul di stasiun }
  TModuleManager = class
  private
    FModules: array[TModuleType] of TModuleData;
    function GetModule(AIndex: TModuleType): PModuleData;

    { Mengkalkulasi ulang atribut modul berdasarkan level upgrade dan jumlah kru }
    procedure RecalculateModuleStats(AModType: TModuleType);
  public
    constructor Create;
    destructor Destroy; override;

    { Mengembalikan semua modul ke kondisi awal }
    procedure ResetToDefault;

    { Mengubah status on/off. Mengembalikan True jika berhasil diubah }
    function ToggleModule(AModType: TModuleType): Boolean;

    { Memaksa perubahan status modul (misal: saat terkena damage) }
    procedure SetModuleStatus(AModType: TModuleType; AStatus: TModuleStatus);

    { Memulai proses perbaikan untuk modul yang rusak }
    function StartRepair(AModType: TModuleType): Boolean;

    { Menghitung total daya yang sedang ditarik oleh semua modul aktif }
    function GetTotalPowerConsumption: Double;

    { Memproses durasi perbaikan yang sedang berjalan berdasarkan DeltaTime }
    procedure ProcessRepairs(DeltaSeconds: Double);

    { Mengecek apakah modul tertentu sedang beroperasi }
    function IsModuleOnline(AModType: TModuleType): Boolean;

    { --- FITUR BARU: UPGRADE & KRU --- }

    { Mendapatkan biaya Tech Points untuk upgrade selanjutnya }
    function GetUpgradeCost(AModType: TModuleType): Double;

    { Menerapkan upgrade ke modul (Meningkatkan efisiensi daya) }
    function ApplyUpgrade(AModType: TModuleType): Boolean;

    { Menugaskan kru ke modul (Mempercepat waktu perbaikan dan efisiensi spesifik) }
    function AddCrew(AModType: TModuleType): Boolean;

    { Menarik kru dari modul }
    function RemoveCrew(AModType: TModuleType): Boolean;

    { Akses pointer langsung ke data modul }
    property Modules[AIndex: TModuleType]: PModuleData read GetModule; default;
  end;

implementation

{ TModuleManager }

constructor TModuleManager.Create;
begin
  inherited Create;
  ResetToDefault;
end;

destructor TModuleManager.Destroy;
begin
  inherited Destroy;
end;

function TModuleManager.GetModule(AIndex: TModuleType): PModuleData;
begin
  Result := @FModules[AIndex];
end;

procedure TModuleManager.RecalculateModuleStats(AModType: TModuleType);
var
  M: PModuleData;
begin
  M := @FModules[AModType];

  { Efek Upgrade: Setiap level upgrade mengurangi konsumsi daya sebesar 15% }
  M^.PowerDraw := M^.BasePowerDraw * (1.0 - (M^.UpgradeLevel * 0.15));
  if M^.PowerDraw < 0.0 then M^.PowerDraw := 0.0;

  { Efek Kru: Setiap kru yang ditugaskan mempercepat waktu perbaikan sebesar 25% }
  M^.RepairTimeReq := M^.BaseRepairTimeReq * (1.0 - (M^.AssignedCrew * 0.25));
  if M^.RepairTimeReq < 1.0 then M^.RepairTimeReq := 1.0;
end;

procedure TModuleManager.ResetToDefault;
var
  m: TModuleType;
begin
  for m := Low(TModuleType) to High(TModuleType) do
  begin
    FModules[m].ModType := m;
    FModules[m].Status := msOffline;
    FModules[m].RepairProgress := 0.0;
    FModules[m].UpgradeLevel := 0;
    FModules[m].AssignedCrew := 0;

    { BALANCING: Menyesuaikan beban daya dan waktu perbaikan untuk meningkatkan kesulitan. }
    case m of
      mtLifeSupport:
        begin FModules[m].BasePowerDraw := 30.0; FModules[m].BaseRepairTimeReq := 20.0; end;
      mtDeflectorShield:
        begin FModules[m].BasePowerDraw := 50.0; FModules[m].BaseRepairTimeReq := 25.0; end;
      mtResearchLab:
        begin FModules[m].BasePowerDraw := 40.0; FModules[m].BaseRepairTimeReq := 20.0; end;
      mtCommsArray:
        begin FModules[m].BasePowerDraw := 15.0; FModules[m].BaseRepairTimeReq := 15.0; end;
      mtMainGenerator:
        begin FModules[m].BasePowerDraw := 0.0;  FModules[m].BaseRepairTimeReq := 35.0; end;
    end;

    { Kalkulasi nilai aktual berdasarkan level awal }
    RecalculateModuleStats(m);
  end;

  { Status awal permainan: Beberapa sistem krusial dalam keadaan aktif }
  FModules[mtLifeSupport].Status := msOnline;
  FModules[mtCommsArray].Status := msOnline;
  FModules[mtMainGenerator].Status := msOnline;
end;

function TModuleManager.ToggleModule(AModType: TModuleType): Boolean;
begin
  Result := False;
  if (FModules[AModType].Status = msDamaged) or (FModules[AModType].Status = msRepairing) then Exit;
  if AModType = mtMainGenerator then Exit; { Generator utama tidak bisa di-toggle manual }

  if FModules[AModType].Status = msOnline then
    FModules[AModType].Status := msOffline
  else if FModules[AModType].Status = msOffline then
    FModules[AModType].Status := msOnline;

  Result := True;
end;

procedure TModuleManager.SetModuleStatus(AModType: TModuleType; AStatus: TModuleStatus);
begin
  FModules[AModType].Status := AStatus;
  if AStatus = msDamaged then
    FModules[AModType].RepairProgress := 0.0;
end;

function TModuleManager.StartRepair(AModType: TModuleType): Boolean;
begin
  Result := False;
  if FModules[AModType].Status = msDamaged then
  begin
    FModules[AModType].Status := msRepairing;
    FModules[AModType].RepairProgress := 0.0;
    Result := True;
  end;
end;

function TModuleManager.GetTotalPowerConsumption: Double;
var
  m: TModuleType;
  total: Double;
begin
  total := 0.0;
  for m := Low(TModuleType) to High(TModuleType) do
  begin
    if FModules[m].Status = msOnline then
      total := total + FModules[m].PowerDraw;
  end;
  Result := total;
end;

procedure TModuleManager.ProcessRepairs(DeltaSeconds: Double);
var
  m: TModuleType;
begin
  for m := Low(TModuleType) to High(TModuleType) do
  begin
    if FModules[m].Status = msRepairing then
    begin
      FModules[m].RepairProgress := FModules[m].RepairProgress + DeltaSeconds;

      { Jika waktu perbaikan sudah tercapai, set menjadi offline agar bisa dinyalakan manual }
      if FModules[m].RepairProgress >= FModules[m].RepairTimeReq then
      begin
        FModules[m].Status := msOffline;
        FModules[m].RepairProgress := 0.0;
      end;
    end;
  end;
end;

function TModuleManager.IsModuleOnline(AModType: TModuleType): Boolean;
begin
  Result := FModules[AModType].Status = msOnline;
end;

function TModuleManager.GetUpgradeCost(AModType: TModuleType): Double;
begin
  { Biaya upgrade meningkat seiring level: 50, 100, 150 Tech Points }
  Result := 50.0 + (FModules[AModType].UpgradeLevel * 50.0);
end;

function TModuleManager.ApplyUpgrade(AModType: TModuleType): Boolean;
begin
  Result := False;
  { Batas maksimal level upgrade adalah 3 }
  if FModules[AModType].UpgradeLevel < 3 then
  begin
    Inc(FModules[AModType].UpgradeLevel);
    RecalculateModuleStats(AModType);
    Result := True;
  end;
end;

function TModuleManager.AddCrew(AModType: TModuleType): Boolean;
begin
  Result := False;
  { Batas maksimal 3 kru per modul }
  if FModules[AModType].AssignedCrew < 3 then
  begin
    Inc(FModules[AModType].AssignedCrew);
    RecalculateModuleStats(AModType);
    Result := True;
  end;
end;

function TModuleManager.RemoveCrew(AModType: TModuleType): Boolean;
begin
  Result := False;
  if FModules[AModType].AssignedCrew > 0 then
  begin
    Dec(FModules[AModType].AssignedCrew);
    RecalculateModuleStats(AModType);
    Result := True;
  end;
end;

end.
