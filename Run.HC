Cd(__DIR__);;
#include "RandNum";


#define ENEMY_COL	1
#define PLR_COL		2
#define BULLET_COL	3



CDC *plrSprite;
plrSprite = GRRead("Sprites/Player.GR.Z");
CDC *enemyT1Sprite;
enemyT1Sprite = GRRead("Sprites/SkullT1.GR.Z");
CDC *enemyT1Sprite_Shoot;
enemyT1Sprite_Shoot = GRRead("Sprites/SkullT1_Shoot.GR.Z");
CDC *bulletSprite = GRRead("Sprites/EBullet.GR.Z");

CDC *menuLogo = GRRead("Sprites/Logo.GR.Z");

Bool in_menu = TRUE;
Bool gaming = TRUE;

class Keys {
  Bool up,down,left,right,actionA,actionB,actionC,pause;
};


class Vector2 {
  F64 x, y;
};

class Collider : CQue
{
  Vector2 position;
  Vector2 size;
  I8 type;
};

class Player
{
  Collider *myCollider;
  U64 Score;
  U64 lives;
  Bool immune;
  F64 speed;
};

class Enemy :CQue
{
  Collider *myCollider;
  I8 type;
  I16 health;
  I16 speed;
  Bool shooting;
  I16 shootCooldown;
};

class pBullet : CQue
{
  Collider *myCollider;
};

class eBullet : CQue
{
  Collider *myCollider;
  Vector2 velocity;
};


class Wave
{
  I64 T1Enemies;
  I64 T2Enemies;
  I64 T3Enemies;
  I64 BossType;
  I64 SpawnDelay;
  I64 BulletSpeed;
  Bool Boss;
};

#include "Waves.HC";

Wave *currentWave = CAlloc(sizeof(Wave));

I64 amountOfEnemies = 0;
I64 amountOfEBullets = 0;

Player player;
player.speed = 5;
Keys keys;


Collider colliders;
QueInit(&colliders);

pBullet pBullets;
QueInit(&pBullets);

eBullet eBullets;
QueInit(&eBullets);

Enemy Enemies;
QueInit(&Enemies);

U0 SetWave(Wave *setWave)
{
  currentWave->T1Enemies = setWave->T1Enemies;
  currentWave->T2Enemies = setWave->T2Enemies;
  currentWave->T3Enemies = setWave->T3Enemies;
  currentWave->BossType = setWave->BossType;
  currentWave->Boss = setWave->Boss;
  currentWave->SpawnDelay = setWave->SpawnDelay;
  currentWave->BulletSpeed = setWave->BulletSpeed;
}

Collider NewCollider(F64 x1, F64 y1, F64 x2, F64 y2, I8 type)
{
  Collider *new = CAlloc(sizeof(Collider));
  new->position.x = x1;
  new->position.y = y1;
  new->size.x = x2;
  new->size.y = y2;
  new->type = type;
  QueIns(new, colliders.last);
  return new;
}

Bool CheckCollision(Collider *a, Collider *b){
  if(a->position.x > b->position.x + b->size.x){
    return FALSE;
  }
  if(a->position.x + a->size.x < b->position.x){
    return FALSE;
  }
  if(a->position.y > b->position.y + b->size.y){
    return FALSE;
  }
  if(a->position.y + a->size.y < b->position.y){
    return FALSE;
  }

  return TRUE;
}

player.myCollider = NewCollider(298,400,12,12, PLR_COL);

U0 DrawSquare(CDC *dc, I64 x, I64 y, I64 w, I64 h)
{
  GrLine(dc, x, y, w + x, y);
  GrLine(dc, x, y, x, y+h);
  GrLine(dc, w+x, y, w+x, y+h);
  GrLine(dc, x, y+h, w+x, y+h);
}

U0 DrawColliders(CDC *dc)
{
  Collider *temp = colliders.next;
  while(temp != &colliders)
  {
    dc->color = GREEN;
    DrawSquare(dc,
      temp->position.x,
      temp->position.y,
      temp->size.x,
      temp->size.x);
    temp = temp->next;
  }
}
Bool slowMode = FALSE;


U0 MakeEnemy(F64 x1, F64 y1, I8 type)
{
  Enemy *new = CAlloc(sizeof(Enemy));
  new->myCollider = NewCollider(
    x1,
    y1,
    24,
    24,
    ENEMY_COL
  );
  new->type = type;
  switch(type) {
    case 1: 
      new->health = 5;
      new->shootCooldown = 30;
      new->speed = 2;
    break;
    case 2:
      new->health = 4;
      new->shootCooldown = 15;
      U16 dir = RandU16Range(0, 1);
      if(dir == 1)
        {new->speed = 1;}
      if(dir == 0)
	{new->speed = -1;}
      break;      
    default: new->health = 5; new->shootCooldown = 30; new->speed = 2; break;
  }
  QueIns(new, Enemies.last);
}

U0 RemoveEnemy(Enemy *enemy)
{
  QueRem(enemy->myCollider);
  Free(enemy->myCollider);
  QueRem(enemy);
  Free(enemy);
}

U0 TargetVelocity(Vector2 *source, Vector2 *target, Vector2 *out, I64 speed)
{
  F64 vx = target->x - source->x;
  F64 vy = target->y - source->y;

  F64 length = Sqrt(vx * vx + vy * vy);

  if(length != 0)
  {
    vx /= length;
    vy /= length;
  }

  out->x = vx * speed;
  out->y = vy * speed;
}

I64 immunityTimer = 10 * 30;

U0 PlayerKill()
{
  if(!player.immune)
  {
    // resetting the immunity timer
    immunityTimer = 10 * 30;
    player.lives--;
    player.immune = TRUE;
  }
}

U0 ShootEBullet(Enemy *enemy, F64 targetX, F64 targetY)
{
  eBullet *new = CAlloc(sizeof(eBullet));
  new->myCollider = NewCollider(
  enemy->myCollider->position.x + 8,
  enemy->myCollider->position.y + 8,
  5,
  5,
  BULLET_COL
  );
  enemy->shooting = TRUE;
  Vector2 targetPos;
  targetPos.x = targetX;
  targetPos.y = targetY;

  TargetVelocity(&enemy->myCollider->position, &targetPos, &new->velocity, currentWave->BulletSpeed);
  QueIns(new, eBullets);
}


U0 RemoveEBullet(eBullet *bullet)
{
  QueRem(bullet->myCollider);
  Free(bullet->myCollider);
  QueRem(bullet);
  Free(bullet);
}


U0 EBulletLogic(eBullet *bullet)
{
  bullet->myCollider->position.x += bullet->velocity.x / 100;
  bullet->myCollider->position.y += bullet->velocity.y / 100;

  F64 bulletX = bullet->myCollider->position.x;
  F64 bulletY = bullet->myCollider->position.y;

  if(bulletX > 320)
  {
    RemoveEBullet(bullet);
  }
  else if(bulletX <= 0)
  {
    RemoveEBullet(bullet);
  }
  else if(bulletY <= 0)
  {
    RemoveEBullet(bullet);
  }
  else if(bulletY > 500)
  {
    RemoveEBullet(bullet);
  }
  else if(CheckCollision(bullet->myCollider, player.myCollider))
  {
    PlayerKill;
    if(!player.immune)
    {
      RemoveEBullet(bullet);
    }
  }
  
}

U0 EnemyShootPatternCircle(Enemy *enemy)
{
  // Up
  ShootEBullet(enemy, enemy->myCollider->position.x, enemy->myCollider->position.y - 2);
  // Down
  ShootEBullet(enemy, enemy->myCollider->position.x, enemy->myCollider->position.y + 2);
  // Right
  ShootEBullet(enemy, enemy->myCollider->position.x + 2, enemy->myCollider->position.y);
  // Left
  ShootEBullet(enemy, enemy->myCollider->position.x - 2, enemy->myCollider->position.y);
  // Up Left
  ShootEBullet(enemy, enemy->myCollider->position.x - 2, enemy->myCollider->position.y - 2);
  // Up Right
  ShootEBullet(enemy, enemy->myCollider->position.x + 2, enemy->myCollider->position.y - 2);
  // Down Left
  ShootEBullet(enemy, enemy->myCollider->position.x - 2, enemy->myCollider->position.y + 2);
  // Down Right
  ShootEBullet(enemy, enemy->myCollider->position.x + 2, enemy->myCollider->position.y + 2);
}


U0 EnemyLogic(Enemy *enemy, CDC *dc)
{
  

  
  switch(enemy->type)
  {
    // Enemy that shoots at your position
    case 1:
      enemy->myCollider->position.y += enemy->speed;
      if(enemy->shootCooldown <= 0)
      {
        Vector2 *playerPos;
	playerPos = &player.myCollider->position;
	ShootEBullet(enemy, player.myCollider->position.x, player.myCollider->position.y);
        enemy->shootCooldown = 30;
        // enemy->shooting = FALSE;
      }

      if(enemy->shootCooldown > 0)
      {
        enemy->shootCooldown--;
      }

    break;

    // Enemy that shoots a circle
    case 2:
      enemy->myCollider->position.y += 1.5;
      enemy->myCollider->position.x += enemy->speed;

      if(enemy->shootCooldown <= 0)
      {

	EnemyShootPatternCircle(enemy);
	enemy->shootCooldown = 20;
      }

      if(enemy->shootCooldown > 0)
      {
	enemy->shootCooldown--;
      }

      if(enemy->myCollider->position.x >= 320)
      {
        enemy->speed = -enemy->speed;
      }
      else if(enemy->myCollider->position.x <= 20)
      {
	enemy->speed = -enemy->speed;
      }

    break;

    // Enemy that goes into player and shoots at him
    case 3:
      
      if(enemy->shootCooldown <= 0)
      {
	enemy->shootCooldown = 100;
      }
      if(enemy->shootCooldown > 0)
      {
        Vector2 Velocity;
	Velocity.x = 0; Velocity.y = 0;
	TargetVelocity(&player.myCollider->position, &enemy->myCollider->position, &Velocity, enemy->speed);
	enemy->myCollider->position.x += Velocity.x;
	enemy->myCollider->position.y += Velocity.y;
	enemy->shootCooldown--;
      }

      if(CheckCollision(player.myCollider, enemy->myCollider))
      {
        enemy->health = 0;
      }
      

      if(enemy->health == 0)
      {
        EnemyShootPatternCircle(enemy);
      }
      
    break;
  }




}


U0 DrawEnemies(CDC *dc)
{
  Enemy *temp = Enemies.next;
  while(temp != &Enemies)
  {

    if(temp->type == 1)
    {
      if(temp->shooting)
      {
        GrBlot(dc, 
        temp->myCollider->position.x,
        temp->myCollider->position.y,
        enemyT1Sprite_Shoot);
      }else{
        GrBlot(dc, 
        temp->myCollider->position.x,
        temp->myCollider->position.y,
        enemyT1Sprite);
      }
    }
    EnemyLogic(temp, dc);
    if(temp->health == 0)
    {
      player.Score += 100;
      RemoveEnemy(temp);
    }
    else if(temp->myCollider->position.y > 480)
    {
      RemoveEnemy(temp);
    }
    temp = temp->next;
  }
}


U0 ShootPBullet()
{
  pBullet *new = CAlloc(sizeof(pBullet));
  new->myCollider = NewCollider(
    player.myCollider->position.x + 4,
    player.myCollider->position.y,
    5, 5, BULLET_COL
  );
  QueIns(new, pBullets.last);
}

U0 RemovepBullet(pBullet *bullet)
{
  QueRem(bullet->myCollider);
  Free(bullet->myCollider);
  QueRem(bullet);
  Free(bullet);
}

U0 pBulletLogic(pBullet *bullet) 
{
  bullet->myCollider->position.y -= 10;

  if(bullet->myCollider->position.y < -10)
  {
    RemovepBullet(bullet);
    return;
  }

  Enemy *temp = Enemies.next;
  while(temp != &Enemies)
  {
    if(CheckCollision(bullet->myCollider, temp->myCollider))
    {
      RemovepBullet(bullet);
      temp->health--;
      return;
    }
    temp = temp->next;
  }


}


U0 DrawBullets(CDC *dc)
{
  dc->color = YELLOW;

  pBullet *temp1 = pBullets.next;
  while(temp1 != &pBullets)
  {
    pBullet *next = temp1->next;

    GrRect(dc,
      temp1->myCollider->position.x,
      temp1->myCollider->position.y,
      temp1->myCollider->size.x,
      temp1->myCollider->size.y);

    pBulletLogic(temp1);
    temp1 = next;
  }

}


U0 DrawEBullets(CDC *dc)
{
  eBullet *temp = eBullets.next;
  while(temp != &eBullets)
  {
    eBullet *next = temp->next;

    EBulletLogic(temp);

    temp = next;
  }
}

I64 shootTimer = 0;

I64 enemySpawnTimer = 0;
I64 curWaveId = 0;
I64 nextWaveTimer = 150;

U0 LoadWave(I16 id) 
{
  switch(id)
  {
    case 1: SetWave(&wave1); break;
    case 2: SetWave(&wave2); break;

  }
  enemySpawnTimer = 0;
 
}

U0 WaveLoop()
{

  amountOfEnemies = QueCnt(&Enemies);

  amountOfEBullets = QueCnt(&eBullets);

  if(amountOfEnemies == 0 && amountOfEBullets == 0 && nextWaveTimer > 0) {
    nextWaveTimer--;
  }

  if(nextWaveTimer <= 0) {
    nextWaveTimer = 150;
    curWaveId++;
    LoadWave(curWaveId);
  }
  

  if(enemySpawnTimer <= 0)
  {

    if(currentWave->T1Enemies > 0)
    {
      MakeEnemy(RandU64Range(20, 280), -24, 1);
      currentWave->T1Enemies--;
    }


    if(currentWave->T2Enemies > 0)
    {
      MakeEnemy(160, -24, 2);
      currentWave->T2Enemies--;
    }

    if(currentWave->T3Enemies > 0)
    {
      MakeEnemy(RandU64Range(20, 280), -24, 3);
      currentWave->T3Enemies--;
    }
       
    enemySpawnTimer = currentWave->SpawnDelay;
  }
  else
  {
    enemySpawnTimer--;
  }
}

U0 PlayerMovement()
{
  
  if(keys.actionA)
  {
    slowMode = !slowMode;
    keys.actionA = FALSE;  
  }

  if(keys.actionB && shootTimer == 0)
  {
    ShootPBullet;
    shootTimer = 6;
  }

  if(slowMode)
  {
    player.speed = 2.5;
  }else{
    player.speed = 5;
  }

  if(keys.up && player.myCollider->position.y > 0)
  {
    player.myCollider->position.y -= player.speed;
  }

  if(keys.down && player.myCollider->position.y < 458)
  {
    player.myCollider->position.y += player.speed;
  }

  if(keys.left && player.myCollider->position.x > 10)
  {
    player.myCollider->position.x -= player.speed;
  }

  if(keys.right && player.myCollider->position.x < 320)
  {
    player.myCollider->position.x += player.speed;
  }

}


I64 playerSpriteTimer = 8;
Bool player_IsFlashing = FALSE;

U0 DrawPlayer(CDC *dc)
{
  if(!player.immune)
  {
    GrBlot(dc,
      player.myCollider->position.x - 2,
      player.myCollider->position.y - 4,
      plrSprite);
  }
  else
  {
    if(playerSpriteTimer > 0)
    {
      playerSpriteTimer--;
    }
    if(playerSpriteTimer <= 0)
    {
      playerSpriteTimer = 8;
      player_IsFlashing = !player_IsFlashing;
    }

    if(player_IsFlashing)
    {
    GrBlot(dc,
      player.myCollider->position.x - 2,
      player.myCollider->position.y - 4,
      plrSprite);
    }

  }

  if(immunityTimer <= 0)
  {
    player.immune = FALSE;
  }
  

  if(immunityTimer > 0 && player.immune)
  {
    immunityTimer--; 
  }
}


I8 MenuItem = 1;
I8 OptionsItem = 1;

Bool in_menu_options = FALSE;

U0 MainMenuLogic()
{
  if(keys.actionB)
  {
    switch(MenuItem)
    {
      case 1: in_menu = FALSE; break;
      case 2: in_menu_options = TRUE; break;
      case 3: gaming = FALSE; break;
    }
    keys.actionB = FALSE;
  }
}


U0 DrawMainMenu(CDC *dc)
{
 
  dc->color = WHITE;

  if(MenuItem < 1)
  {
    MenuItem = 1;
  }

  if(MenuItem > 3)
  {
    MenuItem = 3;
  }

  I8 MenuPos = 200;
  switch(MenuItem)
  {
    case 1: MenuPos = 200; break;
    case 2: MenuPos = 212; break;
    case 3: MenuPos = 224; break;
  }

  if(keys.up)
  {
    if(!in_menu_options){
      MenuItem--;
    }else{
      OptionsItem--;
    }
    keys.up = FALSE;
  }

  if(keys.down)
  {
    if(!in_menu_options){
      MenuItem++;
    }else{
      OptionsItem++;
    }
    keys.down = FALSE;
  }
  if(!in_menu_options)
  {
    GrBlot(dc, 50, 100, menuLogo);
    GrPrint(dc, 410, MenuPos, ">");
    GrPrint(dc, 450, 200, "Play");
    GrPrint(dc, 438, 212, "Options");
    GrPrint(dc, 450, 224, "Exit");
  }
  MainMenuLogic;
}


U0 DrawIt(CTask *task, CDC *dc)
{
  DCFill(dc, BLACK);
  if(in_menu)
  {
    DrawMainMenu(dc);
  }
  if(!in_menu)
  {
    dc->color = DKGRAY;
    GrRect(dc, 344, 0, 298, 480);
    PlayerMovement;
 
    WaveLoop;
    dc->color = WHITE;
    GrPrint(dc, 0, 0, "Enemies: %d\nBullets: %d",immunityTimer,amountOfEBullets);
  
    DrawColliders(dc);


    // Drawing the player sprite and the immunity logic
    DrawPlayer(dc);
  
    DrawEnemies(dc);
    DrawBullets(dc);
    DrawEBullets(dc);

    GrPrint(dc, 352, 10, "Score: %d",player.Score);
    GrPrint(dc, 352, 20, "Lives: %d",player.lives);
    if(shootTimer > 0) {
     shootTimer--;
    }
  }
}

U0 Init()
{
  player.Score = 0;
  player.lives = 3;
  player.immune = FALSE;
  keys.up = FALSE;
  keys.down = FALSE;
  keys.left = FALSE;
  keys.right = FALSE;
  keys.actionA = FALSE;
  keys.actionB = FALSE;
  keys.actionC = FALSE;
}

U0 Main()
{
  Init;
  SettingsPush;
  WinMax;
  WinBorder;
  DocClear;
  DocCursor;
  AutoComplete;

 
  I64 arg1,arg2;

  Fs->draw_it = &DrawIt;


  
  try{
    while(gaming) {
      switch(GetMsg(&arg1, &arg2, 1<<MSG_KEY_DOWN+1<<MSG_KEY_UP))
      {
        case MSG_KEY_DOWN:
	  switch(arg1) {
            case CH_SHIFT_ESC: gaming = FALSE; break;
	    case 'w': keys.up = TRUE; break;
	    case 's': keys.down = TRUE; break;
	    case 'a': keys.left = TRUE; break;
	    case 'd': keys.right = TRUE; break;
	    case 'e': keys.actionC = TRUE; break;
            case 'q': keys.actionA = TRUE; break;
	    case CH_SPACE: keys.actionB = TRUE; break;
            case 0:
            //switch(arg2.u8[0]) {
            // }
	    break;
          }
	break;

	case MSG_KEY_UP:
	  switch(arg1) {
	    case 'w': keys.up = FALSE; break;
	    case 's': keys.down = FALSE; break;
	    case 'a': keys.left = FALSE; break;
	    case 'd': keys.right = FALSE; break;
	    case 'q': keys.actionA = FALSE; break;
	    case CH_SPACE: keys.actionB = FALSE; break;
	  }
	break; 
      }
    }
  }catch{
    SettingsPop;
    DocClear;
    PutExcept;
  }

  SettingsPop;
  PutExcept;
  DocClear;

}

Main;