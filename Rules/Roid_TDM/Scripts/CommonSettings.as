#include "BlockCommon.as"
const int BUTTON_SIZE = 4;

void onInit( CRules@ this )
{
	RegisterFileExtensionScript( "WaterPNGMap.as", "png" );
    particles_gravity.y = 0.0f; 
    sv_gravity = 0;    
    v_camera_ints = false;
    sv_visiblity_scale = 2.0f;
	cc_halign = 2;
	cc_valign = 2;
	s_effects = false;
		//smooth shader
	Driver@ driver = getDriver();

	driver.AddShader("hq2x", 1.0f);
	driver.SetShader("hq2x", true);

	
	//gameplay settings (could be a cfg file)
	this.set_u16( "starting_booty", 325 );
	this.set_u16( "warmup_time", 1 * 60 * 30 );//no weapons warmup time
	this.set_u16( "booty_x_max", 200 );
	this.set_u16( "booty_x_min", 100 );
	this.set_u16( "booty_transfer", 50 );//min transfer ammount
	this.set_f32( "booty_transfer_fee", 0.0f );
	this.set_f32( "build_distance", 16 * 16 );//max distance from the core for purchasing blocks

	//
	
	//Icons
	AddIconToken( "$HULL1$", "Blocks.png", Vec2f(8,8), 0 );
	AddIconToken( "$HULL2$", "Blocks.png", Vec2f(8,8), 4 );
	AddIconToken( "$DOOR$", "Blocks.png", Vec2f(8,8), 12 );
	AddIconToken( "$RAM$", "Blocks.png", Vec2f(8,8), 8 );
	AddIconToken( "$THRUSTER1$", "Blocks.png", Vec2f(8,8), 16 );
	AddIconToken( "$THRUSTER2$", "Blocks.png", Vec2f(8,8), 21 );
	AddIconToken( "$HARVESTER$", "Blocks.png", Vec2f(16,16), 67 );
	AddIconToken( "$HARPOON$", "Blocks.png", Vec2f(16,16), 75 ); 
	AddIconToken( "$MACHINEGUN$", "Blocks.png", Vec2f(16,16),32 );
	AddIconToken( "$CANNON$", "Blocks.png", Vec2f(16,16), 30 );
	AddIconToken( "$FLAK$", "Blocks.png", Vec2f(16,16), 11 );
	AddIconToken( "$POINTDEFENSE$", "Blocks.png", Vec2f(16,16), 59 );
	AddIconToken( "$LAUNCHER$", "Blocks.png", Vec2f(16,16), 51 );
	AddIconToken( "$COUPLING$", "Blocks.png", Vec2f(8,8), 35 );
	AddIconToken( "$REPULSOR$", "Blocks.png", Vec2f(8,8), 28 );
	
	//spectator stuff
	this.addCommandID("pick teams");
    this.addCommandID("pick spectator");
	this.addCommandID("pick none");

    AddIconToken( "$TEAMS$", "GUI/MenuItems.png", Vec2f(32,32), 1 );
    AddIconToken( "$SPECTATOR$", "GUI/MenuItems.png", Vec2f(32,32), 19 );

	//sandbox notice
	if ( getPlayersCount() == 0 )
		client_AddToChat( "> Free building mode set until more players join! <" );
	//warn for black water glitch
	if ( v_postprocess )
	{
		client_AddToChat( ">", SColor( 255, 255, 75, 75 ) );
		client_AddToChat( ">>", SColor( 255, 255, 75, 75 ) );
		client_AddToChat( ">>>", SColor( 255, 255, 75, 75 ) );
		client_AddToChat( "NOTICE: the \"smooth shader\" setting causes the water to turn black when zooming in.\nYou can disable the smooth shader at the Video Options tab.", SColor( 255, 255, 75, 75 ) );
	}
}

void ShowTeamMenu( CRules@ this )
{
	CPlayer@ local = getLocalPlayer();
    if (local is null) 
	{
        return;
    }

    CGridMenu@ menu = CreateGridMenu( getDriver().getScreenCenterPos(), null, Vec2f( BUTTON_SIZE, BUTTON_SIZE), "Change team" );

    if (menu !is null)
    {
		CBitStream exitParams;
		menu.AddKeyCommand( KEY_ESCAPE, this.getCommandID("pick none"), exitParams );
		menu.SetDefaultCommand( this.getCommandID("pick none"), exitParams );


        CBitStream params;
        params.write_u16( local.getNetworkID() );
        if (local.getTeamNum() == this.getSpectatorTeamNum())
        {
			CGridButton@ button = menu.AddButton( "$TEAMS$", "Auto-pick teams", this.getCommandID("pick teams"), Vec2f(BUTTON_SIZE, BUTTON_SIZE), params );
		}
		else
		{
			CGridButton@ button = menu.AddButton( "$SPECTATOR$", "Spectator", this.getCommandID("pick spectator"), Vec2f(BUTTON_SIZE, BUTTON_SIZE), params );
		}
    }
}

void ReadChangeTeam( CRules@ this, CBitStream @params, int team )
{
    CPlayer@ player = getPlayerByNetworkId( params.read_u16() );
    if (player is getLocalPlayer())
    {
        player.client_ChangeTeam( team );
        getHUD().ClearMenus();
    }
}

void onCommand( CRules@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("pick teams"))
    {
        ReadChangeTeam( this, params, -1);
    }
    else if (cmd == this.getCommandID("pick spectator"))
    {
        ReadChangeTeam( this, params, this.getSpectatorTeamNum() );
	} else if (cmd == this.getCommandID("pick none"))
	{
		getHUD().ClearMenus();
	}
}