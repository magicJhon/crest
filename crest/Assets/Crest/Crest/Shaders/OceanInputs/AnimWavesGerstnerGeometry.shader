﻿// Crest Ocean System

// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE)

Shader "Crest/Inputs/Animated Waves/Gerstner Geometry"
{
    Properties
    {
		_FeatherWaveStart("Feather wave start (0-1)", Range( 0.0, 0.5 ) ) = 0.1
		_FeatherFromSplineEnd("Feather from spline end (m)", Range( 0.0, 100.0 ) ) = 0.0
		_UseShallowWaterAttenuation("Use Shallow Water Attenuation", Range(0, 1)) = 1
	}

    SubShader
    {
		// Additive blend everywhere
		Blend One One
		ZWrite Off
		ZTest Always
		Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma enable_d3d11_debug_symbols

            #include "UnityCG.cginc"

			#include "../OceanGlobals.hlsl"
			#include "../OceanInputsDriven.hlsl"
			#include "../OceanHelpersNew.hlsl"

			struct appdata
            {
                float4 vertex : POSITION;
                float2 axis : TEXCOORD0;
				float2 distToSplineEnd_invNormDistToShoreline : TEXCOORD1;
            };

            struct v2f
            {
				float4 vertex : SV_POSITION;
				float3 uv_slice : TEXCOORD1;
				float axisHeading : TEXCOORD2;
				float3 worldPosScaled : TEXCOORD3;
				float2 distToSplineEnd_invNormDistToShoreline : TEXCOORD4;
            };

			Texture2DArray _WaveBuffer;

			CBUFFER_START(GerstnerPerMaterial)
			half _FeatherWaveStart;
			half _FeatherFromSplineEnd;
			float _UseShallowWaterAttenuation;
			CBUFFER_END

			CBUFFER_START(CrestPerOceanInput)
			int _WaveBufferSliceIndex;
			float _AverageWavelength;
			float _AttenuationInShallows;
			float _Weight;
			CBUFFER_END

            v2f vert(appdata v)
            {
                v2f o;

				// We take direction of vert, not its position
				float3 positionOS = v.vertex.xyz;

				o.vertex = UnityObjectToClipPos(positionOS);

				// UV coordinate into the cascade we are rendering into
				float3 worldPos = mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
				o.uv_slice.xyz = WorldToUV(worldPos.xz, _CrestCascadeData[_LD_SliceIndex], _LD_SliceIndex);

				const float waveBufferSize = 0.5f * (1 << _WaveBufferSliceIndex);
				o.worldPosScaled = worldPos / waveBufferSize;

				o.axisHeading = atan2( v.axis.y, v.axis.x ) + 2.0 * 3.141592654;

				o.distToSplineEnd_invNormDistToShoreline = v.distToSplineEnd_invNormDistToShoreline;

                return o;
            }

            float4 frag(v2f input) : SV_Target
            {
				float wt = _Weight;

				// Attenuate if depth is less than half of the average wavelength
				const half depth = _LD_TexArray_SeaFloorDepth.SampleLevel(LODData_linear_clamp_sampler, input.uv_slice.xyz, 0.0).x;
				const half depth_wt = saturate(2.0 * depth / _AverageWavelength);
				const float attenuationAmount = _AttenuationInShallows * _UseShallowWaterAttenuation;
				wt *= attenuationAmount * depth_wt + (1.0 - attenuationAmount);

				// Feature at front/back
				wt *= min( input.distToSplineEnd_invNormDistToShoreline.y / _FeatherWaveStart, 1.0 );
				if( _FeatherFromSplineEnd > 0.0 ) wt *= saturate( input.distToSplineEnd_invNormDistToShoreline.x / _FeatherFromSplineEnd );

				// Quantize wave direction and interpolate waves
				const float dTheta = 0.5*0.314159265;
				float angle0 = input.axisHeading;
				const float rem = fmod( angle0, dTheta );
				angle0 -= rem;
				const float angle1 = angle0 + dTheta;

				const float2 axisX0 = float2(cos( angle0 ), sin( angle0 ));
				const float2 axisX1 = float2(cos( angle1 ), sin( angle1 ));
				float2 axisZ0; axisZ0.x = -axisX0.y; axisZ0.y = axisX0.x;
				float2 axisZ1; axisZ1.x = -axisX1.y; axisZ1.y = axisX1.x;

				const float2 uv0 = float2(dot( input.worldPosScaled.xz, axisX0 ), dot( input.worldPosScaled.xz, axisZ0 ));
				const float2 uv1 = float2(dot( input.worldPosScaled.xz, axisX1 ), dot( input.worldPosScaled.xz, axisZ1 ));

				// Sample displacement, rotate into frame
				float4 disp_variance0 = _WaveBuffer.SampleLevel( sampler_Crest_linear_repeat, float3(uv0, _WaveBufferSliceIndex), 0 );
				float4 disp_variance1 = _WaveBuffer.SampleLevel( sampler_Crest_linear_repeat, float3(uv1, _WaveBufferSliceIndex), 0 );
				disp_variance0.xz = disp_variance0.x * axisX0 + disp_variance0.z * axisZ0;
				disp_variance1.xz = disp_variance1.x * axisX1 + disp_variance1.z * axisZ1;
				const float alpha = rem / dTheta;
				float4 disp_variance = lerp( disp_variance0, disp_variance1, alpha );

				// The large waves are added to the last two lods. Don't write cumulative variances for these - cumulative variance
				// for the last fitting wave cascade captures everything needed.
				const float minWavelength = _AverageWavelength / 1.5;
				if( minWavelength > _CrestCascadeData[_LD_SliceIndex]._maxWavelength )
				{
					disp_variance.w = 0.0;
				}

				return wt * disp_variance;
            }
            ENDCG
        }
    }
}
