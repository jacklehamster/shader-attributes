#version 300 es

precision highp float;

const int START_FRAME_INDEX = 0;
const int END_FRAME_INDEX = 1;
const int FRAME_RATE_INDEX = 2;
const int MAX_FRAME_COUNT_INDEX = 3;

const int ANIMATION_UPDATE_INDEX = 0;
const int MOTION_UPDATE_INDEX = 1;

const int TEXTURE_INDEX = 0;
const int LIGHT_INDEX = 1;
const int OPACITY_INDEX = 2;
const int SPRITE_TYPE_INDEX = 3;

const float IS_HUD = 1.;
const float IS_SPRITE = 2.;
const float IS_WAVE = 3.;
const float IS_CIRCLE = 4.;
const float IS_SHADOW = 5.;
const float IS_WIGGLE = 6.;
const float IS_BOUNCE = 7.;
const float IS_SPIN = 8.;

const mat4 IDENTITY = mat4(1.0);


in vec2 vertexPosition;
//attribute vec3 normal;	//	WIP here
in mat4 matrix;				//	4x4
in vec3 motion;					//	[+1]
in vec3 acceleration;		//	[+1]
in vec4 textureIndex;		//	[ubyte] TEXTURE_INDEX / LIGHT / OPACITY / SPRITE_TYPE
in mat4 textureCoordinates;	//	4x4
in vec4 animationInfo;		//	START,END,FRAMERATE,MAX_FRAME_COUNT
in vec4 spriteSheet;			//	[ushort] col,(row),hotspot_x,hotspot_y
in vec2 updateTime;			//	motion_update, animation_update	[+2]

uniform float isPerspective;
uniform float timeInfo;
uniform mat4 perspective;
uniform mat4 ortho;
uniform mat4 view;
uniform mat4 hudView;
uniform mat3 clamp;
uniform mat4 spriteMatrix;
uniform float globalLight;

out vec2 v_textureCoord;
out float v_index;
out float v_opacity;
out float v_light;
out float v_saturation;
out vec2 v_tex01;


vec4 getCornerValue(mat4 textureCoordinates, vec2 position);
float modPlus(float a, float b);
vec2 getTextureShift(vec4 spriteSheet, vec4 animInfo, mat4 textureCoordinates, float time);
vec3 modClampPosition(vec3 position, mat3 clamp);
vec3 applyMotion(float dt, vec3 motion, vec3 acceleration);

float random(vec2 p){return fract(cos(dot(p,vec2(23.14069263277926,2.665144142690225)))*12345.6789);}


void main() {
	float time = timeInfo;
	
	float isFlag = textureIndex[SPRITE_TYPE_INDEX];
	float isHud = max(0., 1. - abs(isFlag - IS_HUD));
	float isWiggle = max(0., 1. - abs(isFlag - IS_WIGGLE));
	float isBounce = max(0., 1. - abs(isFlag - IS_BOUNCE));
	float isSpin = max(0., 1. - abs(isFlag - IS_SPIN));
	float isSprite = max(isSpin, max(isBounce, max(isWiggle, 1. - abs(isFlag - IS_SPRITE))));
	float isWave = max(0., 1. - abs(isFlag - IS_WAVE));
	float isCircle = max(0., 1. - abs(isFlag - IS_CIRCLE));

	vec4 textureInfo = getCornerValue(textureCoordinates, vertexPosition);
	vec2 textureShift = getTextureShift(spriteSheet, animationInfo, textureCoordinates, time);
	v_textureCoord = (textureInfo.xy + textureShift) / 4096.;
	v_index = textureIndex[TEXTURE_INDEX];

	vec2 vPos = vec2(vertexPosition.x, vertexPosition.y * (1. + isBounce * sin(time/30.) * .2));
	float cosRot = cos(time/30.), sinRot = sin(time/30.);
	vec2 vRot = vPos * (1. - isSpin) + isSpin * vec2(vPos.x * cosRot - vPos.y * sinRot, vPos.x * sinRot + vPos.y * cosRot);

	vec2 hotspot = spriteSheet.zw;
	vec4 vertexPosition4 = vec4(vRot + hotspot * vec2(-.002, .002) + vec2(1., -1.), 0., 1.);

	mat4 finalView = isHud * hudView + (1. - isHud) * view;

	float motionTime = updateTime[MOTION_UPDATE_INDEX];
	float dt = (time - motionTime) / 1000.;
	mat4 mat = matrix;

	mat4 shift = IDENTITY;
	shift[3] = mat[3];

	shift[3].xyz = shift[3].xyz + applyMotion(dt, motion, acceleration);
	mat[3].xyz = vec3(0, 0, 0);

	v_opacity = textureIndex[OPACITY_INDEX] / 128.;

	mat4 spMatrix = isSprite * spriteMatrix + (1. - isSprite) * IDENTITY;

	vec4 worldPosition = shift * spMatrix * mat * vertexPosition4;
	float noise = random(worldPosition.xz) * 13.;
	worldPosition.y += isWave * sin(time/2000. + noise) * 10.;
	worldPosition.z += isWiggle * sin(time/100.) * 20.;
	worldPosition.x += isWiggle * sin(time/200.) * 20.;

	mat4 finalViewShift = finalView;
	finalViewShift[3].xyz = modClampPosition(finalViewShift[3].xyz, clamp);
	vec4 relativePosition = finalViewShift * worldPosition;

	float lightDistance = 1. + -100.0 / length(relativePosition);
	v_light = 1.00 * globalLight * textureIndex[LIGHT_INDEX] / 128. * lightDistance;
	v_light += isWave * sin(time/1000. + noise * 33.) * .2;

	float isOrtho = max(isHud, 1. - isPerspective);
	mat4 projection = ortho * isOrtho + perspective * (1. - isOrtho);
	vec4 position = projection * relativePosition;

	gl_Position = position;
	v_tex01 = vertexPosition.xy * isCircle;
}

vec3 applyMotion(float dt, vec3 motion, vec3 acceleration) {
	float dt2 = dt * dt;
	return dt * motion + 0.5 * dt2 * acceleration;
}

float modClampFloat(float value, float low, float range) {
	return low + mod(value - low, range);
}

vec3 modClampPosition(vec3 position, mat3 clamp) {
	vec3 xClamp = clamp[0];
	vec3 yClamp = clamp[1];
	vec3 zClamp = clamp[2];
	return vec3(
		modClampFloat(position.x, xClamp[0], xClamp[1]),
		modClampFloat(position.y, yClamp[0], yClamp[1]),
		modClampFloat(position.z, zClamp[0], zClamp[1]));
}


vec4 getCornerValue(mat4 textureCoordinates, vec2 position) {
	return mix(
		mix(textureCoordinates[0], textureCoordinates[1], position.x * .5 + .5), 
		mix(textureCoordinates[2], textureCoordinates[3], position.x * .5 + .5),
		position.y * .5 + .5);	
}

float modPlus(float a, float b) {
	return mod(a + .4, b);
}

vec2 getTextureShift(vec4 spriteSheet, vec4 animInfo, mat4 textureCoordinates, float time) {
	float animCols = spriteSheet[0];
	if (animCols == 0.) {
		return vec2(0, 0);
	}
	float animTime = updateTime[ANIMATION_UPDATE_INDEX];
	vec2 frameRange = vec2(animInfo[START_FRAME_INDEX], animInfo[END_FRAME_INDEX]);
	float frameCount = max(0., frameRange[1] - frameRange[0]) + 1.;

	float framePerSeconds = abs(animInfo[FRAME_RATE_INDEX]);
	float globalFrame = floor(min(
		(time - animTime) * framePerSeconds / 1000.,
		animInfo[MAX_FRAME_COUNT_INDEX]));

	float frameOffset = modPlus(globalFrame, frameCount);
	float frame;
	if (animInfo[FRAME_RATE_INDEX] > 0.) {
		frame = frameRange[0] + frameOffset;
	} else {
		frame = frameRange[1] - frameOffset;
	}

	float row = floor(frame / animCols);
	float col = floor(frame - row * animCols);

	vec2 cell = vec2(col, row);
	vec2 spriteRect = abs(textureCoordinates[0].xy - textureCoordinates[3].xy);
	return cell * spriteRect;
}

