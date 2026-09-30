unit uSaveLoadForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, uSaveManager;

type
  { TSaveLoadForm }
  TSaveLoadForm = class(TForm)
    pnlBackground: TPanel;
    lblTitle: TLabel;
    btnSlot1: TButton;
    btnSlot2: TButton;
    btnSlot3: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnSlotClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FSelectedSlot: Integer;
    procedure UpdateSlotInfo;
    function GetSaveFilePath(SlotIndex: Integer): string;
  public
    property SelectedSlot: Integer read FSelectedSlot;
  end;

var
  SaveLoadForm: TSaveLoadForm;

implementation

{$R *.lfm}

{ TSaveLoadForm }

procedure TSaveLoadForm.FormCreate(Sender: TObject);
begin
  FSelectedSlot := 0;
  { Menggunakan properti Tag untuk mempermudah identifikasi slot yang dipilih }
  if Assigned(btnSlot1) then btnSlot1.Tag := 1;
  if Assigned(btnSlot2) then btnSlot2.Tag := 2;
  if Assigned(btnSlot3) then btnSlot3.Tag := 3;
end;

procedure TSaveLoadForm.FormShow(Sender: TObject);
begin
  UpdateSlotInfo;
end;

function TSaveLoadForm.GetSaveFilePath(SlotIndex: Integer): string;
var
  SaveDir: string;
begin
  SaveDir := ExtractFilePath(Application.ExeName) + 'data' + PathDelim + 'saves';
  Result := SaveDir + PathDelim + 'slot' + IntToStr(SlotIndex) + '.json';
end;

procedure TSaveLoadForm.UpdateSlotInfo;
var
  i: Integer;
  Btn: TButton;
  Meta: TSaveMetaData;
  Desc: string;
begin
  for i := 1 to 3 do
  begin
    Btn := nil;
    case i of
      1: Btn := btnSlot1;
      2: Btn := btnSlot2;
      3: Btn := btnSlot3;
    end;

    if Assigned(Btn) then
    begin
      Meta := TSaveManager.GetSaveMetaData(GetSaveFilePath(i));
      if Meta.IsValid then
        Desc := Format('SLOT %d - SOL %d [%s]', [i, Meta.SolCycle, Meta.Timestamp])
      else
        Desc := Format('SLOT %d - [ EMPTY ]', [i]);

      Btn.Caption := Desc;
    end;
  end;
end;

procedure TSaveLoadForm.btnSlotClick(Sender: TObject);
begin
  if Sender is TButton then
  begin
    FSelectedSlot := (Sender as TButton).Tag;
    ModalResult := mrOk;
  end;
end;

procedure TSaveLoadForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
