#include "UnityShaderVariables.cginc"
#include "UnityRaytracingMeshUtils.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityStandardBRDF.hlsl"

// pay load define
struct RayPayload
{
    float4 color;
    float depth;
    float shadowAtten;
    bool isTransparent;
    bool isTestShadow;
    bool isTestReflection;
    int reflectionDepth;
};

// properties
float4 _Color;
Texture2D _MainTex;
float4 _MainTex_ST;
SamplerState sampler_linear_repeat;
float _Cutoff;
float _Metallic;
float _Glossiness;
Texture2D _EmissionMap;
float4 _EmissionColor;

// custom variables
RaytracingAccelerationStructure _SceneAS;
float4 _CustomCameraSpacePos;    // w is far
Texture2D _ReflectionRT;

// sky texture
TextureCube _ClearSkybox;
SamplerState sampler_ClearSkybox;

// defines
#define FLOAT_EPSILON 1.192092896e-07
#define unity_ColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
#define MAX_REFLECT_RESURSION 4

// functions
struct AttributeData
{
    float2 barycentrics;
};

struct Vertex
{
    float3 position;
    float3 normal;
    float2 uv;
    float3 worldPosition;
};

Vertex FetchVertex(uint vertexIndex)
{
    Vertex v;
    v.position = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
    v.normal = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
    v.uv = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
    return v;
}

Vertex InterpolateVertices(Vertex v0, Vertex v1, Vertex v2, float3 barycentrics)
{
    Vertex v;
#define INTERPOLATE_ATTRIBUTE(attr) v.attr = v0.attr * barycentrics.x + v1.attr * barycentrics.y + v2.attr * barycentrics.z
    INTERPOLATE_ATTRIBUTE(position);
    INTERPOLATE_ATTRIBUTE(normal);
    INTERPOLATE_ATTRIBUTE(uv);
    return v;
}

Vertex GetVertex(AttributeData attribs)
{
    // fetch vertex data
    uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());

    Vertex v0, v1, v2;
    v0 = FetchVertex(triangleIndices.x);
    v1 = FetchVertex(triangleIndices.y);
    v2 = FetchVertex(triangleIndices.z);

    float3 barycentricCoords = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
    Vertex v = InterpolateVertices(v0, v1, v2, barycentricCoords);
    v.worldPosition = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
    v.normal = normalize(mul(v.normal, (float3x3)WorldToObject()));
    return v;
}

float GetNumberOfLevels(Texture2D _tex)
{
    //UINT MipLevel, float Width, float Height, float NumberOfLevels
    float w, h, m;
    _tex.GetDimensions(0, w, h, m);
    return m;
}

half2 MetallicGloss()
{
    return half2(_Metallic, _Glossiness);
}

half OneMinusReflectivityFromMetallic(half metallic)
{
    half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

half3 DiffuseAndSpecularFromMetallic(half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
{
    specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

float4 DistanceSample(Texture2D _tex, SamplerState _sampler, float2 _uv, float3 _wpos)
{
    float distToCam = length(_wpos - _CustomCameraSpacePos.xyz);
    float ratio = saturate(distToCam / _CustomCameraSpacePos.w);
    float mipScale = _CustomCameraSpacePos.w / 1000 * 10;
    float mip = lerp(0, GetNumberOfLevels(_tex), ratio * mipScale);

    return _tex.SampleLevel(_sampler, _uv, mip);
}

half3 Emission(float2 uv, float3 wpos)
{
#ifndef _EMISSION
    return 0;
#else
    return DistanceSample(_EmissionMap, sampler_linear_repeat, uv, wpos).rgb * _EmissionColor.rgb;
#endif
}

UnityLight MainLight()
{
    UnityLight l;

    l.color = _LightColor0.rgb;
    l.dir = _WorldSpaceLightPos0.xyz;
    return l;
}

// it's like fragment shader
RayPayload RayForwardPass(RayPayload currPayload, Vertex i, float tHit, bool zWrite, bool zTest, float atten, float3 indirectSpecular)
{
    // depth test
    if (tHit > currPayload.depth && zTest)
    {
        return currPayload;
    }

    // SampleLevel since we can't use Sample()
    float2 uvMain = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    float4 albedo = DistanceSample(_MainTex, sampler_linear_repeat, uvMain, i.worldPosition);

    // metallic & gloss
    float2 mg = MetallicGloss();
    float3 specColor;
    float oneMinusReflectivity;
    float3 diffColor = DiffuseAndSpecularFromMetallic(albedo.rgb, mg.r, specColor, oneMinusReflectivity);

    // pbs
    float3 eyeVec = normalize(i.worldPosition - _CustomCameraSpacePos.xyz);
    UnityGI dummyGI = (UnityGI)0;
    dummyGI.light = MainLight();
    dummyGI.light.color *= atten;
    dummyGI.indirect.specular = indirectSpecular;
    float4 color = BRDF1_Unity_PBS(diffColor, specColor, oneMinusReflectivity, mg.g, i.normal, -eyeVec, dummyGI.light, dummyGI.indirect);

    // emission
    color.rgb += Emission(uvMain, i.worldPosition);

    // output
    color.a = albedo.a * _Color.a;
    currPayload.color = color;
    if (zWrite)
    {
        currPayload.depth = tHit;
    }

    return currPayload;
}

float4 RaySky()
{
    return _ClearSkybox.SampleLevel(sampler_ClearSkybox, WorldRayDirection(), 0);
}

float GetShadowAtten(float3 wpos)
{
    // shadow test ray
    RayPayload opaqueShadow = (RayPayload)0;
    opaqueShadow.isTestShadow = true;

    // test for main directional light shadow only
    UnityLight mainLight = MainLight();

    RayDesc ray;
    ray.Origin = wpos;
    ray.Direction = mainLight.dir;
    ray.TMin = 0.01f;
    ray.TMax = 50.0f;

    // test opaque/cutout shadow
    TraceRay(_SceneAS, RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, 0x1, 0, 1, 0, ray, opaqueShadow);

    // test fade shadow
    RayPayload alphaShadow = (RayPayload)0;
    alphaShadow.isTestShadow = true;

    TraceRay(_SceneAS, RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, 0x2, 0, 1, 0, ray, alphaShadow);

    return lerp(1, min(opaqueShadow.shadowAtten, alphaShadow.shadowAtten), 1 - _LightShadowData.x);
}

float DecodeFloatRG(float2 enc)
{
    float2 kDecodeDot = float2(1.0, 1 / 255.0);
    return dot(enc, kDecodeDot);
}

float3 DecodeViewNormalStereo(float4 enc4)
{
    float kScale = 1.7777;
    float3 nn = enc4.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
    float g = 2.0 / dot(nn.xyz, nn.xyz);
    float3 n;
    n.xy = g * nn.xy;
    n.z = g - 1;
    return n;
}

void DecodeDepthNormal(float4 enc, out float depth, out float3 normal)
{
    depth = DecodeFloatRG(enc.zw);
    normal = DecodeViewNormalStereo(enc);
}