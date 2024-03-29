#include "BlockCommon.as"
#include "ShipsCommon.as"
#include "AccurateSoundPlay.as"
 
const f32 PROJECTILE_RANGE = 375.0F;
const f32 PROJECTILE_SPEED = 15.0f;;
const u16 FIRE_RATE = 170;//max wait between shots
const u8 REFILL_AMMOUNT = 3;//every second
const u8 MAX_AMMO = 15; //maximum carryable ammunition

Random _shotrandom(0x15125); //clientside

void onInit( CBlob@ this )
{
	this.Tag("weapon");
	this.Tag("cannon");
	this.Tag("usesAmmo");
	this.Tag("fixed_gun");
	this.addCommandID("fire");
	
	if ( getNet().isServer() )
	{	
		this.set_u16( "ammo", MAX_AMMO );
		this.set_u16( "maxAmmo", MAX_AMMO );
		
		this.Sync("ammo", true );
		this.Sync("maxAmmo", true );

		this.set_bool( "mShipDocked", false );
		this.set_bool( "fireReady", true );
	}
   
	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer( "weapon", 16, 16 );
    if (layer !is null)
    {
    	layer.SetRelativeZ(2);
    	layer.SetLighting( false );
     	Animation@ anim = layer.addAnimation( "fire", 0, false );
        anim.AddFrame(Block::CANNON);
        anim.AddFrame(Block::CANNON2);
        layer.SetAnimation("fire");
    }

	CSpriteLayer@ laser = sprite.addSpriteLayer("laser", "Beam1.png", 8, 8);
	if (laser !is null)//partial length laser
	{
		Animation@ anim = laser.addAnimation( "default", 1, true );
		int[] frames = { 0, 1, 2, 3, 4, 5 };
		anim.AddFrames(frames);
		laser.SetVisible(false);					
		laser.ScaleBy( Vec2f(16, 3.0f) );	
		laser.SetOffset(Vec2f(-62,0));			
		laser.setRenderStyle(RenderStyle::light);
		laser.SetRelativeZ(1);
	}
 
	this.set_u32("fire time", 0);
}

void onTick( CBlob@ this )
{
	if (this.getShape().getVars().customData <= 0)
		return;
	
	u32 gameTime = getGameTime();
	
	//fire ready
	u32 fireTime = this.get_u32("fire time");
	this.set_bool( "fire ready", ( gameTime > fireTime + FIRE_RATE ) );
	//sprite ready
	if ( fireTime + FIRE_RATE - 15 == gameTime )
	{
		CSpriteLayer@ layer = this.getSprite().getSpriteLayer( "weapon" );
		if ( layer !is null )
			layer.animation.SetFrameIndex(0);	
	}
	
	//ammo reload when docked
	if ( getNet().isServer() && ( gameTime + this.getNetworkID() * 33 ) % 30 == 0 )//every 1 sec
	{
		Ship@ ship = getShip( this.getShape().getVars().customData );
		if ( ship !is null )
		{
			u16 ammo = this.get_u16( "ammo" );			

			if ( ship.isMothership )
			{
				//reload ammo
				if ( ammo < MAX_AMMO )
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
			else
				this.set_bool( "mShipDocked", false );

			
			if ( ammo == 0 )
			{
				this.set_u16( "ammo", ammo );
				this.Sync( "ammo", true );
			}
		}
	}
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("fire"))
    {
		if ( !this.get_bool( "fire ready" ) )
			return;
			
		bool isServer = getNet().isServer();
		Vec2f pos = this.getPosition();
		
		this.set_u32( "fire time",	 getGameTime() );
		
		if ( !isClear( this ) )
		{
			directionalSoundPlay( "lightup", pos );
			return;
		}
		
		//ammo
		u16 ammo = this.get_u16( "ammo" );
		
		if ( ammo == 0 )
		{
			directionalSoundPlay( "LoadingTick1", pos, 1.0f );
			return;
		}
		
		ammo--;
		this.set_u16( "ammo", ammo );
		
		u16 shooterID;
		if ( !params.saferead_u16(shooterID) )
			return;
		
		CBlob@ shooter = getBlobByNetworkID( shooterID );
		if (shooter is null)
			return;

		Fire( this, shooter );
	
		CSpriteLayer@ layer = this.getSprite().getSpriteLayer( "weapon" );
		if ( layer !is null )
			layer.animation.SetFrameIndex(1);
    }
}

void Fire( CBlob@ this, CBlob@ shooter )
{
	Vec2f pos = this.getPosition();
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());

	if ( getNet().isServer() )
	{
		f32 variation = 0.9f + _shotrandom.NextFloat()/5.0f;
		f32 _lifetime = 0.05f + variation*PROJECTILE_RANGE/PROJECTILE_SPEED/32.0f;

		CBlob@ cannonball = server_CreateBlob( "cannonball", this.getTeamNum(), pos + aimVector*4 );
		if ( cannonball !is null )
		{
			Vec2f vel = aimVector * PROJECTILE_SPEED;
			
			Ship@ ship = getShip( this.getShape().getVars().customData );
			if ( ship !is null )
			{
				vel += ship.vel;
				
				if ( shooter !is null )
				{
					CPlayer@ attacker = shooter.getPlayer();
					if ( attacker !is null )
						cannonball.SetDamageOwnerPlayer( attacker );
				}

				cannonball.setVelocity( vel );
				cannonball.server_SetTimeToDie( _lifetime );
			}
		}
		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ laser = sprite.getSpriteLayer("laser");
		if (laser !is null)
		{
			laser.SetVisible(true);
		}
	}
	
	CSpriteLayer@ layer = this.getSprite().getSpriteLayer( "weapon" );
	if ( layer !is null )
		layer.animation.SetFrameIndex(0);

	shotParticles(pos + aimVector*9, aimVector.Angle());
	
	directionalSoundPlay( "Zillaser2.ogg", pos, 7.0f );
		
	this.set_bool( "firing", false );
}

bool isClear( CBlob@ this )
{
	Vec2f pos = this.getPosition();
	Vec2f aimVector = Vec2f(1, 0).RotateBy(this.getAngleDegrees());
	u8 teamNum = this.getTeamNum();
	bool clear = true;
	
	HitInfo@[] hitInfos;
	if( getMap().getHitInfosFromRay( pos, -aimVector.Angle(), PROJECTILE_RANGE/4, this, @hitInfos ) )
		for ( uint i = 0; i < hitInfos.length; i++ )
		{
			CBlob@ b =  hitInfos[i].blob;	  
			if( b is null || b is this ) continue;

			if ( b.hasTag("weapon") && b.getTeamNum() == teamNum )//team weaps
			{
				clear = false;
				break;
			}
		}
		
	return clear;
}

void shotParticles(Vec2f pos, float angle)
{
	//muzzle flash
	{
		CParticle@ p = ParticleAnimated( "Entities/Block/turret_muzzle_flash.png",
												  pos, Vec2f(),
												  -angle, //angle
												  1.0f, //scale
												  3, //animtime
												  0.0f, //gravity
												  true ); //selflit
		if(p !is null)
			p.Z = 10.0f;
	}

	Vec2f shot_vel = Vec2f(0.5f,0);
	shot_vel.RotateBy(-angle);

	//smoke
	for(int i = 0; i < 5; i++)
	{
		//random velocity direction
		Vec2f vel(0.1f + _shotrandom.NextFloat()*0.2f, 0);
		vel.RotateBy(_shotrandom.NextFloat() * 360.0f);
		vel += shot_vel * i;

		CParticle@ p = ParticleAnimated( "Entities/Block/turret_smoke.png",
												  pos, vel,
												  _shotrandom.NextFloat() * 360.0f, //angle
												  1.0f, //scale
												  3+_shotrandom.NextRanged(4), //animtime
												  0.0f, //gravity
												  true ); //selflit
		if(p !is null)
			p.Z = 550.0f;
	}
}