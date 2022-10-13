program game;

// Игра пинг-понг

{$mode objfpc}{$H+}
{$modeswitch ADVANCEDRECORDS}

uses
  cmem,
  raylib,
  raymath,
  SysUtils;

const
  SCREEN_WIDTH = 1024;
  SCREEN_HEIGHT = 756;

  RACKET_WIDTH = 30;
  RACKET_HEIGHT = 100;
  RACKET_SPEED = 5;

  BORDER_PADDING = 7;

  BALL_RADIUS = 20;
  DEFAULT_BALL_SPEED = 3;

type
  // Таймер основанный на счётчике времени между фреймами

  { TFrameTimer }

  TFrameTimer = record
  private
    FTicks: double;
    FSeconds: single;
  public
    constructor Create(seconds: single);
    procedure Update;
    procedure Reset;
    function IsTriggered: boolean;
    property Seconds: single read FSeconds write FSeconds;
  end;

  TRacket = record
    Rectangle: TRectangle;
    Color: TColorB;
    CollisionWithBall: boolean;
    // Количество побед
    Score: integer;
  end;

  TPlayer = record
    Racket: TRacket;
  end;

  TEnemy = record
    Racket: TRacket;
    IsMoving: boolean;
    MoveTimer: TFrameTimer;
    PauseTimer: TFrameTimer;
  end;

  TBall = record
    Pos: TVector2;
    Velx, Vely: single;
    Radius: integer;
    Color: TColorB;
    SpeedTimer: TFrameTimer;
  end;

  TGameState = (GSStart, GSGame, GSGameOver);

var
  gplayer: TPlayer;
  genemy: TEnemy;
  gball: TBall;
  ggamestate: TGameState = GSGame;

  procedure DrawRacket(racket: TRacket);
  begin
    DrawRectangle(trunc(racket.Rectangle.x), trunc(racket.Rectangle.y),
      trunc(racket.Rectangle.Width),
      trunc(racket.Rectangle.Height), racket.color);
  end;

  procedure DrawBall(ball: TBall);
  begin
    DrawCircle(trunc(ball.Pos.x), trunc(ball.Pos.y), ball.Radius, ball.Color);
  end;

  procedure DrawCenterLine;
  const
    LINE_WIDTH = 4;
    LINE_HEIGHT = 6;
    LINE_COUNT = 30;
  var
    centerX, i: integer;
    padding: int64;
  begin
    centerX := Trunc(SCREEN_WIDTH / 2);

    padding := trunc((SCREEN_HEIGHT - LINE_HEIGHT * LINE_COUNT) / LINE_COUNT);

    for i := 0 to LINE_COUNT - 1 do
    begin
      DrawRectangle(centerX, trunc(padding / 2) + i * (padding + LINE_HEIGHT),
        LINE_WIDTH, LINE_HEIGHT, LIGHTGRAY);
    end;
  end;

  procedure DrawScore;
  const
    FONT_SIZE = 28;
    PADDING_X = 40;
    PADDING_Y = 10;
  var
    PlayerText, EnemyText: PChar;
    centerX: int64;
  begin
    centerX := trunc(SCREEN_WIDTH / 2 - 5);

    PlayerText := PChar(IntToStr(gplayer.Racket.Score));
    DrawText(PlayerText, centerX - PADDING_X, PADDING_Y, FONT_SIZE, LIGHTGRAY);

    EnemyText := PChar(IntToStr(genemy.Racket.Score));
    DrawText(EnemyText, centerX + PADDING_X, PADDING_Y, FONT_SIZE, LIGHTGRAY);
  end;

  procedure ResetBall;
  var
    centerY, centerX, rndY, rndX: int64;
    signX, signY: integer;
  begin
    rndX := Random(2);
    rndY := Random(2);

    signX := 1;
    signY := 1;

    if rndX = 0 then
      signX := -1;

    if rndY = 0 then
      signY := -1;

    centerX := trunc(SCREEN_WIDTH / 2.0);
    centerY := trunc(SCREEN_HEIGHT / 2.0);

    with gball do
    begin
      Pos.x := centerX;
      Pos.y := centerY;
      Velx := DEFAULT_BALL_SPEED * signX;
      Vely := DEFAULT_BALL_SPEED * signY;
    end;
  end;

  procedure UpdatePlayer;
  begin
    if gplayer.Racket.CollisionWithBall then Exit();

    if IsKeyDown(KEY_W) then
    begin
      gplayer.Racket.Rectangle.y := gplayer.Racket.Rectangle.y - RACKET_SPEED;
    end;

    if IsKeyDown(KEY_S) then
    begin
      gplayer.Racket.Rectangle.y := gplayer.Racket.Rectangle.y + RACKET_SPEED;
    end;

    if gplayer.Racket.Rectangle.y + RACKET_HEIGHT > SCREEN_HEIGHT then
    begin
      gplayer.Racket.Rectangle.y := SCREEN_HEIGHT - RACKET_HEIGHT;
    end;

    if gplayer.Racket.Rectangle.y < 0 then
    begin
      gplayer.Racket.Rectangle.y := 0;
    end;
  end;

  procedure UpdateEnemy;
  var
    ballCenter, newSpeed: single;
  begin
    ballCenter := gball.Pos.y;

    genemy.MoveTimer.Update;
    genemy.PauseTimer.Update;

    newSpeed := 0;

    if (genemy.MoveTimer.IsTriggered) then
    begin
      genemy.PauseTimer.Reset;
      genemy.IsMoving := False;
      if (gball.Pos.x < SCREEN_WIDTH / 2) or (gball.Velx < 0) then
      begin
        genemy.PauseTimer.Seconds := clamp(Random * 1, 0.2, 1);
        genemy.MoveTimer.Seconds := clamp(Random * 2, 0.2, 2);
      end
      else
      begin
        genemy.PauseTimer.Seconds := clamp(Random / 2, 0.1, 0.5);
        genemy.MoveTimer.Seconds := clamp(Random * 4, 1, 4);
      end;
    end;

    if genemy.IsMoving then
    begin
      newSpeed := ballCenter - (genemy.Racket.Rectangle.y +
        genemy.Racket.Rectangle.Height / 2);
      newSpeed := clamp(newSpeed, -RACKET_SPEED, RACKET_SPEED);
    end
    else
    begin
      genemy.MoveTimer.Reset;
    end;

    if genemy.PauseTimer.IsTriggered then
    begin
      genemy.IsMoving := True;
    end;

    genemy.Racket.Rectangle.y :=
      genemy.Racket.Rectangle.y + newSpeed;

    if genemy.Racket.Rectangle.y + genemy.Racket.Rectangle.Height > SCREEN_HEIGHT then
    begin
      genemy.Racket.Rectangle.y := SCREEN_HEIGHT - genemy.Racket.Rectangle.Height;
    end
    else if genemy.Racket.Rectangle.y < 0 then
    begin
      genemy.Racket.Rectangle.y := 0;
    end;
  end;

  procedure NotifyLose(isPlayer: boolean);
  begin
    if isPlayer then
    begin
      Inc(genemy.Racket.Score);
    end
    else
    begin
      Inc(gplayer.Racket.Score);
    end;

    ResetBall;
  end;

  procedure UpdateBall;

    procedure ProcessRacketCollision(racket: TRacket);
    begin
      if CheckCollisionCircleRec(gball.Pos, gball.Radius, racket.Rectangle) then
      begin
        if not racket.CollisionWithBall then
        begin
          if gball.Vely >= 0 then
          begin
            gball.Vely := Random * DEFAULT_BALL_SPEED;
          end
          else
          begin
            gball.Vely := -1 * Random * DEFAULT_BALL_SPEED;
          end;

          gball.velx := -1 * gball.velx;
          racket.CollisionWithBall := True;
        end;
      end
      else
      begin
        racket.CollisionWithBall := False;
      end;
    end;

  begin
    gball.SpeedTimer.Update;

    if gball.SpeedTimer.IsTriggered then
    begin
      gball.Velx := gball.Velx * 1.1;
    end;

    if gball.Pos.x + gball.Radius > SCREEN_WIDTH then
    begin
      gball.velx := -1 * gball.velx;
      NotifyLose(False);
    end
    else if gball.Pos.x - gball.Radius < 0 then
    begin
      gball.velx := -1 * gball.velx;
      NotifyLose(True);
    end;

    if (gball.Pos.y + gball.Radius > SCREEN_HEIGHT) or
      (gball.Pos.y - gball.Radius < 0) then
    begin
      gball.vely := -1 * gball.vely;
    end;

    ProcessRacketCollision(gplayer.Racket);
    ProcessRacketCollision(genemy.Racket);

    gball.Pos.x := gball.Pos.x + gball.velx;
    gball.Pos.y := gball.Pos.y + gball.vely;
  end;

  procedure Init;
  var
    racketCenterY, centerY: int64;
  begin
    Randomize;

    centerY := trunc(SCREEN_HEIGHT / 2.0);
    racketCenterY := Trunc(centerY - RACKET_HEIGHT / 2.0);

    with gplayer.Racket do
    begin
      Rectangle.x := BORDER_PADDING;
      Rectangle.y := racketCenterY;
      Rectangle.Width := RACKET_WIDTH;
      Rectangle.Height := RACKET_HEIGHT;
      Color := WHITE;
    end;

    with genemy.Racket do
    begin
      Rectangle.x := SCREEN_WIDTH - RACKET_WIDTH - BORDER_PADDING;
      Rectangle.y := racketCenterY;
      Rectangle.Width := RACKET_WIDTH;
      Rectangle.Height := RACKET_HEIGHT;
      Color := WHITE;
    end;

    with genemy do
    begin
      IsMoving := True;
      MoveTimer := TFrameTimer.Create(1);
      PauseTimer := TFrameTimer.Create(1);
    end;

    with gball do
    begin
      Radius := BALL_RADIUS;
      Color := WHITE;
      SpeedTimer := TFrameTimer.Create(3);
    end;

    ResetBall;
  end;

  procedure Update;
  begin
    case ggamestate of
      GSGame: begin
        UpdatePlayer;
        UpdateEnemy;
        UpdateBall;
      end;
      else
    end;
  end;

  procedure Draw;
  begin
    case ggamestate of
      GSGame: begin
        BeginDrawing();
        ClearBackground(DARKGRAY);
        DrawCenterLine();
        DrawScore();
        DrawRacket(gplayer.Racket);
        DrawRacket(genemy.Racket);
        DrawBall(gball);
        EndDrawing();
      end;
      else
    end;
  end;

  { TFrameTimer }

  constructor TFrameTimer.Create(seconds: single);
  begin
    FSeconds := seconds;
    FTicks := 0;
  end;

  procedure TFrameTimer.Update;
  begin
    FTicks := FTicks + GetFrameTime;
  end;

  procedure TFrameTimer.Reset;
  begin
    FTicks := 0;
  end;

  function TFrameTimer.IsTriggered: boolean;
  begin
    Result := False;
    if FTicks >= FSeconds then
    begin
      FTicks := 0;
      Result := True;
    end;
  end;

begin
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Ping Pong');
  SetTargetFPS(60);

  Init;

  while not WindowShouldClose() do
  begin
    Update;
    Draw;
  end;

  CloseWindow();
end.
