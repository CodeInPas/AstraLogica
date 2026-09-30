unit uStationModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes;

type
  { Kelas TStationModel mengelola logika dan data sumber daya utama stasiun }
  TStationModel = class
  private
    FStats: TResourceStats;
    FData: TStationData;

    procedure SetOxygenLevel(const Value: Double);
    procedure SetPowerReserve(const Value: Double);
    procedure SetHullIntegrity(const Value: Double);
  public
    constructor Create;
    destructor Destroy; override;

    { Inisialisasi ulang kondisi stasiun untuk permainan baru }
    procedure ResetToDefault;

    { Pembaruan status sumber daya berdasarkan berjalannya waktu (DeltaTime) }
    procedure UpdateTick(DeltaSeconds: Double; OxygenDelta: Double; PowerDelta: Double);

    { Modifikasi nilai secara aman }
    procedure ApplyHullDamage(Amount: Double);
    procedure AddUptime(Seconds: Int64);

    { Manajemen Poin Upgrade (Tech Points) }
    procedure AddTechPoints(Amount: Double);

    { Manajemen Alokasi Kru }
    function AssignCrew: Boolean;
    function UnassignCrew: Boolean;

    { Properti akses langsung }
    property Stats: TResourceStats read FStats write FStats;
    property Data: TStationData read FData write FData;

    { Properti dengan setter untuk memastikan nilai selalu dalam rentang 0.0 - 100.0 }
    property OxygenLevel: Double read FStats.OxygenLevel write SetOxygenLevel;
    property PowerReserve: Double read FStats.PowerReserve write SetPowerReserve;
    property HullIntegrity: Double read FStats.HullIntegrity write SetHullIntegrity;
  end;

implementation

{ TStationModel }

constructor TStationModel.Create;
begin
  inherited Create;
  ResetToDefault;
end;

destructor TStationModel.Destroy;
begin
  inherited Destroy;
end;

procedure TStationModel.ResetToDefault;
begin
  FStats.OxygenLevel := 100.0;
  FStats.PowerReserve := 100.0;
  FStats.HullIntegrity := 100.0;

  { Kapasitas dasar generator dan konsumsi awal }
  FStats.TotalPowerOutput := 100.0;
  FStats.PowerConsumption := 0.0;

  { Inisialisasi sumber daya untuk mekanik Upgrade & Kru }
  FStats.TechPoints := 0.0;
  FStats.TotalCrew := 3; { Stasiun dimulai dengan 3 personil kru }
  FStats.IdleCrew := 3;

  FData.SolCycle := 1;
  FData.UptimeSeconds := 0;
  FData.ActiveCrisis := ctNone;
  FData.CrisisTimeLeft := 0;
end;

procedure TStationModel.SetOxygenLevel(const Value: Double);
begin
  FStats.OxygenLevel := EnsureRange(Value, 0.0, 100.0);
end;

procedure TStationModel.SetPowerReserve(const Value: Double);
begin
  FStats.PowerReserve := EnsureRange(Value, 0.0, 100.0);
end;

procedure TStationModel.SetHullIntegrity(const Value: Double);
begin
  FStats.HullIntegrity := EnsureRange(Value, 0.0, 100.0);
end;

procedure TStationModel.UpdateTick(DeltaSeconds: Double; OxygenDelta: Double; PowerDelta: Double);
begin
  { Menambah/mengurangi sumber daya berdasarkan delta (perubahan per detik) }
  OxygenLevel := FStats.OxygenLevel + (OxygenDelta * DeltaSeconds);
  PowerReserve := FStats.PowerReserve + (PowerDelta * DeltaSeconds);
end;

procedure TStationModel.ApplyHullDamage(Amount: Double);
begin
  HullIntegrity := FStats.HullIntegrity - Amount;
end;

procedure TStationModel.AddUptime(Seconds: Int64);
begin
  FData.UptimeSeconds := FData.UptimeSeconds + Seconds;
end;

procedure TStationModel.AddTechPoints(Amount: Double);
begin
  FStats.TechPoints := FStats.TechPoints + Amount;
end;

function TStationModel.AssignCrew: Boolean;
begin
  Result := False;
  { Pastikan ada kru yang menganggur sebelum ditugaskan ke modul }
  if FStats.IdleCrew > 0 then
  begin
    Dec(FStats.IdleCrew);
    Result := True;
  end;
end;

function TStationModel.UnassignCrew: Boolean;
begin
  Result := False;
  { Pastikan jumlah kru yang menganggur tidak melebihi total kru }
  if FStats.IdleCrew < FStats.TotalCrew then
  begin
    Inc(FStats.IdleCrew);
    Result := True;
  end;
end;

end.
