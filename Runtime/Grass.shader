Shader "Custom/Grass"
{
	Properties
	{
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 2.0

		[Header(Main Settings)]
        [Space]
        _MainColor("Main Color", Color) = (1,1,1,1)
        _MainTex("Main Texture", 2D) = "white" {}
        [Space]
        [Header(Shade Settings)]
        [Space]
        _ShadeBlend("Shade Blend", Range(0, 1)) = .05
        _ShadeFactor("Shade Factor", Range(0, 1)) = .7
        [Space]
        [Header(Specular Settings)]
        [Space]
        [MaterialToggle] _SpecularEnabled("Enabled", Float) = 1
        [HDR] _SpecularColor("Color", Color) = (0.15, 0.15, 0.15, 1)
        _Glossiness("Glossiness", Range(0, 45)) = 32
        [Space]
        [Header(Rim Settings)]
        [Space]
        [MaterialToggle] _RimEnabled("Enabled", Float) = 1
        [HDR] _RimColor("Color", Color) = (0.1, 0.1, 0.1, 1)
        _RimAmount("Angle Threshold", Range(0, 1)) = 0.8
        _RimThreshold("Shade Threshold", Range(0, 1)) = 0.5
        [Space]
        [Header(Cutout Settings)]
        [Space]
        _AlphaCutoff("Alpha Cutoff", Range(0, 1)) = 0.5
		[Space]
        [Header(Wave Settings)]
        [Space]
		_WaveSpeed("Wave Speed", Range(0.0,100.0)) = 3.0
		_WaveHeight("Wave Height", Range(0.0,30.0)) = 5.0
        [Space]
        [Header(Scaling)]
        [Space]
		[MaterialToggle] _ScaleOnX("Scale On X", Float) = 1
		[MaterialToggle] _ScaleOnY("Scale On Y", Float) = 1
		[MaterialToggle] _ScaleOnZ("Scale On Z", Float) = 1
		[Space]
		[Header(Origin Offset)]
        [Space]
		_Xoffset("X Offset", Float) = 0.0
		_Yoffset("Y Offset", Float) = 0.0
		_Zoffset("Z Offset", Float) = 0.0
		[Space]
		[Header(Sway Direction)]
        [Space]
		_XSwayDirection("X Sway", Float) = 0.0
		_YSwayDirection("Y Sway", Float) = 0.0
		_ZSwayDirection("Z Sway", Float) = 0.0
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True"}
		Cull Off
        Blend SrcAlpha OneMinusSrcAlpha
		Pass
		{
			Tags
            {
                "LightMode" = "ForwardBase"
                "PassFlags" = "OnlyDirectional"
            }
			
            Cull [_CullMode]

            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

			struct appdata
            {
                float4 vertex : POSITION;               
                float4 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldNormal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                SHADOW_COORDS(2)
                UNITY_FOG_COORDS(3)
            };

			float4 _MainColor;
			sampler2D _MainTex;
			float4 _MainTex_ST;

            float _ShadeBlend;
            float _ShadeFactor;

            float _SpecularEnabled;
            float4 _SpecularColor;
            float _Glossiness;      

            float _RimEnabled;
            float4 _RimColor;
            float _RimAmount;
            float _RimThreshold;
            
			half _WaveSpeed;
			half _WaveHeight;
            
            half _ScaleOnX;
			half _ScaleOnY;
			half _ScaleOnZ;
            
            half _XSwayDirection;
			half _YSwayDirection;
			half _ZSwayDirection;
            
			half _Xoffset;
			half _Yoffset;
			half _Zoffset;
            
			float _AlphaCutoff;

			v2f vert (appdata v)
			{
				v2f o;
				const half amplitude = sin(-_Time.y * _WaveSpeed) * _WaveHeight;
				float xSway = _XSwayDirection * amplitude;
				float ySway = _YSwayDirection * amplitude;
				float zSway = _ZSwayDirection * amplitude;
				if (_ScaleOnX == 1)
				{
					const float multiplier = v.vertex.x + _Xoffset;
					xSway *= multiplier;
					ySway *= multiplier;
					zSway *= multiplier;
				}
				if (_ScaleOnY == 1)
				{
					const float multiplier = v.vertex.y + _Yoffset;
					xSway *= multiplier;
					ySway *= multiplier;
					zSway *= multiplier;
				}
				if (_ScaleOnZ == 1)
				{
					const float multiplier = v.vertex.z + _Zoffset;
					xSway *= multiplier;
					ySway *= multiplier;
					zSway *= multiplier;
				}
				v.vertex.x = v.vertex.x + xSway;
				v.vertex.y = v.vertex.y + ySway;
				v.vertex.z = v.vertex.z + zSway;
				o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);     
                o.viewDir = WorldSpaceViewDir(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                TRANSFER_SHADOW(o)
                UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

            float4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.worldNormal);
                float3 viewDir = normalize(i.viewDir);

                float NdotL = dot(_WorldSpaceLightPos0, normal);
                float shadow = SHADOW_ATTENUATION(i); // 0 = shaded, 1 = not.

                // Partition the intensity into light and dark
                float lightIntensity = smoothstep(-_ShadeBlend, _ShadeBlend, NdotL * shadow);
                float shadowfactor = lerp(_ShadeFactor, 1, lightIntensity);
                half4 ambientColor = half4(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w, 1);
                float4 lightness = float4(_LightColor0.x + unity_SHAr.w, _LightColor0.y + unity_SHAg.w, _LightColor0.z + unity_SHAb.w, 1);
                float4 shadowness = float4(shadowfactor, shadowfactor, shadowfactor, 1);

                float4 sample = tex2D(_MainTex, i.uv);
                
                if (sample.a < _AlphaCutoff) discard;

                half4 color = _MainColor * sample * lightness * shadowness;

                if (_SpecularEnabled == 1)
                {
                    float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
                    float NdotHalfVector = dot(normal, halfVector);
                    float specularIntensity = pow(NdotHalfVector * lightIntensity, _Glossiness * _Glossiness);
                    float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
                    float4 specular = specularIntensitySmooth * _SpecularColor;
                    specular.a = 1;
                    color += specular;
                }

                if (_RimEnabled == 1)
                {
                    float rimDot = 1 - dot(viewDir, normal);
                    float rimIntensity = rimDot * pow(NdotL, _RimThreshold);
                    rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
                    float4 rim = rimIntensity * _RimColor;
                    rim.a = 1;
                    color += rim;
                }
                
                UNITY_APPLY_FOG(i.fogCoord, color);
                
                return color;
            }
            ENDCG
        }
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
		}
	Fallback "Standard"
}