//#include "WaterEffects.as"
#include "BlockCommon.as"
#include "ShipsCommon.as"
#include "AccurateSoundPlay.as"
 
const f32 BULLET_SPREAD = 2.5f;
const f32 BULLET_RANGE = 275.0F;
const f32 MIN_FIRE_PAUSE = 2.75f; //min wait between shots
const f32 MAX_FIRE_PAUSE = 8.0f; //max wait between shots
const f32 FIRE_PAUSE_RATE = 0.08f; //higher values = higher recover
const u8 REFILL_AMMOUNT = 30; //every second
const u8 MAX_AMMO = 250; //maximum carryable ammunition

Random _shotspreadrandom(0x11598); //clientside

void onInit( CBlob@ this )
{
	this.getCurrentScript().tickFrequency = 2;

	this.Tag("weapon");
	this.Tag("machinegun");
	this.Tag("usesAmmo");
	this.Tag("fixed_gun");
	this.addCommandID("fire");
	this.addCommandID("disable");
	this.set_string("barrel", "left");
	
	if ( getNet().isServer() )
	{
		this.set_u16( "ammo", MAX_AMMO );
		this.set_u16( "maxAmmo", MAX_AMMO );
		this.set_f32("fire pause",MIN_FIRE_PAUSE);
		this.set_bool( "mShipDocked", false );
		
		this.Sync("fire pause", true );
		this.Sync("ammo", true );
		this.Sync("maxAmmo", true );
	}
   
	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer( "weapon", 16, 16 );
    if (layer !is null)
    {
        layer.SetRelativeZ(2);
        layer.SetLighting( false );
        Animation@ anim = layer.addAnimation( "fire left", Maths::Round( MIN_FIRE_PAUSE ), false );
        anim.AddFrame(Block::MACHINEGUN2);
        anim.AddFrame(Block::MACHINEGUN);
               
		Animation@ anim2 = layer.addAnimation( "fire right", Maths::Round( MIN_FIRE_PAUSE ), false );
        anim2.AddFrame(Block::MACHINEGUN3);
        anim2.AddFrame(Block::MACHINEGUN);
               
		Animation@ anim3 = layer.addAnimation( "default", 1, false );
		anim3.AddFrame(Block::MACHINEGUN);
        layer.SetAnimation("default");  
    }
 
	this.set_u32("fire time", 0);
}
 
void onTick( CBlob@ this )
{
	if ( this.getShape().getVars().customData <= 0 )//not placed yet
		return;
		
	u32 gameTime = getGameTime();
	f32 currentFirePause = this.get_f32("fire pause");
	if ( currentFirePause > MIN_FIRE_PAUSE )
		this.set_f32( "fire pause", currentFirePause - FIRE_PAUSE_RATE * this.getCurrentScript().tickFrequency );
  
	//print( "Fire pause: " + currentFirePause );
	
	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ laser = sprite.getSpriteLayer( "laser" );
	
	//kill laser after a certain time
	if ( laser !is null && this.get_u32("fire time") + 2.5f < gameTime )
		sprite.RemoveSpriteLayer("laser");
	
	//ammo reload and don't shoot if docked on mothership
	if ( getNet().isServer() && ( gameTime + this.getNetworkID() * 33 ) % 15 == 0 )//every 1 sec
	{	
		Ship@ ship = getShip( this.getShape().getVars().customData );
		if ( ship !is null )
		{
			u16 ammo = this.get_u16( "ammo" );

			//if ( ship.isMothership )
			{
				//reload ammo
				//if ( ammo < MAX_AMMO )
				{
					this.Sync( "ammo", true );//workaround for sync policy
					ammo = Maths::Min( MAX_AMMO, ammo + REFILL_AMMOUNT );
					this.set_u16( "ammo", ammo );
					this.Sync( "ammo", true );
				}
				
				//don't shoot if docked on mothership
				//CBlob@ core = getMothership( this.getTeamNum() );
				//if ( core !is null )
				//	this.set_bool( "mShipDocked", !coreLinkedDirectional( this, gameTime, core.getPosition() ) ); //very buggy
				this.set_bool( "mShipDocked", false );
			} 
			//else
			//	this.set_bool( "mShipDocked", false );
			//	
			//if ( ammo == 0 )
			//{
			//	this.set_u16( "ammo", ammo );
			//	this.Sync( "ammo", true );
			//}
		}
	}
	
	//reset the random seed periodically so joining clients see the same bullet paths
	if ( gameTime % 450 == 0 )
		_shotspreadrandom.Reset( gameTime );
}
 
bool canShoot( CBlob@ this )
{
	return ( this.get_u32("fire time") + this.get_f32("fire pause") < getGameTime() );
}

bool canIncreaseFirePause( CBlob@ this )
{
	return ( MIN_FIRE_PAUSE < getGameTime() );
}
 
void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("fire"))
    {
		if ( !canShoot(this) )
			return;
			
		u16 shooterID;
		if ( !params.saferead_u16(shooterID) )
			return;
		
		CBlob@ shooter = getBlobByNetworkID( shooterID );
		if (shooter is null)
			return;

		Vec2f shipvel; 
		if ( !params.saferead_Vec2f( shipvel ))
			return;

		bool isServer = getNet().isServer();
		Vec2f pos = this.getPosition();
		
		Ship@ island = getShip( this.getShape().getVars().customData );
		if ( island is null )
			return;

		if ( canIncreaseFirePause(this) )    
		{
			f32 currentFirePause = this.get_f32("fire pause");
			if ( currentFirePause < MAX_FIRE_PAUSE )
				this.set_f32( "fire pause", currentFirePause + Maths::Sqrt( currentFirePause * FIRE_PAUSE_RATE ) );
		}

		this.set_u32("fire time", getGameTime());
		
		//ammo
		u16 ammo = this.get_u16( "ammo" );
		
		//if ( ammo == 0 )
		//{
		//	directionalSoundPlay( "LoadingTick1", pos, 0.5f );
		//	return;
		//}
		
		//ammo--;
		//this.set_u16( "ammo", ammo );
			
		//effects
		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ layer = sprite.getSpriteLayer( "weapon" );
		layer.SetAnimation( "default" );
	   
		Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());
		   
		Vec2f barrelOffset;
		Vec2f barrelOffsetRelative;
		if (this.get_string("barrel") == "left")
		{
			barrelOffsetRelative = Vec2f(0, -2.0);
			barrelOffset = Vec2f(0, -2.0).RotateBy(-aimVector.Angle());
			this.set_string("barrel", "right");
		}
		else
		{
			barrelOffsetRelative = Vec2f(0, 2.0);
			barrelOffset = Vec2f(0, 2.0).RotateBy(-aimVector.Angle());
			this.set_string("barrel", "left");
		}
			
		Vec2f barrelPos = this.getPosition() + aimVector*9 + barrelOffset;

		//hit stuff
		u8 teamNum = shooter.getTeamNum();//teamNum of the player firing
		HitInfo@[] hitInfos;
		CMap@ map = this.getMap();
		bool killed = false;
		bool blocked = false;
		
		f32 offsetAngle = ( _shotspreadrandom.NextFloat() - 0.5f ) * BULLET_SPREAD * 2.0f;
		aimVector.RotateBy(offsetAngle);
		
		f32 rangeOffset = ( _shotspreadrandom.NextFloat() - 0.5f ) * BULLET_SPREAD * 8.0f;
			
		if( map.getHitInfosFromRay( barrelPos, -aimVector.Angle(), BULLET_RANGE + rangeOffset, this, @hitInfos ) )
			for (uint i = 0; i < hitInfos.length; i++)
			{
				HitInfo@ hi = hitInfos[i];
				CBlob@ b = hi.blob;	  
				u16 tileType = hi.tile;
				
				if( b is null || b is this ) continue;

				const int thisColor = this.getShape().getVars().customData;
				int bColor = b.getShape().getVars().customData;
				bool sameShip = bColor != 0 && thisColor == bColor;
				
				const int blockType = b.getSprite().getFrame();
				const bool isBlock = b.getName() == "block";

				if ( !b.hasTag( "booty" ) && (bColor > 0 || !isBlock) )
				{
					if ( isBlock || b.hasTag("rocket") )
					{
						if ( Block::isSolid(blockType) || ( b.getTeamNum() != teamNum && ( b.hasTag("weapon") || b.hasTag("rocket") ) ) )//hit these and die
							killed = true;
						else if ( sameShip && b.hasTag("weapon") && (b.getTeamNum() == teamNum) ) //team weaps
						{
							killed = true;
							blocked = true;
							directionalSoundPlay( "lightup", barrelPos );
							break;
						}
						else
						{
							continue;
						}
					}
					else
					{
						if ( b.getTeamNum() == teamNum || ( b.hasTag("player") && b.isAttached() ) )
							continue;
					}
					
					if ( getNet().isClient() )//effects
					{
						sprite.RemoveSpriteLayer("laser");
						CSpriteLayer@ laser = sprite.addSpriteLayer("laser", "Beam1.png", 8, 8);
						if (laser !is null)//partial length laser
						{
							Animation@ anim = laser.addAnimation( "default", 1, false );
							int[] frames = { 0, 1, 2, 3, 4, 5 };
							anim.AddFrames(frames);
							laser.SetVisible(true);
							f32 laserLength = Maths::Max(0.1f, (hi.hitpos - barrelPos).getLength() / 8.0f);						
							laser.ResetTransform();						
							laser.ScaleBy( Vec2f(laserLength, 1.5f) );							
							laser.TranslateBy( Vec2f(laserLength*4.0f + 4.0f, barrelOffsetRelative.y) );							
							laser.RotateBy( offsetAngle, Vec2f());
							laser.setRenderStyle(RenderStyle::light);
							laser.SetRelativeZ(1);
						}

						hitEffects(b, hi.hitpos);
					}
					
					CPlayer@ attacker = shooter.getPlayer();
					if ( attacker !is null )
						damageBooty( attacker, shooter, b );
						
					if ( isServer )
					{
						f32 damage = getDamage( b, blockType );
						if ( b.hasTag( "propeller" ) && b.getTeamNum() != teamNum && XORRandom(3) == 0 )
							b.SendCommand(b.getCommandID("off"));
						this.server_Hit( b, hi.hitpos, Vec2f_zero, damage, 0, true );
					}
					
					if ( killed ) break;
				}
			}
		
		if ( !blocked )
		{
			shotParticles( barrelPos, shipvel, aimVector.Angle() );
			directionalSoundPlay( "Gunshot" + ( XORRandom(2) + 2 ) + ".ogg", barrelPos );
			if (this.get_string("barrel") == "left")
				layer.SetAnimation( "fire left" );
			if (this.get_string("barrel") == "right")
				layer.SetAnimation( "fire right" );
		}
		
		Vec2f solidPos;
		if ( !killed && map.rayCastSolid(pos, pos + aimVector * (BULLET_RANGE + rangeOffset), solidPos) )
		{
			//print( "hit a rock" );
			if ( getNet().isClient() )//effects
			{
				sprite.RemoveSpriteLayer("laser");
				CSpriteLayer@ laser = sprite.addSpriteLayer("laser", "Beam1.png", 8, 8);
				if (laser !is null)//partial length laser
				{
					Animation@ anim = laser.addAnimation( "default", 1, false );
					int[] frames = { 0, 1, 2, 3, 4, 5 };
					anim.AddFrames(frames);
					laser.SetVisible(true);
					f32 laserLength = Maths::Max(0.1f, (solidPos - barrelPos).getLength() / 8.0f);						
					laser.ResetTransform();						
					laser.ScaleBy( Vec2f(laserLength, 0.5f) );							
					laser.TranslateBy( Vec2f(laserLength*4.0f + 4.0f, barrelOffsetRelative.y) );							
					laser.RotateBy( offsetAngle, Vec2f());
					laser.setRenderStyle(RenderStyle::light);
					laser.SetRelativeZ(1);
				}

				hitEffects(this, solidPos);
			}
		}
	
		else if ( !killed && getNet().isClient() )//full length 'laser'
		{
			sprite.RemoveSpriteLayer("laser");
			CSpriteLayer@ laser = sprite.addSpriteLayer("laser", "Beam1.png", 8, 8);
			if (laser !is null)
			{
				Animation@ anim = laser.addAnimation( "default", 1, false );
				int[] frames = { 0, 1, 2, 3, 4, 5 };
				anim.AddFrames(frames);
				laser.SetVisible(true);
				f32 laserLength = Maths::Max(0.1f, (aimVector * (BULLET_RANGE + rangeOffset)).getLength() / 8.0f);						
				laser.ResetTransform();						
				laser.ScaleBy( Vec2f(laserLength, 0.5f) );							
				laser.TranslateBy( Vec2f(laserLength*4.0f + 4.0f, barrelOffsetRelative.y) );								
				laser.RotateBy( offsetAngle, Vec2f());
				laser.setRenderStyle(RenderStyle::light);
				laser.SetRelativeZ(1);
			}
			
			//MakeWaterParticle( barrelPos + aimVector * (BULLET_RANGE + rangeOffset), Vec2f_zero );
		}
    }
}
 
f32 getDamage( CBlob@ hitBlob, int blockType )
{	
	if ( hitBlob.hasTag( "rocket" ) )
		return 0.4f;

	if ( blockType == Block::THRUSTER1 )
		return 0.1f;
		
	if ( blockType == Block::THRUSTER2 )
		return 0.1f;
	
	if ( hitBlob.hasTag( "weapon" ) )
		return 0.075f;
	
	return 0.01f;//cores, solids
}

void hitEffects( CBlob@ hitBlob, Vec2f worldPoint )
{
	CSprite@ sprite = hitBlob.getSprite();
	const int blockType = sprite.getFrame();
	
	if (hitBlob.getName() == "shark"){
		ParticleBloodSplat( worldPoint, true );
		directionalSoundPlay( "BodyGibFall", worldPoint );
	}
	else	if (hitBlob.hasTag("player") )
	{
		directionalSoundPlay( "ImpactFlesh", worldPoint );
		ParticleBloodSplat( worldPoint, true );
	}
	else	if (Block::isSolid(blockType) || hitBlob.hasTag("weapon") )
	{
		sparks(worldPoint, 4);
		directionalSoundPlay( "Ricochet" +  ( XORRandom(3) + 1 ) + ".ogg", worldPoint, 0.50f );
	}
}
 
void shotParticles(Vec2f pos, Vec2f vel, float angle )
{
	//muzzle flash
	CParticle@ p = ParticleAnimated( "Entities/Block/turret_muzzle_flash.png",
																					  pos, vel,
																					  -angle, //angle
																					  1.0f, //scale
																					  3, //animtime
																					  0.0f, //gravity
																					  true ); //selflit
	if(p !is null)
	{
		p.Z = 10.0f;
	}
}

Random _sprk_r;
void sparks(Vec2f pos, int amount)
{
	for (int i = 0; i < amount; i++)
    {
        Vec2f vel(_sprk_r.NextFloat() * 1.0f, 0);
        vel.RotateBy(_sprk_r.NextFloat() * 360.0f);

        CParticle@ p = ParticlePixel( pos, vel, SColor( 255, 255, 128+_sprk_r.NextRanged(128), _sprk_r.NextRanged(128)), true );
        if(p is null) return; //bail if we stop getting particles

        p.timeout = 10 + _sprk_r.NextRanged(20);
        p.scale = 0.5f + _sprk_r.NextFloat();
        p.damping = 0.95f;
    }
}

void damageBooty( CPlayer@ attacker, CBlob@ attackerBlob, CBlob@ victim )
{
	if ( victim.getName() == "block" )
	{
		const int blockType = victim.getSprite().getFrame();
		u8 teamNum = attacker.getTeamNum();
		u8 victimTeamNum = victim.getTeamNum();
		string attackerName = attacker.getUsername();
		Ship@ victimIsle = getShip( victim.getShape().getVars().customData );
		
		if ( victimIsle !is null && victimIsle.blocks.length > 3
			&& ( victimIsle.owner != "" || victimIsle.isMothership )
			&& victimTeamNum != teamNum
			&& ( victim.hasTag("thruster") || victim.hasTag("weapon") )
			)
		{
			if ( attacker.isMyPlayer() )
			{
				u8 n = XORRandom(4);
				if ( n == 3 )
					Sound::Play( "Pinball_" + XORRandom(4), attackerBlob.getPosition(), 0.5f );
				else
					Sound::Play( "Pinball_" + n, attackerBlob.getPosition(), 0.5f );					
			}

			if ( getNet().isServer() )
			{
				CRules@ rules = getRules();
			
				u16 reward = 3;//thrusters
				if ( victim.hasTag( "weapon" ) )
					reward += 2;
								
				f32 bFactor = ( rules.get_bool( "whirlpool" ) ? 3.0f : 1.0f ) * Maths::Min( 2.5f, Maths::Max( 0.15f,
				( 2.0f * rules.get_u16( "bootyTeam_total" + victimTeamNum ) - rules.get_u16( "bootyTeam_total" + teamNum ) + 1000 )/( rules.get_u32( "bootyTeam_median" ) + 1000 ) ) );
				
				reward = Maths::Round( reward * bFactor );
				
				//server_setPlayerBooty( attackerName, server_getPlayerBooty( attackerName ) + reward );
				//server_updateTotalBooty( teamNum, reward );
			}
		}
	}
}