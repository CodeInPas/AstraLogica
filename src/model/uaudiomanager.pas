unit uAudioManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { Daftar jenis efek suara (SFX) yang tersedia di game }
  TSoundEffect = (
    sfxClick,    { Suara klik tombol / terminal }
    sfxAlarm,    { Suara peringatan / krisis }
    sfxSuccess,  { Suara upgrade / misi sukses }
    sfxError,    { Suara galat / gagal }
    sfxRepair    { Suara pengerjaan drone perbaikan }
  );

  { TAudioManager menangani pemutaran audio dan suara latar (ambient) secara aman }
  TAudioManager = class
  private
    FEnabled: Boolean;
    function GetSoundFileName(Effect: TSoundEffect): string;
  public
    constructor Create;
    destructor Destroy; override;

    { Memutar efek suara sekali }
    procedure PlaySound(Effect: TSoundEffect);

    { Memulai suara latar yang berputar terus-menerus (looping ambient) }
    procedure StartAmbient(const SoundFileName: string);

    { Menghentikan suara latar / ambient yang sedang berjalan }
    procedure StopAmbient;

    { Status aktif/nonaktif audio }
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

implementation

{$IFDEF WINDOWS}
uses
  Windows, MMSystem;
{$ENDIF}

constructor TAudioManager.Create;
begin
  inherited Create;
  FEnabled := True;
end;

destructor TAudioManager.Destroy;
begin
  StopAmbient;
  inherited Destroy;
end;

function TAudioManager.GetSoundFileName(Effect: TSoundEffect): string;
var
  BaseDir: string;
begin
  BaseDir := ExtractFilePath(ParamStr(0)) + PathDelim + 'sounds' + PathDelim;

  case Effect of
    sfxClick:   Result := BaseDir + 'click.wav';
    sfxAlarm:   Result := BaseDir + 'alarm.wav';
    sfxSuccess: Result := BaseDir + 'success.wav';
    sfxError:   Result := BaseDir + 'error.wav';
    sfxRepair:  Result := BaseDir + 'repair.wav';
  else
    Result := '';
  end;
end;

procedure TAudioManager.PlaySound(Effect: TSoundEffect);
var
  FileName: string;
begin
  if not FEnabled then Exit;

  FileName := GetSoundFileName(Effect);
  if not FileExists(FileName) then Exit;

  {$IFDEF WINDOWS}
  sndPlaySound(PChar(FileName), SND_ASYNC or SND_NODEFAULT);
  {$ENDIF}
end;

procedure TAudioManager.StartAmbient(const SoundFileName: string);
var
  FullPath: string;
begin
  if not FEnabled then Exit;

  FullPath := ExtractFilePath(ParamStr(0)) +  PathDelim + 'sounds' + PathDelim + SoundFileName;
  if not FileExists(FullPath) then Exit;

  {$IFDEF WINDOWS}
  { SND_LOOP membuat audio berputar otomatis, SND_ASYNC agar tidak nge-lag/blocking }
  sndPlaySound(PChar(FullPath), SND_ASYNC or SND_LOOP or SND_NODEFAULT);
  {$ENDIF}
end;

procedure TAudioManager.StopAmbient;
begin
  {$IFDEF WINDOWS}
  { Mengirim parameter nil akan menghentikan suara ambient yang sedang melakukan loop }
  sndPlaySound(nil, 0);
  {$ENDIF}
end;

end.
