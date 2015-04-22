{
BitmapSpeedButton component for FireMonkey.
See documentation at http://monkeystyler.com/wiki/TBitmapSpeedButton

Brought to you by the author of MonkeyStyler - FireMonkey style designer.
http://monkeystyler.com

You are free to use this code for any purpose provided:
* You do not charge for source code
* If you fork this project please keep this header intact.
* You are free to use the compiled code from this file in commercial projects.
}
unit Solent.BitmapSpeedButton;

interface
uses FMX.Controls, FMX.Layouts, FMX.Objects, FMX.Types, Classes, FMX.StdCtrls, FMX.Graphics;

type TToolTipPopup = class(TPopup)
  private
    procedure SetText(const Value: String);
  protected
    FText: String;
    procedure ApplyStyle;override;
    procedure UpdateText;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Popup(const AShowModal: Boolean = False);override;
    procedure ClosePopup;override;
  published
    property Text: String read FText write SetText;
  end;

type TImageAlign = (iaTop, iaLeft, iaRight, iaBottom, iaCenter);
  //Whether to get the image from the Bitmap property of the ImageStyleLookup property
  TImageType = (itBitmap, itStyleLookup);

type
  TBitmapSpeedButton = class(TSpeedButton)
  private
    FImageAlign: TImageAlign;
    FTextVisible: Boolean;
    FImageHeight: Single;
    FImageWidth: Single;
    FImagePadding: Single;
    FImageType: TImageType;
    FImageStyleLookup: String;
    FShowingToolTip: Boolean;
    FToolTip: String;
    procedure SetImageAlign(const Value: TImageAlign);
    procedure SetTextVisible(const Value: Boolean);
    procedure SetImageHeight(const Value: Single);
    procedure SetImagePadding(const Value: Single);
    procedure SetImageWidth(const Value: Single);
    procedure SetImageStyleLookup(const Value: String);
    procedure SetImageType(const Value: TImageType);
    procedure SetToolTip(const Value: String);
    procedure SetToolTipPlacement(const Value: TPlacement);
    function GetToolTipPlacement: TPlacement;
  protected
    FImageLayout: TLayout;
    FImage: TImage;
    FBitmap: TBitmap;
    FToolTipPopup: TToolTipPopup;
    //Show ToolTip once this timer trips
    FToolTipTimer: TTimer;
    //Show toolip immediately if another button has ShowingToolTip = True.
    //ShowingToolTip will be set to False once this timer expires (it is enabled on MouseLeave).
    FNoToolTipTimer: TTimer;
    procedure ApplyStyle;override;
    procedure EVBitmapChange(Sender: TObject);
    procedure UpdateImageLayout;
    procedure UpdateImage;
    procedure DoMouseEnter;override;
    procedure DoMouseLeave;override;
    procedure EVToolTipTimer(Sender: TObject);
    procedure EVNoToolTipTimer(Sender: TObject);
  public
    constructor Create(AOwner: TComponent);override;
    destructor Destroy;override;
    property ShowingToolTip: Boolean read FShowingToolTip;
  published
    property ImageAlign: TImageAlign read FImageAlign write SetImageAlign default iaCenter;
    property TextVisible: Boolean read FTextVisible write SetTextVisible;
    property ImageType: TImageType read FImageType write SetImageType;
    property Bitmap: TBitmap read FBitmap write FBitmap;
    property ImageStyleLookup: String read FImageStyleLookup write SetImageStyleLookup;
    property ImageWidth: Single read FImageWidth write SetImageWidth;
    property ImageHeight: Single read FImageHeight write SetImageHeight;
    property ImagePadding: Single read FImagePadding write SetImagePadding;
    property ToolTip: String read FToolTip write SetToolTip;
    property ToolTipPlacement: TPlacement read GetToolTipPlacement write SetToolTipPlacement default TPlacement.TopCenter;
  end;

procedure Register;

implementation

uses
 FMX.Ani, FMX.Forms, SysUtils{$IFNDEF VER230}, FMX.Styles{$ENDIF};

procedure Register;
begin
  RegisterComponents('SolentFMX', [TBitmapSpeedButton]);
end;

{ TToolTipPopup }

procedure TToolTipPopup.ApplyStyle;
begin
  inherited;
  UpdateText;
end;

procedure TToolTipPopup.ClosePopup;
begin
  //If we close popup while our 'showing' animation is in effect we'll get an error due to an FM bug,
  //so explicitly stop the animation.
  StopPropertyAnimation('Opacity');
  inherited;
end;

constructor TToolTipPopup.Create(AOwner: TComponent);
begin
  inherited;
  Placement := TPlacement.TopCenter;
end;

procedure TToolTipPopup.Popup(const AShowModal: Boolean);
begin
  if (FText = '') or IsOpen then
    EXIT;

  Opacity := 0;
  //HACK: Inherited calls ApplyPlacement before it calls ApplyStyle.
  //Since we are setting the size from ApplyStyle (because we don't know how big the text will be
  //until we know how it is being displayed), this causes placement errors.
  //And explicitly calling ApplyPlacement causes an AV (or improper placement, I forget which).
  //So, show the popup (wrong placement), hide it, then show it again (now with correct placement).
  //As far as I can tell this all happens before the display gets updated, so our animation still works.
  inherited;
  ClosePopup;
  inherited;
  TAnimator.AnimateFloat(Self, 'Opacity', 1, 0.2);
end;

procedure TToolTipPopup.SetText(const Value: String);
begin
  FText := Value;
  UpdateText;
end;

type THackText = class(TText)
  end;
procedure TToolTipPopup.UpdateText;
var T: TFMXObject;
  TT: TText;
begin
  T := FindStyleResource('Text');
  if T is TText then
  begin
    TT := TText(T);
    TT.Text := FText;
    //Under XE3 setting Text doesn't realign the contents (bug). And Realign is protected so we need to hack around it.
    THackText(TT).Realign;
    Width := TT.Width+TT.Padding.Left+TT.Padding.Right;
    Height := TT.Height+TT.Padding.Top+TT.Padding.Bottom;
  end;
end;

{ TBitmapSpeedButton }

procedure TBitmapSpeedButton.ApplyStyle;
var T: TFMXObject;
begin
  inherited;
  T := FindStyleResource('imagelayout');
  if (T <> nil) and (T is TLayout) then
    FImageLayout := TLayout(T);
  T := FindStyleResource('image');
  if (T <> nil) and (T is TImage) then
  begin
    FImage := TImage(T);
    UpdateImage;
  end;
  SetTextVisible(FTextVisible);
  UpdateImageLayout;
end;

constructor TBitmapSpeedButton.Create(AOwner: TComponent);
begin
  inherited;
  FBitmap := TBitmap.Create(0,0);
  FBitmap.OnChange := EVBitmapChange;
  FImageAlign := iaCenter;
  Height := 28;
  Width := 28;
  ImageWidth := 24;
  ImageHeight := 24;
  ImagePadding := 2;
  FToolTipTimer := TTimer.Create(Self);
  FToolTipTimer.Enabled := False;
  FToolTipTimer.Interval := 2000;
  FToolTipTimer.OnTimer := EVToolTipTimer;
  FNoToolTipTimer := TTimer.Create(Self);
  FNoToolTipTimer.Enabled := False;
  FNoToolTipTimer.Interval := 2000;
  FNoToolTipTimer.OnTimer := EVNoToolTipTimer;
  if not (csDesigning in ComponentState) then
  begin
    FToolTipPopup := TToolTipPopup.Create(Self);
    FToolTipPopup.Parent := Self;
  end;
  ToolTipPlacement := TPlacement.TopCenter;
end;

destructor TBitmapSpeedButton.Destroy;
begin
  FToolTipTimer.Free;
  FNoToolTipTimer.Free;
  FreeAndNil(FToolTipPopup);
  FBitmap.Free;
  inherited;
end;

procedure TBitmapSpeedButton.DoMouseEnter;
var Showing: Boolean;
  I: Integer;
begin
  inherited;
  FNoToolTipTimer.Enabled := False;
  //Find if any other components have been showing a tooltip recently...
  Showing := False;
  if Parent <> nil then
    for I := 0 to Parent.ChildrenCount-1 do
      if Parent.Children[I] is TBitmapSpeedButton then
        Showing := Showing or TBitmapSpeedButton(Parent.Children[I]).ShowingToolTip;
  //... if show show our tooltip immediately...
  if Showing then
    if Assigned(FToolTipPopup) then
    begin
      FToolTipPopup.Popup;
      FShowingToolTip := True;
    end
    else
  //... otherwise start a timer before showing tooltip.
  else
    FToolTipTimer.Enabled := True;
end;

procedure TBitmapSpeedButton.DoMouseLeave;
begin
  inherited;
  FToolTipTimer.Enabled := False;
  if Assigned(FToolTipPopup) then
  begin
    FToolTipPopup.ClosePopup;
    FNoToolTipTimer.Enabled := False;
    FNoToolTipTimer.Enabled := True;
  end;
end;

procedure TBitmapSpeedButton.EVBitmapChange(Sender: TObject);
begin
  UpdateImage;
end;

procedure TBitmapSpeedButton.EVNoToolTipTimer(Sender: TObject);
begin
  if Assigned(FToolTipPopup) and not FToolTipPopup.IsOpen then
    FShowingToolTip := False;
end;

procedure TBitmapSpeedButton.EVToolTipTimer(Sender: TObject);
begin
  if IsMouseOver and Assigned(FToolTipPopup) then
  begin
    FToolTipPopup.Popup;
    FShowingToolTip := True;
  end;
end;

function TBitmapSpeedButton.GetToolTipPlacement: TPlacement;
begin
  if FToolTipPopup <> nil then
    Result := FToolTipPopup.Placement
  else
    Result := TPlacement.TopCenter;
end;

procedure TBitmapSpeedButton.SetImageAlign(const Value: TImageAlign);
begin
  FImageAlign := Value;
  UpdateImageLayout;
end;

procedure TBitmapSpeedButton.SetImageHeight(const Value: Single);
begin
  FImageHeight := Value;
  if FImage <> nil then
    FImage.Height := Value;
  UpdateImageLayout;
end;

procedure TBitmapSpeedButton.SetImagePadding(const Value: Single);
begin
  FImagePadding := Value;
  UpdateImageLayout;
end;

procedure TBitmapSpeedButton.SetImageStyleLookup(const Value: String);
begin
  FImageStyleLookup := Value;
  if FImageType = itStyleLookup then
    UpdateImage;
end;

procedure TBitmapSpeedButton.SetImageType(const Value: TImageType);
var Changed: Boolean;
begin
  Changed := FImageType <> Value;
  FImageType := Value;
  if Changed then
    UpdateImage;
end;

procedure TBitmapSpeedButton.SetImageWidth(const Value: Single);
begin
  FImageWidth := Value;
  UpdateImageLayout;
end;

procedure TBitmapSpeedButton.SetToolTipPlacement(const Value: TPlacement);
begin
  if Assigned(FToolTipPopup) then
    FToolTipPopup.Placement := Value;
end;

procedure TBitmapSpeedButton.SetTextVisible(const Value: Boolean);
begin
  FTextVisible := Value;
  if ({$IFDEF VER230}FTextObject{$ELSE}TextObject{$ENDIF} <> nil)
    and ({$IFDEF VER230}FTextObject{$ELSE}TextObject{$ENDIF} is TText) then
    TText({$IFDEF VER230}FTextObject{$ELSE}TextObject{$ENDIF}).Visible := Value;
end;

procedure TBitmapSpeedButton.SetToolTip(const Value: String);
begin
  FToolTip := Value;
  if Assigned(FToolTipPopup) then
    FToolTipPopup.Text := Value;
end;

procedure TBitmapSpeedButton.UpdateImage;
var Obj: TFMXObject;
begin
  if FImageType = itBitmap then
    if FImage <> nil then
      FImage.Bitmap.Assign(FBitmap)
    else
  else //itResource
  begin
    Obj := nil;
    if (FScene <> nil) and (FScene.GetStyleBook <> nil) and (FScene.GetStyleBook.Root <> nil) then
      Obj := TControl(FScene.GetStyleBook.{$IFDEF VER230}Root{$ELSE}Style{$ENDIF}.FindStyleResource(FImageStyleLookup));
    if Obj = nil then
      {$IFDEF VER230}
      if Application.DefaultStyles <> nil then
        Obj := TControl(Application.DefaultStyles.FindStyleResource(FImageStyleLookup));
      {$ELSE}
      if TStyleManager.ActiveStyle(nil) <> nil then
        Obj := TControl(TStyleManager.ActiveStyle(nil).FindStyleResource(FImageStyleLookup));
      {$ENDIF}
    if (Obj <> nil) and (Obj is TImage) and (FImage <> nil) then
      FImage.Bitmap.Assign(TImage(Obj).Bitmap);
  end;
end;

procedure TBitmapSpeedButton.UpdateImageLayout;
begin
  if FImage <> nil then
  begin
    FImage.Width := ImageWidth;
    FImage.Height := ImageHeight;
    case ImageAlign of
      iaLeft:FImageLayout.Align := TAlignLAyout.Left;
      iaTop: FImageLayout.Align := TAlignLAyout.Top;
      iaRight: FImageLayout.Align := TAlignLAyout.Right;
      iaBottom: FImageLayout.Align := TAlignLAyout.Bottom;
    else
      FImageLayout.Align := TAlignLayout.Center;
    end;
  end;

  if FImageLayout <> nil then
    if ImageAlign in [iaLeft, iaRight] then
      FImageLayout.Width := FImageWidth+FImagePadding*2
    else if ImageAlign in [iaTop, iaBottom] then
      FImageLayout.Height := FImageHeight+FImagePadding*2;
end;

initialization
  RegisterFMXClasses([TBitmapSpeedButton, TToolTipPopup]);
end.
