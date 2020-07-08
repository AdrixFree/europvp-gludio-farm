///////////////////////////////////////////////////////////
//
//        LANGHOST GLUDIO FARM SCRIPT v2.5 (C) 2020
//
// Press 'SPACE' to run or stop script
// Press 'M' to active MM profile (activated by default)
// Press 'L' to active Archer profile
//
///////////////////////////////////////////////////////////

uses SysUtils, Classes, RegExpr;

///////////////////////////////////////////////////////////
//
//                     USER SETTINGS
//
///////////////////////////////////////////////////////////

const
    ARCH_KEY = 'L';
    MM_KEY = 'M';
    STATUS_KEY = 32;
    DEATH_DELAY = 1500;

var
    GludioPoint : array[0..2] of integer = (-14172, 123626, -3120);

///////////////////////////////////////////////////////////
//
//                     SCRIPT DEFINES
//
///////////////////////////////////////////////////////////

const
    AURA_DISTANCE = 200;
    MOVE_DELAY = 5000;
    MM_BUFF_COUNT = 3;
    ARCH_BUFF_COUNT = 5;
    SURRENDER_WATER = 4463;
    SHIELD_BUF = 1040;
    TARGET_NAME = 'Gludio';
    RANGE_SKILLS_COUNT = 3;
    ARCH_NEXT_DELAY = 1000;

type
    TSkill = (HYDRO_SKILL = 1235,
              SOLAR_SKILL = 1265,
              VORTEX_SKILL = 1342,
              FLASH_SKILL = 1417,
              FLARE_SKILL = 1231);

    TMagBuff = (ARCANE_BUFF = 337,
                CRYSTAL_BUFF = 7917,
                AQUA_BUFF = 1182);

    TArchBuff = (RAPID_BUFF = 99,
                 CRYSTAL_BUFF = 7917,
                 STANCE_BUFF = 312,
                 ACCURACY_BUFF = 256,
                 UE_BUFF = 111);

    TProfile = (MM_PROFILE, ARCH_PROFILE);

var
    LastTarget : string;
    Profile : TProfile;
    Status : boolean;
    MagBuffs : array[0..MM_BUFF_COUNT - 1] of integer = (Integer(ARCANE_BUFF),
                                                         Integer(CRYSTAL_BUFF),
                                                         Integer(AQUA_BUFF));
    ArchBuffs : array[0..ARCH_BUFF_COUNT - 1] of integer = (Integer(RAPID_BUFF),
                                                            Integer(CRYSTAL_BUFF),
                                                            Integer(STANCE_BUFF),
                                                            Integer(ACCURACY_BUFF),
                                                            Integer(UE_BUFF));
    RangeSkills : array[0..RANGE_SKILLS_COUNT - 1] of integer = (Integer(VORTEX_SKILL),
                                                                 Integer(SOLAR_SKILL),
                                                                 Integer(HYDRO_SKILL));

///////////////////////////////////////////////////////////
//
//                  WINAPI FUNCTIONS
//
///////////////////////////////////////////////////////////

function GetAsyncKeyState(vKey: integer): integer; stdcall; external 'user32.dll';

///////////////////////////////////////////////////////////
//
//                       HELPERS
//
///////////////////////////////////////////////////////////

function SendBypass(dlg: string): boolean;
var
    RegExp : TRegExpr;
    List : TStringList;
    i : integer;
    bps : string;
begin
    result:= true;
    RegExp:= TRegExpr.Create;
    List:= TStringList.Create;
  
    RegExp.Expression:= '(<a *(.+?)</a>)|(<button *(.+?)>)';
    if RegExp.Exec(Engine.DlgText)
    then begin
        repeat List.Add(RegExp.Match[0]);
        until (not RegExp.ExecNext);
    end;

    for i := 0 to List.Count - 1 do
    begin
        if (Pos(dlg, List[i]) > 0)
        then begin
            RegExp.Expression:= '"bypass -h *(.+?)"';
            if RegExp.Exec(List[i])
            then bps:= TrimLeft(Copy(RegExp.Match[0], 12, Length(RegExp.Match[0]) - 12));
        end;
    end;

    if (Length(bps) > 0)
    then Engine.BypassToServer(bps);
  
    RegExp.Free;
    List.Free;
end;

///////////////////////////////////////////////////////////
//
//                     FUNCTIONS
//
///////////////////////////////////////////////////////////

function GetTarget() : TL2Char;
var
    i : integer;
    target : TL2Char;
begin
    result := nil;

    for i := 0 to CharList.count - 1 do
    begin
        target := CharList.Items(i);

        if (not target.Valid)
        then continue;

        if (target.Dead)
        then continue;

        if (target.Name <> TARGET_NAME)
        then continue;

        result := target;
        exit;
    end;
end;

procedure RangeAttack();
var
    i : integer;
    skill, vortex, solar : TL2Skill;
begin
    for i := 0 to RANGE_SKILLS_COUNT - 1 do
    begin
        Engine.GetSkillList.ByID(Integer(RangeSkills[i]), skill);
        if (skill.EndTime = 0) and (Status) and (not User.Target.Dead)
        then  begin
            if (RangeSkills[i] = Integer(HYDRO_SKILL))
            then begin
                Engine.GetSkillList.ByID(Integer(VORTEX_SKILL), vortex);
                Engine.GetSkillList.ByID(Integer(SOLAR_SKILL), solar);
                if (vortex.EndTime = 0) or (solar.EndTime = 0)
                then continue;
            end;
            Engine.DUseSkill(Integer(RangeSkills[i]), True, False);
            Delay(200);
        end;
    end;
end;

procedure AttackTarget(target : TL2Char);
begin
    if (not target.Valid)
    then exit;

    Engine.SetTarget(target);

    if (Profile = MM_PROFILE)
    then begin
        if (User.DistTo(target) > AURA_DISTANCE)
        then begin
            RangeAttack();
        end else
        begin
            Engine.DUseSkill(Integer(FLASH_SKILL), False, False);
            delay(10);
            Engine.DUseSkill(Integer(FLARE_SKILL), False, False);
            delay(10);
        end;
    end;

    if (Profile = ARCH_PROFILE)
    then Engine.Attack(ARCH_NEXT_DELAY, true);
end;

procedure SelfBuff();
var
    buff : TL2Skill;
    i : integer;
begin
    if (Profile = MM_PROFILE)
    then begin
        for i := 0 to MM_BUFF_COUNT - 1 do
        begin
            if (not User.Buffs.ByID(Integer(MagBuffs[i]), buff))
            then begin
                if (MagBuffs[i] = Integer(CRYSTAL_BUFF))
                then begin
                    Engine.UseItem(Integer(CRYSTAL_BUFF));
                    continue;
                end;

                if (MagBuffs[i] = Integer(AQUA_BUFF))
                then begin
                    if (not User.Buffs.ByID(SURRENDER_WATER, buff))
                    then begin
                        Engine.SetTarget(User);
                        Engine.UseSkill(Integer(AQUA_BUFF));
                        Engine.CancelTarget;
                    end;
                    Delay(800);
                    continue;
                end;

                Engine.UseSkill(Integer(MagBuffs[i]));
                Delay(800);
            end;
        end;
    end;

    if (Profile = ARCH_PROFILE)
    then begin
        for i := 0 to ARCH_BUFF_COUNT - 1 do
        begin
            if (not User.Buffs.ByID(Integer(ArchBuffs[i]), buff))
            then begin
                if (ArchBuffs[i] = Integer(CRYSTAL_BUFF))
                then begin
                    Engine.UseItem(Integer(CRYSTAL_BUFF));
                    continue;
                end;

                Engine.UseSkill(Integer(ArchBuffs[i]));
                Delay(600);
            end;
        end;
    end;

    delay(100);
end;

procedure MoveToCenter();
begin
    Engine.DMoveTo(GludioPoint[0], GludioPoint[1], GludioPoint[2]);
end;

procedure ReturnToHome();
begin
    delay(4000);
    Engine.GoHome(rtFlags);
    delay(4000);
    Engine.MoveTo(147688, -58984, -2976);
    Engine.MoveTo(147992, -55272, -2728);
    Engine.SetTarget(31275);
    Engine.DlgOpen;
    SendBypass('I want to teleport.');
    delay(1500);
    SendBypass('The Town of Gludio">The Town of Gludio - 71000 Adena');
    delay(4000);
    Engine.MoveTo(-13112, 121832, -2968);
    Engine.SetTarget(100910);
    Engine.DlgOpen();
    delay(1000);
    SendBypass('Исп. профиль');
    delay(1000);
    Engine.MoveTo(-13512, 121704, -2968);
    Engine.DMoveTo(-14232, 121720, -2984);
    delay(3000);
    Status := true;
end;

///////////////////////////////////////////////////////////
//
//                    SCRIPT THREADS
//
///////////////////////////////////////////////////////////

procedure TargetSearchThread();
var
    target : TL2Char;
begin
    LastTarget := '';

    while True do
    begin
        if (Status)
        then begin
            target := GetTarget();
            if (target <> nil)
            then begin
                if (not User.Dead)
                then AttackTarget(target);
            end;
        end;
        delay(1);
    end;
end;

procedure BuffsThread();
begin
    while True do
    begin
        if (Status)
        then SelfBuff();
        delay(100);
    end;
end;

procedure MoveThread();
begin
    while True do
    begin
        if (Status)
        then MoveToCenter();
        Delay(MOVE_DELAY);
    end;
end;

procedure ReadStatusKeyThread();
begin
    Status := false;

    while True do
    begin
        while GetAsyncKeyState(STATUS_KEY) = 0 do Delay(100);
        if (Status)
        then begin
            Engine.GamePrint('GLUDIO> SCRIPT STOP', '.', 2);
            Status := false;
        end else
        begin
            Engine.GamePrint('GLUDIO> SCRIPT RUN', '.', 2);
            Status := true;
        end;
        Delay(600);
    end;
end;

procedure ReadArchKeyThread();
begin
    while True do
    begin
        while GetAsyncKeyState(ord(ARCH_KEY)) = 0 do Delay(100);
        Engine.GamePrint('GLUDIO> SELECT ARCHER PROFILE', '.', 2);
        Profile := ARCH_PROFILE;
        Delay(600);
    end;
end;

procedure ReadMMKeyThread();
begin
    Profile := MM_PROFILE;
    Engine.GamePrint('GLUDIO> SELECT MM PROFILE', '.', 2);

    while True do
    begin
        while GetAsyncKeyState(ord(MM_KEY)) = 0 do Delay(100);
        Engine.GamePrint('GLUDIO> SELECT MM PROFILE', '.', 2);
        Profile := MM_PROFILE;
        Delay(600);
    end;
end;

procedure ReturnHomeThread();
var
    buff : TL2Skill;
begin
    while True do
    begin
        if (User.Dead)
        then begin
            if (not User.Buffs.ByID(SHIELD_BUF, buff))
            then begin
                Status := false;
                ReturnToHome();
            end
            else Engine.GoHome;
            Delay(DEATH_DELAY);
        end;
    end;
end;

///////////////////////////////////////////////////////////
//
//                    MAIN FUNCTION
//
///////////////////////////////////////////////////////////

begin
    Script.NewThread(@TargetSearchThread);
    Script.NewThread(@BuffsThread);
    Script.NewThread(@MoveThread);
    Script.NewThread(@ReadMMKeyThread);
    Script.NewThread(@ReadArchKeyThread);
    Script.NewThread(@ReadStatusKeyThread);
    Script.NewThread(@ReturnHomeThread);
end.