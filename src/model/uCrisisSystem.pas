unit uCrisisSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes;

type
  { Event callback untuk notifikasi status krisis ke GameEngine/UI }
  TCrisisNotifyEvent = procedure(CrisisType: TCrisisType; const Msg: string) of object;

  { Event callback untuk menerapkan damage/efek berkelanjutan per frame }
  TCrisisTickEvent = procedure(CrisisType: TCrisisType; DeltaSeconds: Double) of object;

  { TCrisisSystem menangani kemunculan, peringatan dini, dan durasi dari setiap anomali }
  TCrisisSystem = class
  private
    FCurrentCrisis: TCrisisType;
    FCrisisTimer: Double;        { Menyimpan waktu hitung mundur peringatan atau durasi krisis aktif }
    FTimeUntilNext: Double;      { Jeda waktu sebelum krisis acak berikutnya muncul }
    FIsWarning: Boolean;         { True jika krisis belum menghantam (fase peringatan) }

    FOnWarning: TCrisisNotifyEvent;
    FOnStrike: TCrisisNotifyEvent;
    FOnResolved: TCrisisNotifyEvent;
    FOnEffectTick: TCrisisTickEvent;
  public
    constructor Create;

    { Mengatur ulang sistem krisis ke kondisi awal }
    procedure ResetToDefault;

    { Memproses loop krisis berdasarkan berjalannya waktu (DeltaTime) }
    procedure UpdateTick(DeltaSeconds: Double);

    { Memicu krisis secara manual/spesifik beserta durasi peringatan dininya.
      BALANCING: Default waktu peringatan dikurangi menjadi 10 detik agar pemain harus bereaksi lebih cepat }
    procedure TriggerCrisis(ACrisis: TCrisisType; WarningDuration: Double = 10.0);

    { Mengakhiri krisis saat ini dan mereset hitung mundur krisis berikutnya }
    procedure ResolveCrisis;

    { Properti akses baca }
    property CurrentCrisis: TCrisisType read FCurrentCrisis;
    property CrisisTimer: Double read FCrisisTimer;
    property IsWarning: Boolean read FIsWarning;

    { Event hooks }
    property OnWarning: TCrisisNotifyEvent read FOnWarning write FOnWarning;
    property OnStrike: TCrisisNotifyEvent read FOnStrike write FOnStrike;
    property OnResolved: TCrisisNotifyEvent read FOnResolved write FOnResolved;
    property OnEffectTick: TCrisisTickEvent read FOnEffectTick write FOnEffectTick;
  end;

implementation

{ TCrisisSystem }

constructor TCrisisSystem.Create;
begin
  inherited Create;
  Randomize;
  ResetToDefault;
end;

procedure TCrisisSystem.ResetToDefault;
begin
  FCurrentCrisis := ctNone;
  FCrisisTimer := 0.0;
  FIsWarning := False;

  { BALANCING: Krisis pertama akan muncul lebih cepat (antara 20 hingga 40 detik setelah start) }
  FTimeUntilNext := RandomRange(20, 40);
end;

procedure TCrisisSystem.TriggerCrisis(ACrisis: TCrisisType; WarningDuration: Double = 10.0);
var
  CrisisName: string;
begin
  { Abaikan jika sudah ada krisis yang sedang berlangsung }
  if FCurrentCrisis <> ctNone then Exit;

  FCurrentCrisis := ACrisis;
  FIsWarning := True;
  FCrisisTimer := WarningDuration;

  case ACrisis of
    ctSolarFlare:   CrisisName := 'SOLAR FLARE';
    ctMeteorShower: CrisisName := 'METEOR SHOWER';
    ctPowerSurge:   CrisisName := 'POWER SURGE';
    ctOxygenLeak:   CrisisName := 'OXYGEN LEAK';
  else
    CrisisName := 'UNKNOWN ANOMALY';
  end;

  if Assigned(FOnWarning) then
    FOnWarning(FCurrentCrisis, 'WARNING! ' + CrisisName + ' INBOUND IN ' + IntToStr(Round(WarningDuration)) + 's');
end;

procedure TCrisisSystem.ResolveCrisis;
begin
  if FCurrentCrisis = ctNone then Exit;

  if Assigned(FOnResolved) then
    FOnResolved(FCurrentCrisis, 'CRISIS RESOLVED. SYSTEMS NORMALIZING.');

  FCurrentCrisis := ctNone;
  FIsWarning := False;
  FCrisisTimer := 0.0;

  { BALANCING: Jeda aman (fase damai) antar krisis dipersingkat menjadi 30 hingga 60 detik }
  FTimeUntilNext := RandomRange(30, 60);
end;

procedure TCrisisSystem.UpdateTick(DeltaSeconds: Double);
var
  RandCrisis: Integer;
begin
  if FCurrentCrisis = ctNone then
  begin
    { Fase damai: Kurangi timer menuju krisis berikutnya }
    FTimeUntilNext := FTimeUntilNext - DeltaSeconds;

    if FTimeUntilNext <= 0 then
    begin
      { ctNone bernilai 0 di enum, krisis lainnya bernilai 1 hingga 4 }
      RandCrisis := RandomRange(1, 5);
      TriggerCrisis(TCrisisType(RandCrisis));
    end;
  end
  else
  begin
    { Terdapat krisis aktif atau peringatan }
    FCrisisTimer := FCrisisTimer - DeltaSeconds;

    if FIsWarning then
    begin
      if FCrisisTimer <= 0 then
      begin
        FIsWarning := False;
        { BALANCING: Durasi hantaman krisis diperpanjang menjadi 30 detik untuk memberikan damage yang lebih mematikan }
        FCrisisTimer := 30.0;

        if Assigned(FOnStrike) then
          FOnStrike(FCurrentCrisis, 'CRISIS IMPACT! EVASIVE MANEUVERS OR REPAIRS REQUIRED.');
      end;
    end
    else
    begin
      { Fase hantaman krisis: Terapkan efek/damage secara berkelanjutan melalui event }
      if Assigned(FOnEffectTick) then
        FOnEffectTick(FCurrentCrisis, DeltaSeconds);

      if FCrisisTimer <= 0 then
        ResolveCrisis;
    end;
  end;
end;

end.
