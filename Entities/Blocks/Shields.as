#include "TeamColour.as"

void onInit(CBlob@ this)
{
	int id = Render::addBlobScript(Render::layer_postworld, this, "Shields.as", "Render");
}

void onTick(CBlob@ this)
{

}

void Render(CBlob@ this, int id)
{
	const float[] model = { 1,0,0,0,
							0,1,0,0,
							0,0,1,0,
							0,0,0,1};
	const float w2 = 32;
	const float h2 = 32;

	SColor teamcol = getTeamColor( this.getTeamNum() );
	const u8 r = teamcol.getRed();
	const u8 g = teamcol.getGreen();
	const u8 b = teamcol.getBlue();

	const Vertex[] Shield_Vertices = 
	{
		Vertex(-w2, -h2,  0, 0, 0, 	SColor(5 ,r,g,b)),
		Vertex( w2, -h2,  0, 1, 0, 	SColor(5 ,r,g,b)),
		Vertex( w2,  h2,  0, 1, 1,  SColor(5 ,r,g,b)),
		Vertex(-w2,  h2,  0, 0, 1,  SColor(5 ,r,g,b))
	};

	const string texture_name = "ShieldRing.png";
	//Vec2f pos = Vec2f_lerp(pos, this.getPosition(), getRenderApproximateCorrectionFactor());
	Vec2f pos = this.getPosition();
	float rot = this.getAngleDegrees();

	Render::SetAlphaBlend(true);
	Matrix::SetRotationDegrees(model, 0, 0, rot);
	Matrix::SetTranslation(model, pos.x, pos.y, 0);
	//void Matrix::SetScale(const float[]&inout a, float x, float y, float z)
	Render::SetModelTransform(model);
	Render::RawQuads(texture_name, Shield_Vertices);
}
