// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "CustomStandard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertBase
            #pragma fragment fragBase
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }
    }

    SubShader
    {
        Pass
        {
            Name "MyClosestHit"
            Tags{ "LightMode" = "RayTracing" }

            HLSLPROGRAM
            #include "RayPayload.cginc"

            #pragma raytracing MyRayTracing
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION

            // behaviour if accept hit
            [shader("closesthit")]
            void MyClosestHit(inout RayPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
            {
                Vertex i = GetVertex(attribs);

                // if it is not a shadow ray, cast shadow
                float atten = 1.0f;

                if (payload.isTestReflection)
                {
                    // recursive result (for both opaque/transparent)
                    RayPayload recursiveResult = (RayPayload)0;
                    recursiveResult.color = 0;
                    recursiveResult.isTestReflection = true;

                    RayPayload recursiveResultTrans = (RayPayload)0;
                    recursiveResultTrans.color = 0;
                    recursiveResultTrans.isTestReflection = true;

                    if (payload.reflectionDepth < MAX_REFLECT_RESURSION)
                    {
                        // recursive ray
                        RayDesc recursiveRay;
                        recursiveRay.Origin = i.worldPosition;
                        recursiveRay.Direction = reflect(WorldRayDirection(), i.normal);   // shoot a reflection ray
                        recursiveRay.TMin = 0.1f;
                        recursiveRay.TMax = 50.0f;

                        // opaque reflection
                        recursiveResult.reflectionDepth = payload.reflectionDepth + 1;
                        TraceRay(_SceneAS, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0x1, 0, 1, 0, recursiveRay, recursiveResult);

                        // transparent reflection
                        recursiveResultTrans.reflectionDepth = payload.reflectionDepth + 1;
                        TraceRay(_SceneAS, RAY_FLAG_CULL_BACK_FACING_TRIANGLES | RAY_FLAG_CULL_OPAQUE, 0x02, 0, 1, 0, recursiveRay, recursiveResultTrans);

                        // alpha blending
                        recursiveResult.color.rgb = lerp(recursiveResult.color.rgb, recursiveResultTrans.color.rgb, recursiveResultTrans.color.a);

                        // reflection needs shadows too
                        atten = GetShadowAtten(i.worldPosition);
                    }
                    else
                    {
                        recursiveResult.color = RaySky();
                    }

                    // if it is recursive, carry the result as indirect specular
                    if (payload.reflectionDepth > 1)
                    {
                        payload = RayForwardPass(payload, i, RayTCurrent(), false, false, atten, recursiveResult.color);
                    }
                    else
                    {
                        payload = recursiveResult;
                    }
                }
                else if (!payload.isTestShadow)
                {
                    atten = GetShadowAtten(i.worldPosition);

                    // smooth to mip map
                    float roughness = 1 - _Glossiness * _Glossiness;
                    float specMip = roughness * GetNumberOfLevels(_ReflectionRT);
                    float2 uv = (DispatchRaysIndex().xy + 0.5f) / DispatchRaysDimensions().xy;

                    float4 reflectionColor = _ReflectionRT.SampleLevel(sampler_linear_repeat, uv, specMip);
                    payload = RayForwardPass(payload, i, RayTCurrent(), !payload.isTransparent, true, atten, reflectionColor.rgb);
                }
            }

            // behaviour if hit transparency object
            [shader("anyhit")]
            void MyAnyHit(inout RayPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
            {
                Vertex i = GetVertex(attribs);
                float2 uvMain = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                float alpha = DistanceSample(_MainTex, sampler_linear_repeat, uvMain, i.worldPosition).a * _Color.a;

                #if _ALPHATEST_ON
                    if (alpha - _Cutoff < 0)
                    {
                        IgnoreHit();
                    }
                #endif

                #if _ALPHABLEND_ON || _ALPHAPREMULTIPLY_ON
                    if (alpha < 0.1f && !payload.isTestReflection)
                    {
                        IgnoreHit();
                    }

                    payload.isTransparent = true;
                    if (payload.isTestShadow)
                    {
                        payload.shadowAtten = lerp(1, payload.shadowAtten, alpha);
                    }

                #endif
            }

            ENDHLSL
         }
    }


    //FallBack "VertexLit"
    CustomEditor "StandardShaderGUI"
}
