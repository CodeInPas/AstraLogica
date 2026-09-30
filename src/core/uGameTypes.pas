unit uGameTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { Fase permainan saat ini }
  TGamePhase = (
    gpMainMenu,
    gpPlaying,
    gpPaused,
    gpGameOver,
    gpVictory
  );

  { Mode Filter Visual untuk efek ketegangan layar utama }
  TVisualFilterMode = (
    vfmNone,        { Tidak ada efek tambahan (Standar) }
    vfmCRTGlitch,   { Opsi 1: CRT Scanlines & Glitch Dinamis }
    vfmRedAlert,    { Opsi 2: Red Alert Vignette Pulse }
    vfmStarfield    { Opsi 3: Parallax Starfield & Debris Drift }
  );

  { Jenis opsi protokol pilihan darurat (Emergency Override Directives) }
  TEmergencyDirective = (
    edNone,
    edShieldBoost,     { Opsi A: Diversikan daya ke perisai (Risiko: Oksigen turun cepat) }
    edJettisonCargo    { Opsi B: Buang sektor kargo (Risiko: Kehilangan Tech Points) }
  );

  { --- SISTEM BARU: TRANSMISI ENTITAS MISTERIUS (Deep Space Encounters) --- }

  { Jenis-jenis transmisi anomali yang ditangkap radar }
  TEncounterType = (
    etNone,
    etDerelictShip,  { Kapal kargo hancur (Reward: Resource/Hull, Risk: Virus/Hull Damage) }
    etUnknownSOS,    { Sinyal darurat faksi tak dikenal (Reward: Extra Crew, Risk: Jebakan Pirate/Damage) }
    etAlienSignal    { Transmisi Alien statis (Reward: Massive Tech Points, Risk: Modul Offline/Rusak) }
  );

  { Pilihan keputusan pemain terhadap transmisi }
  TEncounterAction = (
    eaDecrypt, { [ Y ] DEKRIPSI SINYAL }
    eaIgnore   { [ N ] ABAIKAN }
  );

  { ------------------------------------------------------------------------ }

  { Jenis-jenis modul operasional di stasiun luar angkasa }
  TModuleType = (
    mtLifeSupport,     { Menghasilkan oksigen }
    mtDeflectorShield, { Melindungi dari serangan/anomali }
    mtResearchLab,     { Konsumsi daya tinggi, menambah poin progres }
    mtCommsArray,      { Menerima peringatan dini (Event Log) }
    mtMainGenerator    { Sumber daya utama }
  );

  { Status kondisi fisik dan operasional modul }
  TModuleStatus = (
    msOnline,     { Aktif dan mengonsumsi daya }
    msOffline,    { Dinonaktifkan, tidak mengonsumsi daya }
    msDamaged,    { Rusak akibat anomali, tidak bisa diaktifkan }
    msRepairing   { Sedang dalam proses perbaikan }
  );

  { Jenis krisis/anomali yang mengancam stasiun }
  TCrisisType = (
    ctNone,
    ctSolarFlare,   { Mengurangi daya atau merusak perisai }
    ctMeteorShower, { Merusak integritas lambung (Hull) }
    ctPowerSurge,   { Merusak generator atau modul acak }
    ctOxygenLeak    { Mengurangi oksigen secara drastis }
  );

  { Struktur data sumber daya utama stasiun }
  TResourceStats = record
    OxygenLevel: Double;      { Rentang: 0.0 - 100.0 }
    PowerReserve: Double;     { Rentang: 0.0 - 100.0 }
    HullIntegrity: Double;    { Rentang: 0.0 - 100.0 }

    { Sistem Baru: Manajemen Suhu Inti }
    CoreTemperature: Double;  { Rentang: 0.0 - 100.0. Naik jika banyak modul aktif, memicu Meltdown di 100% }

    TotalPowerOutput: Double; { Total daya yang dihasilkan generator }
    PowerConsumption: Double; { Total daya yang ditarik oleh modul aktif }
    TechPoints: Double;       { Poin yang dikumpulkan untuk upgrade modul }
    TotalCrew: Integer;       { Total personil kru di stasiun }
    IdleCrew: Integer;        { Kru yang menganggur dan siap ditugaskan }
  end;

  { Struktur data umum untuk log dan status stasiun }
  TStationData = record
    SolCycle: Integer;        { Hitungan hari (Siklus Sol) }
    UptimeSeconds: Int64;     { Waktu operasional dalam detik }
    ActiveCrisis: TCrisisType;
    CrisisTimeLeft: Integer;  { Detik tersisa sebelum krisis berakhir/terjadi }

    { Data status untuk transmisi misterius yang sedang berlangsung }
    ActiveEncounter: TEncounterType;
    EncounterTimeLeft: Integer; { Waktu (detik) tersisa untuk memberi keputusan sebelum sinyal hilang }
  end;

  { Struktur log pesan untuk antarmuka Event Log }
  TEventLogMsg = record
    Timestamp: string;        { Format: HH:MM:SS }
    Message: string;          { Isi pesan log }
    IsCritical: Boolean;      { Jika True, tampilkan dengan warna peringatan (merah/kuning) }
  end;

implementation

end.
