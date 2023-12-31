

namespace Commander
{
	bool isHoldingBlocks( CBlob@ this )
	{
	   	CBlob@[]@ blob_blocks;
	    this.get( "blocks", @blob_blocks );
	    return false;
	}
	
	bool wasHoldingBlocks( CBlob@ this )
	{
		return getGameTime() - this.get_u32( "placedTime" ) < 10;
	}
	
	void clearHeldBlocks( CBlob@ this )
	{
		CBlob@[]@ blocks;
		if (this.get( "blocks", @blocks ))                 
		{
			for (uint i = 0; i < blocks.length; ++i)
			{
				blocks[i].Tag( "disabled" );
				blocks[i].server_Die();
			}

			blocks.clear();
		}
	}
}


void BuildShopMenu( CBlob@ this,  string description, Vec2f offset )
{
	CRules@ rules = getRules();
	Block::Costs@ c = Block::getCosts( rules );
	Block::Weights@ w = Block::getWeights( rules );
	
	if ( c is null || w is null )
		return;
		
	CGridMenu@ menu = CreateGridMenu( this.getScreenPos() + offset, this, BUILD_MENU_SIZE, description );
	u32 gameTime = getGameTime();
	string repBuyTip = "\nPress the inventory key to buy again.\n";
	u16 WARMUP_TIME = getPlayersCount() > 1 && !rules.get_bool("freebuild") ? rules.get_u16( "warmup_time" ) : 0;
	string warmupText = "Weapons are enabled after the warm-up time ends.\n";
	
	if ( menu !is null ) 
	{
		menu.deleteAfterClick = true;
		
		u16 netID = this.getNetworkID();
		string lastBuy = this.get_string( "last buy" );

		CBitStream params;
		params.write_u16( netID );
		
		{
			params.write_string( "hull1" );
				
			CGridButton@ button = menu.AddButton( "$HULL1$", "Weak Light Hull $" + c.solid, this.getCommandID("buyBlock"), params );
	
			bool select = lastBuy == "hull1";
			if ( select )
				button.SetSelected(2);
				
			button.SetHoverText( "A very tough block for protecting delicate components. Can effectively negate damage from bullets, flak, and to some extent cannons. \nWeight: " + w.solid * 100 + "rkt\n" + ( select ? repBuyTip : "" ) );
		}
		{
			params.write_string( "hull2" );
				
			CGridButton@ button = menu.AddButton( "$HULL2$", "Strong Heavy Hull $" + c.solid, this.getCommandID("buyBlock"), params );
	
			bool select = lastBuy == "hull2";
			if ( select )
				button.SetSelected(2);
				
			button.SetHoverText( "A very tough block for protecting delicate components. Can effectively negate damage from bullets, flak, and to some extent cannons. \nWeight: " + w.solid * 100 + "rkt\n" + ( select ? repBuyTip : "" ) );
		}

		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "thruster1" );
				
			CGridButton@ button = menu.AddButton( "$THRUSTER1$", "Weak Thruster Engine $" + c.thruster1, this.getCommandID("buyBlock"), params );
	
			bool select = lastBuy == "thruster1";
			if ( select )
				button.SetSelected(2);
				
			button.SetHoverText( "A ship motor with some armor plating for protection. Resists flak.\nWeight: " + w.thruster1*5 + " tons\n" + ( select ? repBuyTip : "" ) );
		}


		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "machinegun" );
				
			CGridButton@ button = menu.AddButton( "$MACHINEGUN$", "Machinegun $" + c.machinegun, this.getCommandID("buyBlock"), params );
		
			bool select = lastBuy == "machinegun";
			if ( select )
				button.SetSelected(2);
				
			if ( gameTime > WARMUP_TIME )
				button.SetHoverText( "A fixed rapid-fire, lightweight, machinegun that fires high-velocity projectiles uncounterable by point defense. Effective against engines, flak cannons, and other weapons. \nWeight: " + w.machinegun * 100 + "rkt \nAmmoCap: high\n" + ( select ? repBuyTip : "" ) );
			else
			{
				button.SetHoverText( warmupText );
				button.SetEnabled( false );
			}
		}

		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "cannon" );
				
			CGridButton@ button = menu.AddButton( "$CANNON$", "Zilla Cannon $" + c.cannon, this.getCommandID("buyBlock"), params );
	
			bool select = lastBuy == "cannon";
			if ( select )
				button.SetSelected(2);
				
			if ( gameTime > WARMUP_TIME )
				button.SetHoverText( "A high powered laser cannon for cutting ships in half.\nWeight: " + w.cannon * 100 + "rkt \nAmmoCap: medium\n" + ( select ? repBuyTip : "" ) );
			else
			{
				button.SetHoverText( warmupText );
				button.SetEnabled( false );
			}
		}


		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "shieldgen" );
				
			CGridButton@ button = menu.AddButton( "$SHIELDGEN$", "Sheild Generator $" + c.cannon, this.getCommandID("buyBlock"), params );
	
			bool select = lastBuy == "shieldgen";
			if ( select )
				button.SetSelected(2);
				
			if ( gameTime > WARMUP_TIME )
				button.SetHoverText( "Protection from projectiles.\nWeight: " + w.cannon * 100 + "rkt \nAmmoCap: medium\n" + ( select ? repBuyTip : "" ) );
			else
			{
				button.SetHoverText( warmupText );
				button.SetEnabled( false );
			}
		}

	}
}


void BuyBlock( CBlob@ this, CBlob@ caller, string btype )
{
	CRules@ rules = getRules();
	Block::Costs@ c = Block::getCosts( rules );
	
	if ( c is null )
	{
		warn( "** Couldn't get Costs!" );
		return;
	}

	u8 teamNum = this.getTeamNum();
	u32 gameTime = getGameTime();
	CPlayer@ player = caller.getPlayer();
	string pName = player !is null ? player.getUsername() : "";
	int pBooty = player.getCoins();
	bool weapon = btype == "cannon" || btype == "machinegun" || btype == "flak" || btype == "pointDefense" || btype == "launcher" || btype == "bomb";
	
	u16 cost = -1;
	u8 ammount = 1;
	u8 totalFlaks = 0;
	u8 teamFlaks = 0;
	
	bool coolDown = false;

	Block::Type type;
	if ( btype == "wood" )
	{
		type = Block::A_HULL;
		cost = c.wood;
	}
	else if ( btype == "solid" )
	{
		type = Block::B_HULL;
		cost = c.solid;
	}
	else if ( btype == "thruster1" )
	{
		type = Block::THRUSTER1;
		cost = c.thruster1;
	}
	else if ( btype == "machinegun" )
	{
		type = Block::MACHINEGUN;
		cost = c.machinegun;
	}
	else if ( btype == "cannon" )
	{
		type = Block::CANNON;
		cost = c.cannon;
	}

	else if ( btype == "shieldgen" )
	{
		type = Block::SHIELDGEN;
		cost = c.cannon;
	}

	player.server_setCoins( pBooty - cost );
	ProduceBlock( getRules(), caller, type, ammount );
}

void ReturnBlocks( CBlob@ this, CBlob@ caller )
{
	CRules@ rules = getRules();
	CBlob@[]@ blocks;
	if (caller.get( "blocks", @blocks ) && blocks.size() > 0)                 
	{
		if ( getNet().isServer() )
		{
			CPlayer@ player = caller.getPlayer();
			if ( player !is null )
			{
				string pName = player.getUsername();
				u16 pBooty = player.getCoins();
				u16 returnBooty = 0;
				for (uint i = 0; i < blocks.length; ++i)
				{
					int type = Block::getType( blocks[i] );
					if ( type != Block::COUPLING && blocks[i].getShape().getVars().customData == -1 )
						returnBooty += Block::getCost( type );
				}
				
				if ( returnBooty > 0 && !(getPlayersCount() == 1 || rules.get_bool("freebuild")))
					player.server_setCoins( pBooty + returnBooty );
			}
		}
		
		this.getSprite().PlaySound("join.ogg");
		Commander::clearHeldBlocks( caller );
		caller.set_bool( "blockPlacementWarn", false );
	} else
		warn("returnBlocks cmd: no blocks");
}