//==========================================================
//
#region DECLARE: GLOBAL SETTINGS.


// precision highp float;


#endregion
// 
//==========================================================
//
#region DECLARE: SAMPLERS.


#define	texA gm_BaseTexture	// Just so it is more condensed,
uniform sampler2D texB;		// and matches name with this.


#endregion
// 
//==========================================================
//
#region DECLARE: UNIFORMS.


uniform int uniAction;
uniform vec2 uniTexel;
uniform vec3 uniShape;
uniform float uniThreshold;	
uniform float uniJumpMax;	
uniform vec3 uniJumpA;	
uniform vec3 uniJumpB;	


#endregion
// 
//==========================================================
//
#region DECLARE: VALUE ENCODER.


float DecodeValue(float _pack);
vec2 DecodeValue(vec2 _pack);
vec3 DecodeValue(vec3 _pack);
vec4 DecodeValue(vec4 _pack);

float EncodeValue(float _value);
vec2 EncodeValue(vec2 _value);
vec3 EncodeValue(vec3 _value);
vec4 EncodeValue(vec4 _value);


#endregion
// 
//==========================================================
//
#region DECLARE: POSITION ENCODER FUNCTIONS.


vec2 PositionLUTto2D(vec4 _positionLUT);
vec4 Position2DtoLUT(vec2 _position2D);

vec2 Position3Dto2D(vec3 _position3D);
vec3 Position2Dto3D(vec2 _position2D);

vec3 PositionLUTto3D(vec4 _positionLUT);
vec4 Position3DtoLUT(vec3 _position3D);


#endregion
// 
//==========================================================
//
#region DECLARE: FIELD ENCODER FUNCTIONS.


vec3 EncodeNormal(vec3 _normal);
vec3 DecodeNormal(vec3 _pack);

float EncodeDistance(float _dist);
float EncodeDistance(float _pack);

vec4 EncodeField(vec4 _dist);
vec4 DecodeField(vec4 _pack);


#endregion
// 
//==========================================================
//
#region DECLARE: SAMPLING FUNCTIONS.


vec4 Sample2D(sampler2D _tex, vec2 _position2D);
vec4 Sample3D(sampler2D _tex, vec3 _position3D);
vec4 SampleLUT(sampler2D _tex, vec4 _position4D);


#endregion
// 
//==========================================================
//
#region DECLARE: ACTIONS.


void ActionSeed();
void ActionReverse();
void ActionPass();
void ActionFill();
void ActionField();
void ActionShrink();


#endregion
// 
//==========================================================
//
#region THE MAIN LOOP.


void main()
{
		 if (uniAction == 0) ActionSeed();
	else if (uniAction == 1) ActionReverse();
	else if (uniAction == 2) ActionPass();
	else if (uniAction == 3) ActionFill();
	else if (uniAction == 4) ActionField();
}

#endregion
// 
//==========================================================
//
#region DEFINE: SELECT SEED COORDINATES.


void ActionSeed()
{
	// Look current value.
	vec2 _position2D = floor(gl_FragCoord.xy);
	vec4 _sample = Sample2D(texA, _position2D);
	vec3 _pack = EncodeValue(Position2Dto3D(_position2D));
	
	// Save coordinate, store whether it points to seed.
	gl_FragData[0] = vec4(_pack, (_sample.a >= uniThreshold));
}


void ActionReverse()
{
	vec4 _pack = Sample2D(texA, floor(gl_FragCoord.xy));
	gl_FragData[0] = vec4(_pack.xyz, 1.0 - _pack.w);
}


#endregion
// 
//==========================================================
//
#region DEFINE: ACTION JUMP FLOOD PASS.


void ActionPass()
{
	// Preparations. 
	vec2 _position2D = floor(gl_FragCoord.xy);
	vec3 _position3D = Position2Dto3D(_position2D);
	float _smallest = uniJumpMax;
	
	// Get origin and two neighbours. Origin is default value.
	vec4 _coordO = DecodeValue(Sample2D(texA, _position2D));
	vec4 _coordA = DecodeValue(Sample3D(texA, _position3D + uniJumpA));
	vec4 _coordB = DecodeValue(Sample3D(texA, _position3D + uniJumpB));
		
	// Check whether neighbour A points to seed, and is closer.
	if (_coordA.w > 128.0)
	{
		float _distance = distance(_position3D, _coordA.xyz);
		if (_distance < _smallest) 
		{
			_smallest = _distance;
			_coordO = _coordA;
		}
	}
	
	// Check whether neighbour B points to seed, and is closer.
	if (_coordB.w > 128.0)
	{
		float _distance = distance(_position3D, _coordB.xyz);
		if (_distance < _smallest) 
		{
			_smallest = _distance;
			_coordO = _coordB;
		}
	}
	
	// Save the coordinates.
	gl_FragData[0] = EncodeValue(_coordO);
}


#endregion
// 
//==========================================================
//
#region DEFINE: ACTION FILL WITH SEED VALUES.


void ActionFill()
{
	// Get coordinate to seed, find the seed value.
	vec2 _position2D = floor(gl_FragCoord.xy);
	vec4 _pack = Sample2D(texA, _position2D);
	vec3 _position3D = DecodeValue(_pack.xyz);
	gl_FragData[0] = Sample3D(texB, _position3D);
}


#endregion
// 
//==========================================================
//
#region DEFINE: ACTION GENERATE NORMAL + SIGNED DISTANCE FIELD.


void ActionField()
{
	// Get coordinates to closest seeds.
	vec2 _position2D = floor(gl_FragCoord.xy);
	vec3 _position3D = Position2Dto3D(_position2D);
	vec4 _regular = DecodeValue(Sample2D(texA, _position2D));
	vec4 _reverse = DecodeValue(Sample2D(texA, _position2D));
	
	// Calculate signed distance.
	float _distanceA = distance(_position3D, _regular.xyz);
	float _distanceB = distance(_position3D, _reverse.xyz);
	float _signedDistance = _distanceA - _distanceB;
	
	// Calculate normals.
	vec3 _normals = vec3(0.0);
	if (_signedDistance > 0.0) 
	{
		_normals = normalize(_regular.xyz - _position3D);
	} else if (_signedDistance < 0.0)
	{
		_normals = normalize(_position3D - _reverse.xyz);
	}
	
	// Save the normals and singed distance.
	gl_FragData[0] = EncodeField(vec4(_normals, _signedDistance));
}


#endregion
// 
//==========================================================
//
#region DEFINE: VALUE ENCODER.


float DecodeValue(float _pack)
{
	return floor(_pack * 255.0);
}


vec2 DecodeValue(vec2 _pack)
{
	return floor(_pack * 255.0);
}


vec3 DecodeValue(vec3 _pack)
{
	return floor(_pack * 255.0);
}

vec4 DecodeValue(vec4 _pack)
{
	return floor(_pack * 255.0);
}


float EncodeValue(float _value)
{
	return (clamp(floor(_value), 0.0, 255.0) / 255.0);
}


vec2 EncodeValue(vec2 _value)
{
	return (clamp(floor(_value), vec2(0.0), vec2(255.0)) / 255.0);
}


vec3 EncodeValue(vec3 _value) 
{
	return (clamp(floor(_value), vec3(0.0), vec3(255.0)) / 255.0);
}


vec4 EncodeValue(vec4 _value)
{
	return (clamp(floor(_value), vec4(0.0), vec4(255.0)) / 255.0);
}


#endregion
// 
//==========================================================
//
#region DEFINE: POSITION ENCODER FUNCTIONS.


vec2 PositionLUTto2D(vec4 _positionLUT)
{
	return _positionLUT.xy + _positionLUT.zw * uniShape.xy * 16.0;
}


vec4 Position2DtoLUT(vec2 _position2D)
{
	vec4 _positionLUT;
	vec2 _zfactor = uniShape.xy * 16.0;
	_positionLUT.zw = floor(_position2D / _zfactor);
	_positionLUT.xy = _position2D - _positionLUT.zw * _zfactor;
	return _positionLUT;
}


vec2 Position3Dto2D(vec3 _position3D)
{
	vec2 _position2D;
	float _zfactor = floor(_position3D.z / 16.0);
	_position2D.x = _position3D.x + _position3D.z - _zfactor * 16.0;
	_position2D.y = _position3D.y + _zfactor;
	return _position2D;
}


vec3 Position2Dto3D(vec2 _position2D)
{
	vec3 _position3D;
	vec2 _zfactor = floor(_position2D / 16.0);
	_position3D.xy = _position2D - _zfactor * 16.0;
	_position3D.z = _zfactor.x + _zfactor.y * 16.0;
	return _position3D;
}


vec3 PositionLUTto3D(vec4 _positionLUT)
{
	return vec3(_positionLUT.yx, _positionLUT.z + _positionLUT.w * 16.0);
}


vec4 Position3DtoLUT(vec3 _position3D)
{
	float _w = floor(_position3D.z / 16.0);
	return vec4(_position3D.xy, _position3D.z - _w * 16.0, _w);
}


#endregion
// 
//==========================================================
//
#region DEFINE: FIELD ENCODER FUNCTIONS.


vec3 EncodeNormal(vec3 _normal)
{
	return (_normal + 1.0) / 2.0;
}


vec3 DecodeNormal(vec3 _pack)
{
	return (_pack * 2.0 - 1.0);
}


float EncodeDistance(float _dist)
{
	return floor(_dist + 128.0) / 255.0;
}


float DecodeDistance(float _pack)
{
	return _pack * 255.0 - 128.0;
}


vec4 EncodeField(vec4 _field)
{
	return vec4(
		EncodeNormal(_field.xyz),
		EncodeDistance(_field.w)
	);
}


vec4 DecodeField(vec4 _pack)
{
	return vec4(
		DecodeNormal(_pack.xyz),
		DecodeDistance(_pack.w)
	);
}


#endregion
// 
//==========================================================
//
#region DEFINE: SAMPLING FUNCTIONS.


vec4 Sample2D(sampler2D _tex, vec2 _position2D)
{
	return texture2D(_tex, (_position2D + 0.5) / uniTexel);
}


vec4 Sample3D(sampler2D _tex, vec3 _position3D)
{
	_position3D = clamp(_position3D, vec3(0.0), uniShape-1.0);
	return Sample2D(_tex, Position3Dto2D(_position3D));
}


vec4 SampleLUT(sampler2D _tex, vec4 _positionLUT)
{
	return Sample2D(_tex, PositionLUTto2D(_positionLUT));
}


#endregion
// 
//==========================================================








